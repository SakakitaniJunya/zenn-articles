---
title: "Expo / RN で半日溶かす前に — 7 つのハマりどころ"
---

筆者が 2026 年に 1 人 CEO 体制で Web SaaS にモバイル版を足した時、書いてある通りに進めていても **1 日溶かす系のハマり** が何度かあった。本章では再現性が高いものを 7 つ並べる。

## 1. NativeWind の class が「半分だけ効く」

### 症状

`className="rounded-2xl bg-brand-500"` を当てた Pressable のうち、`rounded-2xl` だけ効いていない。同じファイル内の別 Pressable では効いている。

### 真因

NativeWind v4 は `.expo/` と `node_modules/.cache/` に生成 CSS をキャッシュする。tailwind.config.js を変更した時、これらが古いまま残ると **新しい class 名が生成 CSS に含まれず、無視される**。

### 対処

```bash
rm -rf .expo node_modules/.cache
pnpm expo start --clear
```

これを「設定を疑う前の第一手」として身につける。筆者は 10 時間溶かした。

![NativeWind cache 腐敗で class が半分しか効いていない画面 (border は当たっているが rounded-2xl が無視されている)](/books/expo-router-saas-mobile-catchup/images/pitfall-metro-cache-error.png)

## 2. iOS シミュレータで Metro projectRoot を誤認

### 症状

`pnpm ios` で起動はする。だが、ビルドした Hermes JS バンドルが古い main ブランチの bundle で、Pull したはずの最新変更が反映されない。

### 真因

monorepo (`apps/mobile`) で実行した時、Metro が `projectRoot` を `apps/mobile` ではなくリポジトリ root に推測することがある。bundle が `/` から探されて、別 worktree の `index.js` を拾う。

### 対処

```js
// metro.config.js
const path = require("path");
const config = getDefaultConfig(__dirname);
config.projectRoot = __dirname;
config.watchFolders = [path.resolve(__dirname, "../../packages")];
module.exports = config;
```

`projectRoot` を明示する。`watchFolders` には共有 package だけを足す (`..` を雑に足すと別ツリーを巻き込む)。

## 3. `expo prebuild --clean` が ios/build を消し飛ばす

### 症状

`expo prebuild --clean` を叩いた瞬間、未コミットの `ios/Komyu/Info.plist` 編集や `ios/build/` の中間生成物が全部消える。

### 真因

`--clean` は文字通り `ios/` `android/` ディレクトリを **削除して再生成** する。.gitignore で除外していた状態管理ファイル (例: `ios/build/`) も巻き添えになる。

### 対処

- `prebuild --clean` を叩く前に **必ず `git stash` または commit**
- 退避が必要なら `rsync -av ios/ /tmp/ios-backup/` を先に走らせる
- `--clean` なしの `expo prebuild` は既存を上書きするだけなので安全 (基本これで足りる)

## 4. iOS 実機の「Login → 何も起こらない」

### 症状

シミュレータでは動くが、TestFlight 経由で実機にインストールしたらログインボタンが反応しない (画面遷移しない)。

### 真因 (3 つの典型)

1. **`EXPO_PUBLIC_API_BASE_URL` がローカル LAN IP のまま** ビルドされた (本番 URL に上書きされていない)
2. iOS の **App Transport Security** で `http://` を弾いている (`https://` で動作確認していなかった)
3. 本番 API の **CORS 設定で `Authorization` ヘッダが許可されていない**

### 対処

- `eas.json` の各プロファイルで `EXPO_PUBLIC_API_BASE_URL` を明示
- 本番は必ず HTTPS
- サーバ側 CORS は `Access-Control-Allow-Headers` に `Authorization` を含める

## 5. SecureStore の値が iOS でだけ突然消える

### 症状

iOS で「ログイン後にアプリを閉じ → 再起動するとログアウトされている」が再現する。Android では起きない。

### 真因

`keychainAccessible` のデフォルトが `WHEN_UNLOCKED` で、**端末ロック中に Background fetch から SecureStore を読もうとして失敗** している。失敗が連鎖して session を消す処理が動いていた。

### 対処

```ts
await SecureStore.setItemAsync(KEY, value, {
  keychainAccessible: SecureStore.AFTER_FIRST_UNLOCK,
});
```

`AFTER_FIRST_UNLOCK` にすると初回ロック解除以降は読める。Push 通知から起動するアプリでは必須。

