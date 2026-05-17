---
title: "SecureStore 抽象化 — Web プレビューを壊さず JWT を保管する"
---

mobile アプリで JWT を保存する時の常識的選択肢は `expo-secure-store`。iOS は Keychain、Android は EncryptedSharedPreferences にバインドされていて、アプリ削除以外で他アプリから読めない。

問題は **`expo-secure-store` が Web (ブラウザ) で動かない** ことだ。Expo は `expo start --web` で React Native for Web として動作プレビューできるが、SecureStore は native module なので `Platform.OS === "web"` の時にエラーを吐く。

## 解決策: Platform 分岐を 1 ファイルに閉じ込める

```ts
// lib/auth-storage.ts
import { Platform } from "react-native";
import * as SecureStore from "expo-secure-store";

const KEY = "auth.session";

type Session = { token: string; userId: string };

export async function saveSession(session: Session): Promise<void> {
  const json = JSON.stringify(session);
  if (Platform.OS === "web") {
    localStorage.setItem(KEY, json);
    return;
  }
  await SecureStore.setItemAsync(KEY, json, {
    keychainAccessible: SecureStore.AFTER_FIRST_UNLOCK,
  });
}

export async function loadSession(): Promise<Session | null> {
  const raw = Platform.OS === "web"
    ? localStorage.getItem(KEY)
    : await SecureStore.getItemAsync(KEY);
  if (!raw) return null;
  try {
    return JSON.parse(raw) as Session;
  } catch {
    return null;
  }
}

export async function clearSession(): Promise<void> {
  if (Platform.OS === "web") {
    localStorage.removeItem(KEY);
    return;
  }
  await SecureStore.deleteItemAsync(KEY);
}

export async function getToken(): Promise<string | null> {
  const session = await loadSession();
  return session?.token ?? null;
}
```

これだけ。残りの全コードは `saveSession` / `loadSession` / `clearSession` を呼ぶだけで、内部の Platform 分岐を意識しなくてよくなる。

## Auth Context との接続

React Context に session を持たせる典型形:

```tsx
// lib/auth-context.tsx
import { createContext, useContext, useEffect, useState } from "react";
import {
  loadSession, saveSession, clearSession, type Session,
} from "@/lib/auth-storage";

type Status = "loading" | "authenticated" | "unauthenticated";
type Ctx = {
  status: Status;
  session: Session | null;
  login: (s: Session) => Promise<void>;
  logout: () => Promise<void>;
};

const AuthContext = createContext<Ctx | null>(null);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [status, setStatus] = useState<Status>("loading");

  useEffect(() => {
    let cancel = false;
    (async () => {
      const s = await loadSession();
      if (cancel) return;
      setSession(s);
      setStatus(s ? "authenticated" : "unauthenticated");
    })();
    return () => { cancel = true; };
  }, []);

  return (
    <AuthContext.Provider
      value={{
        status,
        session,
        login: async (s) => { await saveSession(s); setSession(s); setStatus("authenticated"); },
        logout: async () => { await clearSession(); setSession(null); setStatus("unauthenticated"); },
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth(): Ctx {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used inside <AuthProvider>");
  return ctx;
}
```

`status === "loading"` の間にナビゲーションが走らないように、`_layout.tsx` 側で `null` を返してスプラッシュを維持する。

## なぜ Web プレビューを温存するのか

「mobile アプリなんだから native でしか動かなくていいでしょ」とも思えるが、実際に開発中に Web プレビューが効くと:

- **Designer / 営業に共有しやすい** (ローカルでサーバ立てたら社内 LAN で見られる)
- **iOS シミュレータより起動 5 秒早い** → スタイル微調整サイクルが速い
- **E2E テストを Playwright で書きやすくなる** (Maestro と並走)

これらが地味に効くので、SecureStore の差を抽象化するコストは安い保険。

## キー設計のコツ

- `auth.session` のように **namespace + key** の形でキー名を統一しておく
- 後から `prefs.lang` `cache.list.communities` などが増える時、prefix で安全に分けられる
- iOS Keychain は accessibility 設定 (`AFTER_FIRST_UNLOCK` 等) で「初回起動直後の Background fetch でも読めるか」を変えられる。Push 通知から起動して即 API 叩きたい場合は `AFTER_FIRST_UNLOCK_THIS_DEVICE_ONLY` を選ぶ

## 落とし穴

1. **SecureStore は 2KB を超えると公式に警告** が出る (expo-secure-store docs)。書き込み自体が即失敗するわけではないが、サイズ増加で挙動が変わる将来リスクを避けるため、session 以外の大きな JSON は入れない
2. **Expo Web プレビューでは Service Worker が悪さ** することがある。`localStorage` をいじっても画面が更新されない時は SW unregister
3. **Android で `SecureStore.deleteItemAsync` がエラー** を吐くことがある (キーが存在しない時)。try/catch で握り潰すか、`getItemAsync` で存在チェックしてから delete

## 次の章

第 6 章では Web の既存 API を `/api/mobile/*` ネームスペースで切り直すパターンを扱う。
