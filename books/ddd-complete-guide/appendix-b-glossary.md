---
title: "付録B: DDD用語集"
---

# 付録 B: DDD 用語集

本用語集では、ドメイン駆動設計（DDD）に登場する主要概念を英語原語・定義・詳細説明・コード例・関連語とともに解説します。用語はアルファベット順に配置しています。コード例はすべて C# で記述しています。

---

## A

---

### Aggregate（集約）

**英語原語**: Aggregate

**定義**: 整合性境界を持つエンティティと値オブジェクトのクラスタ。トランザクションの単位として扱われます。

**詳細説明**:
Aggregate は複数のエンティティおよび値オブジェクトを一つのまとまりとして扱うパターンです。Aggregate の内側は常に整合した状態（Invariant が保たれた状態）を維持します。外部からは必ず Aggregate Root を通じてアクセスし、内部オブジェクトへの直接参照は許可しません。トランザクションの境界が Aggregate の境界と一致するため、一つのトランザクションで複数の Aggregate を変更することは原則として禁止です。これにより、大規模システムでの並行性問題を回避し、スケーラビリティを確保します。Aggregate の境界設計はドメインの整合性要件によって決定され、技術的な都合ではなくビジネスルールに基づいて行います。

```csharp
// Aggregate の例：Order（注文）
public class Order : AggregateRoot<OrderId>
{
    private readonly List<OrderLine> _lines = new();
    public IReadOnlyList<OrderLine> Lines => _lines.AsReadOnly();

    public void AddLine(ProductId productId, int quantity, Money price)
    {
        Guard.Against.NegativeOrZero(quantity, nameof(quantity));
        _lines.Add(new OrderLine(productId, quantity, price));
        AddDomainEvent(new OrderLineAddedEvent(Id, productId, quantity));
    }
}
```

→ Aggregate Root 参照 / Entity 参照 / Invariant 参照 / Unit of Work 参照

---

### Aggregate Root（集約ルート）

**英語原語**: Aggregate Root

**定義**: Aggregate の入口となる単一のエンティティ。外部からのアクセスはすべてここを経由します。

**詳細説明**:
Aggregate Root は Aggregate の代表エンティティであり、外部からのすべての操作を受け付ける唯一の窓口です。Aggregate Root のみがグローバル識別子（ID）を持ち、Repository から取得・保存される対象となります。Aggregate 内部の子エンティティは Aggregate Root の IDによってのみ外部から参照され、直接の参照（オブジェクト参照）は Aggregate の境界を越えません。Domain Event の発行も通常 Aggregate Root が担当します。Aggregate Root がビジネスルールの適用点となるため、ドメインロジックが適切にカプセル化されます。

```csharp
public abstract class AggregateRoot<TId>
{
    public TId Id { get; protected set; } = default!;
    private readonly List<IDomainEvent> _events = new();
    public IReadOnlyList<IDomainEvent> DomainEvents => _events.AsReadOnly();

    protected void AddDomainEvent(IDomainEvent @event) => _events.Add(@event);
    public void ClearDomainEvents() => _events.Clear();
}
```

→ Aggregate 参照 / Domain Event 参照 / Repository 参照

---

### Anemic Domain Model（貧血ドメインモデル）

**英語原語**: Anemic Domain Model

**定義**: ドメインオブジェクトがデータ保持のみを担い、ビジネスロジックが外部（サービス層）に散在した反パターン。

**詳細説明**:
Anemic Domain Model は Martin Fowler が命名した反パターンです。ドメインクラスが getter/setter のみを持ち、ビジネスロジックは別途 Service クラスや Manager クラスに書かれる構成です。オブジェクト指向の本来の目的（データとふるまいの統合）に反しており、ドメインの意図がコードに表現されません。Anemic Domain Model になっていないかを確認するには、「ドメインクラスのメソッドを削除したらビジネスロジックはどこに行くか？」を問います。すべてサービス層に残るなら Anemic です。DDD ではドメインオブジェクト自身がビジネスルールを適用・検証する「Rich Domain Model」を目指します。

```csharp
// 悪い例（Anemic）
public class Order { public OrderStatus Status { get; set; } }
public class OrderService
{
    public void Cancel(Order o) { o.Status = OrderStatus.Cancelled; } // ロジックが外に
}

// 良い例（Rich）
public class Order
{
    public OrderStatus Status { get; private set; }
    public void Cancel() // ロジックがドメインオブジェクトに
    {
        if (Status != OrderStatus.Pending) throw new DomainException("キャンセル不可");
        Status = OrderStatus.Cancelled;
        AddDomainEvent(new OrderCancelledEvent(Id));
    }
}
```

→ Domain Model 参照 / Domain Service 参照

---

### Anti-Corruption Layer（腐敗防止層）

**英語原語**: Anti-Corruption Layer (ACL)

**定義**: 外部システムや他の Bounded Context のモデルがドメインモデルを汚染しないよう保護する翻訳層。

**詳細説明**:
Anti-Corruption Layer（ACL）は、外部システムや別の Bounded Context から受け取ったデータを、自分のドメインモデルに適した形式に変換するアダプター層です。外部システムのモデルが自ドメインの概念と異なる場合や、外部モデルが設計上劣っている場合に、その影響が自ドメインに及ばないよう遮断します。ACL は通常、Application Service 層の外側（インフラストラクチャ層）に配置し、外部 API のレスポンスを自ドメインの Value Object や Entity に変換します。マイクロサービスアーキテクチャでは、他のサービスのメッセージを自ドメインのイベントに変換する際にも使用します。

```csharp
// 外部CRMシステムとの統合
public class CrmAntiCorruptionLayer
{
    private readonly ICrmClient _crmClient;

    public async Task<Customer> GetCustomerAsync(string externalId)
    {
        var dto = await _crmClient.FetchContactAsync(externalId);
        // 外部モデル → ドメインモデルへ変換
        return new Customer(
            CustomerId.New(),
            new PersonName(dto.FirstName, dto.LastName),
            new Email(dto.EmailAddress));
    }
}
```

→ Bounded Context 参照 / Context Map 参照 / Integration Event 参照

---

### Application Service（アプリケーションサービス）

**英語原語**: Application Service

**定義**: ユースケースを調整するが、ドメインロジックは持たない薄い層。コマンドを受け取り、ドメインモデルに処理を委譲します。

**詳細説明**:
Application Service はユースケース（アプリケーション機能）の実行を調整します。具体的には、リポジトリからエンティティを取得し、ドメインオブジェクトのメソッドを呼び出し、結果を永続化するという一連の手順を管理します。ドメインロジック（ビジネスルール）は持たず、あくまでドメインモデルのメソッドに処理を委譲します。トランザクションの開始・コミットも Application Service の責務です。MediatR を使う場合、Command Handler が Application Service の役割を担います。Application Service は薄く保つことが重要で、多くのロジックが入り始めたらドメイン層に移動すべきサインです。

```csharp
public class PlaceOrderCommandHandler : IRequestHandler<PlaceOrderCommand, Guid>
{
    private readonly IOrderRepository _orders;
    private readonly ICustomerRepository _customers;

    public async Task<Guid> Handle(PlaceOrderCommand cmd, CancellationToken ct)
    {
        var customer = await _customers.GetByIdAsync(cmd.CustomerId, ct);
        var order = customer.PlaceOrder(cmd.Items.Select(i => i.ToDomain()).ToList());
        await _orders.AddAsync(order, ct);
        return order.Id.Value;
    }
}
```

