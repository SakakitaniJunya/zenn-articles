---
title: "/api/mobile/* で Cookie セッションを完全分離する 4 ルール"
---

Web 側で既に API が動いているプロジェクトでは、mobile が叩く API を増やすたびに「これは Cookie 認証か? Bearer か?」と分岐ロジックを書きたくなる。これは事故の素で、規模が大きくなるほど **Web と mobile が同じハンドラを共有する設計は破綻する**。

解決は単純で、URL prefix で完全に分ける。

```
/api/auth/*          → Web (NextAuth, Cookie session)
/api/communities     → Web (Cookie session)
/api/mobile/auth/*   → Mobile (Bearer JWT)
/api/mobile/communities → Mobile (Bearer JWT)
/api/mobile/me       → Mobile (Bearer JWT)
```

## 設計ルール 4 つ

### ルール 1: `/api/mobile/*` は Cookie を一切見ない

Web 側 `auth.ts` (next-auth 設定) の `authorized` callback で、`/api/mobile/*` は素通しさせる。

```ts
// auth.ts (next-auth v5)
export const { auth, handlers } = NextAuth({
  callbacks: {
    authorized({ request, auth }) {
      const { pathname } = request.nextUrl;
      if (pathname.startsWith("/api/mobile/")) return true; // Bearer 検証は route で
      if (pathname.startsWith("/api/")) return !!auth;
      // ... rest
      return true;
    },
  },
});
```

これで NextAuth の Cookie 検証が `/api/mobile/*` をスルーする。各ハンドラ先頭で `requireMobileAuth(req)` を呼んで Bearer を検証する責務に切り替わる。

> **前提**: この `authorized` callback は **`middleware.ts` で `export { auth as middleware }` を export している場合にだけ評価される**。middleware を有効化していないプロジェクトは `route.ts` 側の `requireMobileAuth` が単独で防御を担うことになるので、Web 側の Cookie 認証が別途必要なら middleware を必ず生やす。

### ルール 2: ハンドラ先頭で Auth、それ以降は Web と同じ

```ts
// app/api/mobile/communities/route.ts
import { NextRequest, NextResponse } from "next/server";
import { requireMobileAuth } from "@/lib/mobile-auth";
import { listCommunities } from "@/src/common/communities";

export async function GET(req: NextRequest) {
  const { sub: userId } = await requireMobileAuth(req);
  const items = await listCommunities({ userId });
  return NextResponse.json({ items });
}
```

`listCommunities` のような **ビジネスロジック層は `src/common/*` に置いて Web 側と共有する**。HTTP 層 (route.ts) だけが薄く 2 系統。

### ルール 3: レスポンスは「mobile が欲しい形」に合わせる

Web 側 API は SSR / Server Component の都合で「リストだけ返す」「ページ全体の context を返す」など雑食になりがちだが、mobile はクライアントから fetch する分、**必要なフィールドだけ返す薄い API** を作り直したほうが net で速い。

```ts
// 共有層
export async function listCommunities({ userId }: { userId: string }) {
  return db.communities.findMany({
    where: { members: { some: { userId } } },
    select: {
      id: true,
      name: true,
      iconUrl: true,
      // membersCount は mobile 一覧画面で使うのでここで含める
      _count: { select: { members: true } },
    },
  });
}
```

### ルール 4: 共通エラー形式を decide しておく

```jsonc
// 200 OK
{ "items": [...] }

// 4xx / 5xx
{ "error": "invalid_credentials" }      // クライアント表示用 code
{ "error": "internal", "trace": "..." } // 内部詳細は dev only
```

`error` フィールドは **必ず slug 化 (snake_case)** しておくと、mobile クライアントで i18n key として直接使える。

## ディレクトリ構成例

```
app/
  api/
    auth/[...nextauth]/route.ts   # Web NextAuth
    communities/route.ts          # Web 用
    mobile/
      auth/
        login/route.ts
        google/route.ts
        refresh/route.ts
      me/route.ts
      communities/route.ts
      communities/[id]/route.ts
      chats/[id]/messages/route.ts
src/
  common/                          # ビジネスロジック共有層
    communities.ts
    chats.ts
    auth-server.ts
lib/
  mobile-auth.ts                   # Bearer 検証
```

## トークン更新 (refresh) を入れるか問題

JWT を 30 日にしておくと、初期段階では refresh エンドポイントを書かなくても回る。だが、

- ユーザーが退会してから 30 日近くトークンが生きる
- パスワード変更時に旧 JWT を無効化したい
- iOS / Android で生体認証を間に挟みたい

という要件が出てきた時に refresh が必要になる。**書き始めるのは認証要件が固まってからで遅くない**。最初に書くと未使用 API が増えて事故源になる。

## 落とし穴

1. **`/api/mobile/auth/login` を CSRF 保護対象から外し忘れる** と、Web に CSRF middleware を入れた瞬間に mobile login が 403 で落ちる
2. **Web 側のレスポンスをそのまま流用** すると、画像 URL が相対パスで返り mobile から取れない。`/api/mobile/*` は **常に absolute URL** で返す
3. **monorepo で `src/common` を mobile から import すると Metro が解決に失敗**することがある。`metro.config.js` の `watchFolders` に親ディレクトリを追加する

```js
// mobile/metro.config.js
const { getDefaultConfig } = require("expo/metro-config");
const path = require("path");
const config = getDefaultConfig(__dirname);
config.watchFolders = [path.resolve(__dirname, "../src")];
module.exports = config;
```

## 次の章

第 7 章では Push 通知 (expo-notifications + FCM / APNs) の配線と、デバイストークンをサーバに渡す経路を扱う。
