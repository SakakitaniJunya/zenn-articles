---
title: "付録A: 参考文献・推薦図書"
---

# 付録 A: 参考文献・推薦図書

本付録では、ドメイン駆動設計（DDD）を深く理解するために有益な書籍・オンラインリソース・ライブラリ・コミュニティを体系的に整理します。初心者から上級者まで、それぞれのレベルに合わせた学習ロードマップも示します。

---

## A.1 必読書：DDD コア文献

### A.1.1 Domain-Driven Design: Tackling Complexity in the Heart of Software（Blue Book）

**著者**: Eric Evans / **出版**: Addison-Wesley, 2003 / **邦題**: エリック・エヴァンスのドメイン駆動設計

DDD の原典であり、すべての実践者が最終的には手にすべき一冊です。エリック・エヴァンスが長年のコンサルティング経験から抽出した概念——ユビキタス言語、境界付けられたコンテキスト、集約、ドメインイベントなど——が体系的に論述されています。前半では戦術的パターン（エンティティ、値オブジェクト、リポジトリなど）を、後半では戦略的設計（コンテキストマップ、Core Domain の特定）を扱います。難解と言われますが、それはソフトウェア設計の本質的な難しさを正直に記述しているためです。初読では第 1 部と第 2 部を中心に読み、実装経験を積んだ後に第 3 部の戦略的設計を再読することを強く推奨します。邦訳版は翔泳社より出版されており、用語の日本語訳が後の学習の基盤となります。

---

### A.1.2 Implementing Domain-Driven Design（Red Book）

**著者**: Vaughn Vernon / **出版**: Addison-Wesley, 2013 / **邦題**: 実践ドメイン駆動設計

Blue Book の「概念書」に対し、Red Book は「実装書」という位置付けです。Vaughn Vernon は Eric Evans の理論を Java を用いた具体的なコード例で解説し、集約設計の 4 つの原則（小さく保つ、ルートを通じてのみアクセス、整合性境界の単位とする、IDで他集約を参照する）を明示しました。CQRS・Event Sourcing・Hexagonal Architecture との組み合わせ方も詳述されており、Blue Book 読了後の実装フェーズで非常に有用です。日本語版は翔泳社より出版されています。600 ページを超える大著ですが、第 1 章の「DDD とは何か」と第 10 章の「集約」だけでも読む価値があります。C# 開発者も十分に応用できる内容です。

---

### A.1.3 Domain-Driven Design Distilled

**著者**: Vaughn Vernon / **出版**: Addison-Wesley, 2016 / **邦題**: ドメイン駆動設計入門

Red Book の内容をコンパクトにまとめた入門書です。200 ページ程度で、特に戦略的設計（ドメイン・サブドメイン・境界付けられたコンテキスト・コンテキストマップ）のエッセンスを素早く把握するのに最適です。Blue Book や Red Book に挑む前の足がかりとして、あるいは DDD の全体像を短時間で再確認したい場面で役立ちます。Event Storming の紹介も含まれており、本書だけでチームへの DDD 導入を始めるための十分な知識が得られます。日本語版は「ドメイン駆動設計入門 ボトムアップでわかる！ドメイン駆動設計のキホン」（翔泳社）が参考になります。

---

### A.1.4 Patterns, Principles, and Practices of Domain-Driven Design

**著者**: Scott Millett, Nick Tune / **出版**: Wrox, 2015

英語圏で非常に評価の高い DDD 実装書で、C# と .NET を使った豊富なコード例が特徴です。Blue Book の難解な概念を丁寧に解きほぐしつつ、現代的な Web アプリケーション開発への適用方法を示します。CQRS・Event Sourcing・マイクロサービスへの DDD 適用、そして Hexagonal Architecture（Ports and Adapters）の実践的な実装まで網羅しています。C# 開発者にとっては Blue Book よりも先に読むべき書籍かもしれません。800 ページ超の大著ですが、各章が独立しており、必要な箇所から読み進めることができます。

---

### A.1.5 Introducing EventStorming

**著者**: Alberto Brandolini / **出版**: Leanpub, 2017（継続的更新）

