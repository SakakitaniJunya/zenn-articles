---
title: "QWebChannel — C++ ↔ JS の JSON RPC を 1 ファイルで通す"
---

QWebChannel は **C++ オブジェクトを JavaScript から呼び出せる、JS の signal を C++ slot で受け取れる、双方向の JSON RPC レイヤー**だ。Qt が公式に提供しており、Electron の IPC や Tauri の `invoke` よりも遥かに整理されている。

本章のゴールは:

- 1 つの Bridge クラスを書く (`EditorBridge`)
- `Q_PROPERTY` と `Q_INVOKABLE` でメソッド/プロパティを公開する
- JS 側から呼ぶ
- 反対方向 (C++ から JS を能動 push する) も書く

## 全体像

```
[C++ EditorBridge (QObject)]
   │  Q_INVOKABLE void saveAs(QString path);
   │  signals:  void documentChanged(QString json);
   │
   │  QWebChannel.registerObject("editor", this)
   ▼
[QWebChannel] ←── (JSON RPC) ──→ [qwebchannel.js]
                                    │
                                    │  channel.objects.editor.saveAs(path)
                                    │  channel.objects.editor.documentChanged.connect(handler)
                                    ▼
                                  [Web 側 TipTap]
```

## Bridge クラス

### EditorBridge.h

```cpp
#pragma once

#include <QObject>
#include <QString>
#include <QJsonObject>

class EditorBridge : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString currentPath READ currentPath NOTIFY currentPathChanged)
    Q_PROPERTY(bool isDirty READ isDirty NOTIFY isDirtyChanged)

public:
    explicit EditorBridge(QObject *parent = nullptr);

    QString currentPath() const { return m_currentPath; }
    bool    isDirty() const { return m_isDirty; }

    // 内部 (C++ → JS) 通知用
    void notifyDocumentLoaded(const QString &markdown);
    void notifyThemeChanged(const QString &themeName);

public slots:
    // JS から呼べる API (Q_INVOKABLE 相当)
    void requestSave(const QString &markdown);
    void requestSaveAs(const QString &markdown);
    void requestOpen();
    void setDirty(bool dirty);

signals:
    void currentPathChanged();
    void isDirtyChanged();
    void documentLoaded(QString markdown);   // C++ → JS push
    void themeChanged(QString themeName);    // C++ → JS push
    void saveFinished(bool ok, QString path);

private:
    void setCurrentPath(const QString &path);
    QString m_currentPath;
    bool m_isDirty = false;
};
```

ポイント:

- **`public slots` に書いた関数は JS から呼べる** (`Q_INVOKABLE` を付けたメソッドも完全に同じく公開される。両者は QWebChannel の expose 機構として等価で、慣習として slots を選ぶことが多い)
- **`Q_PROPERTY` の READ + NOTIFY** で、JS 側に reactive な値として露出
- **`signals` は JS の `connect()` で受けられる**

### EditorBridge.cpp

```cpp
#include "EditorBridge.h"
#include <QFileDialog>
#include <QFile>
#include <QTextStream>

EditorBridge::EditorBridge(QObject *parent) : QObject(parent) {}

void EditorBridge::requestSave(const QString &markdown) {
    if (m_currentPath.isEmpty()) {
        requestSaveAs(markdown);
        return;
    }
    QFile f(m_currentPath);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text)) {
        emit saveFinished(false, m_currentPath);
        return;
    }
    QTextStream out(&f);
    out << markdown;
    setDirty(false);
    emit saveFinished(true, m_currentPath);
}

void EditorBridge::requestSaveAs(const QString &markdown) {
    const auto path = QFileDialog::getSaveFileName(
        nullptr, tr("名前を付けて保存"), QString(),
        tr("Markdown (*.md);;All Files (*)"));
    if (path.isEmpty()) {
        emit saveFinished(false, QString());
        return;
    }
    setCurrentPath(path);
    requestSave(markdown);
}

void EditorBridge::requestOpen() {
    const auto path = QFileDialog::getOpenFileName(
        nullptr, tr("開く"), QString(),
        tr("Markdown (*.md *.markdown);;All Files (*)"));
    if (path.isEmpty()) return;
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return;
    const QString markdown = QTextStream(&f).readAll();
    setCurrentPath(path);
    setDirty(false);
    emit documentLoaded(markdown);   // JS 側に push
}

void EditorBridge::setDirty(bool dirty) {
    if (m_isDirty == dirty) return;
    m_isDirty = dirty;
    emit isDirtyChanged();
}

void EditorBridge::setCurrentPath(const QString &path) {
    if (m_currentPath == path) return;
    m_currentPath = path;
    emit currentPathChanged();
}

void EditorBridge::notifyDocumentLoaded(const QString &markdown) {
    emit documentLoaded(markdown);
}

void EditorBridge::notifyThemeChanged(const QString &themeName) {
    emit themeChanged(themeName);
}
```