→ Command Handler 参照 / Domain Service 参照 / Repository 参照

---

## B

---

### Bounded Context（境界付けられたコンテキスト）

**英語原語**: Bounded Context

**定義**: ドメインモデルが一貫した意味を持つ明確な境界を持つシステムの区画。

**詳細説明**:
Bounded Context は、特定のモデルが有効である境界を明示的に定義する DDD の最も重要な戦略的パターンです。大規模システムでは「顧客」という概念が Sales・Shipping・Billing など複数のコンテキストで異なる意味を持ちます。Bounded Context はその境界を明確にし、各コンテキスト内でモデルが一貫した意味を持つことを保証します。Bounded Context はチーム・コードベース・データベーススキーマ・デプロイ単位などと対応する場合が多く、マイクロサービスの境界決定に直接活用できます。Context Map でコンテキスト間の関係を可視化します。

→ Context Map 参照 / Ubiquitous Language 参照 / Shared Kernel 参照

---

## C

---

### Command（コマンド）

**英語原語**: Command

**定義**: システムの状態を変更する意図を表すオブジェクト。副作用を持つ操作の要求を表します。

**詳細説明**:
Command は CQRS の「書き込み側」で使用される操作の要求オブジェクトです。「〇〇してください」という意図を表すため、過去形ではなく命令形で命名します（PlaceOrder・CancelOrder・AddCustomer など）。Command は失敗する可能性があり、バリデーションエラーやビジネスルール違反により拒否されることがあります。Command はイミュータブルに設計し、一度作成後は変更できないようにします。C# では `record` 型が Command の表現に適しています。Command を処理するのは Command Handler（Application Service）です。

```csharp
public record PlaceOrderCommand(
    Guid CustomerId,
    IReadOnlyList<OrderItemDto> Items,
    string DeliveryAddress) : IRequest<Guid>;
```

→ Command Handler 参照 / CQRS 参照 / Query 参照

---

### Command Handler（コマンドハンドラー）

**英語原語**: Command Handler

**定義**: Command を受け取り、対応するドメインロジックを実行するクラス。Application Service の一形態。

**詳細説明**:
Command Handler は特定の Command に対応する処理を実装するクラスです。MediatR ライブラリでは `IRequestHandler<TCommand, TResponse>` を実装することで Command Handler を定義します。Command Handler の責務は：リポジトリからエンティティを取得する・ドメインオブジェクトのメソッドを呼び出す・変更されたエンティティを保存する・Domain Event を発行する、の 4 つです。Command Handler 自体にビジネスロジックを書かず、ドメインオブジェクトに委譲することが重要です。バリデーションは MediatR Pipeline Behavior を使って Command Handler の前段で実行します。

```csharp
public class CancelOrderCommandHandler : IRequestHandler<CancelOrderCommand, Unit>
{
    private readonly IOrderRepository _orders;

    public async Task<Unit> Handle(CancelOrderCommand cmd, CancellationToken ct)
    {
        var order = await _orders.GetByIdAsync(new OrderId(cmd.OrderId), ct)
            ?? throw new OrderNotFoundException(cmd.OrderId);
        order.Cancel(cmd.Reason);
        await _orders.SaveAsync(order, ct);
        return Unit.Value;
    }
}
```

→ Application Service 参照 / Command 参照 / Repository 参照

---

### Conformist（追従者）

**英語原語**: Conformist

**定義**: 上流の Bounded Context のモデルに対して翻訳なしに従う Context Map のパターン。

**詳細説明**:
Conformist は Context Map における関係パターンの一つです。下流チームが上流チームのモデルをそのまま受け入れる（翻訳しない）関係を指します。上流チームが強い立場にあり、下流チームが交渉力を持たない場合に発生します。Conformist は Anti-Corruption Layer を持たないため、上流モデルの変更が直接影響します。この関係は短期的な実装コストは低いですが、上流への依存が深まるリスクがあります。戦略的に採用する場合（例：外部の標準的な業界モデルへの準拠）と、パワーバランスの結果として強いられる場合の両方があります。

→ Anti-Corruption Layer 参照 / Context Map 参照

---

### Context Map（コンテキストマップ）

**英語原語**: Context Map

**定義**: 複数の Bounded Context 間の関係・依存・統合方法を可視化した図。

**詳細説明**:
Context Map はシステム全体の Bounded Context とその関係を一枚の図に表現した戦略的設計ツールです。コンテキスト間の関係には Shared Kernel・Customer/Supplier・Conformist・Anti-Corruption Layer・Open Host Service・Published Language・Partnership・Big Ball of Mud などのパターンがあります。Context Map を作成することで、どのチームがどのコンテキストを担当し、どのような依存関係があるかが一目でわかります。コンテキスト間の統合方法（同期 API・非同期メッセージング・共有データベースなど）も記録します。Event Storming の後工程として Context Map を作成するアプローチが効果的です。

→ Bounded Context 参照 / Shared Kernel 参照 / Anti-Corruption Layer 参照

---

### Core Domain（コアドメイン）

**英語原語**: Core Domain

**定義**: ビジネスの競争優位性の源泉となる最も重要なサブドメイン。最大の投資とベストなエンジニアを充てるべき領域。

**詳細説明**:
Core Domain は Eric Evans が強調する戦略的設計の中心概念です。すべてのドメインが等しく重要なわけではなく、競合他社との差別化をもたらすドメインに集中投資すべきという考え方です。Core Domain は自社で開発・運営し、汎用サブドメインはパッケージや SaaS を利用します。Core Domain の特定は経営レベルの意思決定と直結します。例えばECサイトなら「商品推薦・在庫最適化」が Core Domain であり、「認証・決済」は Supporting または Generic Subdomain として外部化します。DDD の複雑なパターン（Event Sourcing・CQRS・精巧な集約設計）は Core Domain にのみ適用し、他のドメインには単純な実装で十分です。

→ Subdomain 参照 / Generic Subdomain 参照 / Supporting Subdomain 参照

---

### CQRS（コマンドクエリ責務分離）

**英語原語**: Command Query Responsibility Segregation

**定義**: 書き込み操作（Command）と読み取り操作（Query）のモデルを分離するアーキテクチャパターン。

**詳細説明**:
CQRS は Greg Young が普及させたパターンで、CQS（Command Query Separation）の原則をアーキテクチャレベルに拡張したものです。Write 側は Command を受け付け、ドメインモデルを通じてデータを変更します。Read 側は Query を受け付け、最適化された Read Model（ビューモデル）を返します。この分離により、Read と Write でそれぞれに最適なデータモデルを使用できます。Write 側は EF Core + ドメインモデル、Read 側は Dapper + SQL または Redis キャッシュという構成が典型的です。Event Sourcing と組み合わせる場合、Write 側はイベントストアに書き込み、Read 側は Projection でイベントから Read Model を構築します。CQRS は全システムに適用するのではなく、複雑なクエリが必要な部分に限定的に適用することが推奨されます。

