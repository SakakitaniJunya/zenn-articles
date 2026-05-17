# 画像配置ガイド (Colason book)

Zenn book では `books/<slug>/images/<file>` を `![alt](/books/<slug>/images/<file>)` で参照できる。
本ディレクトリは C++/Qt6 + QWebEngine ハイブリッド Markdown エディタ ガイド用の画像置き場。

## ファイル命名規約

- 全て **kebab-case + 数字 prefix なし**
- 拡張子: PNG (UI/UX 系) / JPG (写真系) / SVG (図解系)
- 解像度: スクリーンショットは **2x retina (横 1200-2400px)** を推奨、Zenn 側で縮小される

## 必要な画像 (各章で挿入予定)

| ファイル名 | 章 | 内容 | 推奨サイズ |
|---|---|---|---|
| `electron-vs-qt-quadrant.svg` | 01 | 4 選択肢比較 (起動速度 × 配布サイズ) の四象限図 | 1200×900 |
| `mainwindow-layout.png` | 03 | QMainWindow + Sidebar + Editor の画面構成 (要マスク) | 1600×1000 |
| `qwebengine-init-flow.svg` | 04 | WebView 初期化順を間違えた時の真っ黒画面 → 正常画面の対比 | 1600×900 |
| `qwebchannel-mesh.svg` | 05 | 4 Bridge (Editor/Outline/Search/Theme) のメッシュ図 | 1200×800 |
| `tiptap-codemirror-toggle.png` | 06 | WYSIWYG モードと Source モードの切り替え | 1600×900 |
| `feature-manager-star.svg` | 07 | MainWindow を Hub にした Manager 群の星型依存 | 1200×800 |
| `dmg-installer-macos.png` | 08 | macOS DMG インストーラのドラッグ&ドロップ画面 | 1200×800 |
| `lgpl-checklist.svg` | 08 | LGPL §4(a)-(e) 義務チェックリスト図解 | 1200×1200 |
| `pitfall-blackscreen.png` | 09 | QWebEngineView が真っ黒のスクリーンショット | 1200×800 |

## 表紙

- `../cover.png` (book ルート直下) を Zenn が自動で表紙として使う
- 推奨サイズ: **500×700 (縦長カード型)** or **1200×630 (OGP 兼用)**

## クレジット

スクリーンショットには **個人を特定できる情報・proprietary な顧客 .md ファイル** が映らないようマスクすること。
Qt / Apple / Microsoft のロゴ・スクリーンショットを引用する場合は各社のブランド利用規約に従う。