## Bridge を登録する (C++ 側)

EditorPane で WebView を準備したあとに登録する。

```cpp
// EditorPane の constructor または MainWindow から呼ぶ
auto *editorBridge = new EditorBridge(this);
m_webChannel->registerObject(QStringLiteral("editor"), editorBridge);
```

`registerObject("editor", ...)` の "editor" という名前で JS 側に露出する。

> **タイミング重要**: `registerObject` は **`QWebEngineView::load()` を呼ぶ前に完了させる**。JS 側で `new QWebChannel(qt.webChannelTransport, callback)` が走った時に object が未登録だと、callback で `channel.objects.editor === undefined` となる。第 4 章の `EditorPane` constructor 内で「`setWebChannel()` → 全 `registerObject()` → `load()`」の順を厳守する。

## JS 側で受ける

editor/dist/index.html の中で `qwebchannel.js` を読み込み、bridge を取得する。

```html
<!-- editor/index.html -->
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <script src="qrc:///qtwebchannel/qwebchannel.js"></script>
  <script type="module" src="/src/index.ts"></script>
</head>
<body>
  <div id="root"></div>
</body>
</html>
```

`qrc:///qtwebchannel/qwebchannel.js` は Qt が WebChannel モジュールにバンドルしている JS で、特別な URL でアクセスできる。

```ts
// editor/src/bridge.ts
type Bridge = {
  currentPath: string;
  isDirty: boolean;
  requestSave(markdown: string): Promise<void>;
  requestSaveAs(markdown: string): Promise<void>;
  requestOpen(): Promise<void>;
  setDirty(dirty: boolean): Promise<void>;
  documentLoaded: { connect(fn: (markdown: string) => void): void };
  themeChanged:   { connect(fn: (theme: string) => void): void };
  saveFinished:   { connect(fn: (ok: boolean, path: string) => void): void };
  currentPathChanged: { connect(fn: () => void): void };
  isDirtyChanged:     { connect(fn: () => void): void };
};

declare const QWebChannel: new (transport: unknown, cb: (ch: { objects: { editor: Bridge } }) => void) => void;
declare const qt: { webChannelTransport: unknown };

export function initBridge(): Promise<Bridge> {
  return new Promise((resolve) => {
    new QWebChannel(qt.webChannelTransport, (channel) => {
      resolve(channel.objects.editor);
    });
  });
}
```

## エディタ初期化と連動

```ts
// editor/src/index.ts
import { initBridge } from "./bridge";
import { mountEditor } from "./editor";

(async () => {
  const bridge = await initBridge();
  const editor = mountEditor(document.getElementById("root")!);

  // C++ → JS: ドキュメントロード
  bridge.documentLoaded.connect((markdown: string) => {
    editor.setMarkdown(markdown);
  });

  // C++ → JS: テーマ変更
  bridge.themeChanged.connect((name: string) => {
    document.body.dataset.theme = name;
  });

  // JS → C++: 編集差分があれば dirty 通知
  editor.onChange((markdown) => {
    bridge.setDirty(true);
  });

  // JS → C++: Cmd+S で保存
  document.addEventListener("keydown", (e) => {
    if (e.key === "s" && (e.metaKey || e.ctrlKey)) {
      e.preventDefault();
      bridge.requestSave(editor.getMarkdown());
    }
  });

  bridge.saveFinished.connect((ok, path) => {
    if (ok) {
      console.log("saved:", path);
    } else {
      console.error("save failed:", path);
    }
  });
})();
```

