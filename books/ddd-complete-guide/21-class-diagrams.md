---
title: "第21章: クラス図で DDD を完全に理解する"
---

# 第 21 章: クラス図で DDD を完全に理解する

## 0. TL;DR

DDD の全パターンをクラス図として描けるようになることが、本章の目標です。「なんとなく理解している」から「設計を図で説明・議論できる」へのジャンプには、正確なクラス図の読み書きが不可欠です。Mermaid 記法を使って、Value Object・Entity・Aggregate・Repository・Domain Service・Hexagonal Architecture・CQRS・Event Sourcing の全パターンをクラス図で表現します。

---

## 1. なぜ DDD にクラス図が必要か

### 1.1 「なんとなく理解している」の罠

DDD を学ぶエンジニアが最初に陥るパターン:

```
本を読む → 「なるほど、Value Object は不変なんだ」
コードを書く → 「とりあえず record にした」
レビューする → 「これ Value Object の使い方合ってる？なんかモヤモヤ」
```

この「モヤモヤ」を解消するのがクラス図です。クラス図を描くことで:

1. **設計の矛盾が見える**: `Order` が `Customer` の全フィールドを持っていたら、クラス図に描いた瞬間に「これは集約の境界がおかしい」と気づく
2. **チームで議論できる**: 「Aggregate Root はどれ？」「この依存方向は正しい？」をコードではなく図で議論できる
3. **レビューが速くなる**: コードレビューの前にクラス図をレビューすれば、設計の問題を早期に発見できる

### 1.2 Mermaid 記法の基礎

本章では Mermaid の `classDiagram` を使います。Zenn では Mermaid がネイティブにレンダリングされます。

**基本記法:**

```mermaid
classDiagram
    class ClassName {
        -privateField: Type
        #protectedField: Type
        +publicProperty: Type
        +staticMethod()$ ReturnType
        +instanceMethod() ReturnType
    }
```

**関係の記法:**

| 記法 | 関係 | 意味 |
|------|------|------|
| `A --> B` | 依存 (Dependency) | A が B を使う |
| `A ..> B` | 依存（点線）| A が B に依存するが弱い |
| `A --o B` | 集約 (Aggregation) | A が B を参照する |
| `A *-- B` | コンポジション (Composition) | A が B を所有する（ライフサイクルが同じ） |
| `A <\|-- B` | 継承 (Inheritance) | B は A のサブクラス |
| `A <\|.. B` | 実装 (Realization) | B は A を実装する |

---

## 2. Value Object のクラス図

### 2.1 基本的な Value Object

```mermaid
classDiagram
    class ValueObject {
        <<abstract>>
        #GetEqualityComponents()* IEnumerable~object~
        +Equals(obj) bool
        +GetHashCode() int
        +==() bool
        +!=() bool
    }

    class Money {
        +Amount: decimal
        +Currency: string
        +Of(amount, currency)$ Money
        +Zero(currency)$ Money
        +Add(other) Money
        +Subtract(other) Money
        +Multiply(factor) Money
        +IsZero() bool
    }

    class EmailAddress {
        +Value: string
        +Of(email)$ EmailAddress
        +Domain() string
        +IsBusinessEmail() bool
    }

    class Address {
        +PostalCode: string
        +Prefecture: string
        +City: string
        +Street: string
        +Of(postal, pref, city, street)$ Address
        +Format() string
    }

    class PhoneNumber {
        +Value: string
        +Of(phone)$ PhoneNumber
        +Format() string
        +IsMobile() bool
    }

    class DateRange {
        +Start: DateOnly
        +End: DateOnly
        +Of(start, end)$ DateRange
        +Contains(date) bool
        +Overlaps(other) bool
        +Days() int
    }

    ValueObject <|-- Money : extends
    ValueObject <|-- EmailAddress : extends
    ValueObject <|-- Address : extends
    ValueObject <|-- PhoneNumber : extends
    ValueObject <|-- DateRange : extends
```

**C# 実装（Value Object 基底クラス）:**

