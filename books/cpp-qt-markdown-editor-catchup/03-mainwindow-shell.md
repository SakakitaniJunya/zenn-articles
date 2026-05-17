---
title: "QMainWindow で OS 標準メニュー・D&D・状態保存を全部もらう"
---

Qt Widgets の `QMainWindow` は「メニューバー + ツールバー + ステータスバー + 中央ウィジェット + ドック」を箱から出して提供してくれる。本章では Markdown エディタに必要な最小構成を実装する。

## ファイル構成 (本章で扱う範囲)

```
src/
  main.cpp
  ui/
    MainWindow.h
    MainWindow.cpp
    MenuBarManager.h
    MenuBarManager.cpp
    StatusBarManager.h
    StatusBarManager.cpp
  core/
    DocumentManager.h
    DocumentManager.cpp
```

![QMainWindow を中心としたウィンドウ構成 — MenuBar / Sidebar (Dock) / 中央 EditorPane / StatusBar の典型レイアウト](/books/cpp-qt-markdown-editor-catchup/images/mainwindow-layout.png)

## main.cpp

```cpp
#include <QApplication>
#include "ui/MainWindow.h"

int main(int argc, char *argv[]) {
    QApplication::setAttribute(Qt::AA_ShareOpenGLContexts);
    QApplication app(argc, argv);
    app.setApplicationName("YourEditor");
    app.setOrganizationName("CreaNest");
    app.setOrganizationDomain("creanest.co");

    MainWindow window;
    window.show();
    return app.exec();
}
```

**`AA_ShareOpenGLContexts` は QWebEngine 必須属性**。QApplication 構築前にセットする。これを忘れると WebView 初期化で warning が連続する。

## MainWindow.h

```cpp
#pragma once

#include <QMainWindow>
#include <memory>

class EditorPane;
class MenuBarManager;
class StatusBarManager;
class DocumentManager;

class MainWindow : public QMainWindow {
    Q_OBJECT
public:
    explicit MainWindow(QWidget *parent = nullptr);
    ~MainWindow() override;

protected:
    void closeEvent(QCloseEvent *event) override;
    void dragEnterEvent(QDragEnterEvent *event) override;
    void dropEvent(QDropEvent *event) override;

private slots:
    void onNewDocument();
    void onOpenDocument();
    void onSaveDocument();
    void onSaveAsDocument();
    void onDocumentModified();

private:
    void restoreGeometry();
    void saveGeometry();

    EditorPane *m_editorPane;
    std::unique_ptr<MenuBarManager> m_menuBarManager;
    std::unique_ptr<StatusBarManager> m_statusBarManager;
    std::unique_ptr<DocumentManager> m_documentManager;
};
```

ポイント:

- メンバは **forward declaration + unique_ptr** で持つ → ヘッダの include 量を最小化
- `Q_OBJECT` マクロを付けると AUTOMOC が moc を実行してくれる
- ドラッグ&ドロップは `QMainWindow` の virtual を override するだけで OS の D&D に乗る

## MainWindow.cpp の骨格

```cpp
#include "ui/MainWindow.h"
#include "ui/EditorPane.h"
#include "ui/MenuBarManager.h"
#include "ui/StatusBarManager.h"
#include "core/DocumentManager.h"

#include <QCloseEvent>
#include <QDragEnterEvent>
#include <QDropEvent>
#include <QMimeData>
#include <QSettings>
#include <QFileDialog>
#include <QMessageBox>

MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent),
      m_editorPane(new EditorPane(this)),
      m_menuBarManager(std::make_unique<MenuBarManager>(this)),
      m_statusBarManager(std::make_unique<StatusBarManager>(this)),
      m_documentManager(std::make_unique<DocumentManager>(this)) {

    setCentralWidget(m_editorPane);
    setAcceptDrops(true);

    m_menuBarManager->install(this);
    m_statusBarManager->install(this);

    connect(m_menuBarManager.get(), &MenuBarManager::newRequested,
            this, &MainWindow::onNewDocument);
    connect(m_menuBarManager.get(), &MenuBarManager::openRequested,
            this, &MainWindow::onOpenDocument);
    connect(m_menuBarManager.get(), &MenuBarManager::saveRequested,
            this, &MainWindow::onSaveDocument);
    connect(m_menuBarManager.get(), &MenuBarManager::saveAsRequested,
            this, &MainWindow::onSaveAsDocument);
    connect(m_documentManager.get(), &DocumentManager::modifiedChanged,
            this, &MainWindow::onDocumentModified);

    restoreGeometry();
    setWindowTitle("YourEditor");
}

MainWindow::~MainWindow() = default;

void MainWindow::closeEvent(QCloseEvent *event) {
    if (m_documentManager->isModified()) {
        const auto ret = QMessageBox::question(
            this, tr("未保存の変更"),
            tr("保存せずに閉じますか?"),
            QMessageBox::Save | QMessageBox::Discard | QMessageBox::Cancel);
        if (ret == QMessageBox::Cancel) { event->ignore(); return; }
        if (ret == QMessageBox::Save)   { onSaveDocument(); }
    }
    saveGeometry();
    event->accept();
}

void MainWindow::dragEnterEvent(QDragEnterEvent *event) {
    if (event->mimeData()->hasUrls()) event->acceptProposedAction();
}

void MainWindow::dropEvent(QDropEvent *event) {
    const auto urls = event->mimeData()->urls();
    if (urls.isEmpty()) return;
    m_documentManager->openFile(urls.first().toLocalFile());
}

void MainWindow::restoreGeometry() {
    QSettings settings;
    if (settings.contains("MainWindow/geometry")) {
        QMainWindow::restoreGeometry(settings.value("MainWindow/geometry").toByteArray());
    } else {
        resize(1200, 800);
    }
}

void MainWindow::saveGeometry() {
    QSettings settings;
    settings.setValue("MainWindow/geometry", QMainWindow::saveGeometry());
}
```