```csharp
// Write 側：Command
public record PlaceOrderCommand(Guid CustomerId, List<OrderItemDto> Items) : IRequest<Guid>;

// Read 側：Query
public record GetOrderSummaryQuery(Guid OrderId) : IRequest<OrderSummaryDto>;
public class GetOrderSummaryQueryHandler : IRequestHandler<GetOrderSummaryQuery, OrderSummaryDto>
{
    private readonly IDbConnection _db;
    public async Task<OrderSummaryDto> Handle(GetOrderSummaryQuery q, CancellationToken ct)
        => await _db.QueryFirstAsync<OrderSummaryDto>(
            "SELECT o.Id, o.Status, SUM(l.Price) AS Total FROM Orders o ...", new { q.OrderId });
}
```

→ Command 参照 / Query 参照 / Read Model 参照 / Event Sourcing 参照

---

## D

---

### Domain（ドメイン）

**英語原語**: Domain

**定義**: ソフトウェアが解決しようとしているビジネスの問題空間全体。

**詳細説明**:
Domain は DDD における最も基本的な概念で、ソフトウェアが対象とするビジネス活動の領域です。例えば「オンライン小売業」「保険契約管理」「病院の患者管理」などがドメインです。Domain は複数のサブドメイン（Subdomain）に分割でき、Core Domain・Supporting Subdomain・Generic Subdomain の 3 種類に分類されます。Domain Expert（ドメインエキスパート）がドメインの知識を持つ専門家であり、開発者との協働でドメインモデルを構築します。ドメインを正しく理解することが DDD の出発点であり、コードを書く前にドメインを深く理解する努力が重要です。

→ Core Domain 参照 / Subdomain 参照 / Domain Expert 参照 / Ubiquitous Language 参照

---

### Domain Event（ドメインイベント）

**英語原語**: Domain Event

**定義**: ドメイン内で発生した重要なビジネスの出来事を表すイミュータブルなオブジェクト。

**詳細説明**:
Domain Event は「ビジネス上意味のある出来事が起きた」という事実を記録するオブジェクトです。過去形で命名します（OrderPlaced・PaymentReceived・InventoryDepleted など）。Domain Event は Aggregate Root 内で発行され、Application Service がリポジトリへの保存後にそれらを MediatR または Event Bus を通じて配信します。同一 Bounded Context 内での副作用処理（在庫減算・通知送信など）に使用します。別の Bounded Context への通知には Integration Event を使用します。Domain Event を記録することで、システムの状態変化の履歴が得られ、Event Sourcing の基盤となります。イミュータブルに設計し、発生した事実は変更できないことを表現します。

```csharp
public record OrderPlacedEvent(
    Guid OrderId,
    Guid CustomerId,
    IReadOnlyList<OrderLineDto> Lines,
    DateTime OccurredAt) : IDomainEvent;

// Aggregate Root での発行
public class Order : AggregateRoot<OrderId>
{
    public static Order Place(Customer customer, List<OrderLine> lines)
    {
        var order = new Order(OrderId.New(), customer.Id, lines);
        order.AddDomainEvent(new OrderPlacedEvent(order.Id.Value, customer.Id.Value,
            lines.Select(l => l.ToDto()).ToList(), DateTime.UtcNow));
        return order;
    }
}
```

→ Integration Event 参照 / Event Sourcing 参照 / Aggregate Root 参照

---

### Domain Expert（ドメインエキスパート）

**英語原語**: Domain Expert

**定義**: 対象ビジネスドメインの深い専門知識を持つ人物。開発者との協働でモデル化を行う。

**詳細説明**:
Domain Expert はビジネスの専門家であり、必ずしもソフトウェア開発の知識を持つ必要はありません。DDD ではドメインエキスパートと開発者が継続的に対話し、共同でドメインモデルを洗練させます。この対話の結果として Ubiquitous Language が形成されます。Domain Expert はコードを書かないかもしれませんが、「集約の境界」「ビジネスルールの例外」「イベントの重要性」については最高の知識源です。Event Storming は Domain Expert と開発者が同じ部屋で行うワークショップであり、この対話を構造化します。Domain Expert なしに DDD を実践することは、地図なしに航海するようなものです。

→ Ubiquitous Language 参照 / Event Storming 参照

---

### Domain Model（ドメインモデル）

**英語原語**: Domain Model

**定義**: ビジネスドメインの概念・ルール・振る舞いをオブジェクトで表現したもの。

**詳細説明**:
Domain Model はドメインの知識をコードで表現したものです。Entity・Value Object・Domain Service・Domain Event・Aggregate などのパターンを使ってビジネスの概念を表現します。良いドメインモデルはドメインエキスパートが読んでも理解できる（Ubiquitous Language が実現されている）ものです。Domain Model はビジネスルールのみを含み、UI・データベース・外部サービスへの依存を持ちません。テストしやすく、インフラから独立した純粋なオブジェクト群として設計します。Anemic Domain Model（データのみでロジックなし）は避け、振る舞いを持つ Rich Domain Model を目指します。

→ Anemic Domain Model 参照 / Entity 参照 / Value Object 参照

---

### Domain Service（ドメインサービス）

**英語原語**: Domain Service

**定義**: 特定のエンティティや値オブジェクトに自然に属さないドメインロジックを表すステートレスなサービス。

**詳細説明**:
Domain Service は複数の Aggregate や Value Object を使った計算・検証・処理など、単一のオブジェクトに収まらないドメインロジックを担当します。Domain Service はステートレスであり、状態を保持しません。Domain Service と Application Service の違いは「ドメインロジックを持つかどうか」です。Domain Service はドメインのルールを知っており（「送金可能かどうかの判定」など）、Application Service はそれを呼び出すだけです。Domain Service が外部システムと通信する場合は、インターフェースを定義してドメイン層に置き、実装をインフラ層に置くことで依存性を逆転させます。

```csharp
// Domain Service の例
public class TransferService
{
    // 複数の Aggregate（Account）を使うドメインロジック
    public void Transfer(Account from, Account to, Money amount)
    {
        if (!from.CanWithdraw(amount))
            throw new InsufficientFundsException(from.Id, amount);
        from.Debit(amount);
        to.Credit(amount);
    }
}
```

→ Application Service 参照 / Domain Model 参照

---

## E

---

### Entity（エンティティ）

**英語原語**: Entity

**定義**: 一意の識別子を持ち、ライフサイクルを通じて同一性が追跡されるドメインオブジェクト。

**詳細説明**:
Entity は識別子（ID）によって同一性を判断するオブジェクトです。属性値が変わっても同じ ID を持つ限り「同じもの」として扱います（例：名前が変わった顧客は同じ顧客）。これは Value Object（値が等しければ同一）との根本的な違いです。Entity は可変状態を持ち、ライフサイクル（作成・変更・削除）が存在します。ただし、可変性は最小限にとどめ、状態変更は意図のあるメソッドを通じて行います。すべての状態変化にはビジネスの理由があり、ただの setter による変更は避けます。Entity の同一性は型安全な ID クラス（Value Object）で表現することが推奨されます。

```csharp
public class Customer : Entity<CustomerId>
{
    public PersonName Name { get; private set; }
    public Email Email { get; private set; }

    public Customer(CustomerId id, PersonName name, Email email)
    {
        Id = id;
        Name = name;
        Email = email;
    }

    public void ChangeEmail(Email newEmail)
    {
        if (Email == newEmail) return;
        Email = newEmail;
        AddDomainEvent(new CustomerEmailChangedEvent(Id, newEmail));
    }
}
```

→ Value Object 参照 / Aggregate 参照

---

### Event Handler（イベントハンドラー）

**英語原語**: Event Handler