```csharp
namespace SharedKernel;

public abstract class ValueObject
{
    protected abstract IEnumerable<object> GetEqualityComponents();

    public override bool Equals(object? obj)
    {
        if (obj is null || obj.GetType() != GetType()) return false;
        var other = (ValueObject)obj;
        return GetEqualityComponents().SequenceEqual(other.GetEqualityComponents());
    }

    public override int GetHashCode()
        => GetEqualityComponents()
            .Aggregate(1, (hash, obj) => HashCode.Combine(hash, obj.GetHashCode()));

    public static bool operator ==(ValueObject left, ValueObject right)
        => left.Equals(right);

    public static bool operator !=(ValueObject left, ValueObject right)
        => !left.Equals(right);
}

public sealed class Money : ValueObject
{
    public decimal Amount { get; }
    public string Currency { get; }

    private Money(decimal amount, string currency)
    {
        if (amount < 0) throw new DomainException("金額は0以上");
        if (currency.Length != 3) throw new DomainException("通貨コードは3文字（ISO 4217）");
        Amount = amount;
        Currency = currency;
    }

    public static Money Of(decimal amount, string currency) => new(amount, currency);
    public static Money Zero(string currency) => new(0m, currency);
    public Money Add(Money other)
    {
        EnsureSameCurrency(other);
        return new Money(Amount + other.Amount, Currency);
    }
    public Money Multiply(decimal factor) => new(Amount * factor, Currency);
    public bool IsZero => Amount == 0m;

    private void EnsureSameCurrency(Money other)
    {
        if (Currency != other.Currency)
            throw new InvalidOperationException($"通貨不一致: {Currency} vs {other.Currency}");
    }

    protected override IEnumerable<object> GetEqualityComponents()
    {
        yield return Amount;
        yield return Currency;
    }
}
```

### 2.2 Record を使った Value Object（.NET 9）

```mermaid
classDiagram
    note for OrderId "record: 構造的等価性が自動"
    class OrderId {
        +Value: Guid
        +New()$ OrderId
        +From(guid)$ OrderId
    }

    note for CustomerId "record: Guid をラップするだけ"
    class CustomerId {
        +Value: Guid
        +New()$ CustomerId
        +From(guid)$ CustomerId
    }

    note for ProductId "Strongly-Typed ID"
    class ProductId {
        +Value: Guid
        +New()$ ProductId
        +From(guid)$ ProductId
    }
```

---

## 3. Entity と Aggregate のクラス図

### 3.1 Entity の基底クラス

```mermaid
classDiagram
    class Entity~TId~ {
        <<abstract>>
        +Id: TId
        -_domainEvents: List~IDomainEvent~
        +DomainEvents: IReadOnlyList~IDomainEvent~
        #RaiseDomainEvent(event) void
        +PopDomainEvents() IReadOnlyList~IDomainEvent~
        +Equals(obj) bool
        +GetHashCode() int
    }

    class AggregateRoot~TId~ {
        <<abstract>>
    }

    Entity~TId~ <|-- AggregateRoot~TId~ : extends
```

### 3.2 Order Aggregate の完全クラス図

```mermaid
classDiagram
    class Order {
        -Id: OrderId
        -_customerId: CustomerId
        -_status: OrderStatus
        -_items: List~OrderItem~
        -_placedAt: DateTime
        -_specialInstructions: string?
        +Items: IReadOnlyList~OrderItem~
        +Status: OrderStatus
        +TotalAmount: Money
        +PlaceNew(customerId, items)$ Order
        +PlaceAsGift(sender, recipient, items, msg)$ Order
        +Reconstitute(id, customerId, ...)$ Order
        +Confirm() void
        +Ship(trackingNumber) void
        +Cancel(reason) void
        +AddItem(item) void
        +RemoveItem(itemId) void
    }

    class OrderItem {
        -Id: OrderItemId
        -_productId: ProductId
        -_productName: string
        -_quantity: int
        -_unitPrice: Money
        +ProductId: ProductId
        +Quantity: int
        +UnitPrice: Money
        +TotalPrice: Money
        +Create(productId, name, qty, price)$ OrderItem
        +Reconstitute(id, productId, ...)$ OrderItem
        +WithQuantity(qty) OrderItem
    }

    class OrderStatus {
        <<enumeration>>
        Pending
        Confirmed
        Shipped
        Delivered
        Cancelled
    }

    class OrderId {
        +Value: Guid
        +New()$ OrderId
        +From(guid)$ OrderId
    }

    class CustomerId {
        +Value: Guid
    }

    class Money {
        +Amount: decimal
        +Currency: string
        +Add(other) Money
    }

    AggregateRoot~OrderId~ <|-- Order : extends
    Entity~OrderItemId~ <|-- OrderItem : extends
    Order *-- OrderItem : 1..*
    Order --> OrderStatus : has
    Order --> OrderId : identified by
    Order --> CustomerId : references
    OrderItem --> Money : unitPrice
```

