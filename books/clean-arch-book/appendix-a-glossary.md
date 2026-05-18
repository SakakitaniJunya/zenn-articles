---
title: "付録 A — 用語辞典"
free: true
---

# 付録 A — 用語辞典

本書で使った用語を、本文での登場章 + 公式ソースへのリンクと共に整理する。
**未知の用語が本文に出てきたらここに戻る** ことを推奨。

---

## A-1. アーキテクチャ概念

| 用語 | 詳細 | 本書 |
| --- | --- | --- |
| **[Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)** | Robert C. Martin が 2012 年に提唱。同心円モデルで「外側 → 内側」の依存だけを許す。中心は Entities(業務ルール)、外側は Frameworks。 | [Ch2](02-clean-architecture) |
| **[DDD(Domain-Driven Design)](https://en.wikipedia.org/wiki/Domain-driven_design)** | Eric Evans が *Domain-Driven Design* (2003) で体系化。業務概念をそのままコードの型に写し、ドメイン専門家とコードの語彙を一致させる方法論。 | [Ch3](03-ddd-minimum) |
| **[Hexagonal Architecture / Ports & Adapters](https://alistair.cockburn.us/hexagonal-architecture/)** | Alistair Cockburn が 2005 年に提唱。Clean Architecture と思想は同じ(外側にアダプタ、内側に純粋業務)。Port = interface、Adapter = 実装。 | [Ch2](02-clean-architecture) |
| **[Onion Architecture](https://jeffreypalermo.com/2008/07/the-onion-architecture-part-1/)** | Jeffrey Palermo が 2008 年に提唱。玉ねぎ状に層を重ねる Clean Architecture の親戚。 | [Ch2](02-clean-architecture) |
| **[レイヤードアーキテクチャ](https://en.wikipedia.org/wiki/Multitier_architecture)** | Presentation / Application / Domain / Infrastructure の伝統的 4 層構成。Clean Architecture はこれを「依存の向き」で厳格化したもの。 | [Ch2](02-clean-architecture) |
| **[CQRS](https://martinfowler.com/bliki/CQRS.html)** | Command Query Responsibility Segregation(Greg Young, Martin Fowler)。書き込み(Command) と読み取り(Query) を別の経路で扱う設計。 | [Ch10](10-handler-decomposition), [Ch11](11-repository-design) |
| **Domain 層** | 業務ルールの本体が住む層。DB や Web を知らない。Entity / VO / Domain Service / Repository interface がここ。 | [Ch2](02-clean-architecture) |
| **Application 層** | 1 ユースケース(注文作成、ステータス更新…)のフローを書く層。Handler の住処。 | [Ch2](02-clean-architecture), [Ch10](10-handler-decomposition) |
| **Infrastructure 層** | DB / HTTP / メッセージング / 設定 など「外の世界」とつなぐ層。Repository 実装はここ。 | [Ch2](02-clean-architecture) |
| **[Bounded Context](https://martinfowler.com/bliki/BoundedContext.html)** | DDD の Strategic Design 概念。同じ業務用語でも意味が違うとき、用語の有効範囲を区切る境界。 | [Ch3](03-ddd-minimum), [Ch9](09-aggregate-boundary) |
| **[Ubiquitous Language(ユビキタス言語)](https://martinfowler.com/bliki/UbiquitousLanguage.html)** | ドメイン専門家とエンジニアが共有する語彙。業務用語がそのままコードの型名・メソッド名に現れる。 | [Ch3](03-ddd-minimum) |

---

## A-2. DDD ビルディングブロック

| 用語 | 詳細 | 本書 |
| --- | --- | --- |
| **Entity** | ID で識別され、状態を持ち変化していくもの。例: `Order`。**同じ属性でも ID が違えば別物**。 | [Ch3](03-ddd-minimum), [Ch6](06-entity-state-transition) |
| **Aggregate Root** | 複数 Entity をひと束にした "窓口"。外部は Root 経由でしか中の Entity に触れない。例: `Order` が `OrderLine` を内包する場合、`Order` が Root。 | [Ch3](03-ddd-minimum), [Ch9](09-aggregate-boundary) |
| **[Value Object (VO)](https://martinfowler.com/bliki/ValueObject.html)** | 値そのものに意味があり、状態を持たない不変オブジェクト。**同じ値なら同一**。例: `Money(1000, "JPY")`。 | [Ch7](07-value-object) |
| **Domain Service** | Entity に置きづらいロジック(複数 Aggregate にまたがる / 外部依存が必要) を置く場所。interface を Domain、実装を Infrastructure に。 | [Ch8](08-domain-service-strategy) |
| **[Repository](https://martinfowler.com/eaaCatalog/repository.html)** | 永続化の窓口。コレクション風 interface を提供。interface だけ Domain が知り、実装は Infrastructure。 | [Ch11](11-repository-design) |
| **[Factory](https://en.wikipedia.org/wiki/Factory_method_pattern)** | Entity の生成手順を集約するオブジェクト。コンストラクタが複雑なときに使う。 | [Ch3](03-ddd-minimum) |
| **Application Handler** | 1 ユースケースの「Command 受信 → Entity 呼出 → 永続化 → 通知」フローを書く場所。CQRS の Command 側に相当。 | [Ch10](10-handler-decomposition) |
| **[Domain Event](https://martinfowler.com/eaaDev/DomainEvent.html)** | 「何かが起きた」事実を表すオブジェクト。Entity が状態を変えたあとに発火し、別 Aggregate や外部システムへの伝播はリスナーが担う。 | [Ch3](03-ddd-minimum), [Ch6](06-entity-state-transition) |
| **不変条件 (Invariant)** | 「Entity が常に保たねばならない条件」。例: 「注文金額は 0 以上」「Pending からしか Confirmed に遷移できない」。Entity のメソッドがガードする。 | [Ch6](06-entity-state-transition) |
| **[Anemic Domain Model](https://martinfowler.com/bliki/AnemicDomainModel.html)** | Entity が public setter だらけで振る舞いを持たない設計。Martin Fowler が明示的にアンチパターンと位置づけ。 | [Ch4](04-rich-vs-anemic) |
| **Rich Domain Model** | Entity が状態と振る舞いの両方を持つ設計。本書の推奨。 | [Ch4](04-rich-vs-anemic) |
| **Anti-Corruption Layer** | Bounded Context をまたぐとき、他コンテキストの概念が侵食するのを防ぐ層。 | [Ch9](09-aggregate-boundary) |

---

## A-3. 設計原則

| 用語 | 詳細 | 本書 |
| --- | --- | --- |
| **[SOLID](https://en.wikipedia.org/wiki/SOLID)** | OOP の 5 原則。S(Single Responsibility)・O(Open-Closed)・L(Liskov Substitution)・I(Interface Segregation)・D(Dependency Inversion)。 | [Ch2](02-clean-architecture), [Ch8](08-domain-service-strategy) |
| **Open/Closed Principle (OCP)** | 「**拡張に開き、修正に閉じる**」。新ケースの追加で既存コードを修正せずに済む状態。Bertrand Meyer (1988) の原典[^meyer]。 | [Ch8](08-domain-service-strategy) |
| **Dependency Inversion Principle (DIP)** | 「上位モジュールも下位モジュールも、抽象(interface)に依存する。具体に依存しない」。Repository interface を Domain に置く理由がこれ。 | [Ch2](02-clean-architecture), [Ch8](08-domain-service-strategy) |
| **Interface Segregation Principle (ISP)** | 「クライアントは使わないメソッドへの依存を強制されない」。God Repository を分割する根拠。 | [Ch11](11-repository-design) |
| **[Tell, Don't Ask](https://martinfowler.com/bliki/TellDontAsk.html)** | 「状態を聞いて判断する(Ask)」のではなく「命じる(Tell)」。`if (order.Status == X) order.Status = Y` ではなく `order.Confirm()`。Andy Hunt, Dave Thomas, *The Pragmatic Programmer* (1999) で提唱。 | [Ch6](06-entity-state-transition) |
| **[YAGNI(You Aren't Gonna Need It)](https://martinfowler.com/bliki/Yagni.html)** | 「将来必要になりそう」だけで作らない。Strategy パターンの過剰適用を防ぐ根拠。 | [Ch2](02-clean-architecture), [Ch8](08-domain-service-strategy) |
| **[Boy Scout Rule](https://www.oreilly.com/library/view/97-things-every/9780596809515/ch08.html)** | 「来たときよりきれいにして帰る」。Robert C. Martin がコード品質維持の原則として広めた。 | [Ch14](14-legacy-migration) |
| **Single Source of Truth (SSOT)** | データ・ルールの正本を 1 箇所に集める原則。VO がエンドユーザ向けの「Email とは何か」を独占する根拠。 | [Ch7](07-value-object) |

[^meyer]: Bertrand Meyer, *Object-Oriented Software Construction*, Prentice Hall, 1988.

---

## A-4. 設計パターン

| 用語 | 詳細 | 本書 |
| --- | --- | --- |
| **[Strategy パターン](https://en.wikipedia.org/wiki/Strategy_pattern)** | GoF *Design Patterns* (1994) で命名。入れ替え可能なアルゴリズムを interface で抽象化し、利用側を `if` から解放。 | [Ch8](08-domain-service-strategy), [Ch10](10-handler-decomposition) |
| **[Factory パターン](https://en.wikipedia.org/wiki/Factory_method_pattern)** | オブジェクト生成の手順を専用クラス / メソッドに切り出す。GoF パターンの 1 つ。 | [Ch3](03-ddd-minimum) |
| **Repository パターン** | Martin Fowler が *PoEAA* (2002) で整理。永続化を interface で隠蔽し、ドメインから DB を見えなくする。 | [Ch11](11-repository-design) |
| **State パターン** | GoF パターン。状態に応じて振る舞いを変える設計。本書は "State パターンの軽量版" として状態遷移メソッドを Entity に持たせる。 | [Ch6](06-entity-state-transition) |
| **[Template Method](https://en.wikipedia.org/wiki/Template_method_pattern)** | アルゴリズムの骨格を抽象クラスで定義し、一部だけサブクラスで override する。Strategy の共通前処理が大量にあるときの代替。 | [Ch8](08-domain-service-strategy) |
| **[Mediator パターン](https://en.wikipedia.org/wiki/Mediator_pattern)** | GoF パターン。オブジェクト間の相互作用を中央のオブジェクトに集める。`MediatR` ライブラリの語源。 | [Ch10](10-handler-decomposition) |
| **[Strangler Fig パターン](https://martinfowler.com/bliki/StranglerFigApplication.html)** | Martin Fowler が 2004 年に提唱。新コードを既存の周りに育てて徐々に置き換える段階的移行手法。 | [Ch14](14-legacy-migration) |
| **[Branch by Abstraction](https://martinfowler.com/bliki/BranchByAbstraction.html)** | Jez Humble が *Continuous Delivery* (2010) で紹介。interface 経由で旧↔新を切り替え、段階的に置き換える手法。 | [Ch14](14-legacy-migration) |
| **[Saga パターン](https://microservices.io/patterns/data/saga.html)** | Hector Garcia-Molina, Kenneth Salem (1987) の古典。分散トランザクションの代替として、補償操作で結果整合性を保証。 | [Ch9](09-aggregate-boundary) |
| **[Transactional Outbox パターン](https://microservices.io/patterns/data/transactional-outbox.html)** | DB 更新と Event 発行を同一トランザクションで扱う。Chris Richardson が整理。 | [Ch6](06-entity-state-transition) |

---

## A-5. 実装基盤の用語

| 用語 | 詳細 | 本書 |
| --- | --- | --- |
| **[DI(依存性注入)](https://en.wikipedia.org/wiki/Dependency_injection)** | 依存先(interface)をコンストラクタで受け取り、コンテナ(.NET の `IServiceCollection` など) が具象を注入する仕組み。 | [Ch2](02-clean-architecture), [Ch8](08-domain-service-strategy) |
| **[Unit of Work / `IUnitOfWork`](https://martinfowler.com/eaaCatalog/unitOfWork.html)** | 1 トランザクション内の DB 変更をまとめて `SaveChangesAsync` で確定する仕組み。Martin Fowler が *PoEAA* で整理。 | [Ch11](11-repository-design) |
| **`CancellationToken`(C#)** | 「処理途中でキャンセル要求を伝える」ためのトークン。引数 `ct` でよく出てくる。 | 全章 |
| **`IOptions<T>`(C#)** | 設定ファイル(appsettings.json) を型として注入する仕組み。`IOptions<RegionSettings>.Value` で中身取得。 | [Ch8](08-domain-service-strategy) |
| **[冪等性(Idempotency)](https://en.wikipedia.org/wiki/Idempotence)** | 「同じ操作を何度実行しても結果が変わらない」性質。Kafka / SignalR の再送・リトライ安全性の要。 | [Ch6](06-entity-state-transition), [Ch10](10-handler-decomposition) |
| **[Mock(テストダブル)](https://martinfowler.com/articles/mocksArentStubs.html)** | テスト時に依存を偽物に差し替えて挙動を制御。Anemic Model だと Mock が増えがち、Rich Model だと Entity を直接 new できるので減る。 | [Ch13](13-test-strategy) |
| **[Testcontainers](https://testcontainers.com/)** | コンテナで本物の外部依存(PostgreSQL / Redis 等) を起動するライブラリ。.NET / TypeScript / Java / Go など対応。 | [Ch11](11-repository-design), [Ch13](13-test-strategy) |
| **[Kafka](https://kafka.apache.org/)** | 分散メッセージングシステム。Producer がイベントを publish、Consumer が subscribe する。 | [Ch6](06-entity-state-transition), [Ch10](10-handler-decomposition) |
| **[MediatR](https://github.com/jbogard/MediatR)** | Jimmy Bogard 作の .NET 用 Mediator パターン実装。Handler のディスパッチを Mediator が担う。 | [Ch10](10-handler-decomposition) |
| **Feature Flag** | コードに残しつつ機能の有効/無効を実行時に切り替える仕組み。段階リリース・A/B テスト・緊急停止に使う。 | [Ch14](14-legacy-migration) |
| **Characterization Test** | 既存コードの「現状の振る舞い」を保証するテスト。リファクタ前に書く。Michael Feathers の *Working Effectively with Legacy Code* (2004) で提唱。 | [Ch10](10-handler-decomposition), [Ch14](14-legacy-migration) |
| **Shadow Run** | 新実装を本番に並走させ、結果を比較して安全性を確認する手法。 | [Ch14](14-legacy-migration) |
| **Eventual Consistency(結果整合性)** | Werner Vogels (2009) の古典[^vogels]。分散システムで「いずれは整合する」を保証する弱い整合性モデル。 | [Ch9](09-aggregate-boundary) |

[^vogels]: Werner Vogels, "Eventually Consistent", *Communications of the ACM*, vol. 52 no. 1, January 2009.

---

## A-6. C# 特有の構文(中級向け補足)

| 用語 | 詳細 | 本書 |
| --- | --- | --- |
| **[Primary Constructor](https://learn.microsoft.com/en-us/dotnet/csharp/whats-new/tutorials/primary-constructors)(C# 12+)** | `public sealed class Foo(IBar bar) { ... }` のようにクラス宣言と同時にコンストラクタ引数を定義する短縮構文。 | コード例多数 |
| **[`record`](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/record)** | 値等価セマンティクスを持つ短縮クラス定義。`public sealed record Money(decimal Amount, string Currency);`。VO 実装に向く。 | [Ch7](07-value-object) |
| **[Pattern matching `is not (X or Y)`](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/patterns)** | C# 8+ の型・値マッチング構文。`if (Status is not (OrderStatus.Confirmed or OrderStatus.Processing))` のように複数値の否定を 1 行で書ける。 | [Ch6](06-entity-state-transition) |
| **`private set` / `init`** | プロパティのアクセサ修飾子。`{ get; private set; }` は「クラス内からのみ書き込み可」、`{ get; init; }` は「生成時のみ書き込み可」。Rich Model の必需品。 | [Ch6](06-entity-state-transition) |
| **[`with` 式](https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/with-expression)** | record の不変更新構文。`var bumped = money with { Amount = money.Amount + 100 };`。 | [Ch7](07-value-object) |
| **[Value Conversions(EF Core)](https://learn.microsoft.com/en-us/ef/core/modeling/value-conversions)** | EF Core の型変換機能。Strongly-Typed ID(`OrderId` ↔ `string`)のマッピングに使う。 | [Ch6](06-entity-state-transition), [Ch7](07-value-object) |
| **[Owned Entity Type(EF Core)](https://learn.microsoft.com/en-us/ef/core/modeling/owned-entities)** | VO を「親 Entity の一部」としてマッピングする機能。`Address` などを Order に埋め込むときに使う。 | [Ch7](07-value-object) |

---

## A-7. TypeScript / フロントエンド関連

| 用語 | 詳細 | 本書 |
| --- | --- | --- |
| **[Branded Type / Phantom Type](https://egghead.io/blog/using-branded-types-in-typescript)** | TypeScript で nominal typing を擬似的に実現する手法。`type OrderId = string & { __brand: "OrderId" }`。 | [Ch7](07-value-object), [Ch12](12-frontend-application) |
| **[Zod](https://zod.dev/)** | TypeScript ファーストのスキーマバリデーションライブラリ。`z.object({...})` で型と検証を一体化。 | [Ch12](12-frontend-application) |
| **[React Hook Form](https://react-hook-form.com/)** | パフォーマンス重視の React フォームライブラリ。Zod と組み合わせて使うことが多い。 | [Ch12](12-frontend-application) |
| **[React `useState`](https://react.dev/reference/react/useState)** | コンポーネント内のローカル状態管理フック。 | [Ch12](12-frontend-application) |
| **[i18n](https://en.wikipedia.org/wiki/Internationalization_and_localization)** | Internationalization。多言語化対応。文言を別ファイルに集約。 | [Ch12](12-frontend-application) |
| **schema validation** | フォーム入力を「ルール定義オブジェクト」で宣言的に検証する手法。Zod / Yup / Valibot 等。 | [Ch12](12-frontend-application) |
| **cross-field validation** | 「項目 A が X なら項目 B は Y でなければならない」のような複数項目にまたがる検証。 | [Ch12](12-frontend-application) |
| **[Server Components(RSC)](https://react.dev/reference/rsc/server-components)** | Next.js 13+ で導入。サーバーで描画するコンポーネント。データ取得を担い、クライアント JS を減らす。 | [Ch12](12-frontend-application) |
| **[Mock Service Worker(MSW)](https://mswjs.io/)** | フロントエンドのテストや開発時に API レスポンスをモックするツール。 | [Ch13](13-test-strategy) |
| **[Playwright](https://playwright.dev/)** | Microsoft 製の E2E テストフレームワーク。Chrome / Firefox / Safari 対応。 | [Ch13](13-test-strategy) |
| **[Vitest](https://vitest.dev/)** | Vite ベースの高速テストランナー。Jest 互換 API。 | [Ch13](13-test-strategy) |

---

## A-8. その他

| 用語 | 詳細 |
| --- | --- |
| **[Big Ball of Mud](http://www.laputan.org/mud/)** | Brian Foote, Joseph Yoder (1997) の論文タイトル。「構造のないコードの塊」を表す古典的なアンチパターン用語。 |
| **[Ice Cream Cone(テスト)](https://watirmelon.blog/testing-pyramids-ice-cream-cones/)** | テストピラミッドが逆さま(E2E 大量・Unit 少数)のアンチパターン。CI が遅くなり脆くなる。 |
| **Identity Map** | ORM の概念。「同じ ID の Entity は同じインスタンスを返す」を保証する仕組み。EF Core の `DbContext` が実装。 |
| **Identity Field** | Entity の ID を表すフィールド。本書では Strongly-Typed ID(`OrderId`)推奨。 |

---

## A-9. 略語一覧

| 略語 | 正式名称 |
| --- | --- |
| **DDD** | Domain-Driven Design |
| **VO** | Value Object |
| **DI** | Dependency Injection |
| **DIP** | Dependency Inversion Principle |
| **OCP** | Open-Closed Principle |
| **SRP** | Single Responsibility Principle |
| **ISP** | Interface Segregation Principle |
| **LSP** | Liskov Substitution Principle |
| **DTO** | Data Transfer Object |
| **CQRS** | Command Query Responsibility Segregation |
| **PoEAA** | Patterns of Enterprise Application Architecture(Fowler の書名) |
| **YAGNI** | You Aren't Gonna Need It |
| **UoW** | Unit of Work |
| **BC** | Bounded Context |
| **ACL** | Anti-Corruption Layer |
| **SSOT** | Single Source of Truth |
| **RSC** | React Server Components |
| **MSW** | Mock Service Worker |
| **TDA** | Tell, Don't Ask |
| **EAA** | Enterprise Application Architecture |

---

→ **[付録 B PR レビューチェックリスト](appendix-b-checklist)**
