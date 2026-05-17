---
title: "Feature Manager パターン — 5,000 行越えで破綻しない C++ 責務分離"
---

C++ 側のコードが 5,000 行を超えるあたりから、`MainWindow.cpp` に何でも書く設計は破綻する。本章では Markdown エディタが必要とする 4 つの責務を、それぞれ **単一責務の Manager クラス** に分離するパターンを示す。

## 責務マトリクス

| Manager | 責務 | 依存 |
|---|---|---|
| DocumentManager | 現在開いている .md のメタデータ (path / dirty / 最終保存時刻) | QFileSystemWatcher (任意) |
| ThemeManager | テーマ (light / dark / sepia / custom) と CSS variable の管理 | QSettings |
| AutoSaveManager | 一定間隔で draft を自動保存、復元する | QTimer / QStandardPaths |
| ExportManager | PDF / HTML / Docx 出力 | QPrinter / QTextDocument |

## DocumentManager

ファイル I/O と「現在のドキュメントの状態」を集中管理。

```cpp
// core/DocumentManager.h
#pragma once

#include <QObject>
#include <QString>

class DocumentManager : public QObject {
    Q_OBJECT
public:
    explicit DocumentManager(QObject *parent = nullptr);

    QString currentPath() const { return m_currentPath; }
    bool    isModified() const  { return m_modified; }

public slots:
    void openFile(const QString &path);
    void saveFile(const QString &markdown);
    void saveAs(const QString &path, const QString &markdown);
    void closeFile();
    void setModified(bool modified);

signals:
    void documentOpened(QString path, QString markdown);
    void documentSaved(QString path);
    void modifiedChanged(bool modified);
    void error(QString message);

private:
    QString m_currentPath;
    bool    m_modified = false;
};
```

```cpp
// core/DocumentManager.cpp (抜粋)
void DocumentManager::openFile(const QString &path) {
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        emit error(tr("ファイルを開けませんでした: %1").arg(path));
        return;
    }
    const QString markdown = QString::fromUtf8(f.readAll());
    m_currentPath = path;
    setModified(false);
    emit documentOpened(path, markdown);
}

void DocumentManager::saveFile(const QString &markdown) {
    if (m_currentPath.isEmpty()) {
        emit error(tr("保存先が未設定です"));
        return;
    }
    QFile f(m_currentPath);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text)) {
        emit error(tr("書き込みに失敗しました"));
        return;
    }
    f.write(markdown.toUtf8());
    setModified(false);
    emit documentSaved(m_currentPath);
}

void DocumentManager::setModified(bool modified) {
    if (m_modified == modified) return;
    m_modified = modified;
    emit modifiedChanged(modified);
}
```

EditorBridge (第 5 章) は薄く保ち、I/O は DocumentManager に委譲する。

## ThemeManager

```cpp
// core/ThemeManager.h
class ThemeManager : public QObject {
    Q_OBJECT
public:
    enum class Theme { Light, Dark, Sepia, Custom };

    Theme currentTheme() const { return m_theme; }
    QString currentThemeName() const;

public slots:
    void setTheme(Theme theme);
    void setCustomCss(const QString &css);

signals:
    void themeChanged(Theme theme, QString cssVariables);

private:
    Theme m_theme = Theme::Light;
    QString m_customCss;
    void loadFromSettings();
    void persist();
};
```

```cpp
QString ThemeManager::currentThemeName() const {
    switch (m_theme) {
        case Theme::Light:  return "light";
        case Theme::Dark:   return "dark";
        case Theme::Sepia:  return "sepia";
        case Theme::Custom: return "custom";
    }
    return "light";
}

void ThemeManager::setTheme(Theme theme) {
    if (m_theme == theme) return;
    m_theme = theme;
    persist();
    // CSS variables を Web 側に push する
    const auto css = buildCssVariables(theme);
    emit themeChanged(theme, css);
}
```

ThemeBridge (第 5 章で言及) はこの `themeChanged(theme, cssVariables)` を受けて、JS 側で `document.documentElement.style.setProperty('--bg', '#fff')` のように当てる。

```ts
// editor/src/theme-controller.ts
bridge.themeChanged.connect((theme, cssVariables) => {
  document.body.dataset.theme = theme;
  // cssVariables は "--bg:#fff;--fg:#222;..." の形を想定
  const root = document.documentElement;
  cssVariables.split(";").forEach((decl) => {
    const [k, v] = decl.split(":");
    if (k && v) root.style.setProperty(k.trim(), v.trim());
  });
});
```

## AutoSaveManager

```cpp
// core/AutoSaveManager.h
class AutoSaveManager : public QObject {
    Q_OBJECT
public:
    explicit AutoSaveManager(QObject *parent = nullptr);

    void start();
    void stop();
    QString recoverDraftFor(const QString &path) const;

public slots:
    void captureSnapshot(const QString &path, const QString &markdown);

signals:
    void snapshotSaved(QString path);

private:
    QTimer *m_timer;
    QString m_lastPath;
    QString m_lastMarkdown;
    QString draftDir() const;
    QString draftPathFor(const QString &origPath) const;
};
```