### 3.3 状態遷移を含む図

```mermaid
stateDiagram-v2
    [*] --> Pending: PlaceNew() / PlaceAsGift()

    Pending --> Confirmed: Confirm()
    Pending --> Cancelled: Cancel(reason)

    Confirmed --> Shipped: Ship(trackingNumber)
    Confirmed --> Cancelled: Cancel(reason)

    Shipped --> Delivered: Deliver()

    Delivered --> [*]
    Cancelled --> [*]
```

---

## 4. Repository パターンのクラス図

```mermaid
classDiagram
    class IOrderRepository {
        <<interface>>
        +FindByIdAsync(id, ct) Task~Order?~
        +FindByCustomerAsync(customerId, ct) Task~IReadOnlyList~Order~~
        +SaveAsync(order, ct) Task
        +DeleteAsync(id, ct) Task
        +ExistsAsync(id, ct) Task~bool~
    }

    class EfOrderRepository {
        -_context: AppDbContext
        +FindByIdAsync(id, ct) Task~Order?~
        +FindByCustomerAsync(customerId, ct) Task~IReadOnlyList~Order~~
        +SaveAsync(order, ct) Task
    }

    class InMemoryOrderRepository {
        -_store: ConcurrentDictionary~Guid, Order~
        +FindByIdAsync(id, ct) Task~Order?~
        +SaveAsync(order, ct) Task
    }

    class AppDbContext {
        +Orders: DbSet~Order~
        +OrderItems: DbSet~OrderItem~
        +SaveChangesAsync(ct) Task~int~
    }

    IOrderRepository <|.. EfOrderRepository : implements
    IOrderRepository <|.. InMemoryOrderRepository : implements
    EfOrderRepository --> AppDbContext : uses
```

---

## 5. Domain Service と Application Service のクラス図

```mermaid
classDiagram
    %% Domain Service（ビジネスロジック、外部依存なし）
    class OrderPricingService {
        <<Domain Service>>
        +CalculateTotal(items, discounts) Money
        +ApplyMemberDiscount(price, tier) Money
        +CalculateTax(subtotal, taxRate) Money
    }

    class IInventoryAvailabilityChecker {
        <<interface: Domain Port>>
        +CheckAvailabilityAsync(productId, qty) Task~StockAvailability~
    }

    %% Application Service（オーケストレーション）
    class PlaceOrderHandler {
        <<Application Service>>
        -_orderRepo: IOrderRepository
        -_productRepo: IProductRepository
        -_pricingService: OrderPricingService
        -_dispatcher: IDomainEventDispatcher
        +HandleAsync(cmd, ct) Task~PlaceOrderResult~
    }

    class GetOrderQueryHandler {
        <<Application Service>>
        -_dapper: IDbConnection
        +HandleAsync(query, ct) Task~OrderDetailDto?~
    }

    %% Infrastructure（ポートの実装）
    class InventorySystemAdapter {
        <<ACL / Adapter>>
        +CheckAvailabilityAsync(productId, qty) Task~StockAvailability~
    }

    PlaceOrderHandler --> IOrderRepository : uses
    PlaceOrderHandler --> OrderPricingService : uses
    PlaceOrderHandler --> IInventoryAvailabilityChecker : uses
    IInventoryAvailabilityChecker <|.. InventorySystemAdapter : implements
```

---

## 6. Hexagonal Architecture（ポート＆アダプター）のクラス図