## 6. react-native-worklets の不整合で iOS が Maestro テスト 0/17

### 症状

`react-native-reanimated` を入れた途端、Maestro の E2E が全部こけて 0/17 になる。シミュレータでは動く。

### 真因

`react-native-reanimated` 4.x が `react-native-worklets` を peer dependency に持つが、Expo SDK 54 の resolution と微妙にズレて **dual install** されることがある。Hermes が worklet コンテキストを 2 つ作って衝突する。

### 対処

```jsonc
// package.json (pnpm)
"pnpm": {
  "overrides": {
    "react-native-worklets": "0.5.1"
  }
}

// npm / yarn は "resolutions" を使う
"resolutions": {
  "react-native-worklets": "0.5.1"
}
```

`pnpm` の `resolutions` は基本無視されるので、**pnpm.overrides を必ず使う**。`pnpm dedupe` で 1 つに揃っているか確認。

![iOS Maestro E2E が 0/17 で全部こけた画面 — react-native-worklets が dual install されているサイン](/books/expo-router-saas-mobile-catchup/images/pitfall-ios-triple-blocker.png)

## 7. ngrok-free tunnel が user 占有で他の Mac から繋がらない

### 症状

社内デモで Mac を別の人に渡したら `pnpm start --tunnel` が「tunnel session is in use by another user」で起動しない。

### 真因

ngrok-free アカウントは **1 セッション同時占有 1 つ**。複数人が同時にトンネルを張れない。

### 対処

- LAN モードで運用 (`expo start` だけで OK、QR は LAN IP)
- Personal Hotspot を使う場合は `expo start --tunnel` の代わりに `EXPO_PUBLIC_API_BASE_URL=http://<lan-ip>:3000 pnpm start`
- どうしても tunnel が必要なら ngrok 有料化 ($8/月)、または cloudflared に乗り換え

## デバッグツール最小セット

| ツール | 用途 |
|---|---|
| **Flipper** (廃止傾向) | RN 0.74 まで。0.81 では非推奨 |
| **React Native DevTools** (Hermes 内蔵) | network / console / debugger を `j` キーで開く |
| **Maestro** | E2E (シナリオを YAML で書く、画面録画つき) |
| **Reactotron** | Redux / Context の inspection、軽量 |
| **Sentry React Native** | プロダクションのクラッシュ収集 |

`pnpm start` 起動中に `j` キーを押すと Chrome DevTools が開く。これが Hermes 標準の最初の頼り先。

## まとめ — 1 人開発で気をつけること

- **cache 系は疑え**: 設定をいじる前に `--clear` を 1 回挟む
- **monorepo の projectRoot を明示する**: 自動推論に頼らない
- **iOS と Android で挙動が違う系は SecureStore の attribute を疑え**
- **EAS の無料枠 (月 30 ビルド) は CI で雑に使うと尽きる**: 手動 trigger 推奨

本書のサンプルコードは特定アプリ非依存に書き直してあるが、ハマりどころは全て筆者が実際に遭遇したものだ。1 人 CEO で全部背負っていると 1 つの罠で半日が消えるので、本書がその半日を救う本になっていれば嬉しい。

## 著者と CreaNest について

筆者は 2026 年に CreaNest 株式会社で 1 人 CEO 体制の AI 駆動開発を運営している。複数の自社 SaaS (コミュニティ運営 / ネイルサロン予約 / 読書感想文 / ジュニアスポーツ振り返り 等の領域) を Claude Code + 13 部署 director パターンで動かしている。

X: [@sakaki_creanest](https://x.com/sakaki_creanest)

本書の続編として、

- 「Web SaaS の Next.js / Cloud Run / Firestore 構成パターン」
- 「Maestro E2E で iOS シナリオを書く」
- 「monorepo で Web + mobile + admin を 1 つの pnpm workspace に詰める」

なども検討中。

## 読者へのお願い (CTA)

本書が役に立ったら、以下の 3 ステップで著者に届けてほしい。

1. **X で [@sakaki_creanest](https://x.com/sakaki_creanest) を follow** — 続編 / 派生記事 / 失敗談はここで先に流す
2. **コメント or X リプライで「自分の repo ではこう適用した / ここで詰まった」を共有** — 続編の章立てに反映する
3. **Zenn の「いいね」とブックマーク** — Zenn のアルゴリズム上、これが続編公開のモチベーションになる

フィードバック歓迎。
