---
title: "参考文献"
free: true
---

# 参考文献

本書で引用したすべての文献・記事・公式ドキュメント。
**本書を読み終えたら、これらの原典に当たることを強く推奨する**。

---

## 📚 書籍(基礎文献)

### Eric Evans, *Domain-Driven Design* シリーズ

- Eric Evans, *Domain-Driven Design: Tackling Complexity in the Heart of Software*, Addison-Wesley, 2003.
  - 通称「青本」。DDD の原典。Tactical/Strategic 両方を網羅。
  - 邦訳: 『エリック・エヴァンスのドメイン駆動設計』翔泳社、2011。

### Vaughn Vernon, *Implementing Domain-Driven Design*

- Vaughn Vernon, *Implementing Domain-Driven Design*, Addison-Wesley, 2013.
  - 通称「赤本」。実装パターンを詳述。Aggregate 設計の実践的指針。
  - 邦訳: 『実践ドメイン駆動設計』翔泳社、2015。

- Vaughn Vernon, *Domain-Driven Design Distilled*, Addison-Wesley, 2016.
  - DDD の要約版。150 ページで核心を読める。
  - 邦訳: 『ドメイン駆動設計 蒸留』翔泳社、2018。

### Robert C. Martin, *Clean Architecture*

- Robert C. Martin, *Clean Architecture: A Craftsman's Guide to Software Structure and Design*, Prentice Hall, 2017.
  - Clean Architecture の体系書。SOLID 原則と層分離。
  - 邦訳: 『Clean Architecture 達人に学ぶソフトウェアの構造と設計』KADOKAWA、2018。

- Robert C. Martin, *Clean Code: A Handbook of Agile Software Craftsmanship*, Prentice Hall, 2008.
  - 命名・関数・コメント等のコード品質。
  - 邦訳: 『Clean Code アジャイルソフトウェア達人の技』アスキー・メディアワークス、2009。

### Martin Fowler, *Patterns of Enterprise Application Architecture*

- Martin Fowler, *Patterns of Enterprise Application Architecture*, Addison-Wesley, 2002.
  - 通称 *PoEAA*。Repository / Unit of Work / Data Mapper / Service Layer 等の原典。
  - 邦訳: 『エンタープライズアプリケーションアーキテクチャパターン』翔泳社、2005。

### Martin Fowler, *Refactoring*

- Martin Fowler, *Refactoring: Improving the Design of Existing Code*, 2nd ed., Addison-Wesley, 2018.
  - 第 3 章 "Bad Smells in Code" — Primitive Obsession などのコードの匂い。
  - 邦訳: 『リファクタリング 既存のコードを安全に改善する(第 2 版)』オーム社、2019。

### Michael Feathers, *Working Effectively with Legacy Code*

- Michael Feathers, *Working Effectively with Legacy Code*, Prentice Hall, 2004.
  - Characterization Tests、Seams、レガシーコード改善の体系書。
  - 邦訳: 『レガシーコード改善ガイド』翔泳社、2009。

### Andy Hunt, Dave Thomas, *The Pragmatic Programmer*

- Andy Hunt, Dave Thomas, *The Pragmatic Programmer: From Journeyman to Master*, Addison-Wesley, 1999. (20th Anniversary ed., 2019)
  - Tell, Don't Ask の出典。実務に効く 70 のティップス。
  - 邦訳: 『達人プログラマー(新装版)』オーム社、2016。

### GoF, *Design Patterns*

- Erich Gamma, Richard Helm, Ralph Johnson, John Vlissides, *Design Patterns: Elements of Reusable Object-Oriented Software*, Addison-Wesley, 1994.
  - Strategy / Factory / State / Template Method 等の原典。
  - 邦訳: 『オブジェクト指向における再利用のためのデザインパターン(改訂版)』ソフトバンククリエイティブ、1999。

### Jez Humble, David Farley, *Continuous Delivery*

- Jez Humble, David Farley, *Continuous Delivery: Reliable Software Releases through Build, Test, and Deployment Automation*, Addison-Wesley, 2010.
  - Branch by Abstraction、Feature Toggle 等。
  - 邦訳: 『継続的デリバリー 信頼できるソフトウェアリリースのためのビルド・テスト・デプロイメントの自動化』KADOKAWA、2017。

### その他基礎文献