```mermaid
classDiagram
    %% Domain Layer（中心）
    class Order {
        +PlaceNew()$ Order
        +Confirm() void
    }
    class IOrderRepository {
        <<Secondary Port>>
        +FindByIdAsync(id) Task~Order?~
        +SaveAsync(order) Task
    }
    class IEmailSender {
        <<Secondary Port>>
        +SendAsync(to, subject, body) Task
    }
    class IInventoryPort {
        <<Secondary Port>>
        +CheckAsync(productId, qty) Task~bool~
    }

    %% Application Layer（Primary Port）
    class PlaceOrderUseCase {
        <<Primary Port>>
        +ExecuteAsync(cmd) Task
    }

    class PlaceOrderHandler {
        <<Primary Adapter（実装）>>
        +HandleAsync(cmd) Task
    }

    %% Infrastructure Layer（Secondary Adapter）
    class EfOrderRepository {
        <<Secondary Adapter>>
    }
    class SendGridEmailSender {
        <<Secondary Adapter>>
    }
    class InventorySystemAdapter {
        <<Secondary Adapter / ACL>>
    }

    %% UI Layer
    class OrdersController {
        <<Primary Adapter（HTTP）>>
        +PostAsync(request) ActionResult
    }

    OrdersController --> PlaceOrderUseCase : drives
    PlaceOrderHandler ..|> PlaceOrderUseCase : implements
    PlaceOrderHandler --> IOrderRepository : uses
    PlaceOrderHandler --> IEmailSender : uses
    PlaceOrderHandler --> IInventoryPort : uses
    IOrderRepository <|.. EfOrderRepository : implements
    IEmailSender <|.. SendGridEmailSender : implements
    IInventoryPort <|.. InventorySystemAdapter : implements
    PlaceOrderHandler --> Order : creates
```

---

## 7. CQRS パターンのクラス図

```mermaid
classDiagram
    %% Commands（書き込み側）
    class ICommand~TResult~ {
        <<interface>>
    }

    class PlaceOrderCommand {
        +CustomerId: Guid
        +Items: IReadOnlyList~PlaceOrderItemCommand~
    }

    class CancelOrderCommand {
        +OrderId: Guid
        +Reason: string
    }

    class ICommandHandler~TCommand, TResult~ {
        <<interface>>
        +HandleAsync(cmd, ct) Task~TResult~
    }

    class PlaceOrderHandler {
        +HandleAsync(cmd, ct) Task~PlaceOrderResult~
    }

    class CancelOrderHandler {
        +HandleAsync(cmd, ct) Task
    }

    %% Queries（読み取り側）
    class IQuery~TResult~ {
        <<interface>>
    }

    class GetOrderDetailQuery {
        +OrderId: Guid
    }

    class ListOrdersQuery {
        +CustomerId: Guid?
        +Status: string?
        +Page: int
        +PageSize: int
    }

    class IQueryHandler~TQuery, TResult~ {
        <<interface>>
        +HandleAsync(query, ct) Task~TResult~
    }

    class GetOrderDetailQueryHandler {
        -_db: IDbConnection
        +HandleAsync(query, ct) Task~OrderDetailDto?~
    }

    ICommand~TResult~ <|.. PlaceOrderCommand : implements
    ICommand~TResult~ <|.. CancelOrderCommand : implements
    ICommandHandler~TCommand, TResult~ <|.. PlaceOrderHandler : implements
    ICommandHandler~TCommand, TResult~ <|.. CancelOrderHandler : implements
    IQuery~TResult~ <|.. GetOrderDetailQuery : implements
    IQuery~TResult~ <|.. ListOrdersQuery : implements
    IQueryHandler~TQuery, TResult~ <|.. GetOrderDetailQueryHandler : implements
    PlaceOrderHandler --> Order : creates/updates
    GetOrderDetailQueryHandler ..> OrderDetailDto : returns
```

---

## 8. Event Sourcing のクラス図