Event Storming の考案者 Alberto Brandolini 自身による解説書です。Post-it ノートを使ったワークショップ技法として知られる Event Storming の思想・手順・ファシリテーション方法を詳述しています。本書の核心は「ソフトウェア設計のボトルネックは技術ではなく認知である」という哲学であり、ドメインエキスパートと開発者が同じ言語で議論するための実践的な手法を提供します。Leanpub での電子書籍は現在も更新が続いており、最新の知見が反映されています。チームで DDD を導入する際のワークショップ設計の教科書として手元に置くべき一冊です。

---

### A.1.6 Learning Domain-Driven Design

**著者**: Vlad Khononov / **出版**: O'Reilly, 2021 / **邦題**: ドメイン駆動設計をはじめよう

2021 年出版の比較的新しい DDD 書籍で、現代のソフトウェア開発環境（マイクロサービス、クラウドネイティブ）を前提とした内容が特徴です。Vlad Khononov は DDD の概念を「なぜ」という観点から丁寧に説明し、どのような状況でどのパターンを使うべきかの判断基準を明示します。Blue Book の難解さを避けつつ、本質的な内容をカバーしているため、DDD 入門書として現時点で最も推奨できる書籍の一つです。日本語版がオライリー・ジャパンから出版されており、翻訳品質も高いと評価されています。特に第 III 部「DDD の適用」は実務への架け橋として有益です。

---

### A.1.7 Microservices Patterns

**著者**: Chris Richardson / **出版**: Manning, 2018

厳密には DDD 書籍ではありませんが、マイクロサービスアーキテクチャと DDD の組み合わせを理解する上で必読の一冊です。Saga パターン・Event Sourcing・CQRS・API Gateway など、マイクロサービス環境での DDD 実装に必要なパターンが網羅されています。特にサービス間の整合性管理（Outbox パターン・Saga オーケストレーション vs コレオグラフィ）の解説は実務で直接役立ちます。著者の Chris Richardson は microservices.io の運営者でもあり、豊富な実践経験に裏打ちされた内容です。

---

### A.1.8 Enterprise Integration Patterns

**著者**: Gregor Hohpe, Bobby Woolf / **出版**: Addison-Wesley, 2003

メッセージング・パターンの古典的教科書です。DDD における Integration Event・Process Manager・Correlation ID などの概念の基盤となるメッセージングアーキテクチャが体系化されています。MassTransit・NServiceBus・Azure Service Bus を使った実装の背景知識として不可欠です。400 以上のパターンを収録していますが、全部を読む必要はなく、Point-to-Point Channel・Publish-Subscribe Channel・Message Filter・Correlation Identifier・Process Manager の章を重点的に読むことを推奨します。

---

### A.1.9 Clean Architecture

**著者**: Robert C. Martin / **出版**: Prentice Hall, 2017 / **邦題**: Clean Architecture

DDD の Hexagonal Architecture（Ports and Adapters）と深く関連する設計思想を説いた書籍です。依存性の方向を制御し、ビジネスロジックをインフラから独立させる原則は DDD の考え方と完全に一致します。「プラグイン可能なアーキテクチャ」の概念は、DDD の Application Service・Domain Service・Repository インターフェースの設計に直接応用できます。Uncle Bob の主張はやや過激な面もありますが、依存性逆転の原則（DIP）とクリーンアーキテクチャの同心円モデルは DDD 実践の強固な土台となります。

---

## A.2 オンラインリソース

### A.2.1 公式・著名ブログ

**Domain Language（Eric Evans のサイト）**
https://domainlanguage.com/
Eric Evans 自身が DDD Reference（Blue Book の概念を無料で参照できる PDF）を公開しています。英語原典の用語定義を確認する際の最高権威として活用してください。

**Vaughn Vernon のブログ**
https://vaughnvernon.com/
Red Book 著者による最新の考察・記事を掲載しています。DDD Distilled 以降の Vernon の思想進化を追うことができます。