**定義**: Domain Event または Integration Event を受け取り、対応する副作用処理を実行するクラス。

**詳細説明**:
Event Handler は発行されたイベントを購読し、そのイベントに応じた処理を行います。MediatR の `INotificationHandler<TEvent>` を実装することで Domain Event のハンドラーを定義できます。Event Handler は Application Service と同様に薄く設計し、実際のビジネスロジックはドメインオブジェクトまたは Domain Service に委譲します。一つのイベントに対して複数の Event Handler が存在できます（例：OrderPlaced に対して「在庫引き当て」「メール送信」「ポイント付与」の 3 つのハンドラー）。Domain Event Handler は同一トランザクション内で実行されることが多く、Integration Event Handler は別トランザクションで実行されます。

```csharp
public class SendOrderConfirmationEmailHandler
    : INotificationHandler<OrderPlacedEvent>
{
    private readonly IEmailService _email;
    public async Task Handle(OrderPlacedEvent notification, CancellationToken ct)
        => await _email.SendOrderConfirmationAsync(notification.CustomerId,
                notification.OrderId);
}
```

→ Domain Event 参照 / Integration Event 参照 / Outbox Pattern 参照

---

### Event Sourcing（イベントソーシング）

**英語原語**: Event Sourcing

**定義**: 状態を直接保存せず、状態変化を引き起こしたイベントの列を永続化するパターン。

**詳細説明**:
Event Sourcing では、エンティティの現在の状態を直接データベースに保存するのではなく、その状態に至るまでに発生したすべての Domain Event を時系列順に保存します。現在の状態を取得するには、すべてのイベントを最初から順に「再生」（リプレイ）することで復元します。この方法により、エンティティの完全な変更履歴が得られ、任意の時点の状態を再現できます。監査ログ・デバッグ・テンポラルクエリなどの要件に自然に対応できます。Snapshot を使って定期的に現在状態を保存することで、リプレイのコストを削減します。CQRS と組み合わせることで、Projection を使った柔軟な Read Model 構築が可能になります。複雑さを伴うため、Core Domain や監査要件がある場合に限定的に適用することが推奨されます。

```csharp
public class OrderEventSourced
{
    public Guid Id { get; private set; }
    public OrderStatus Status { get; private set; }

    // イベントを再生して状態を復元
    public void Apply(OrderPlacedEvent e) { Id = e.OrderId; Status = OrderStatus.Pending; }
    public void Apply(OrderCancelledEvent e) { Status = OrderStatus.Cancelled; }

    public static OrderEventSourced Rehydrate(IEnumerable<IDomainEvent> events)
    {
        var order = new OrderEventSourced();
        foreach (var e in events) order.Apply((dynamic)e);
        return order;
    }
}
```

→ Event Store 参照 / Projection 参照 / Snapshot 参照 / CQRS 参照

---

### Event Store（イベントストア）

**英語原語**: Event Store

**定義**: Event Sourcing で使用する、ドメインイベントを時系列順に永続化する専用ストレージ。

**詳細説明**:
Event Store はイベントの書き込みが追記のみ（Append Only）で、既存データを変更できないという特性を持つストレージです。EventStoreDB は Event Sourcing 専用に設計されたデータベースで、.NET 向けのクライアントライブラリを提供します。PostgreSQL を Event Store として使用する場合は Marten ライブラリが選択肢になります。Event Store の基本操作は「ストリームへのイベント追加」と「ストリームからのイベント取得」の 2 種類です。Optimistic Concurrency（楽観的並行性制御）はストリームのバージョン番号を用いて実現します。

→ Event Sourcing 参照 / Optimistic Concurrency 参照 / Snapshot 参照

---

### Event Storming（イベントストーミング）

**英語原語**: Event Storming

**定義**: ドメインエキスパートと開発者が Post-it を使ってドメインイベントを中心にビジネスプロセスをモデリングするワークショップ技法。

**詳細説明**:
Event Storming は Alberto Brandolini が考案したワークショップ形式のモデリング手法です。オレンジ色の付箋でドメインイベント（過去形の重要な出来事）を壁に並べることから始め、コマンド・アクター・集約・ポリシー・外部システムなどを色別の付箋で追加していきます。技術的な知識がなくても参加でき、ドメインエキスパートと開発者が同じ言語で議論できる場を提供します。Big Picture Event Storming（全体像把握）と Design Level Event Storming（詳細設計）の 2 つのスコープがあります。Event Storming の成果として、Bounded Context の候補・Aggregate の候補・Ubiquitous Language の語彙が得られます。

→ Domain Event 参照 / Bounded Context 参照 / Ubiquitous Language 参照

---

### Eventual Consistency（結果整合性）

**英語原語**: Eventual Consistency

**定義**: 複数の Bounded Context や Aggregate 間のデータが、即座にではなく、一定時間後に整合した状態に収束するという設計原則。

**詳細説明**:
Eventual Consistency は、マイクロサービスや分散システムにおいて、強い整合性（Strong Consistency）ではなく緩やかな整合性モデルを採用するアプローチです。一つのトランザクションで複数の Bounded Context を更新する代わりに、Domain Event や Integration Event を使って非同期に伝播させ、最終的に整合した状態を目指します。ユーザーから見れば「注文後しばらくすると在庫が更新される」という動作になります。Saga パターンや Outbox Pattern と組み合わせて実装します。Eventual Consistency を採用する際は、ビジネス要件として許容できる「不整合の時間窓」を明確にする必要があります。

→ Saga 参照 / Outbox Pattern 参照 / Integration Event 参照

---

## F

---

### Factory（ファクトリー）

**英語原語**: Factory

**定義**: 複雑なオブジェクトや Aggregate の生成ロジックをカプセル化する生成パターン。

**詳細説明**:
Factory は Aggregate や Entity の生成が複雑で、複数の値オブジェクトの作成・不変条件の検証・初期 Domain Event の発行などが必要な場合に使用します。Factory を使うことで、クライアントコードが複雑な生成手順を知る必要がなくなります。静的ファクトリーメソッド（`Order.Create(...)`）・専用ファクトリークラス（`OrderFactory`）・Domain Service としての Factory の 3 つの形態があります。最も単純な場合は、Aggregate Root 自身に静的ファクトリーメソッドを定義することが多いです。Application Service の `new` は避け、生成ロジックはドメイン層に置きます。

```csharp
public class Order : AggregateRoot<OrderId>
{
    // ファクトリーメソッドで生成ロジックをカプセル化
    public static Order Create(Customer customer, ShippingAddress address)
    {
        if (!customer.IsEligibleForOrder())
            throw new CustomerNotEligibleException(customer.Id);
        var order = new Order(OrderId.New(), customer.Id, address, DateTime.UtcNow);
        order.AddDomainEvent(new OrderCreatedEvent(order.Id, customer.Id));
        return order;
    }
}
```

→ Aggregate 参照 / Aggregate Root 参照

---

## G

---

### Generic Subdomain（汎用サブドメイン）

**英語原語**: Generic Subdomain

**定義**: 多くのシステムで共通的に必要とされ、自社の競争優位性に関係しないサブドメイン。