```mermaid
classDiagram
    class IDomainEvent {
        <<interface>>
        +OccurredAt: DateTime
        +EventType: string
        +StreamId: Guid
        +StreamVersion: int
    }

    class OrderPlacedEvent {
        +OrderId: Guid
        +CustomerId: Guid
        +Items: IReadOnlyList~OrderItemSnapshot~
        +TotalAmount: decimal
        +Currency: string
        +OccurredAt: DateTime
    }

    class OrderConfirmedEvent {
        +OrderId: Guid
        +ConfirmedAt: DateTime
        +OccurredAt: DateTime
    }

    class OrderCancelledEvent {
        +OrderId: Guid
        +Reason: string
        +OccurredAt: DateTime
    }

    class IEventStore {
        <<interface>>
        +AppendAsync(streamId, events, expectedVersion, ct) Task
        +LoadAsync(streamId, ct) Task~IReadOnlyList~StoredEvent~~
        +LoadFromVersionAsync(streamId, fromVersion, ct) Task~IReadOnlyList~StoredEvent~~
    }

    class EventSourcedOrder {
        <<Event-Sourced Aggregate>>
        -Id: OrderId
        -_status: OrderStatus
        -_version: int
        +From(history)$ EventSourcedOrder
        +PlaceNew(customerId, items)$ EventSourcedOrder
        +Confirm() void
        +Cancel(reason) void
        -Apply(event: OrderPlacedEvent) void
        -Apply(event: OrderConfirmedEvent) void
        -Apply(event: OrderCancelledEvent) void
        -ApplyEvent(event) void
    }

    IDomainEvent <|.. OrderPlacedEvent : implements
    IDomainEvent <|.. OrderConfirmedEvent : implements
    IDomainEvent <|.. OrderCancelledEvent : implements
    EventSourcedOrder --> IDomainEvent : raises
    IEventStore --> IDomainEvent : stores
```

---

## 9. Saga / Process Manager のクラス図

```mermaid
classDiagram
    class IOrderFulfillmentSaga {
        <<interface>>
        +HandleAsync(event: OrderPlacedEvent) Task
        +HandleAsync(event: StockReservedEvent) Task
        +HandleAsync(event: PaymentProcessedEvent) Task
        +HandleAsync(event: StockReservationFailedEvent) Task
        +HandleAsync(event: PaymentFailedEvent) Task
    }

    class OrderFulfillmentSagaState {
        +SagaId: Guid
        +OrderId: Guid
        +CurrentState: FulfillmentState
        +StockReserved: bool
        +PaymentProcessed: bool
        +CreatedAt: DateTime
        +UpdatedAt: DateTime
    }

    class FulfillmentState {
        <<enumeration>>
        WaitingForStockReservation
        WaitingForPayment
        Compensating
        Completed
        Failed
    }

    class OrderFulfillmentSagaOrchestrator {
        -_state: OrderFulfillmentSagaState
        -_commandBus: ICommandBus
        +HandleAsync(event: OrderPlacedEvent) Task
        -CompensateAsync() Task
    }

    IOrderFulfillmentSaga <|.. OrderFulfillmentSagaOrchestrator : implements
    OrderFulfillmentSagaOrchestrator --> OrderFulfillmentSagaState : manages
    OrderFulfillmentSagaState --> FulfillmentState : has
```

---

## 10. ECサイト全体ドメインモデル

```mermaid
classDiagram
    %% OrderContext
    class Order {
        -Id: OrderId
        -_customerId: CustomerId
        -_status: OrderStatus
        -_items: List~OrderItem~
        +PlaceNew()$ Order
        +Confirm() void
        +Ship(tracking) void
    }

    class OrderItem {
        -_productId: ProductId
        -_quantity: int
        -_unitPrice: Money
        +TotalPrice: Money
    }

    %% CustomerContext（参照のみ）
    class Customer {
        -Id: CustomerId
        -_name: string
        -_email: EmailAddress
        -_tier: CustomerTier
        +Register()$ Customer
        +UpdateEmail(email) void
    }

    %% InventoryContext
    class Inventory {
        -Id: InventoryId
        -_productId: ProductId
        -_quantityOnHand: int
        -_reservedQuantity: int
        +Reserve(qty) void
        +Release(qty) void
        +AvailableQuantity: int
    }

    %% PaymentContext
    class Payment {
        -Id: PaymentId
        -_orderId: OrderId
        -_amount: Money
        -_status: PaymentStatus
        +Process(method) void
        +Refund(reason) void
    }

    %% ShippingContext
    class Shipment {
        -Id: ShipmentId
        -_orderId: OrderId
        -_address: Address
        -_trackingNumber: string?
        +Dispatch() void
        +Deliver() void
    }

    %% 関係（Bounded Context 間は Integration Event で繋ぐ）
    Order *-- OrderItem : 1..*
    Order ..> Customer : references by ID
    Order ..> Inventory : triggers reserve via event
    Order ..> Payment : triggers payment via event
    Payment ..> Order : references by ID
    Shipment ..> Order : references by ID
```