**Martin Fowler のブログ（martinfowler.com）**
https://martinfowler.com/tags/domain%20driven%20design.html
CQRS・Event Sourcing・Bounded Context の解説記事が充実しており、短時間でコアコンセプトを把握するのに最適です。Fowler の文章は明快で、DDD 初心者の入り口として非常に適しています。

**Microsoft .NET Architecture Guides**
https://dotnet.microsoft.com/en-us/learn/dotnet/architecture-guides
Microsoft が公式に提供する DDD・クリーンアーキテクチャ・マイクロサービスの実装ガイドです。特に「.NET Microservices: Architecture for Containerized .NET Applications」は C# での DDD 実装の参考として必読です。無料 PDF でダウンロード可能です。

**eShopOnContainers（GitHub）**
https://github.com/dotnet-architecture/eShopOnContainers
Microsoft が提供する .NET マイクロサービスのリファレンス実装です。DDD・CQRS・Event Sourcing・Outbox Pattern などが C# で実装されており、実際のコードを読みながら学ぶことができます。

**Udi Dahan のブログ**
https://udidahan.com/
NServiceBus の作者であり、CQRS・Saga・メッセージング設計の第一人者です。「Command-Query Responsibility Segregation」の元記事はここで読めます。

---

### A.2.2 YouTube / 動画リソース

**"Domain-Driven Design Europe" YouTube チャンネル**
https://www.youtube.com/@ddd_eu
DDD Europe カンファレンスの講演動画が無料公開されています。Eric Evans・Vaughn Vernon・Alberto Brandolini・Nick Tune などの第一人者の講演が視聴できます。特に以下をお勧めします：
- "DDD and Microservices: At Last, Some Boundaries!" (Eric Evans)
- "Bounded Contexts, Microservices, and Everything in Between" (Vladik Khononov)

**Greg Young の CQRS/Event Sourcing 解説（YouTube）**
https://www.youtube.com/watch?v=8JKjvY4etTY
CQRS と Event Sourcing の概念を考案・普及させた Greg Young による 8 時間の無料ワークショップ動画です。Event Store の作り方から始まり、Projection・Snapshot・Saga まで網羅しています。

**"Modelling Mondays" by Nick Tune**
https://www.youtube.com/@NickTune
Strategic DDD・コンテキストマッピング・チームトポロジーとの組み合わせについて定期的に動画を公開しています。

**NDC Conferences の DDD 関連動画**
https://www.youtube.com/@NDC
.NET 系カンファレンスである NDC Oslo/London の DDD 関連セッションが多数公開されています。実際の C#/.NET プロジェクトへの適用事例が豊富です。

---

### A.2.3 ポッドキャスト

**"Software Engineering Radio"**
https://www.se-radio.net/
Episode 226（Eric Evans とのインタビュー）は DDD 学習の補助として非常に有益です。

**"Maintainable Software"**
https://maintainable.fm/
ソフトウェア設計全般を扱うポッドキャストで、DDD 関連エピソードも多く含まれます。

---

## A.3 C#/.NET 向けライブラリ・フレームワーク

### A.3.1 MediatR

**GitHub**: https://github.com/jbogard/MediatR
**NuGet**: `dotnet add package MediatR`

Jimmy Bogard 作のメディエーターパターン実装ライブラリです。DDD における Command・Query・Domain Event の送受信基盤として広く使われています。`IRequest<TResponse>`・`IRequestHandler<TRequest,TResponse>`・`INotification`・`INotificationHandler<TNotification>` の 4 つのインターフェースを中心に構成されており、Application Service 層の実装が非常にシンプルになります。Pipeline Behavior を使えば、バリデーション・ロギング・トランザクション管理などの横断的関心事を宣言的に実装できます。

```csharp
// Command の定義
public record CreateOrderCommand(Guid CustomerId, List<OrderItem> Items)
    : IRequest<Guid>;

// Handler の定義
public class CreateOrderCommandHandler : IRequestHandler<CreateOrderCommand, Guid>
{
    public async Task<Guid> Handle(CreateOrderCommand request, CancellationToken ct)
    {
        // ドメインロジックの呼び出し
    }
}
```