```cpp
AutoSaveManager::AutoSaveManager(QObject *parent)
    : QObject(parent), m_timer(new QTimer(this)) {
    m_timer->setInterval(15'000);   // 15 秒ごと
    connect(m_timer, &QTimer::timeout, this, [this]() {
        if (m_lastPath.isEmpty() || m_lastMarkdown.isEmpty()) return;
        QFile f(draftPathFor(m_lastPath));
        if (f.open(QIODevice::WriteOnly | QIODevice::Text)) {
            f.write(m_lastMarkdown.toUtf8());
            emit snapshotSaved(m_lastPath);
        }
    });
}

QString AutoSaveManager::draftDir() const {
    auto dir = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation);
    QDir().mkpath(dir + "/drafts");
    return dir + "/drafts";
}

QString AutoSaveManager::draftPathFor(const QString &origPath) const {
    // パスをハッシュにして衝突回避
    const auto hash = QCryptographicHash::hash(origPath.toUtf8(),
                                              QCryptographicHash::Sha1).toHex();
    return draftDir() + "/" + QString::fromUtf8(hash) + ".draft.md";
}

QString AutoSaveManager::recoverDraftFor(const QString &path) const {
    QFile f(draftPathFor(path));
    if (!f.open(QIODevice::ReadOnly)) return QString();
    return QString::fromUtf8(f.readAll());
}
```

起動時に `recoverDraftFor(lastOpenedPath)` を呼んで draft の有無を確認し、もしあれば「未保存の変更を復元しますか?」と聞く。これで Typora 的な「アプリ強制終了からの復元」が成り立つ。

## ExportManager

```cpp
// core/ExportManager.h
class ExportManager : public QObject {
    Q_OBJECT
public:
    enum class Format { Pdf, Html };

public slots:
    void exportAs(Format format, const QString &htmlContent, const QString &outPath);

signals:
    void exported(QString outPath);
    void exportFailed(QString reason);
};
```

```cpp
void ExportManager::exportAs(Format format, const QString &html, const QString &outPath) {
    if (format == Format::Html) {
        QFile f(outPath);
        if (!f.open(QIODevice::WriteOnly | QIODevice::Text)) {
            emit exportFailed(tr("書き込み不可")); return;
        }
        f.write(html.toUtf8());
        emit exported(outPath);
        return;
    }
    if (format == Format::Pdf) {
        QTextDocument doc;
        doc.setHtml(html);
        QPrinter printer(QPrinter::HighResolution);
        printer.setOutputFormat(QPrinter::PdfFormat);
        printer.setOutputFileName(outPath);
        doc.print(&printer);
        emit exported(outPath);
        return;
    }
}
```

`QTextDocument + QPrinter` の組み合わせで PDF 出力ができる。**ただしレイアウトは Web 側の見た目と完全には一致しない** (QTextDocument は独自の HTML サブセット解釈、メインスレッドをブロック)。

**実用上は `QWebEnginePage::printToPdf()` 一択** だ。WebView 側でレンダリング済みの見た目をそのまま PDF 化でき、非同期でメインスレッドをブロックしない。WYSIWYG エディタの PDF 出力は printToPdf() を選ぶ:

```cpp
m_webView->page()->printToPdf(
    [outPath](const QByteArray &data) {
        QFile f(outPath);
        if (f.open(QIODevice::WriteOnly)) f.write(data);
    },
    QPageLayout(QPageSize(QPageSize::A4),
                QPageLayout::Portrait,
                QMarginsF(15, 15, 15, 15)));
```

## Manager 群を MainWindow にぶら下げる

```cpp
class MainWindow : public QMainWindow {
private:
    std::unique_ptr<DocumentManager> m_documentManager;
    std::unique_ptr<ThemeManager>    m_themeManager;
    std::unique_ptr<AutoSaveManager> m_autoSaveManager;
    std::unique_ptr<ExportManager>   m_exportManager;
    // Bridges (第 5 章)
    EditorBridge  *m_editorBridge;
    ThemeBridge   *m_themeBridge;
    OutlineBridge *m_outlineBridge;
    SearchBridge  *m_searchBridge;
};
```

Manager 同士の依存は最小に保ち、`MainWindow` が **シグナル仲介役** に徹する。

```cpp
// MainWindow::wireConnections()
connect(m_documentManager.get(), &DocumentManager::documentOpened,
        m_editorBridge, &EditorBridge::notifyDocumentLoaded);
connect(m_editorBridge, &EditorBridge::saveFinished,
        m_documentManager.get(), [this](bool ok, QString path) {
            if (ok) m_documentManager->setModified(false);
        });
connect(m_themeManager.get(), &ThemeManager::themeChanged,
        m_themeBridge, &ThemeBridge::notifyThemeChanged);
connect(m_documentManager.get(), &DocumentManager::documentSaved,
        m_autoSaveManager.get(), [this](QString path) {
            QFile::remove(m_autoSaveManager->draftPathFor(path));
        });
```

## なぜ Manager を分けるか

- **テストが書きやすい**: 各 Manager は QApplication 無しで unit test できる
- **C++ 側の責務が明確になる**: バグが Document I/O なのか Theme 反映なのかが瞬時に分かる
- **新機能が「どこに置くか」を迷わない**: 「これは Auto Save の話だから AutoSaveManager に行く」と即決できる

## 落とし穴

1. **Manager 同士で `connect` を直接張る** と、依存グラフが循環してテスト不能になる。**MainWindow を Hub にして単方向の星型** を維持
2. **QSettings からの load を Manager constructor で同期実行** すると、初期化順依存のバグが出る。`init()` を別途呼ぶ二段階構築にする
3. **AutoSave で書き込み中の I/O ロック**: ユーザーの save と AutoSave が同時に走るとファイル破損する。draft は別ファイルに書いて、本ファイルへの move は atomic に
4. **PDF export の日本語 fallback フォント**: QPrinter は OS 標準フォント探索に依存する。日本語が豆腐になる場合は `QFontDatabase` で明示的にフォント embed

## 次の章

第 8 章では macOS / Windows / Linux 配布と LGPL ソース提供義務の実務を扱う。
