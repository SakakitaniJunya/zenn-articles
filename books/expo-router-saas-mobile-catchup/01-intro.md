---
title: "はじめに — Web SaaS にモバイルを足す 4 つの選択肢"
free: true
---

> 2026 年、Next.js SaaS にモバイルアプリ版を 2 週間で足した。`tailwind.config.js` の token をそのまま使い、認証は Web の `NEXTAUTH_SECRET` を再利用し、API は `/api/mobile/*` に薄く分離。10 時間溶かしたハマり (NativeWind cache 腐敗 / iOS triple blocker 等) も含めて、9 章で再現可能にしたのが本書。

Next.js で動いている社内 SaaS や C2C プラットフォームに「モバイルアプリ版」を足したい、というのは珍しい話ではない。問題はそこから先で、選択肢が多すぎて 1 人開発だと判断ミスのコストが大きい。

本書は **既存 Web の認証・API・型・Tailwind トークンを最大限再利用しながら、Expo Router でモバイルを 2 週間で立ち上げる** という選択肢を採った人向けの実践ガイドだ。**ゼロから React Native を学ぶ本ではなく、既存 Web SaaS の資産を最大流用してモバイルを足す本**として位置付けている。

## 4 つの選択肢を雑に比較する

| 選択肢 | 立ち上げ速度 | 再利用度 | iOS/Android ネイティブ感 | 将来の拡張余地 |
|---|---|---|---|---|
| ① PWA + Web View ラッパ | ◎ (数日) | ◎ | △ | ✕ (App Store 審査がたまにキツい) |
| ② React Native (素) | △ (1〜2 ヶ月) | △ | ○ | ◎ |
| ③ **Expo + Expo Router** | ◎ (1〜2 週) | ○ | ○ | ○ |
| ④ Flutter | ✕ (型・API が別言語) | ✕ | ◎ | ○ |

筆者の判断は **③ Expo + Expo Router** だった。理由は次の 4 つに集約される。

### 1. file-based routing は Next.js から発想を持ち越せる

`app/(tabs)/index.tsx` / `app/community/[id].tsx` という構造は Next.js App Router をやった人にとって完全に同型だ。SSR は無いが、ファイル配置 → ナビゲーション、という頭の使い方を変えずに済む。

### 2. NativeWind v4 で Tailwind トークンを Web と共有できる

`tailwind.config.js` を Web 側と並べて書ける。Spacing / カラー / typography を 1 つの config で揃えると、Web の UI を mobile に縮小コピーする作業が「class 名のコピペでだいたい合う」レベルになる。

### 3. expo-secure-store と localStorage を抽象化すれば JWT 認証を流用できる

NextAuth で発行している JWT (HS256 + `NEXTAUTH_SECRET` 署名) を mobile からも受けられるように `/api/mobile/auth/*` を新設する。Web 側 NextAuth はそのまま、mobile は Bearer token 一本で済む。

### 4. Web プレビュー (`expo start --web`) が地味に効く

ローカルで「ログイン画面を Tailwind で組んだら最終的にどう見えるか」を **iOS シミュレータを起動せずに** 試せる。1 日 100 回スタイル調整をする時期にエミュレータの起動オーバーヘッドが消えるのはデカい。

## 本書の対象読者

- **Solo CEO or 〜5 名チームで Web SaaS を運用していて、Swift / Kotlin を雇わずに mobile を出したい人**
- Next.js + Tailwind で Web SaaS を動かしている開発者
- 「app/ ディレクトリ」「`use client`」「Server Components」あたりが既知
- TypeScript strict 慣れ (`any` を書かない人)
- iOS / Android のネイティブ部分には興味があるが、Swift / Kotlin を書きたくない

## 本書の対象外

- Flutter / Capacitor / NativeScript 派生
- React Native の細かい新アーキテクチャ (TurboModules / Fabric の内部) を深掘りする
- Apple Developer / Google Play 提出の審査ノウハウ (これは別書のテーマ)

## 本書のサンプルコードについて

各章のコードは **特定アプリ非依存の最小サンプル** に書き直してある。実際のプロダクションでは型がもっと複雑になり、エラーハンドリングも増えるが、最初に押さえるべき形は本書のサンプルで十分だ。

> **注記**: 著者は 2026 年に Web SaaS のモバイル版を 1 人 CEO 体制で立ち上げた。本書は実プロジェクトのコードを直接転載していないが、ハマったポイント・採用した設計判断はその経験に基づく。

## 次の章

第 2 章では `expo-router` の最小構成を立てる。`app/_layout.tsx` / route group / dynamic route の使い方を、Next.js App Router からの差分中心で見る。