---

### A.3.2 MassTransit

**GitHub**: https://github.com/MassTransit/MassTransit
**公式サイト**: https://masstransit.io/

分散メッセージングフレームワークで、RabbitMQ・Azure Service Bus・Amazon SQS などのメッセージブローカーを抽象化します。DDD の Integration Event・Saga（オーケストレーション型 StateMachine として実装）・Outbox Pattern を C# でエレガントに実装できます。MassTransit の Saga は `MassTransitStateMachine<TState>` を継承して定義し、状態遷移を宣言的に記述できます。Outbox Pattern のサポートも組み込まれており、トランザクション内でメッセージを安全に送信できます。

---

### A.3.3 Entity Framework Core

**GitHub**: https://github.com/dotnet/efcore
**公式ドキュメント**: https://docs.microsoft.com/en-us/ef/core/

.NET の標準 ORM で、DDD の Repository パターンの実装基盤として使用します。`DbContext` を Unit of Work として、`DbSet<T>` を Repository として機能させるアプローチが一般的です。Value Object の所有型（`OwnsOne`・`OwnsMany`）サポートにより、ドメインモデルをそのままデータベースにマッピングできます。ただし、EF Core の「変更追跡」機能は Domain Model の純粋性を損なうリスクがあるため、集約ルートのみを `DbSet` として公開し、子エンティティへの直接アクセスを禁止する設計が推奨されます。

---

### A.3.4 Dapper

**GitHub**: https://github.com/DapperLib/Dapper
**NuGet**: `dotnet add package Dapper`

軽量マイクロ ORM で、CQRS の Read 側（クエリ側）の実装に最適です。EF Core が Write 側（Command 側）を担当し、Dapper が Read 側を担当するハイブリッドアプローチは、多くの DDD 実装で採用されています。生 SQL に近い記述でパフォーマンスを確保しつつ、オブジェクトへのマッピングを自動化します。`IDbConnection` の拡張メソッドとして `Query<T>`・`QueryFirst<T>`・`Execute` などを提供します。

---

### A.3.5 FluentValidation

**GitHub**: https://github.com/FluentValidation/FluentValidation
**NuGet**: `dotnet add package FluentValidation`

バリデーションロジックをドメインモデルから分離して記述するためのライブラリです。Application Service 層で Command のバリデーションを行う際に使用します。MediatR の Pipeline Behavior と組み合わせることで、ハンドラーに到達する前に自動バリデーションを実行できます。

```csharp
public class CreateOrderCommandValidator : AbstractValidator<CreateOrderCommand>
{
    public CreateOrderCommandValidator()
    {
        RuleFor(x => x.CustomerId).NotEmpty();
        RuleFor(x => x.Items).NotEmpty().WithMessage("注文アイテムは必須です");
    }
}
```

---

### A.3.6 Ardalis.Specification / Ardalis.GuardClauses

**GitHub**: https://github.com/ardalis/Specification
**NuGet**: `dotnet add package Ardalis.Specification`

Steve Smith（ardalis）が提供する Specification パターンの実装ライブラリです。Repository からのデータ取得条件をドメイン層で表現するための `Specification<T>` 基底クラスを提供します。`Ardalis.GuardClauses` は集約やエンティティのコンストラクタで不変条件（Invariant）を検証するためのガード節実装で、`Guard.Against.Null`・`Guard.Against.NegativeOrZero` などの表現力の高いバリデーションメソッドを提供します。

---

### A.3.7 EventStoreDB / Marten

**EventStoreDB**: https://eventstore.com/
**Marten**: https://martendb.io/

Event Sourcing を C# で実装するためのデータストアです。EventStoreDB は Event Sourcing 専用に設計されたデータベースで、Greg Young が中心となって開発しました。Marten は PostgreSQL を Event Store として使用する場合の .NET クライアントで、Document Database としての利用も可能です。Marten を使うことで、既存の PostgreSQL インフラを流用しながら Event Sourcing を導入できます。

---

### A.3.8 Polly

**GitHub**: https://github.com/App-vNext/Polly
**NuGet**: `dotnet add package Polly`

