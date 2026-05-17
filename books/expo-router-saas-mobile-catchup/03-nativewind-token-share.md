---
title: "NativeWind v4 — Web の Tailwind トークンを 1 設定で mobile に共有"
---

[NativeWind](https://www.nativewind.dev/) は Tailwind を React Native の `View` / `Text` / `Pressable` に当てられるようにするライブラリで、v4 から内部実装が CSS Variables ベースになり、Web 版 Tailwind とほぼ同じ token を使えるようになった。

本章のゴール:

1. NativeWind v4 を Expo に組み込む
2. Web 側 `tailwind.config.js` と **token (color / spacing / typography) を 1 つの config で共有** する
3. クラス名が「半分だけ効く」典型症状の原因と直し方を知る

## インストール

```bash
pnpm add nativewind tailwindcss@^3.4
pnpm add -D postcss autoprefixer
```

> **重要**: ここで「v4」と書いている所には 2 種類ある。
> - **NativeWind v4** — 本書で採用する RN 用 Tailwind の最新メジャー
> - **Tailwind CSS v4** — Tailwind 本体の最新メジャー (API 変更大、`@theme` directive 等)
>
> 2026-05 時点で **NativeWind v4 がサポートするのは Tailwind v3.4 系まで**。Tailwind v4 は NativeWind 側で未対応のため、`tailwindcss@^3.4` を必ず pin する。

## tailwind.config.js (Web と同型に書く)

```js
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./app/**/*.{tsx,ts}",
    "./components/**/*.{tsx,ts}",
  ],
  presets: [require("nativewind/preset")],
  theme: {
    extend: {
      colors: {
        brand: {
          50:  "#f5f7ff",
          500: "#5b67ff",
          900: "#1d2370",
        },
      },
      fontFamily: {
        sans: ["system-ui", "sans-serif"],
      },
    },
  },
};
```

ここまでは Web の Tailwind とほぼ同じ。**唯一違うのは `presets: [require("nativewind/preset")]`** の 1 行で、これが RN 専用の variant (Pressable の `active:` など) を有効化する。

## babel.config.js と metro.config.js

```js
// babel.config.js
module.exports = function (api) {
  api.cache(true);
  return {
    presets: [
      ["babel-preset-expo", { jsxImportSource: "nativewind" }],
      "nativewind/babel",
    ],
  };
};
```

```js
// metro.config.js
const { getDefaultConfig } = require("expo/metro-config");
const { withNativeWind } = require("nativewind/metro");

const config = getDefaultConfig(__dirname);
module.exports = withNativeWind(config, { input: "./global.css" });
```

```css
/* global.css */
@tailwind base;
@tailwind components;
@tailwind utilities;
```

`app/_layout.tsx` の先頭で `import "@/global.css"` を 1 行追加すれば NativeWind が起動する。

## Web 側との token 共有 (monorepo パターン)

monorepo (`packages/ui-tokens/tailwind.config.js`) に token だけを切り出し、Web / mobile 両方から `presets: [require("@your-org/ui-tokens/tailwind.config.js")]` で読むのが最もスケールする。

最小構成:

```js
// packages/ui-tokens/tailwind.config.js
module.exports = {
  theme: {
    extend: {
      colors: { brand: { 500: "#5b67ff" } },
      spacing: { 18: "4.5rem" },
    },
  },
};
```

Web 側:
```js
module.exports = {
  presets: [require("@your-org/ui-tokens/tailwind.config.js")],
  content: ["./app/**/*.{tsx,ts}", ...],
};
```

Mobile 側:
```js
module.exports = {
  presets: [
    require("nativewind/preset"),
    require("@your-org/ui-tokens/tailwind.config.js"),
  ],
  content: ["./app/**/*.{tsx,ts}", ...],
};
```

token を 1 ファイルにまとめると、Designer が色を変えた時に Web / mobile 両方に同時反映できる。

## NativeWind の使い方

```tsx
import { View, Text, Pressable } from "react-native";

export function PrimaryButton({ label, onPress }: { label: string; onPress: () => void }) {
  return (
    <Pressable
      onPress={onPress}
      className="rounded-2xl bg-brand-500 px-6 py-3 active:opacity-80"
    >
      <Text className="text-white font-semibold text-base">{label}</Text>
    </Pressable>
  );
}
```

Web の React 開発と書き味は同じ。`active:` は Pressable に押下中だけ当たる variant で、RN 専用。

## 「クラス名が半分だけ効く」症状の真因

NativeWind を入れて 2-3 週間使うと、ほぼ全員が遭遇する症状がある。

- 同じ class を当てているのに、特定の screen でだけ効かない
- 一見、設定が間違っているように見える
- でも `tailwind.config.js` も `babel.config.js` も正しい

これは **Metro のキャッシュと Expo のキャッシュが腐っているだけ** の場合がほとんどだ。NativeWind v4 は generated CSS を `.expo` / `node_modules/.cache` に置くため、上書きが間に合わないことがある。

```bash
rm -rf .expo node_modules/.cache
pnpm expo start --clear
```

これを最初から「症状の第一手」として知っておくと、設定を疑って 10 時間溶かす事故が防げる。筆者は最初に書き換え地獄に落ちて 1 日溶かした。

## 次の章

第 4 章では Web 側で使っている NextAuth の JWT を mobile から流用する `/api/mobile/auth/*` の設計を見る。