---

## 11. Context Map のクラス図

Context Map はクラス図よりもフロー図（graph）で表現する方が適切です。

```mermaid
graph TB
    subgraph CoreDomain["Core Domain"]
        ORDER["OrderContext\n【Core】"]
    end

    subgraph Supporting["Supporting Subdomain"]
        CUST["CustomerContext\n【Supporting】\nOpen-Host Service"]
        INV["InventoryContext\n【Supporting】"]
        SHIP["ShippingContext\n【Supporting】"]
    end

    subgraph Generic["Generic Subdomain（外部SaaS）"]
        PAY["PaymentContext\n（Stripe）\nConformist + ACL"]
        NOTIF["NotificationContext\n（SendGrid）\nConformist + ACL"]
        ANALYTICS["AnalyticsContext\n（BigQuery）\nSeparate Ways"]
    end

    CUST -->|"Customer-Supplier\n顧客情報API v2"| ORDER
    ORDER -->|"Integration Event\n→ OrderPlaced"| INV
    ORDER -->|"Integration Event\n→ OrderPlaced"| PAY
    ORDER -->|"Integration Event\n→ OrderPlaced"| NOTIF
    ORDER -->|"Integration Event\n→ OrderPlaced"| ANALYTICS
    INV -->|"Integration Event\n→ StockReserved"| SHIP
```

---

## 12. アーキテクト必携: よく使うクラス図パターン集

### 12.1 依存逆転の原則（DIP）

```mermaid
classDiagram
    %% 誤った依存（Domain → Infrastructure）
    class OrderService_Wrong {
        -EfOrderRepository repo
        +PlaceOrder() void
    }
    class EfOrderRepository_Wrong {
        -DbContext _db
        +Save(order) void
    }

    %% 正しい依存（Domain ← Infrastructure, Domain → Interface）
    class PlaceOrderHandler_Right {
        -IOrderRepository _repo
        +HandleAsync(cmd) Task
    }
    class IOrderRepository_Right {
        <<interface>>
        +SaveAsync(order) Task
    }
    class EfOrderRepository_Right {
        +SaveAsync(order) Task
    }

    OrderService_Wrong --> EfOrderRepository_Wrong : 直接依存（NG）
    PlaceOrderHandler_Right --> IOrderRepository_Right : 依存（OK）
    EfOrderRepository_Right ..|> IOrderRepository_Right : 実装（OK）
```

### 12.2 Outbox Pattern

```mermaid
classDiagram
    class OutboxMessage {
        +Id: Guid
        +EventType: string
        +Payload: string
        +OccurredAt: DateTime
        +ProcessedAt: DateTime?
        +RetryCount: int
    }

    class OutboxPublisher {
        -_db: AppDbContext
        -_messageBus: IMessageBus
        +PublishPendingAsync(ct) Task
    }

    class AppDbContext {
        +Orders: DbSet~Order~
        +OutboxMessages: DbSet~OutboxMessage~
        +SaveChangesAsync(ct) Task~int~
    }

    OutboxPublisher --> OutboxMessage : reads/updates
    OutboxPublisher --> AppDbContext : queries
    AppDbContext *-- OutboxMessage : stores
```

---

## 13. クラス図を描く際のルール

### 13.1 Bounded Context ごとに独立した図を用意する

一枚の図に全コンテキストを詰め込まない。ECサイトであれば:
- `class-diagram-order-context.md`
- `class-diagram-customer-context.md`
- `class-diagram-inventory-context.md`
- `class-diagram-full-system.md`（概要のみ）