`QSettings` は OS ごとに適切な保存先を自動選択する (macOS は plist、Windows はレジストリ、Linux は ~/.config/...)。

## MenuBarManager.h

```cpp
#pragma once

#include <QObject>
class QMainWindow;
class QAction;

class MenuBarManager : public QObject {
    Q_OBJECT
public:
    explicit MenuBarManager(QObject *parent = nullptr);
    void install(QMainWindow *window);

signals:
    void newRequested();
    void openRequested();
    void saveRequested();
    void saveAsRequested();
    void quitRequested();

private:
    QAction *m_newAction = nullptr;
    QAction *m_openAction = nullptr;
    QAction *m_saveAction = nullptr;
    QAction *m_saveAsAction = nullptr;
    QAction *m_quitAction = nullptr;
};
```

## MenuBarManager.cpp (抜粋)

> **Qt バージョン前提**: `addAction(text, shortcut, receiver, slot)` のような 4 引数オーバーロードは **Qt 6.3 以降**で追加された API。Qt 6.0〜6.2 を併走させる読者は 3 引数 + `setShortcut` の分割形式に書き直す必要がある。本書全体は **Qt 6.8+ 前提**。

```cpp
#include "MenuBarManager.h"
#include <QMainWindow>
#include <QMenuBar>
#include <QMenu>
#include <QAction>
#include <QKeySequence>

MenuBarManager::MenuBarManager(QObject *parent) : QObject(parent) {}

void MenuBarManager::install(QMainWindow *window) {
    auto *menuBar = window->menuBar();

    auto *fileMenu = menuBar->addMenu(tr("&ファイル"));
    m_newAction = fileMenu->addAction(tr("&新規"), QKeySequence::New,
                                     this, &MenuBarManager::newRequested);
    m_openAction = fileMenu->addAction(tr("&開く..."), QKeySequence::Open,
                                      this, &MenuBarManager::openRequested);
    fileMenu->addSeparator();
    m_saveAction = fileMenu->addAction(tr("&保存"), QKeySequence::Save,
                                      this, &MenuBarManager::saveRequested);
    m_saveAsAction = fileMenu->addAction(tr("名前を付けて保存..."),
                                         QKeySequence::SaveAs,
                                         this, &MenuBarManager::saveAsRequested);

#ifndef Q_OS_MACOS
    fileMenu->addSeparator();
    m_quitAction = fileMenu->addAction(tr("&終了"), QKeySequence::Quit,
                                      this, &MenuBarManager::quitRequested);
#endif
}
```

macOS は「終了」を File メニューに入れない (アプリメニュー側に Qt が自動配置) のが慣習なので `#ifndef Q_OS_MACOS` で分岐。`QKeySequence::Save` のような標準キーバインドを使うと、Cmd+S (macOS) / Ctrl+S (Windows/Linux) が自動でマップされる。

## StatusBarManager.h / cpp (要点)

```cpp
// 単語数・カーソル位置・自動保存ステータスを表示するだけのマネージャ
class StatusBarManager : public QObject {
    Q_OBJECT
public:
    void install(QMainWindow *window);
    void setWordCount(int words);
    void setAutoSaveStatus(const QString &text);
private:
    QLabel *m_wordCountLabel = nullptr;
    QLabel *m_autoSaveLabel = nullptr;
};
```

```cpp
void StatusBarManager::install(QMainWindow *window) {
    auto *bar = window->statusBar();
    m_wordCountLabel = new QLabel(window);
    m_autoSaveLabel = new QLabel(window);
    bar->addPermanentWidget(m_wordCountLabel);
    bar->addPermanentWidget(m_autoSaveLabel);
}
```

`statusBar()` は QMainWindow が遅延生成する。`addPermanentWidget` は右端に固定配置。

## サイドバー (Dock Widget)

サイドバー (Files / Outline / Search) は `QDockWidget` を 3 つ生やすか、1 つの `QTabWidget` を `QDockWidget` 内に入れる。**Tab 1 個の Dock が UX 上一番扱いやすい**。

```cpp
auto *sidebar = new SidebarContainer(this);  // 自前の QTabWidget ベース widget
auto *dock = new QDockWidget(tr("サイドバー"), this);
dock->setWidget(sidebar);
dock->setAllowedAreas(Qt::LeftDockWidgetArea);
addDockWidget(Qt::LeftDockWidgetArea, dock);
```

`saveState() / restoreState()` で配置を `QSettings` に永続化できる。

## 落とし穴

1. **`Q_OBJECT` を付け忘れる** と signals / slots が動かない。CMake で AUTOMOC を on にしていても、ヘッダにマクロが無いと moc が走らない
2. **`QAction` の slot 接続を lambda + capture で書きすぎる** と、widget 削除順序で dangling pointer 化することがある。member function pointer で書くのが安全
3. **QSettings の organization 名を main.cpp で設定し忘れる** と、設定保存先が空文字になって fail silently で値が消える
4. **`closeEvent` で `event->ignore()` してから confirm dialog を出さない** と、保存ダイアログが出る前にウィンドウが閉じる

## 次の章

第 4 章では QWebEngineView を中央ウィジェットに埋め込んで、Vite ビルド済みの editor/dist/ をロードする部分を扱う。