- Mike Cohn, *Succeeding with Agile: Software Development Using Scrum*, Addison-Wesley, 2009. (テストピラミッド)
- Sandi Metz, *Practical Object-Oriented Design in Ruby*, Addison-Wesley, 2012. (オブジェクト指向設計の名著)
- Bertrand Meyer, *Object-Oriented Software Construction*, Prentice Hall, 1988. (Open-Closed Principle 原典)
- Vlad Khononov, *Learning Domain-Driven Design*, O'Reilly, 2021. (Strategic DDD 入門)
- Chris Richardson, *Microservices Patterns*, Manning, 2018. (Saga パターン等)

---

## 🌐 原典 Web 記事

### Robert C. Martin (Uncle Bob)

- [The Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html), 2012-08-13. — 同心円図の原典
- [The Single Responsibility Principle](https://blog.cleancoder.com/uncle-bob/2014/05/08/SingleReponsibilityPrinciple.html), 2014.
- [The Dependency Inversion Principle](https://www.cs.utexas.edu/users/downing/papers/PrinciplesAndPatterns-1996.pdf), 1996. — DIP 原典 PDF。

### Martin Fowler — bliki

- [AnemicDomainModel](https://martinfowler.com/bliki/AnemicDomainModel.html), 2003-11-25.
- [TellDontAsk](https://martinfowler.com/bliki/TellDontAsk.html), 2013-07-18.
- [CQRS](https://martinfowler.com/bliki/CQRS.html), 2011-07-14.
- [Yagni](https://martinfowler.com/bliki/Yagni.html), 2015-05-26.
- [BoundedContext](https://martinfowler.com/bliki/BoundedContext.html), 2014-01-15.
- [UbiquitousLanguage](https://martinfowler.com/bliki/UbiquitousLanguage.html), 2006.
- [ValueObject](https://martinfowler.com/bliki/ValueObject.html), 2016-11-14.
- [DomainEvent](https://martinfowler.com/eaaDev/DomainEvent.html), 2005.
- [Repository (EAA Catalog)](https://martinfowler.com/eaaCatalog/repository.html).
- [Unit of Work (EAA Catalog)](https://martinfowler.com/eaaCatalog/unitOfWork.html).
- [StranglerFigApplication](https://martinfowler.com/bliki/StranglerFigApplication.html), 2004-06-29.
- [BranchByAbstraction](https://martinfowler.com/bliki/BranchByAbstraction.html), 2014-04-07.
- [TestDouble](https://martinfowler.com/bliki/TestDouble.html), 2006-01-17.
- [Mocks Aren't Stubs](https://martinfowler.com/articles/mocksArentStubs.html), 2007-01-02.

### Alistair Cockburn

- [Hexagonal Architecture (Ports and Adapters)](https://alistair.cockburn.us/hexagonal-architecture/), 2005.

### Jeffrey Palermo

- [The Onion Architecture: part 1](https://jeffreypalermo.com/2008/07/the-onion-architecture-part-1/), 2008-07-29.
- [The Onion Architecture: part 2](https://jeffreypalermo.com/2008/07/the-onion-architecture-part-2/), 2008-07-30.
- [The Onion Architecture: part 3](https://jeffreypalermo.com/2008/07/the-onion-architecture-part-3/), 2008-08-04.

### Vaughn Vernon

- [Effective Aggregate Design Part I: Modeling a Single Aggregate](https://www.dddcommunity.org/library/vernon_2011/), 2011. (IEEE Software)
- [Effective Aggregate Design Part II: Making Aggregates Work Together](https://www.dddcommunity.org/library/vernon_2011/), 2011.
- [Effective Aggregate Design Part III: Gaining Insight Through Discovery](https://www.dddcommunity.org/library/vernon_2011/), 2011.

### Werner Vogels

- [Eventually Consistent](https://www.allthingsdistributed.com/2008/12/eventually_consistent.html), 2008. (*Communications of the ACM*, Jan 2009)

### Joel Spolsky

- [Things You Should Never Do, Part I](https://www.joelonsoftware.com/2000/04/06/things-you-should-never-do-part-i/), 2000-04-06.

### その他

- Ham Vocke, [The Practical Test Pyramid](https://martinfowler.com/articles/practical-test-pyramid.html), 2018. (Fowler's blog)
- Jimmy Bogard, [Vertical Slice Architecture](https://jimmybogard.com/vertical-slice-architecture/), 2018.
- Jimmy Bogard, [Hybrid Persistence with EF Core and Dapper](https://jimmybogard.com/hybrid-persistence-with-ef-core-and-dapper/), 2017.
- Hector Garcia-Molina, Kenneth Salem, "Sagas", *ACM SIGMOD*, 1987.
- Brian Foote, Joseph Yoder, [Big Ball of Mud](http://www.laputan.org/mud/), 1997.
- Chris Richardson, [Pattern: Transactional outbox](https://microservices.io/patterns/data/transactional-outbox.html).
- Chris Richardson, [Pattern: Saga](https://microservices.io/patterns/data/saga.html).
- Mark Seemann, [Mocks for Commands, Stubs for Queries](https://blog.ploeh.dk/2013/10/23/mocks-for-commands-stubs-for-queries/), 2013.

---

## 📘 公式ドキュメント

### Microsoft Learn — C# / .NET

- [Primary constructors (C# 12)](https://learn.microsoft.com/en-us/dotnet/csharp/whats-new/tutorials/primary-constructors)
- [Records (C# 9+)](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/record)
- [Patterns (C# 8+)](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/patterns)
- [With expression](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/with-expression)

### Microsoft Learn — EF Core

- [Backing fields](https://learn.microsoft.com/en-us/ef/core/modeling/backing-field)
- [Owned Entity Types](https://learn.microsoft.com/en-us/ef/core/modeling/owned-entities)
- [Value conversions](https://learn.microsoft.com/en-us/ef/core/modeling/value-conversions)
- [Saving data](https://learn.microsoft.com/en-us/ef/core/saving/)

### TypeScript / React

- [TypeScript Handbook — Branded Types](https://www.typescriptlang.org/docs/handbook/2/everyday-types.html)
- [React — useState](https://react.dev/reference/react/useState)
- [React Server Components](https://react.dev/reference/rsc/server-components)
- [Zod](https://zod.dev/)
- [React Hook Form](https://react-hook-form.com/)

### テスト

- [Testcontainers](https://testcontainers.com/)
- [Playwright](https://playwright.dev/)
- [Vitest](https://vitest.dev/)
- [Mock Service Worker](https://mswjs.io/)
- [xUnit](https://xunit.net/)
- [Moq](https://github.com/devlooped/moq)

### ライブラリ

- [MediatR](https://github.com/jbogard/MediatR)
- [AutoMapper](https://automapper.org/)
- [Dapper](https://github.com/DapperLib/Dapper)

---

## 📺 講演動画

- [Eric Evans — DDD Europe 2019 Keynote](https://www.youtube.com/watch?v=GogQor9WG-c)
- [Greg Young — CQRS and Event Sourcing](https://www.youtube.com/watch?v=JHGkaShoyNs)
- [Sandi Metz — All the Little Things](https://www.youtube.com/watch?v=8bZh5LMaSmE) (Refactoring 名講演)

---

## 🇯🇵 日本語の良書 / 記事

- 増田亨『現場で役立つシステム設計の原則』技術評論社、2017。 — Rich Domain Model の実装入門。
- 松岡幸一郎『ドメイン駆動設計入門 ボトムアップでわかる!ドメイン駆動設計の基本』翔泳社、2020。
- 川島義隆ほか『ドメイン駆動設計 モデリング/実装ガイド』 2020(電子書籍)。 — 日本語で実装パターンを網羅。
- [little-hands ブログ — ドメイン駆動設計関連記事](https://little-hands.hatenablog.com/) — 松岡氏の連載。

---

## 🌟 本書の補足リソース

本書のソースコード(章末演習の解答含む完全版)は、CreaNest Engineering のリポジトリで公開予定:

- GitHub: (publication-time に URL を更新)
- Zenn 本: (publication-time に URL を更新)
- 著者: [@sakaki_creanest](https://x.com/sakaki_creanest)

ご質問・誤りの指摘は X / GitHub Issue で。

---

## 引用について

本書を引用される場合は以下の書式で:

```text
@sakaki_creanest, "if の住所を決める本 — Clean Architecture × DDD でロジックの居場所を見極める設計術", 2026.
```

本書は CC BY 4.0 で配布する。本書に登場するすべての引用元については各原典の著作権が優先する。

---

→ **[トップに戻る](README)**