## メッセージ設計のコツ

1. **JSON シリアライズ可能な型だけを渡す** (Qt の自動変換は QString / int / double / bool / QJsonObject / QJsonArray が安全)
2. **大きなペイロード (画像の base64 等) は避ける** — JSON 越しのコピーが発生して 100ms オーダーで詰まる。代わりにファイルパスを渡す
3. **状態は片方に集約** — `m_isDirty` を C++ 側だけで持ち、JS は `setDirty(bool)` を呼ぶだけ、という方向を統一する。両方に状態を置くと sync 地獄
4. **Bridge クラスを機能別に分ける** — Editor / Outline / Search / Theme と 4 つに分けると責務が綺麗 (Colason の実装パターン)

## 4 Bridge 設計の例

| Bridge | 役割 |
|---|---|
| EditorBridge | ファイル I/O、dirty フラグ、save/open ダイアログ |
| OutlineBridge | エディタの heading list を C++ 側 Sidebar に push |
| SearchBridge | C++ 側 GlobalSearch から hit position を JS にハイライト指示 |
| ThemeBridge | C++ ThemeManager から CSS variable を push |

`registerObject` を 4 回呼ぶだけで、JS 側に `channel.objects.editor` `channel.objects.outline` `channel.objects.search` `channel.objects.theme` が生える。

```mermaid
flowchart LR
    subgraph Cpp ["C++ Native 側"]
        EB["EditorBridge<br/>(file I/O)"]
        OB["OutlineBridge<br/>(heading push)"]
        SB["SearchBridge<br/>(hit pos)"]
        TB["ThemeBridge<br/>(CSS vars)"]
    end

    Channel(("1 個の<br/>QWebChannel"))

    subgraph Js ["JS WebView 側"]
        JE["channel.objects.editor"]
        JO["channel.objects.outline"]
        JS2["channel.objects.search"]
        JT["channel.objects.theme"]
    end

    EB -- registerObject(\"editor\") --> Channel
    OB -- registerObject(\"outline\") --> Channel
    SB -- registerObject(\"search\") --> Channel
    TB -- registerObject(\"theme\") --> Channel

    Channel -.qwebchannel.js.-> JE
    Channel -.qwebchannel.js.-> JO
    Channel -.qwebchannel.js.-> JS2
    Channel -.qwebchannel.js.-> JT
```

責務が綺麗に 4 つに割れているので、後で「Comment Bridge」「Spellcheck Bridge」を足したくなった時も `registerObject` を 1 回追加するだけで済む。

## 落とし穴

1. **`registerObject` の名前と JS 側で使う名前を間違える** と silent fail (undefined になる)。constexpr で定数化推奨
2. **`Q_OBJECT` を継承クラスに付け忘れる** と signal/slot が dispatch されない
3. **`signal` 引数を `QJsonObject` で巨大化** すると JS への push でブロックする。差分だけ渡す
4. **`QFileDialog::getSaveFileName` の parent を `this` (QObject) にできない**: QWidget 派生の親が必要。`nullptr` 渡すか、MainWindow のポインタを参照経由で渡す
5. **複数の Bridge を同時に register** する時は **1 個の `QWebChannel` インスタンスに `registerObject()` を 4 回呼ぶ**のが正解。`QWebEnginePage::setWebChannel()` は page に紐づく channel を 1 個だけ保持するので、新しい channel で再呼び出しすると前の channel ごと丸ごと差し替えられる

## 次の章

第 6 章では Web 側 (Vite + TipTap + CodeMirror) の責務と、Bridge との接続点を実装する。