### 13.2 クラス図に入れるもの・入れないもの

**入れるもの:**
- ドメインオブジェクト（Entity・Value Object・Aggregate Root）
- Repository の Interface
- Application Service の Interface（使い方の理解に必要な場合）
- 関係（コンポジション・継承・依存）

**入れないもの:**
- 全フィールドの型（概要図では重要なものだけ）
- Implementation の詳細（EF Core の設定など）
- DTO（アプリ詳細すぎる）

### 13.3 レビューチェックリスト

**集約の境界確認:**
- [ ] Aggregate Root が一つだけ存在するか
- [ ] Aggregate 内の子エンティティは Aggregate 経由でのみアクセスされるか
- [ ] 異なる Aggregate 間の参照はIDのみか（オブジェクト参照ではないか）

**依存方向の確認:**
- [ ] Domain Layer から Infrastructure Layer への矢印がないか
- [ ] Infrastructure Layer が Domain Layer の Interface を実装しているか
- [ ] 循環依存がないか

**Value Object の確認:**
- [ ] 不変な概念が Value Object として設計されているか
- [ ] IDフィールドが Value Object でラップされているか（`Guid` の直接使用がないか）

---

## 14. 演習問題

**問1: 医療予約システムのクラス図**

以下のユビキタス言語から、Aggregate・Entity・Value Object を識別し、クラス図を描いてください。

- **患者**（氏名、生年月日、保険証番号）
- **予約**（予約日時、担当医師、診療科、ステータス）
- **診療科**（内科・外科・整形外科など）
- **担当医師**（医師ID、氏名、資格）
- **診療時間枠**（開始時刻、終了時刻、残り予約可能数）

解答のポイント:
```mermaid
classDiagram
    class Appointment {
        <<Aggregate Root>>
        -Id: AppointmentId
        -_patientId: PatientId
        -_slotId: TimeSlotId
        -_status: AppointmentStatus
        +Book(patient, slot)$ Appointment
        +Cancel(reason) void
        +Confirm() void
    }

    class TimeSlot {
        <<Aggregate Root>>
        -Id: TimeSlotId
        -_doctorId: DoctorId
        -_period: TimePeriod
        -_remainingCapacity: int
        +Reserve() void
        +Release() void
        +IsAvailable: bool
    }

    class Patient {
        <<Aggregate Root>>
        -Id: PatientId
        -_name: PatientName
        -_birthDate: DateOnly
        -_insuranceNumber: InsuranceNumber
    }
```

**問2: Event Sourcing のイベントクラス図**

銀行口座（BankAccount）の Event Sourcing 実装について:
- イベント: `AccountOpened`, `MoneyDeposited`, `MoneyWithdrawn`, `AccountClosed`
- 状態: `Balance`, `Status`, `Version`

これらのクラス図を描き、`Apply(event)` メソッドの実装を示してください。

**問3: マイクロサービス間のクラス図**

注文サービスと在庫サービスが Choreography Saga で連携する場合のクラス図を描いてください。

- 注文サービス: `Order` Aggregate、`OrderPlacedEvent` 発行
- 在庫サービス: `Inventory` Aggregate、`StockReservedEvent` / `StockReservationFailedEvent` 発行
- 注文サービスが `StockReservationFailedEvent` を受けた場合: `Order.Cancel()` を呼ぶ

---

## 参考文献と著者の解釈

UML クラス図の表記法は Object Management Group（OMG）が策定した UML 2.5 仕様に基づいています。DDD コンテキストでのクラス図の使い方は、Vaughn Vernon の *Implementing Domain-Driven Design*（2013）が最も詳細に扱っています。

筆者の経験では、クラス図を「完璧に描こうとする」のではなく、「議論のきっかけを作るために描く」という姿勢が重要です。Evans も強調するように、DDD のモデルは会話の中で進化するものです。クラス図は最初から完璧である必要はなく、チームの理解が深まるにつれて更新していきます。

Mermaid を使うことで、コードと設計図を同じリポジトリで管理できます。「コードと図が乖離する」問題を防ぐために、PR のレビューには必ずクラス図の更新も含めることを推奨します。