**詳細説明**:
Generic Subdomain は認証・決済処理・メール送信・地図表示など、業種を問わず必要とされる機能領域です。これらは既製品（SaaS・ライブラリ・OSSフレームワーク）で解決することが合理的です。Core Domain と Generic Subdomain を区別することで、自社エンジニアのリソースをビジネス価値の高い領域に集中できます。AWS Cognito・Auth0（認証）・Stripe（決済）・SendGrid（メール）などを Generic Subdomain として外部化するのが典型的な判断です。内製化のコストと外部化のリスクを比較して判断します。

→ Core Domain 参照 / Supporting Subdomain 参照

---

## H

---

### Hexagonal Architecture（六角形アーキテクチャ）

**英語原語**: Hexagonal Architecture / Ports and Adapters

**定義**: ドメインロジックをUI・データベース・外部サービスから完全に独立させるアーキテクチャパターン。別名「Ports and Adapters」。

**詳細説明**:
Hexagonal Architecture は Alistair Cockburn が提唱した設計パターンで、アプリケーションのコア（ドメインロジック）を六角形の中心に置き、外部とのやり取りをすべて Port（インターフェース）と Adapter（実装）で行います。Primary Adapter（Web コントローラー、コンソールアプリ）はアプリケーションを「駆動する」側、Secondary Adapter（データベース、外部 API）はアプリケーションによって「駆動される」側です。依存の方向は常に外→内（インフラ→アプリ→ドメイン）となり、依存性逆転の原則（DIP）を徹底します。DDD のドメイン層はインフラへの依存を一切持ちません。これにより、ドメイン層のユニットテストが非常に容易になります。

```
Controller (Primary Adapter)
    ↓ calls
Application Service
    ↓ uses interface (Port)
IOrderRepository (Port / Domain Layer)
    ↑ implements
SqlOrderRepository (Secondary Adapter / Infrastructure Layer)
```

→ Domain Model 参照 / Repository 参照 / Anti-Corruption Layer 参照

---

## I

---

### Idempotency（べき等性）

**英語原語**: Idempotency

**定義**: 同じ操作を複数回実行しても、最初の 1 回と同じ結果になる性質。

**詳細説明**:
Idempotency はメッセージングシステムや分散トランザクションで重要な概念です。ネットワーク障害によりメッセージが重複配信された場合でも、処理を安全にべき等にすることで、二重処理を防ぎます。実装方法として、処理済みのメッセージ ID を記録するテーブルを持ち、受信時に重複チェックを行うアプローチが一般的です。Command Handler や Integration Event Handler でべき等性を保証することで、Saga や Outbox Pattern との組み合わせで強固な信頼性が得られます。`IdempotencyKey`（一意なリクエスト識別子）をクライアントから送信させ、サーバーで処理済みかチェックするパターンも広く使われます。

→ Outbox Pattern 参照 / Integration Event 参照 / Saga 参照

---

### Infrastructure Layer（インフラストラクチャ層）

**英語原語**: Infrastructure Layer

**定義**: データベース・外部 API・メッセージキューなど、技術的な詳細を担当する最外層。

**詳細説明**:
Infrastructure Layer はドメイン層で定義されたインターフェース（Port）の実装（Adapter）を提供する層です。例えばドメイン層に `IOrderRepository` インターフェースがあれば、`SqlOrderRepository`（EF Core 実装）がインフラ層に配置されます。Infrastructure Layer は外部システム（データベース・メッセージブローカー・外部 API・ファイルシステムなど）との通信を担当します。ドメイン層は Infrastructure Layer に依存しませんが、Infrastructure Layer はドメイン層に依存します（依存の方向が逆転）。DI コンテナ（.NET の `IServiceCollection`）でインターフェースと実装の紐付けを行い、実行時に適切な実装が注入されます。

→ Hexagonal Architecture 参照 / Repository 参照

---

### Integration Event（統合イベント）

**英語原語**: Integration Event

**定義**: 異なる Bounded Context 間でのデータ共有・副作用伝播のために使用するイベント。

**詳細説明**:
Integration Event は Domain Event と異なり、Bounded Context の境界を越えて別のコンテキストに通知するためのイベントです。同一トランザクションではなく、メッセージブローカー（RabbitMQ・Azure Service Bus など）を介して非同期に配信されます。Integration Event はバージョン管理が必要で、後方互換性を意識して設計します。Domain Event が Integration Event に変換されるタイミングは、Application Service が Domain Event を受け取り、インフラ層のメッセージパブリッシャーに渡す時点です。Outbox Pattern を使うことで、データベース保存とメッセージ送信の原子性を保証します。

```csharp
// Domain Event（同一 Context 内）
public record OrderPlacedEvent(Guid OrderId, ...) : IDomainEvent;

// Integration Event（別 Context への通知、メッセージブローカー経由）
public record OrderPlacedIntegrationEvent(Guid OrderId, Guid CustomerId,
    decimal TotalAmount, string Currency, DateTime PlacedAt) : IIntegrationEvent;
```

→ Domain Event 参照 / Outbox Pattern 参照 / Anti-Corruption Layer 参照 / Bounded Context 参照

---

### Invariant（不変条件）

**英語原語**: Invariant

**定義**: Aggregate が常に満たさなければならないビジネスルール。いかなる操作後も真でなければなりません。

**詳細説明**:
Invariant は Aggregate の整合性を定義するビジネスルールです。例えば「注文のアイテム数は 1 以上でなければならない」「残高は 0 未満にできない」などが Invariant です。Invariant は Aggregate Root のメソッド内で検証し、違反した場合はドメイン例外をスローします。Aggregate の境界設計において、「どの Invariant を一つのトランザクションで保護する必要があるか」が境界決定の重要な判断基準です。複数の Aggregate にまたがる Invariant は「整合性の要件が緩い（Eventual Consistency で許容できる）」かどうかを確認します。Invariant の検証は必ずドメイン層で行い、Application Service や UI に漏らしません。

```csharp
public class Order : AggregateRoot<OrderId>
{
    public void RemoveLine(ProductId productId)
    {
        _lines.RemoveAll(l => l.ProductId == productId);
        // Invariant: 注文には最低1つのアイテムが必要
        if (_lines.Count == 0)
            throw new DomainException("注文には最低1つのアイテムが必要です");
    }
}
```

→ Aggregate 参照 / Aggregate Root 参照 / Domain Event 参照

---

## O

---

### Open Host Service（オープンホストサービス）

**英語原語**: Open Host Service

**定義**: 自分の Bounded Context を他のコンテキストが利用しやすいよう、標準的なプロトコルで公開するパターン。

**詳細説明**:
Open Host Service は Context Map のパターンの一つで、サービスプロバイダー側が自ドメインへのアクセスを標準化された API（REST、GraphQL、gRPC など）として公開する設計です。多くの利用者がいる場合、各利用者向けにカスタム翻訳を提供するのではなく、標準的なプロトコルで一元的に公開することで保守コストを削減します。Published Language と組み合わせて使うことで、共通のデータ形式（JSON スキーマ・Protocol Buffers など）でやり取りします。API バージョン管理が重要になります。

→ Published Language 参照 / Context Map 参照

---

### Optimistic Concurrency（楽観的並行性制御）

**英語原語**: Optimistic Concurrency

**定義**: データ更新時に「競合が起きないはず」と楽観的に仮定し、保存時にバージョン番号で競合を検出するパターン。

