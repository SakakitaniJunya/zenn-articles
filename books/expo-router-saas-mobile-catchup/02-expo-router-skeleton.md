---
title: "Expo Router 6 最小構成 — Next.js App Router からの差分 5 つ"
---

Expo Router は file-based routing を React Native に持ち込んだもので、Next.js App Router を触ったことがあれば 9 割の概念が再利用できる。本章では最小プロジェクトを立ち上げ、Next.js との差分を 5 つに整理する。

> **バージョン前提**: 本書は **Expo SDK 54 + Expo Router 6** (2026 年時点の最新想定) を前提に書いている。バージョン番号が読者の手元と合わない場合は、各章末尾の「落とし穴」セクションを先に確認してほしい。多くの差異は Router 4 系からのアップグレードガイドで吸収できる。

## プロジェクト作成

```bash
pnpm create expo-app@latest my-mobile --template default
cd my-mobile
pnpm install
pnpm start
```

`pnpm start` で Metro が起動し、QR コードが表示される。Expo Go (iOS/Android アプリ) で読み取ると即実機で動く。最初の動作確認はここまでで十分。

## 最小ディレクトリ構造

```
app/
  _layout.tsx          # ルート: providers / 認証ガード
  index.tsx            # / にアクセスした時の画面
  (auth)/              # route group: ログイン関連
    _layout.tsx
    login.tsx
    register.tsx
  (app)/               # route group: 認証必須エリア
    _layout.tsx
    (tabs)/            # タブナビゲーション
      _layout.tsx
      index.tsx        # ホーム
      profile.tsx
    chat/[id].tsx      # 動的ルート
```

`(auth)` `(app)` `(tabs)` は **route group** で、URL には現れず「同じ階層に置きながら別グループの layout を当てたい」時に使う。Next.js App Router の `(group)` と完全に同じ。

## Next.js App Router からの差分 5 つ

### 差分 1: `_layout.tsx` (Next.js は `layout.tsx`)

ファイル名にアンダースコアが付くだけ。中身の役割は同じで、配下の全ルートをラップする。

```tsx
// app/_layout.tsx
import { Stack } from "expo-router";
import { AuthProvider } from "@/lib/auth-context";

export default function RootLayout() {
  return (
    <AuthProvider>
      <Stack screenOptions={{ headerShown: false }} />
    </AuthProvider>
  );
}
```

### 差分 2: ナビゲーションは `<Stack>` / `<Tabs>` / `<Drawer>` を layout で宣言

Next.js は「URL を変えるとサーバが新しい page.tsx を返す」だが、Expo Router は「クライアント側で stack に push する」。layout で何を使うかを宣言する。

```tsx
// app/(app)/(tabs)/_layout.tsx
import { Tabs } from "expo-router";
export default function TabsLayout() {
  return (
    <Tabs screenOptions={{ headerShown: false }}>
      <Tabs.Screen name="index"   options={{ title: "ホーム" }} />
      <Tabs.Screen name="profile" options={{ title: "プロフィール" }} />
    </Tabs>
  );
}
```

### 差分 3: `useRouter()` の API が少し違う

Next.js: `router.push("/foo")` / `router.replace("/bar")`
Expo Router: 同じ。だが `router.navigate("/foo")` という「stack に既にあれば pop、なければ push」という挙動を持つ独自 API がある。タブ間遷移で重複 push を避けたい時に便利。

### 差分 4: 動的ルートは `[id].tsx` と `useLocalSearchParams`

```tsx
// app/(app)/chat/[id].tsx
import { useLocalSearchParams } from "expo-router";
export default function ChatScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  return <Text>Chat {id}</Text>;
}
```

`useSearchParams()` (グローバル) と `useLocalSearchParams()` (現在の screen) の 2 種類がある。stack の前画面と現画面で同じ param 名を使った時に挙動が違うので、**基本は `useLocalSearchParams` を使う**。

### 差分 5: SSR が無い分、認証ガードはクライアントで書く

Next.js では `middleware.ts` で `redirect("/login")` するが、Expo Router では layout の中で auth context を見て `<Redirect>` を返す。

```tsx
// app/(app)/_layout.tsx
import { Redirect, Stack } from "expo-router";
import { useAuth } from "@/lib/auth-context";

export default function AppLayout() {
  const { status } = useAuth();
  if (status === "loading") return null;
  if (status === "unauthenticated") return <Redirect href="/(auth)/login" />;
  return <Stack screenOptions={{ headerShown: false }} />;
}
```

## newArchEnabled: true は迷わず付ける

`app.json` に `"newArchEnabled": true` を入れておく。SDK 54 以降は New Architecture (Fabric + TurboModules) が安定しており、ライブラリ互換も基本問題ない。後で外す方が大変なので最初から有効化。

## 次の章

第 3 章では NativeWind v4 を入れて、Web 側 Tailwind の `tailwind.config.js` と token を共有する手順を見る。
