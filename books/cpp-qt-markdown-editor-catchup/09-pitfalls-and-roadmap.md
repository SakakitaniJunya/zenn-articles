---
title: "C++/Qt で半日溶かす前に — 8 つのハマりどころと Colason ロードマップ"
---

C++ + Qt + WebEngine ハイブリッドで Markdown エディタを書く時に、筆者が実際に踏んだ罠を 8 つ列挙する。一度遭遇すれば 30 分で直せるが、知らないと半日溶ける類のものだ。

## 1. QWebEngine の Chromium ビルドが 5 時間かかる

vcpkg で `qtwebengine` を初めて入れると **5 時間かかる** (Apple M1 / 16GB RAM 実測)。Chromium 本体のソースをまるごと clone してビルドするため。

ディスク使用量は **ビルド中ピーク 20-40GB / install 後は 3-5GB** が目安 (中間生成物・object ファイル込みで膨らむ)。SSD 残量を最低 60GB 確保してから走らせる。

**対処**: Linux Codespaces なら apt 経由で 5-10 分。**ローカル開発は Codespaces をメイン**にしてリリースビルドだけ GitHub Actions で 3 OS マトリクスにする運用が最強。

## 2. `Qt::AA_ShareOpenGLContexts` を忘れて WebView が真っ黒

```cpp
QApplication::setAttribute(Qt::AA_ShareOpenGLContexts);  // ← QApplication 構築 "前"
QApplication app(argc, argv);
```

これを忘れると、QWebEngineView が画面に出ても中身が render されない。warning ログに `OpenGL context could not be shared` が出ているはず。

![QWebEngineView が真っ黒のまま表示される画面 — `AA_ShareOpenGLContexts` 未設定時の典型症状](/books/cpp-qt-markdown-editor-catchup/images/pitfall-blackscreen.png)

## 3. qwebchannel.js が読めない

```html
<script src="qrc:///qtwebchannel/qwebchannel.js"></script>
```

この URL は Qt が WebChannel モジュールから自動公開しているもの。

- `QtWebChannel` を CMake で link し忘れている → URL が 404 になる
- editor/index.html ではなく editor/src/index.ts の中で fetch しようとして CORS で落ちる → script タグで読む

## 4. macOS で .app ダブルクリック起動できない (PATH 問題)

開発時に terminal から `./YourEditor.app/Contents/MacOS/YourEditor` で起動すると動くが、Finder からダブルクリックすると動かない。

**真因**: `editor/dist/` を `add_custom_command POST_BUILD` で .app の Contents/MacOS/ にコピーしているが、.app バンドル外の path を使うと Finder 起動時の working directory が違って解決できない。

**対処**: `editor/dist/` を `Contents/Resources/editor/` に配置し、C++ 側で `QCoreApplication::applicationDirPath() + "/../Resources/editor"` で resolve する。

## 5. Windows の build フォルダが MAX_PATH (260) を超える

vcpkg の依存パッケージは深い `vcpkg_installed/x64-windows/share/qt6-tools/...` のような長い path を生成する。Windows の MAX_PATH 制限 (260 文字) を超えた瞬間にビルド失敗。

**対処**:
- リポジトリを `C:\dev\YourEditor` のような短い path に置く (`C:\Users\xxx\Documents\...` は禁忌)
- レジストリで MAX_PATH 拡張を有効化 (Windows 10 Build 1607+): `HKLM\SYSTEM\CurrentControlSet\Control\FileSystem\LongPathsEnabled = 1`

## 6. QWebChannel の signal 連鎖でメモリ無限増殖

C++ 側 signal を JS 側で connect し、JS のハンドラが C++ slot を呼び、C++ slot がさらに signal を emit する。これがループになると **JS engine のヒープが毎秒数 MB 増える**。

**対処**:
- C++ → JS の signal は **状態が変化した時だけ emit** (`setDirty(bool)` で同値ならスキップ)
- JS → C++ の呼び出しは **debounce 100ms** くらいで間引く

## 7. Linux の AppImage で日本語フォントが豆腐になる

AppImage は最小限のフォントしか同梱されない。日本語フォントが端末に無いと CJK 文字が全部豆腐。

**対処**: AppImage に Noto Sans CJK を同梱するか、起動時に `fc-list :lang=ja` で日本語フォントの存在を確認して警告ダイアログ。

## 8. moc が走らずに `vtable for ... not defined`

リンカエラーで `undefined reference to vtable for MyClass` が出るのは、**Q_OBJECT マクロを書いたのに moc が走っていない** サイン。原因:

- ヘッダを CMake の `add_executable` の sources に含めていない
- `set(CMAKE_AUTOMOC ON)` を忘れている
- ヘッダファイルだけ別ライブラリに置いてあって AUTOMOC が走らない

**対処**: クラスを実装する .cpp と .h は同じ target の sources に必ず含める。

## 個人的に学んだこと

1. **ビルドが通るかどうかを最初の 1 日で決着させる** — ここで悩むと残り全部後手に回る
2. **C++ と TypeScript の責務を最初に決める** — 後で「これどっちでやるべきだっけ」となる前に Bridge メッセージの形を Fix
3. **Manager パターンを最初から入れる** — 5,000 行を超えてから refactor すると地獄
4. **配布は最後ではなく中盤で 1 回通す** — LGPL 義務 / 署名 / インストーラの手間を後回しにすると、リリース日が 2 週間ずれる

## Colason 本体について

本書のサンプルコードは特定アプリ非依存に書き直してあるが、設計パターンと罠リストは筆者が **Colason** という Markdown エディタを開発した経験に基づいている。

Colason の現状 (2026-05-17 時点):

- **ステータス**: ideation (L3) — プロトタイプ動作
- **ポジショニング**: SPEC 駆動開発時代の Markdown 専用 reader
- **次の意思決定**: 2026-06-15 に PMF 検証結果で GO / NO-GO 判定
  - GO: GPLv3 + 商用例外で OSS 化、商用ライセンスは自社サイト経由の一括販売モデルを検討中 (予価未定)
  - NO-GO: 凍結継続、Zenn 本だけ「C++/Qt6 学習記録」として独立 publish

### なぜ「一括買い切り」モデルを選ぶか

- Markdown エディタにサブスク (月額) は心理抵抗が大きい (Bear / iA Writer がここで苦戦している声をよく聞く)
- **一括 + メジャー版アップグレード課金** のモデルは Mac App 文化と相性が良い (Sublime Text や類似ジャンルの先行事例あり)
- App Store ではなく **自社サイト + Stripe 直販** にすると手数料を抑えやすい
- 日本法人 (CreaNest) 発の **代替選択肢** として、ベンダーの所在を明確にしたい層に届くポジションを取れる

### なぜ GPLv3 + 商用例外か

- MIT だと商用 fork (機能をクローズドソースに取り込む派生) を抑止できない
- source-available 系 (Sustainable Use License 等) は OSS コントリビュータの流入が期待しづらい
- GPLv3 + 商用例外条項なら **「OSS 版は完全自由、商用ライセンスは別契約」** を両立できる (Qt 本体と同じデュアルライセンスモデル)

### 本書の役割

- **リードマグネット**: C++/Qt6 で WYSIWYG Markdown エディタを作る話題は Zenn 上でほぼ未開拓
- **OSS コントリビュータ funnel**: 読者が「自分で動かしてみたい」と思った時に Colason に着地
- **直接マネタイズはしない**: 本書自体は無料、価値は流入とブランド構築

## 著者と CreaNest について

筆者は 2026 年に CreaNest 株式会社で 1 人 CEO 体制の AI 駆動開発を運営している。複数の自社 SaaS (コミュニティ運営 / ネイルサロン予約 / 読書感想文 / ジュニアスポーツ振り返り 等の領域) を Claude Code + 13 部署 director パターンで動かしている。

X: [@sakaki_creanest](https://x.com/sakaki_creanest)

本書の続編として、

- 「QWebChannel で堅いハイブリッドアプリの責務分離パターン」
- 「Qt6 + Codespaces で C++ デスクトップを 0 円開発する」
- 「LGPL の現実的な実務 — 商用配布で踏みやすい地雷」

なども検討中。

## 読者へのお願い (CTA)

本書が役に立ったら、以下の 3 ステップで著者に届けてほしい。

1. **X で [@sakaki_creanest](https://x.com/sakaki_creanest) を follow** — Colason の PMF 判定 (2026-06-15 予定) 結果や GitHub 公開告知はここで最速で出す
2. **コメント or X リプライで「自分なら C++/Qt でこう書く / Electron との比較感」を共有** — 続編の章立てに反映する
3. **Zenn の「いいね」とブックマーク** — Zenn のアルゴリズム上、これが続編公開と Colason OSS 化の判断材料になる

フィードバック歓迎。

---

> **本書の disclaimer**: 紹介している Colason は 2026-05-17 時点で ideation 段階のプロトタイプであり、商用ライセンス販売は開始していません。PMF 検証結果次第で本書の最終章 (Colason のロードマップ) は更新される可能性があります。
