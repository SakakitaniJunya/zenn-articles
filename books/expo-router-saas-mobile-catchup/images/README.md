# 画像配置ガイド (Expo book)

Zenn book では `books/<slug>/images/<file>` を `![alt](/books/<slug>/images/<file>)` で参照できる。
本ディレクトリは Expo Router Web→Mobile キャッチアップガイド用の画像置き場。

## ファイル命名規約

- 全て **kebab-case + 数字 prefix なし**
- 拡張子: PNG (UI/UX 系) / JPG (写真系) / SVG (図解系)
- 解像度: スクリーンショットは **2x retina (横 1200-2400px)** を推奨、Zenn 側で縮小される

## 必要な画像 (各章で挿入予定)

| ファイル名 | 章 | 内容 | 推奨サイズ |
|---|---|---|---|
| `nativewind-effect-before-after.png` | 03 | NativeWind class が効く前後の対比スクリーンショット | 1600×900 |
| `secure-storage-flow.svg` | 05 | Native / Web プレビューでの保存先分岐の概念図 | 1200×600 |
| `eas-dashboard.png` | 08 | EAS Build ダッシュボード (Build 履歴画面) | 1600×900 |
| `eas-internal-qr.png` | 08 | EAS internal distribution の QR コード共有画面 | 800×800 |
| `pitfall-metro-cache-error.png` | 09 | NativeWind cache 腐敗で class が半分効かない画面 | 1600×900 |
| `pitfall-ios-triple-blocker.png` | 09 | Maestro E2E 0/17 のスクリーンショット | 1600×900 |

## 表紙

- `../cover.png` (book ルート直下) を Zenn が自動で表紙として使う
- 推奨サイズ: **500×700 (縦長カード型)** or **1200×630 (OGP 兼用)**

## クレジット

スクリーンショットは原則として **特定アプリの個人情報・本番 URL が映らないようマスク** すること。
EAS dashboard / Expo の UI を引用する場合は Expo のブランド利用規約に従う。
