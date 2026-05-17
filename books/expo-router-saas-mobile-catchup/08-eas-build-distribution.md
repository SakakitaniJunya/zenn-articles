---
title: "EAS Build — 4 プロファイル設計で社内配布から本番ストアまで通す"
---

ローカルで `pnpm ios` / `pnpm android` が動いたら次は配布。Expo Application Services (EAS) Build を使うと、Apple / Google の証明書周りをクラウドに任せて任意の OS でビルドできる。本章では実運用で必要な 4 プロファイルを設計する。

## eas.json 最小構成

```jsonc
// eas.json
{
  "cli": { "version": ">= 16.0.0" },
  "build": {
    "development": {
      "developmentClient": true,
      "distribution": "internal"
    },
    "internal": {
      "distribution": "internal",
      "android": {
        "buildType": "apk",
        "gradleCommand": ":app:assembleRelease"
      },
      "env": {
        "EXPO_PUBLIC_API_BASE_URL": "https://api.example.com"
      }
    },
    "preview": {
      "distribution": "internal",
      "ios": { "simulator": false },
      "channel": "preview"
    },
    "production": {
      "channel": "production",
      "autoIncrement": true
    }
  },
  "submit": {
    "production": {
      "ios": {
        "appleId": "you@example.com",
        "ascAppId": "1234567890"
      },
      "android": {
        "serviceAccountKeyPath": "./play-service-account.json",
        "track": "production"
      }
    }
  }
}
```

## 4 プロファイルの使い分け

| Profile | 目的 | 配布 | 出力 |
|---|---|---|---|
| `development` | Dev Client (ネイティブモジュール検証) | EAS internal | apk + ipa (シミュレータ用) |
| `internal` | 社内テスター向け APK 直配布 | EAS internal QR | release 署名 APK |
| `preview` | TestFlight / Play 内部テスト | TestFlight + Play Internal | ストア提出形式 |
| `production` | ストア本番提出 | App Store / Play Store | AAB (Android) / IPA (iOS) |

### development

新しいネイティブライブラリ (例: 認証 SDK / カメラ / Bluetooth) を入れた時、Expo Go では動かない。Dev Client は **Expo Go の代わりに自分のネイティブモジュールを焼き込んだ開発用アプリ** で、`pnpm start` から繋いで JS だけ HMR する。

```bash
npx eas-cli build --profile development --platform android
```

### internal

社内テスター 5〜10 人に APK だけ配りたい時。Play Console を経由しないので即配布できる。`distribution: "internal"` + `android.buildType: "apk"` がポイント。EAS のダッシュボードから QR コードを生成して Slack で投げるだけ。

### preview

TestFlight / Play Console 内部テスト用。`channel: "preview"` を切っておくと、OTA (Over-The-Air) Update で JS だけ差し替えられる。production と preview を別チャネルにしておくと事故が減る。

### production

ストア提出用。`autoIncrement: true` で buildNumber / versionCode を自動で +1 する。submit プロファイルとセットで:

```bash
npx eas-cli build --profile production --platform all
npx eas-cli submit --profile production --platform all
```

## EXPO_PUBLIC_* の env var ルール

env の prefix が `EXPO_PUBLIC_` のものは **ビルド時にバンドルに埋め込まれる**。これは:

- 安全に埋めていいもの: API base URL / 公開クライアント ID
- 絶対に埋めてはいけないもの: API key / secret / OAuth client secret

を分ける必要がある。基本ルールは「サーバ側で必要な値は EXPO_PUBLIC_ にしない」「クライアントだけが使う値だけ EXPO_PUBLIC_ にする」。

## iOS の証明書管理を EAS に任せる

`eas credentials` で対話的に Apple Developer 証明書を EAS のクラウドに保存できる。次回以降は build 時に自動取得され、ローカルで `.p12` 管理しなくて済む。

```bash
npx eas-cli credentials --platform ios
```

### Apple Developer Program (¥12,800/年) は必要?

- 実機で動かしたいだけ (個人) → 7 日制限の Free Provisioning でも可
- TestFlight / App Store 提出 → 必須
- iPad / iPhone 両対応 → 必須

Apple Developer Program は USD $99/年 (JP 表示は ¥13,000 台、為替で変動)、Google Play Console は USD $25 一括 (JP は ¥3,000 台一括)。**価格は変動するため最新は公式サイトを参照**。Android 先行で出してから iOS を後から、というロードマップは現実的。

## OTA Update (EAS Update)

ネイティブ層を変更していない JS / アセットだけの修正なら、ストア審査を通さず即配信できる。

```bash
npx eas-cli update --branch production --message "fix: profile screen crash"
```

`channel: "production"` を切ったビルドが起動時にこの update を pull する。**ネイティブ依存を変えた場合は新規ビルド + 提出が必要**。

## 自動署名と CI 統合

GitHub Actions から EAS Build を叩く例:

```yaml
# .github/workflows/eas-internal.yml
name: EAS internal build
on:
  workflow_dispatch:
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v3
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: pnpm }
      - run: pnpm install --frozen-lockfile
      - uses: expo/expo-github-action@v8
        with:
          eas-version: latest
          token: ${{ secrets.EXPO_TOKEN }}
      - run: cd mobile && eas build --platform android --profile internal --non-interactive
```

`EXPO_TOKEN` は EAS のダッシュボードで Personal Access Token を生成して GitHub Secrets に置く。

## 落とし穴

1. **app.json の bundleIdentifier / package を後から変える**と TestFlight 側で別アプリ扱いになり、ユーザーがゼロからインストールし直す。最初に決める
2. **EAS の無料枠は変動する** (2026-05 時点では「priority builds の月間枠 + キュー待ちの無制限ビルド」のハイブリッド構成)。CI で毎 PR ビルドすると枠を食い潰すので `workflow_dispatch` 手動 trigger 推奨。**最新の枠は Expo 公式 pricing ページを参照**
3. **iOS preview は実機転送に時間がかかる** ことがある。最初の TestFlight 公開は数時間覚悟
4. **Android release 署名鍵を紛失するとアプリ更新不能**。EAS に預けるか、自前で安全に保存

## 次の章

最終章でハマりポイントとデバッグ TIPS を、筆者の Komyu mobile での実話ベースで列挙する。