回復力（レジリエンス）パターン（Retry・Circuit Breaker・Timeout・Fallback）の実装ライブラリです。DDD のマイクロサービス環境で他の Bounded Context との統合（Anti-Corruption Layer 経由のリモート呼び出しなど）に失敗した場合の回復処理を宣言的に実装できます。.NET 8 以降は `Microsoft.Extensions.Resilience` として統合されています。

---

## A.4 学習ロードマップ

### A.4.1 初心者フェーズ（0〜3ヶ月）

**目標**: DDD の核となる概念を理解し、単一の Bounded Context 内で実装できるようになる。

1. **「Learning Domain-Driven Design」（Vlad Khononov）** を通読する
   - 第 I 部「戦略的設計」と第 II 部「戦術的設計」に集中する
   - 読了後、自分の業務ドメインに当てはめてドメインモデルを紙に書いてみる

2. **martinfowler.com の DDD 関連記事**を読む
   - "BoundedContext"・"UbiquitousLanguage"・"CQRS"・"Event Sourcing" の各記事を優先

3. **eShopOnContainers のコードを写経する**
   - まず Ordering マイクロサービスの構造を理解する
   - Command Handler → Domain Model → Repository の流れを追う

4. **小さな Pet Project を作る**
   - 図書管理システム・在庫管理システムなど、慣れ親しんだドメインで始める
   - Value Object・Entity・Aggregate・Repository・Application Service の 5 つのパターンだけを実装する

**この段階では避けること**: CQRS・Event Sourcing・Saga の実装は後回しにする。概念の理解よりも実装経験を優先する。

---

### A.4.2 中級者フェーズ（3〜12ヶ月）

**目標**: 複数の Bounded Context を設計し、CQRS・Event-Driven Architecture を実装できるようになる。

1. **「Implementing Domain-Driven Design」（Vaughn Vernon）** を精読する
   - 第 7 章「サービス」・第 10 章「集約」・第 8 章「ドメインイベント」を特に深く読む
   - コード例を C# に翻訳しながら手を動かす

2. **「Domain-Driven Design Distilled」（Vaughn Vernon）** で戦略的設計を習得する
   - Context Map の 8 つの関係パターンをすべて理解する
   - Event Storming ワークショップを実際にチームで試す

3. **CQRS + MediatR の実装練習**
   - Write 側は EF Core + MediatR の Command Handler
   - Read 側は Dapper + Query Handler
   - Domain Event は INotification で発行

4. **Outbox Pattern と Integration Event の実装**
   - MassTransit の Outbox サポートを使った実装
   - RabbitMQ または Azure Service Bus への接続

5. **「Microservices Patterns」（Chris Richardson）** でサービス間統合を学ぶ

---

### A.4.3 上級者フェーズ（1年〜）

**目標**: 組織規模での DDD 導入をリードし、複雑なドメイン設計の問題を解決できるようになる。

1. **「Domain-Driven Design」（Eric Evans、Blue Book）** を精読する
   - 特に第 14 章「モデルの整合性の維持」・第 15 章「蒸留」・第 16 章「大規模な構造」
   - 読むたびに新しい気づきが生まれる名著

2. **Event Sourcing + EventStoreDB の実装**
   - Event Store の設計・Projection の実装・Snapshot 戦略

3. **「Patterns, Principles, and Practices of DDD」（Millett, Tune）** で知識を体系化

4. **DDD Europe / Domain-Driven Design Community のカンファレンスに参加・動画視聴**

5. **社内で Event Storming ワークショップをファシリテートする**

6. **Team Topologies（Matthew Skelton, Manuel Pais）** を読み、Bounded Context とチーム構造の対応を設計する

---

## A.5 日本語リソース

### A.5.1 日本語書籍

**「ドメイン駆動設計入門 ボトムアップでわかる！ドメイン駆動設計のキホン」**
著者: 成瀬 允宣 / 出版: 翔泳社, 2020

