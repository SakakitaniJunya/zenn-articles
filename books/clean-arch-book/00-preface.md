---
title: "まえがき — なぜこの本を書いたか"
free: true
---

# まえがき — なぜこの本を書いたか

## ある日のコードレビュー

```csharp
public async Task<Result> HandleAsync(CreateOrderCommand cmd, CancellationToken ct)
{
    var order = factory.Create(cmd);

    if (cmd.IsExpress) { ... }
    else { ... }

    if (cmd.HasCoupon) { ... }

    if (cmd.IsAutoConfirm)
    {
        if (cmd.AutoConfirmReason != "VIP")
        {
            if (await pricingService.IsAvailableAsync(order, ct))
            {
                // ...
            }
        }
    }
    else { ... }

    // 200 行つづく
}
```

これは私が実際に PR レビューで遭遇したコードを抽象化したものだ。元のコードは 1 メソッド 400 行を超えていた。コミット履歴をたどると、最初は 30 行だった。半年で 13 倍に膨らんだ。

「**機能追加するたびに if が増える**」のは、ほぼ全てのプロダクトコードで起きる。これ自体は当たり前の現象だ。問題は、**増えた if が正しい場所にいない** ことにある。

## この本が答えること

この本は次の問いに答える。

> 「業務ルールの if を、コードベースのどこに書くべきか?」

答えは「Entity に書きなさい」のような一行では済まない。**判定の手順** が必要だ。具体的には:

1. その if は `this.State`(=自身の状態) を読むか?
2. その if は引数だけで結果が決まる純粋計算か?
3. その if は外部依存(DB / API / マスタ参照)を必要とするか?
4. その if は複数の Aggregate にまたがるか?

この 4 つの問いを順に当てると、どの登場人物(Entity / Value Object / Domain Service / Handler)に書くべきかが決まる。本書 [第 5 章](05-judgment-table) で詳述するこの判定表は、本書の心臓部だ。

## 誰のための本か

### 想定読者

- **新人〜中堅エンジニア** で、Clean Architecture / DDD という単語は知っているが、いざコードを書くと「これってどこに置くんだっけ?」と毎回迷う人
- **チームリード** で、新メンバに「なぜここに書いてはいけないか」を毎回口頭で説明していて疲れている人
- **アーキテクト** で、PR レビューのチェックポイントを言語化して共有したい人

### 前提知識

- C# か TypeScript のどちらかは書ける(両方は不要)
- `interface`, `class`, `async/await` は知っている
- Clean Architecture / DDD は「同心円の絵を見たことがある」程度で OK

これより深い知識は **第 2-3 章で全部入れ直す**。前提ゼロでも読めるように設計してある。

## 本書の特徴

### 1. **1 つの題材を全章で育てていく**

題材は **EC サイトの `Order` Aggregate** に固定する。第 6 章で状態遷移を入れ、第 7 章で VO を切り出し、第 8 章で Domain Service を足し、第 9 章で Aggregate 境界を引き直し、第 10 章で Handler を解体する。同じコードがリファクタで進化していくのを追体験できる。

### 2. **Before/After を必ず両方載せる**

「これがアンチパターンです」だけでは不十分。「Before のコードがあって、After のコードがあって、その差分がなぜ良くなったか」を全章で揃える。

### 3. **すべての主張に出典を張る**

Martin Fowler、Eric Evans、Robert Martin、Vaughn Vernon、Alistair Cockburn — 設計の原典は意外と少数の人物に集中している。彼らの原著ページ・ブログへのリンクをすべて張る。本書を読み終わったら、原典に当たれるようにしてある。

### 4. **Mermaid 図を多用する**

文字だけで設計を説明するのは限界がある。本書は **1 章につき平均 3-5 個の Mermaid 図** を入れる。「アーキテクチャ図」「シーケンス図」「状態遷移図」「依存関係図」を使い分ける。

### 5. **C# と TypeScript の両方で書く**

バックエンドの題材は C#(.NET 8 / EF Core)、フロントエンドは TypeScript(React + Zod)。**第 12 章** はフロントエンド側に同じ原則を適用する独立章。

## 本書が "言わない" こと

本書は **設計の地図** であって、**フレームワーク完全ガイドではない**。以下は意図的に深入りしない。

- ❌ ASP.NET Core の設定方法、DI コンテナの細かい挙動
- ❌ Entity Framework Core のクエリ最適化、N+1 問題の解決
- ❌ CQRS の Read モデル設計、Event Sourcing
- ❌ マイクロサービス間通信、分散トランザクション
- ❌ Kubernetes、Docker、CI/CD パイプライン

これらは別の良書がたくさんある。本書は「**ロジックの居場所を見極める一点**」に集中する。

## 読み方

### **通読派** の場合

第 1 章から順に読む。1 日 1 章ペースで 2 週間。第 5 章までは前提知識の整理なので、サクサク読める。第 6 章以降はコード例を Editor に貼って動かしながら読むと定着率が変わる。

### **逆引き派** の場合

[README](README) の章一覧から、いま自分が直面している問題に近い章を選ぶ。例:

- 「Handler が肥大化してきた」→ [第 10 章](10-handler-decomposition)
- 「`OrderStatus` が switch だらけ」→ [第 6 章](06-entity-state-transition)
- 「string で値オブジェクトを扱っている気がする」→ [第 7 章](07-value-object)
- 「Aggregate の境界をどう引けばいいか分からない」→ [第 9 章](09-aggregate-boundary)
- 「テストが書きにくい」→ [第 13 章](13-test-strategy)
- 「Legacy をどう直していくか」→ [第 14 章](14-legacy-migration)

### **チーム研修教材として使う場合**

週次の勉強会で 1 章ずつ取り上げ、章末演習を全員でレビューし合う形式を推奨する。新メンバ onboarding に使う場合は、第 1-5 章を 1 日で読み切り、第 6 章以降を週 1 章ペースで進めるとよい。

## 謝辞

この本は CreaNest の AI Agent と人間レビュアーの共同作業で書いた。
原典に当たる作業を AI Agent が助けてくれたおかげで、出典付きの主張を高密度で並べることができた。

エンジニアリングの設計知見は、Martin Fowler、Eric Evans、Robert Martin、Vaughn Vernon、Alistair Cockburn ら巨人の肩の上にある。本書は彼らの思想を **日本の開発現場の文脈に翻訳しただけ** に過ぎない。原典こそ最も価値がある。

それでは始めよう。次の章で、なぜ if は増殖するのか、その病理を診断する。

→ **[第 1 章 なぜ if は増殖するのか](01-why-if-grows)**
