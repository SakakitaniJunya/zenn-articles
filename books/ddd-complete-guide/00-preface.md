---
title: "はじめに — なぜ今、DDDを学ぶべきか"
---


## この本で学ぶこと

Domain-Driven Design (DDD) は、2003 年に Eric Evans が著した "Domain-Driven Design: Tackling Complexity in the Heart of Software"（通称「ブルーブック」）で体系化されました。20 年以上が経過した今でも、複雑なビジネスシステムを設計するうえで最も影響力のある思想のひとつです。

しかし DDD は「学びにくい」ことで悪名高い概念でもあります。

多くの開発者が次のように感じます:

- Entity と Value Object は分かった気がするが、どこに境界を引けばいいのか分からない
- Repository パターンは知っているが、なぜ DAO ではダメなのか説明できない
- Bounded Context という言葉は聞いたことがあるが、実際にどう決めるのか分からない
- コードを DDD っぽく書いているつもりだが、設計議論で「貧血ドメインモデルだ」と指摘される

この本の目的は、「DDD の全体像を頭から尻尾まで繋げる」ことです。パターンの暗記ではなく、**なぜそのパターンが必要なのか**、**どのように判断するのか**、**実際のコードでどう表現するのか** を、一冊で理解できるように書きました。

## 本書の構成

```
Part I   DDD の思想         (第 1-3 章)
Part II  戦略的設計          (第 4-6 章)
Part III 戦術的設計          (第 7-14 章)
Part IV  アーキテクチャ       (第 15-17 章)
Part V   実践               (第 18-21 章)
```

## 登場する思想家と文献

本書で参照する主な先人たちを紹介します。各章の「専門家の視点」はこれらの文献と登壇資料に基づいています。

| 人物 | 貢献 | 主著 |
|------|------|------|
| **Eric Evans** | DDD の発明者。「ブルーブック」の著者 | *Domain-Driven Design* (2003) |
| **Vaughn Vernon** | 実践 DDD の普及。「レッドブック」の著者 | *Implementing Domain-Driven Design* (2013) |
| **Alberto Brandolini** | Event Storming の考案者 | *Introducing EventStorming* (2021) |
| **Greg Young** | CQRS / Event Sourcing の提唱者 | ブログ・カンファレンス登壇 (2010~) |
| **Martin Fowler** | Anemic Domain Model アンチパターン命名 | *Patterns of Enterprise Application Architecture* (2002) |
| **Alistair Cockburn** | Hexagonal Architecture (Ports & Adapters) | *Hexagonal Architecture* 論文 (2005) |
| **Nick Tune** | Strategic DDD の現代的実践 | *Architecture Modernization* (2023) |

## サンプルコード

本書のすべてのコードは C# (.NET 9) で書かれています。対応するリポジトリは以下で公開しています。

```
https://github.com/SakakitaniJunya/ddd-csharp-sample
```

ディレクトリ構成:

```
src/
├── Domain/       ← ビジネスルールの核 (外部依存ゼロ)
├── Application/  ← ユースケースのオーケストレーター
└── Infrastructure/ ← DB・外部API・フレームワーク
```

---

> "The heart of software is its ability to solve domain-related problems for its user."
>
> — Eric Evans, *Domain-Driven Design* (2003)

ソフトウェアの心臓は、ユーザーのドメイン関連の問題を解決する能力にある。この一文が、DDD のすべてを言い表しています。

では始めましょう。