日本語で書かれた DDD 入門書として最も評価の高い一冊です。C# を使ったコード例が豊富で、値オブジェクト・エンティティ・集約・リポジトリ・ドメインサービス・アプリケーションサービスを段階的に実装しながら学べます。Blue Book・Red Book の難解さを日本語で補足してくれる書籍として、特に日本の開発者に強く推薦します。

**「実践ドメイン駆動設計」（翔泳社）**
Vaughn Vernon「Implementing Domain-Driven Design」の日本語版。翻訳品質が高く、英語が苦手な方でも Red Book の内容を深く学べます。

**「ドメイン駆動設計をはじめよう」（オライリー・ジャパン）**
Vlad Khononov の日本語版。現代的な視点で DDD を解説しており、最新の学習書として推薦します。

---

### A.5.2 Zenn 記事

**「ドメイン駆動設計の本質」by nrslib**
https://zenn.dev/nrslib/articles/ddd-essence
DDD の本質的な概念を日本語で簡潔に解説した記事です。

**「DDDパターン一覧」シリーズ**
Zenn で「DDD」タグを検索すると、日本人開発者による実践的な記事が多数見つかります。C# での実装例も豊富です。

**「実践 DDD with C#」シリーズ**
複数の著者が C# での DDD 実装を段階的に解説しています。

---

### A.5.3 コミュニティ・イベント

**DDD-Community-JP（旧 JDDD）**
https://ddd-community-jp.connpass.com/
日本国内で最も活発な DDD コミュニティです。定期的に勉強会・もくもく会を開催しており、DDD 実践者と直接交流できます。EventStorming Japan や DDD Alliance の日本支部としても活動しています。

**TechBullish / builderscon / JJUG CCC**
日本の技術カンファレンスでも DDD 関連セッションが増えています。過去の発表資料が Speaker Deck や GitHub で公開されているケースが多く、検索する価値があります。

**nrslib の YouTube チャンネル**
https://www.youtube.com/@nrslib
日本語で DDD・クリーンアーキテクチャ・CQRS を解説する動画コンテンツを発信しています。

---

### A.5.4 GitHub リポジトリ（日本語コメント付き）

**「DDD のサンプルリポジトリ」**
GitHub で `ddd csharp japanese` や `ドメイン駆動設計 サンプル` で検索すると、日本人開発者による丁寧なコメント付きサンプルが見つかります。特に以下のキーワードでの検索を推奨します：
- `ddd-sample csharp`
- `clean-architecture dotnet japanese`
- `hexagonal-architecture csharp`

---

## A.6 関連する設計パターン・アーキテクチャの参考資料

### A.6.1 クリーンアーキテクチャ / Hexagonal Architecture

- **「Clean Architecture」** Robert C. Martin（前述）
- **「Get Your Hands Dirty on Clean Architecture」** Tom Hombergs（Leanpub、Java ベースだが概念は C# に直接応用可）
- **Ports and Adapters Pattern** https://alistair.cockburn.us/hexagonal-architecture/
  （Hexagonal Architecture の原典、Alistair Cockburn 著）

### A.6.2 Event-Driven Architecture

- **「Building Event-Driven Microservices」** Adam Bellemare（O'Reilly, 2020）
  Apache Kafka を中心とした Event-Driven Architecture の実践書。DDD の Domain Event・Integration Event の概念と接続します。

- **「Designing Event-Driven Systems」** Ben Stopford（O'Reilly, 無料 PDF）
  https://www.confluent.io/designing-event-driven-systems/
  Kafka 創設者 Jay Kreps チームによる無料電子書籍。Event Log as a Source of Truth の概念が DDD の Event Sourcing と深く関連します。

### A.6.3 Team Topologies

- **「Team Topologies」** Matthew Skelton, Manuel Pais（IT Revolution, 2019）
  Bounded Context の境界をチーム構造に対応させる「Conway's Law の逆利用」を実践するための理論書。DDD の戦略的設計の組織的実装を考える上で必読です。

---

*本付録は 2024 年時点の情報を基に作成しています。特にオンラインリソースについては、URLや公開状況が変わる場合があります。最新の情報は各サイトで直接ご確認ください。*