**詳細説明**:
Optimistic Concurrency は、データ取得時にロックをかけず、更新時にバージョン番号（または ETag）が取得時と同じかを確認することで競合を検出します。競合が検出された場合は例外（`DbUpdateConcurrencyException` など）をスローし、クライアントに再試行を要求します。DDD の Aggregate は一般にトランザクション境界が小さいため、Pessimistic Locking（悲観的ロック）より Optimistic Concurrency が適しています。EF Core では `[ConcurrencyToken]` 属性または Fluent API の `IsConcurrencyToken()` で簡単に実装できます。Event Sourcing の Event Store でもストリームのバージョン番号による Optimistic Concurrency が標準的です。

```csharp
public class Order
{
    [ConcurrencyToken]
    public int Version { get; private set; }
}
```

→ Aggregate 参照 / Event Store 参照

---

### Outbox Pattern（アウトボックスパターン）

**英語原語**: Outbox Pattern

**定義**: データベース保存とメッセージ送信の原子性を保証するパターン。まず同一DBトランザクション内でメッセージを保存し、後でブローカーに転送します。

**詳細説明**:
分散システムでは「データベースへの保存」と「メッセージブローカーへの送信」を原子的に行うことが困難です。Outbox Pattern はこの問題を解決します。具体的には、同一データベーストランザクション内でビジネスデータとメッセージ（Outbox テーブル）の両方を保存します。その後、バックグラウンドジョブ（Outbox Processor）が Outbox テーブルを定期的に読み取り、メッセージブローカーに転送します。転送成功後にアウトボックスのレコードを削除または処理済みにします。これにより「保存はできたがメッセージ送信に失敗」というデータ不整合を防ぎます。MassTransit はこのパターンのネイティブサポートを提供しています。

```csharp
// EF Core での Outbox 実装例（概略）
public class OutboxMessage
{
    public Guid Id { get; set; }
    public string EventType { get; set; } = null!;
    public string Payload { get; set; } = null!;
    public DateTime CreatedAt { get; set; }
    public DateTime? ProcessedAt { get; set; }
}
// Application Service 内で同一トランザクションに Integration Event を書き込む
await _context.OutboxMessages.AddAsync(new OutboxMessage { ... });
await _context.SaveChangesAsync();
```

→ Integration Event 参照 / Idempotency 参照 / Eventual Consistency 参照

---

## P

---

### Process Manager（プロセスマネージャー）

**英語原語**: Process Manager

**定義**: 複数のステップにまたがるビジネスプロセスの状態を管理し、適切なコマンドを発行するオーケストレーター。

**詳細説明**:
Process Manager は長期トランザクション（Long-Running Transaction）とも呼ばれ、複数のサービスや Aggregate にまたがるビジネスプロセスの進行状況を追跡します。Saga の一形態であり、オーケストレーション型の Saga 実装に相当します。Process Manager は受け取ったイベントに応じて次のコマンドを発行し、プロセスを前に進めます。状態を永続化することで、途中でシステムがクラッシュしても安全に再開できます。MassTransit の `MassTransitStateMachine<TState>` がその代表的な実装です。Saga（コレオグラフィ型）と比べて中央集権的で可視性が高いが、オーケストレーターへの依存が生まれます。

```csharp
public class OrderFulfillmentStateMachine
    : MassTransitStateMachine<OrderFulfillmentState>
{
    public State AwaitingPayment { get; private set; } = null!;
    public State AwaitingShipment { get; private set; } = null!;

    public OrderFulfillmentStateMachine()
    {
        During(AwaitingPayment,
            When(PaymentReceived).Then(ctx => ctx.Saga.PaidAt = DateTime.UtcNow)
                .PublishAsync(ctx => ctx.Init<ShipOrderCommand>(new { ctx.Saga.OrderId }))
                .TransitionTo(AwaitingShipment));
    }
}
```

→ Saga 参照 / Integration Event 参照 / Command 参照

---

### Projection（プロジェクション）

**英語原語**: Projection

**定義**: Event Store に保存されたイベントの列から、特定の目的のための Read Model を構築する処理。

**詳細説明**:
Projection は Event Sourcing と CQRS の組み合わせで使用されます。Write 側でイベントが発生するたびに、Projection がそのイベントを受け取り、Read Model（クエリ用のデータストア）を更新します。Projection は状態として現在の Read Model を持ち、イベントを受け取るたびに増分更新します。Projection を複数作成することで、異なる目的（管理画面用・統計用・検索インデックス用）の最適化された Read Model を並行して維持できます。Projection は冪等に設計し、イベントを再生し直すことで Read Model を任意の時点に再構築できます。

```csharp
public class OrderSummaryProjection
{
    private readonly IOrderSummaryRepository _readRepo;

    public async Task HandleAsync(OrderPlacedEvent @event)
    {
        await _readRepo.UpsertAsync(new OrderSummaryReadModel
        {
            OrderId = @event.OrderId,
            CustomerId = @event.CustomerId,
            Status = "Pending",
            PlacedAt = @event.OccurredAt
        });
    }

    public async Task HandleAsync(OrderCancelledEvent @event)
        => await _readRepo.UpdateStatusAsync(@event.OrderId, "Cancelled");
}
```

→ Event Sourcing 参照 / Read Model 参照 / CQRS 参照

---

### Published Language（公開言語）

**英語原語**: Published Language

**定義**: Bounded Context 間でデータを交換するために合意された共通のデータ形式・スキーマ。

**詳細説明**:
Published Language は Open Host Service で公開するデータの形式を標準化したもので、JSON スキーマ・Protocol Buffers・XML スキーマ・OpenAPI（Swagger）仕様などがその例です。Published Language を使うことで、Bounded Context 間の統合の技術的契約が明示されます。消費者駆動型契約テスト（Consumer-Driven Contract Testing）は Published Language の自動検証手段として有用です。業界標準の Published Language（HL7 FHIR・SWIFT メッセージ・EDI など）が存在する場合は活用します。

→ Open Host Service 参照 / Context Map 参照 / Integration Event 参照

---

## Q

---

### Query（クエリ）

**英語原語**: Query

**定義**: システムの状態を変更せずにデータを取得する操作。副作用を持ちません。

**詳細説明**:
Query は CQRS の「読み取り側」で使用される情報取得の要求オブジェクトです。「〇〇を教えてください」という意図を表すため、名詞形で命名します（GetOrderById・SearchOrders・GetCustomerSummary など）。Query は状態を変更しないため（副作用なし）、何度実行しても同じ結果が返ります（純粋な読み取り）。Query Handler は最適化された Read Model や直接 SQL から結果を取得します。ドメインモデルを経由する必要はなく、Dapper などで直接データを取得するアプローチが効率的です。

```csharp
public record GetOrderDetailsQuery(Guid OrderId) : IRequest<OrderDetailsDto?>;

public class GetOrderDetailsQueryHandler
    : IRequestHandler<GetOrderDetailsQuery, OrderDetailsDto?>
{
    private readonly IDbConnection _db;
    public async Task<OrderDetailsDto?> Handle(
        GetOrderDetailsQuery q, CancellationToken ct)
        => await _db.QueryFirstOrDefaultAsync<OrderDetailsDto>(
            "SELECT * FROM v_order_details WHERE order_id = @OrderId",
            new { q.OrderId });
}
```

→ CQRS 参照 / Read Model 参照 / Command 参照

---

## R

---

### Read Model（リードモデル）

**英語原語**: Read Model

**定義**: クエリの効率化のために最適化された、Write 側のドメインモデルとは独立したデータ構造。

**詳細説明**:
Read Model は CQRS の読み取り側のデータ構造で、特定のユースケース（画面・レポート・API レスポンス）に最適化されています。複数のテーブルの結合や集計結果を事前に計算して保存することで、クエリのパフォーマンスを向上させます。Read Model は Write 側のドメインモデルの整合性制約（Aggregate 境界）に縛られないため、自由な形状を取れます。Read Model の実装先はリレーショナル DB（非正規化テーブル）・Redis・Elasticsearch・ファイルなど用途に応じて選択します。Event Sourcing 環境では Projection によって構築・更新されます。Read Model は捨てて再構築できる「派生データ」として扱い、真のデータは Write 側に持ちます。

```csharp
// 画面表示用に最適化された Read Model
public class OrderListItemDto
{
    public Guid OrderId { get; set; }
    public string CustomerName { get; set; } = null!;
    public int ItemCount { get; set; }
    public decimal TotalAmount { get; set; }
    public string Status { get; set; } = null!;
    public DateTime PlacedAt { get; set; }
}
```

→ CQRS 参照 / Projection 参照 / Query 参照

---

### Repository（リポジトリ）

**英語原語**: Repository

**定義**: Aggregate をメモリ内コレクションであるかのように抽象化し、永続化の詳細を隠蔽するパターン。

**詳細説明**:
Repository はドメイン層でインターフェースを定義し、インフラ層で実装します。ドメインオブジェクトがデータベースの存在を知らないようにします。Repository は Aggregate Root の単位で定義し、子エンティティのみの Repository は作成しません（Aggregate Root 経由でのみアクセスするため）。Repository の実装は EF Core（Write 側）や Dapper（Read 側）を使いますが、ドメイン層から見えるのはインターフェースのみです。テスト時はインメモリの偽実装（Fake Repository）に差し替えることで、データベース不要の高速なユニットテストが可能になります。

```csharp
// ドメイン層のインターフェース
public interface IOrderRepository
{
    Task<Order?> GetByIdAsync(OrderId id, CancellationToken ct = default);
    Task AddAsync(Order order, CancellationToken ct = default);
    Task SaveAsync(Order order, CancellationToken ct = default);
}

// インフラ層の実装
public class SqlOrderRepository : IOrderRepository
{
    private readonly AppDbContext _ctx;
    public async Task<Order?> GetByIdAsync(OrderId id, CancellationToken ct)
        => await _ctx.Orders.Include(o => o.Lines)
            .FirstOrDefaultAsync(o => o.Id == id, ct);
}
```

→ Aggregate Root 参照 / Hexagonal Architecture 参照 / Unit of Work 参照

---

## S

---

### Saga（サガ）

**英語原語**: Saga

**定義**: 複数の Aggregate またはサービスにまたがる長期トランザクションを管理するパターン。障害時の補償トランザクションを持ちます。

**詳細説明**:
Saga は分散システムで強い整合性（2 フェーズコミット）を使わずに複数のサービス間のビジネストランザクションを管理します。2 種類の Saga があります。オーケストレーション型は Process Manager が中央集権的にコマンドを発行してプロセスを制御します。コレオグラフィ型は各サービスがイベントを受け取り自律的に次のアクションを実行します。どちらのアプローチでも、ステップの失敗時には補償トランザクション（例：注文キャンセル後に在庫を戻す）を実行します。Saga は Eventual Consistency を前提とするため、一時的な不整合状態の存在をビジネスルールとして受け入れる必要があります。

→ Process Manager 参照 / Outbox Pattern 参照 / Eventual Consistency 参照

---

### Shared Kernel（共有カーネル）

**英語原語**: Shared Kernel

**定義**: 複数の Bounded Context が共有するコード・モデルの部分。変更には全チームの合意が必要。

**詳細説明**:
Shared Kernel は 2 つ以上の Bounded Context が共通して使用するコード部分で、共通の Value Object（Money・Address・DateRange など）や共通のインターフェースが典型例です。Shared Kernel は変更の影響が複数チームに及ぶため、変更には関連するすべてのチームの合意が必要です。Shared Kernel のサイズは最小限に保つことが重要で、肥大化すると独立した変更が困難になります。NuGet パッケージとして共有するアプローチが一般的です。Shared Kernel を使いすぎると Bounded Context の独立性が失われるため、慎重に採用します。

→ Bounded Context 参照 / Context Map 参照

---

### Snapshot（スナップショット）

**英語原語**: Snapshot

**定義**: Event Sourcing において、現在の Aggregate の状態を定期的に保存し、イベント再生のコストを削減するパターン。

**詳細説明**:
Event Sourcing でイベント数が増えると、Aggregate の状態を復元するためにすべてのイベントを再生するコストが増加します。Snapshot は特定の時点での Aggregate の状態をスナップショットとして保存します。次回の読み込み時は、最新スナップショットから始めてその後のイベントのみを再生します。Snapshot の取得タイミングは「100 イベントごと」「特定のビジネスイベント発生時」などで設定します。Snapshot はパフォーマンス最適化であり、ビジネスロジックに影響しません。Snapshot がなくてもシステムは正しく動作します。

→ Event Sourcing 参照 / Event Store 参照

---

### Specification（仕様）

**英語原語**: Specification

**定義**: ビジネスルールとして表現された述語（条件）をオブジェクトとしてカプセル化するパターン。

**詳細説明**:
Specification パターンは「ある条件を満たすかどうか」の判定ロジックをオブジェクトとして表現します。バリデーション・フィルタリング・オブジェクト生成条件の記述に使用します。Specification は AND・OR・NOT 演算子で組み合わせることができます。Repository と組み合わせて「この条件を満たすエンティティをすべて取得する」というクエリに使用することもあります（Ardalis.Specification ライブラリが代表的な実装です）。Specification を使うことで、散在しがちな条件判定ロジックをドメイン層に集約できます。

```csharp
public class CustomerEligibleForPremiumSpec : Specification<Customer>
{
    public CustomerEligibleForPremiumSpec()
        => Query.Where(c => c.TotalSpent >= 100_000 && c.MembershipMonths >= 12);
}

// 使用例
var premiumCustomers = await _customers.ListAsync(
    new CustomerEligibleForPremiumSpec(), ct);
```

→ Repository 参照 / Domain Service 参照

---

### Strangler Fig Pattern（ストラングラーフィグパターン）

**英語原語**: Strangler Fig Pattern

**定義**: レガシーシステムを段階的に新しいシステムで置き換える移行パターン。新機能を新システムに追加しながら徐々に旧システムを廃止します。

**詳細説明**
Strangler Fig Pattern は Martin Fowler が命名したパターンで、モノリスから DDD ベースのマイクロサービスへ移行する際によく使われます。新機能や修正が必要な箇所から少しずつ新しい Bounded Context として切り出し、ファサード（API Gateway など）の後ろで旧システムと共存させます。時間とともに新システムが旧システムを「絞め殺す」（Strangle）ように置き換えていきます。リスクを分散しながら段階的に移行できるため、大規模な一括移行（Big Bang Rewrite）より現実的です。

→ Bounded Context 参照 / Anti-Corruption Layer 参照

---

### Subdomain（サブドメイン）

**英語原語**: Subdomain

**定義**: ドメイン全体を分割した部分領域。Core・Supporting・Generic の 3 種類に分類されます。

**詳細説明**:
大規模なドメインを単一のモデルで表現することは現実的ではないため、サブドメインに分割して扱います。Core Domain はビジネスの競争優位性の源泉、Supporting Subdomain はコアを補助する重要な機能、Generic Subdomain は汎用的で外部調達可能な機能という分類です。この分類は、どのサブドメインにエンジニアリングリソースを集中させるかという戦略的判断と直結します。Subdomain は問題空間（Problem Space）の概念であり、Bounded Context は解決空間（Solution Space）の概念です。理想的には Subdomain と Bounded Context が 1 対 1 に対応しますが、常にそうとは限りません。

→ Core Domain 参照 / Bounded Context 参照 / Generic Subdomain 参照 / Supporting Subdomain 参照

---

### Supporting Subdomain（支援サブドメイン）

**英語原語**: Supporting Subdomain

**定義**: Core Domain を支援する重要なサブドメイン。自社固有の要件があり外部調達困難だが、競争優位の源泉ではない。

**詳細説明**:
Supporting Subdomain は Generic Subdomain より重要で、Core Domain より重要度が低いという中間的な位置付けです。例えば、EC サイトなら「在庫管理」は Supporting Subdomain にあたります（競争優位には直接つながらないが、外部 SaaS では自社固有の要件に対応しにくい）。Supporting Subdomain には一定の投資が必要ですが、Core Domain ほど精巧な DDD パターンを適用する必要はありません。トランザクションスクリプトや Active Record パターンなどシンプルな実装で始め、必要に応じて洗練させます。

→ Core Domain 参照 / Generic Subdomain 参照 / Subdomain 参照

---

## T

---

### Transaction Script（トランザクションスクリプト）

**英語原語**: Transaction Script

**定義**: 1 つの機能を 1 本のプロシージャとして実装する設計パターン。ドメインモデルを使わない単純な実装方式。

**詳細説明**:
Transaction Script は Martin Fowler の「Patterns of Enterprise Application Architecture」で命名されたパターンで、DDD の対比として理解すると有益です。単純な CRUD 操作や、ドメインの複雑さが低いサブドメイン（Supporting・Generic）に適用するとシンプルで実装コストが低い利点があります。DDD が「必要以上に複雑である」と批判される場合、批判者が念頭に置いているのは Transaction Script で十分なケースに DDD を適用した過剰設計のことが多いです。Generic Subdomain や Supporting Subdomain では Transaction Script を選択することが合理的な判断になる場合があります。

→ Domain Model 参照 / Core Domain 参照

---

## U

---

### Ubiquitous Language（ユビキタス言語）

**英語原語**: Ubiquitous Language

**定義**: ドメインエキスパートと開発者が共通して使用するドメイン固有の語彙体系。コード・ドキュメント・会話すべてで統一して使います。

**詳細説明**:
Ubiquitous Language は DDD の哲学的中核概念です。「顧客」をあるチームでは「User」と呼び、別のチームでは「Client」と呼ぶような用語の不統一は、コミュニケーションのズレとバグの原因になります。Ubiquitous Language はクラス名・メソッド名・変数名・テーブル名・API エンドポイント名・ドキュメントの見出しまで、あらゆる場所で一貫して使用します。Ubiquitous Language は Bounded Context ごとに異なることが許容されます（例：「顧客」という語が Sales Context と Shipping Context で異なる属性を持つ）。Event Storming ワークショップは Ubiquitous Language を発見・確立するための効果的な手段です。

→ Bounded Context 参照 / Domain Expert 参照 / Event Storming 参照

---

### Unit of Work（作業単位）

**英語原語**: Unit of Work

**定義**: 一つのビジネストランザクション内でのすべての変更を追跡し、一括でコミットまたはロールバックするパターン。

**詳細説明**:
Unit of Work は Martin Fowler が定義したパターンで、複数のリポジトリ操作を一つのトランザクションとして扱います。EF Core の `DbContext` は Unit of Work パターンの実装です。`SaveChangesAsync()` を呼ぶまで変更は追跡され、1 回の DB アクセスでまとめてコミットされます。Application Service（Command Handler）が Unit of Work のライフサイクルを管理します。分散環境では複数のサービスにまたがる Unit of Work は実現できないため、Saga や Outbox Pattern で代替します。Unit of Work のスコープが大きすぎると並行性の問題が増えるため、トランザクションは最小限に保ちます。

```csharp
// IUnitOfWork インターフェース
public interface IUnitOfWork
{
    Task<int> SaveChangesAsync(CancellationToken ct = default);
}

// DbContext が UoW を実装
public class AppDbContext : DbContext, IUnitOfWork { }

// Command Handler での使用
await _unitOfWork.SaveChangesAsync(ct); // 変更をまとめてコミット
```

→ Repository 参照 / Aggregate 参照

---

## V

---

### Value Object（値オブジェクト）

**英語原語**: Value Object

**定義**: 識別子を持たず、属性の値の組み合わせによって同一性を判断するイミュータブルなオブジェクト。

**詳細説明**:
Value Object は「同じ値を持てば同じもの」と判断されるオブジェクトです。Money(100, "JPY") と Money(100, "JPY") は同じ価値を表し、等しいと見なされます。Value Object は不変（イミュータブル）に設計し、作成後に状態を変更できません。変更が必要な場合は新しい Value Object を作成します。単なる文字列・整数に型安全性を与えるために使用します（Email 型・Money 型・OrderId 型など）。ドメインのルール（Email のフォーマット検証・Money の正の値チェック）をコンストラクタで強制します。C# の `record` 型は Value Object の実装に最適です（構造的等価性が自動実装される）。

```csharp
public record Money(decimal Amount, string Currency)
{
    public Money(decimal amount, string currency) : this(amount, currency)
    {
        if (amount < 0) throw new DomainException("金額は0以上である必要があります");
        if (string.IsNullOrWhiteSpace(currency)) throw new DomainException("通貨コードは必須です");
        Amount = amount;
        Currency = currency.ToUpperInvariant();
    }

    public Money Add(Money other)
    {
        if (Currency != other.Currency) throw new DomainException("通貨が一致しません");
        return new Money(Amount + other.Amount, Currency);
    }
}
```

→ Entity 参照 / Invariant 参照 / Aggregate 参照

---

## W

---

### Write Model（ライトモデル）

**英語原語**: Write Model

**定義**: CQRS の書き込み側で使用するドメインモデル。ビジネスルールと整合性を担保します。

**詳細説明**:
Write Model は Command を受け取り、ドメインルールを適用してデータを変更します。Read Model との分離により、Write 側では整合性・ビジネスルール適用・Invariant 保護に特化した設計が可能になります。Write Model は最適化されたドメインオブジェクト群（Aggregate・Entity・Value Object）で構成され、クエリのパフォーマンスよりもビジネスルールの正確性を優先します。Event Sourcing を使う場合、Write Model の永続化はイベントとして行われ、Read 側の Projection によって別途 Read Model が構築されます。Write Model は Aggregate の整合性境界に従い、一つのトランザクションで一つの Aggregate のみを変更します。

→ CQRS 参照 / Read Model 参照 / Aggregate 参照 / Event Sourcing 参照

---

*本用語集は 2024 年時点での DDD コミュニティにおける一般的な定義に基づいています。一部の用語については、著者によって異なる解釈が存在します。本書の文脈での定義と合わせてご参照ください。*
