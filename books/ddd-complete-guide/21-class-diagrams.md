---
title: "第21章: クラス図でDDDを完全に理解する"
---


## なぜクラス図が必要か

DDD を「なんとなく理解した気がする」から「設計を人に説明できる」へ進むには、**モデルを視覚化する能力**が不可欠です。

Eric Evans は Blue Book の中で、チームがドメインモデルを共有するために図（UML クラス図）を積極的に使うことを推奨しています。ただし彼はこう警告しています:

> 「図はモデルではない。図はモデルのある側面を可視化したコミュニケーションツールに過ぎない」

つまりクラス図は、コードの前に「チームの共通理解」を作るためのものです。

---

## 1. Value Object 階層

```mermaid
classDiagram
    class ValueObject {
        <<abstract>>
        #GetEqualityComponents() IEnumerable~object~
        +Equals(obj: object) bool
        +GetHashCode() int
        +operator==() bool
        +operator!=() bool
    }

    class Money {
        +Amount: decimal
        +Currency: string
        +Of(amount, currency)$ Money
        +Zero()$ Money
        +Add(other: Money) Money
        +Subtract(other: Money) Money
        +Multiply(qty: int) Money
        +IsGreaterThan(other: Money) bool
    }

    class EmailAddress {
        +Value: string
        +Of(value: string)$ EmailAddress
        -Validate(value) void
    }

    class Address {
        +PostalCode: string
        +Prefecture: string
        +City: string
        +Street: string
        +Of(postalCode, prefecture, city, street)$ Address
    }

    class PhoneNumber {
        +CountryCode: string
        +Number: string
        +Format() string
    }

    class DateRange {
        +Start: DateTime
        +End: DateTime
        +Duration: TimeSpan
        +Contains(date) bool
        +OverlapsWith(other: DateRange) bool
    }

    class OrderId {
        +Value: Guid
        +New()$ OrderId
        +From(value: Guid)$ OrderId
    }

    class CustomerId {
        +Value: Guid
        +From(value: Guid)$ CustomerId
    }

    class ProductId {
        +Value: Guid
        +From(value: Guid)$ ProductId
    }

    class OrderItemId {
        +Value: Guid
        +New()$ OrderItemId
    }

    ValueObject <|-- Money
    ValueObject <|-- EmailAddress
    ValueObject <|-- Address
    ValueObject <|-- PhoneNumber
    ValueObject <|-- DateRange
    ValueObject <|-- OrderId
    ValueObject <|-- CustomerId
    ValueObject <|-- ProductId
    ValueObject <|-- OrderItemId
```

**読み方のポイント:**
- `<<abstract>>` がついたクラスは基底クラス（直接インスタンス化しない）
- `$` マークは static メンバー（ファクトリメソッド）
- 全 Value Object は `ValueObject` を継承する → 等値比較が自動的に正しく動く

---

## 2. Entity 階層と Aggregate 境界

```mermaid
classDiagram
    class IDomainEvent {
        <<interface>>
    }

    class Entity~TId~ {
        <<abstract>>
        -_domainEvents: List~IDomainEvent~
        +Id: TId
        +DomainEvents: IReadOnlyList~IDomainEvent~
        #RaiseDomainEvent(event) void
        +ClearDomainEvents() void
        +Equals(obj) bool
        +GetHashCode() int
    }

    class Order {
        <<AggregateRoot>>
        +Id: OrderId
        +CustomerId: CustomerId
        +Status: OrderStatus
        +ShippingAddress: Address
        +PlacedAt: DateTime
        +ShippedAt: DateTime?
        +Items: IReadOnlyList~OrderItem~
        +TotalAmount: Money
        +Create(customerId, address)$ Order
        +AddItem(productId, name, price, qty) void
        +RemoveItem(itemId: OrderItemId) void
        +Place() void
        +Ship() void
        +Cancel(reason: string) void
        -EnsureStatus(expected, action) void
    }

    class OrderItem {
        <<Entity内部 - 外から直接操作禁止>>
        +Id: OrderItemId
        +ProductId: ProductId
        +ProductName: string
        +UnitPrice: Money
        +Quantity: int
        +SubTotal: Money
        +Create(id, productId, name, price, qty)$ OrderItem
        +IncreaseQuantity(additional: int) void
    }

    class Customer {
        <<AggregateRoot>>
        +Id: CustomerId
        +Name: string
        +Email: EmailAddress
        +Tier: CustomerTier
        +DefaultAddress: Address?
        +TotalPurchaseCount: int
        +Create(id, name, email)$ Customer
        +UpgradeTier(newTier: CustomerTier) void
        +SetDefaultAddress(address: Address) void
        +RecordPurchase() void
    }

    class Product {
        <<AggregateRoot>>
        +Id: ProductId
        +Name: string
        +Price: Money
        +StockQuantity: int
        +IsActive: bool
        +Create(id, name, price, stock)$ Product
        +UpdatePrice(newPrice: Money) void
        +Reserve(quantity: int) void
        +Release(quantity: int) void
        +Deactivate() void
    }

    Entity~TId~ <|-- Order : TId = OrderId
    Entity~TId~ <|-- OrderItem : TId = OrderItemId
    Entity~TId~ <|-- Customer : TId = CustomerId
    Entity~TId~ <|-- Product : TId = ProductId

    Order "1" *-- "1..*" OrderItem : 【同Aggregate内】直接参照OK
    Order --> CustomerId : 【Aggregate外】IDのみで参照
    OrderItem --> ProductId : 【Aggregate外】IDのみで参照
    Order --> Address : has (shipping)
    Order --> Money : has (total)
    Customer --> EmailAddress : has
    Customer --> Address : has (default)
    Product --> Money : has (price)
```

**Aggregate 境界のルール:**
- `*--` (composition): 同一 Aggregate 内 → 直接オブジェクト参照 OK
- `-->` (association): 別 Aggregate → **ID のみで参照**（`CustomerId` を保持し `Customer` オブジェクトを持たない）

---

## 3. Domain Events フロー

```mermaid
classDiagram
    class IDomainEvent {
        <<interface>>
    }

    class OrderCreatedEvent {
        +OrderId: OrderId
        +CustomerId: CustomerId
        +OccurredAt: DateTime
    }

    class OrderPlacedEvent {
        +OrderId: OrderId
        +CustomerId: CustomerId
        +TotalAmount: Money
        +OccurredAt: DateTime
    }

    class OrderShippedEvent {
        +OrderId: OrderId
        +ShippedAt: DateTime
        +OccurredAt: DateTime
    }

    class OrderCancelledEvent {
        +OrderId: OrderId
        +Reason: string
        +OccurredAt: DateTime
    }

    class IDomainEventHandler~TEvent~ {
        <<interface>>
        +HandleAsync(event: TEvent) Task
    }

    class IDomainEventDispatcher {
        <<interface>>
        +DispatchAsync(events: IReadOnlyList~IDomainEvent~) Task
    }

    class DomainEventDispatcher {
        -_serviceProvider: IServiceProvider
        +DispatchAsync(events) Task
    }

    class OrderPlacedEmailHandler {
        -_emailService: IEmailService
        +HandleAsync(event: OrderPlacedEvent) Task
    }

    class OrderPlacedInventoryHandler {
        -_inventoryService: IInventoryService
        +HandleAsync(event: OrderPlacedEvent) Task
    }

    IDomainEvent <|.. OrderCreatedEvent
    IDomainEvent <|.. OrderPlacedEvent
    IDomainEvent <|.. OrderShippedEvent
    IDomainEvent <|.. OrderCancelledEvent

    IDomainEventHandler~TEvent~ <|.. OrderPlacedEmailHandler
    IDomainEventHandler~TEvent~ <|.. OrderPlacedInventoryHandler

    IDomainEventDispatcher <|.. DomainEventDispatcher
    DomainEventDispatcher ..> IDomainEventHandler~TEvent~ : resolves & calls
```

---

## 4. Repository パターン (依存逆転の実現)

```mermaid
classDiagram
    namespace DomainLayer {
        class IOrderRepository {
            <<interface>>
            +FindByIdAsync(id: OrderId) Order?
            +FindByCustomerAsync(customerId) IReadOnlyList~Order~
            +FindByStatusAsync(status) IReadOnlyList~Order~
            +SaveAsync(order: Order) void
            +DeleteAsync(id: OrderId) void
        }
        class ICustomerRepository {
            <<interface>>
            +FindByIdAsync(id: CustomerId) Customer?
            +FindByEmailAsync(email: EmailAddress) Customer?
            +SaveAsync(customer: Customer) void
        }
        class IProductRepository {
            <<interface>>
            +FindByIdAsync(id: ProductId) Product?
            +FindActiveAsync() IReadOnlyList~Product~
            +SaveAsync(product: Product) void
        }
    }

    namespace InfrastructureLayer {
        class EfOrderRepository {
            -_ctx: AppDbContext
            +FindByIdAsync(id: OrderId) Order?
            +FindByCustomerAsync(customerId) IReadOnlyList~Order~
            +FindByStatusAsync(status) IReadOnlyList~Order~
            +SaveAsync(order: Order) void
            +DeleteAsync(id: OrderId) void
        }
        class InMemoryOrderRepository {
            -_store: ConcurrentDictionary~Guid, Order~
            +FindByIdAsync(id: OrderId) Order?
            +SaveAsync(order: Order) void
        }
        class AppDbContext {
            +Orders: DbSet~Order~
            +Customers: DbSet~Customer~
            +Products: DbSet~Product~
        }
    }

    EfOrderRepository ..|> IOrderRepository : implements
    InMemoryOrderRepository ..|> IOrderRepository : implements (テスト用)
    EfOrderRepository --> AppDbContext : uses
```

---

## 5. Application Service と CQRS

```mermaid
classDiagram
    namespace Commands {
        class PlaceOrderCommand {
            +CustomerId: Guid
            +PostalCode: string
            +Items: List~OrderItemRequest~
        }
        class CancelOrderCommand {
            +OrderId: Guid
            +Reason: string
        }
        class PlaceOrderHandler {
            -_orderRepo: IOrderRepository
            -_customerRepo: ICustomerRepository
            -_domainService: OrderDomainService
            -_dispatcher: IDomainEventDispatcher
            +HandleAsync(cmd: PlaceOrderCommand) PlaceOrderResult
        }
        class CancelOrderHandler {
            -_orderRepo: IOrderRepository
            -_dispatcher: IDomainEventDispatcher
            +HandleAsync(cmd: CancelOrderCommand) void
        }
    }

    namespace Queries {
        class GetOrderQuery {
            +OrderId: Guid
        }
        class GetOrdersByCustomerQuery {
            +CustomerId: Guid
            +Status: OrderStatus?
            +Page: int
            +PageSize: int
        }
        class OrderDto {
            +OrderId: Guid
            +Status: string
            +TotalAmount: decimal
            +Currency: string
            +Items: List~OrderItemDto~
            +PlacedAt: DateTime
        }
        class GetOrderQueryHandler {
            -_readDb: IOrderReadRepository
            +HandleAsync(query: GetOrderQuery) Task~OrderDto~
        }
    }

    PlaceOrderHandler --> PlaceOrderCommand : receives
    CancelOrderHandler --> CancelOrderCommand : receives
    GetOrderQueryHandler --> GetOrderQuery : receives
    GetOrderQueryHandler --> OrderDto : returns
    PlaceOrderHandler --> IOrderRepository : uses
    PlaceOrderHandler --> OrderDomainService : uses
```

---

## 6. 全体システムクラス図 (Domain Layer 完全版)

```mermaid
classDiagram
    %% 基底
    class ValueObject { <<abstract>> }
    class Entity~TId~ { <<abstract>> }
    class IDomainEvent { <<interface>> }
    class DomainException { +Message: string }

    %% Value Objects
    class Money { +Amount: decimal; +Currency: string }
    class Address { +PostalCode: string; +Prefecture: string }
    class EmailAddress { +Value: string }
    class OrderId { +Value: Guid }
    class CustomerId { +Value: Guid }
    class ProductId { +Value: Guid }
    class OrderItemId { +Value: Guid }

    %% Aggregates
    class Order {
        <<AggregateRoot>>
        +Status: OrderStatus
        +TotalAmount: Money
        +AddItem() void
        +Place() void
        +Ship() void
        +Cancel() void
    }
    class OrderItem {
        <<Entity>>
        +Quantity: int
        +SubTotal: Money
    }
    class Customer {
        <<AggregateRoot>>
        +Tier: CustomerTier
        +UpgradeTier() void
    }
    class Product {
        <<AggregateRoot>>
        +StockQuantity: int
        +Reserve() void
    }

    %% Events
    class OrderPlacedEvent { +TotalAmount: Money }
    class OrderShippedEvent { +ShippedAt: DateTime }

    %% Repositories (Interfaces)
    class IOrderRepository { <<interface>> }
    class ICustomerRepository { <<interface>> }

    %% Domain Service
    class OrderDomainService {
        +CalculateDiscount() Money
        +HasRecentDuplicate() bool
    }

    %% 継承
    ValueObject <|-- Money
    ValueObject <|-- Address
    ValueObject <|-- EmailAddress
    ValueObject <|-- OrderId
    ValueObject <|-- CustomerId
    ValueObject <|-- ProductId
    ValueObject <|-- OrderItemId
    Entity~TId~ <|-- Order
    Entity~TId~ <|-- OrderItem
    Entity~TId~ <|-- Customer
    Entity~TId~ <|-- Product
    IDomainEvent <|.. OrderPlacedEvent
    IDomainEvent <|.. OrderShippedEvent

    %% Aggregate 関係
    Order "1" *-- "1..*" OrderItem
    Order --> CustomerId
    OrderItem --> ProductId
    Order --> Address
    Order --> Money
    Customer --> EmailAddress
    Product --> Money

    %% Domain Event 発行
    Order ..> OrderPlacedEvent : raises
    Order ..> OrderShippedEvent : raises

    %% Repository
    IOrderRepository ..> Order : manages
    ICustomerRepository ..> Customer : manages

    %% Domain Service
    OrderDomainService --> Order : uses
    OrderDomainService --> Money : returns
```

---

## 7. OrderStatus ステートマシン

```mermaid
stateDiagram-v2
    [*] --> Draft : Order.Create()
    Draft --> Placed : order.Place()\n[Guard: Items.Any()]
    Draft --> Cancelled : order.Cancel(reason)
    Placed --> Shipped : order.Ship()
    Placed --> Cancelled : order.Cancel(reason)
    Shipped --> Delivered : order.Deliver()
    Shipped --> Cancelled : ❌ DomainException\n発送済みはキャンセル不可
    Cancelled --> [*]
    Delivered --> [*]

    note right of Draft
        AddItem() / RemoveItem() 可能
        Place() で確定
    end note

    note right of Shipped
        ShippedAt が記録される
        OrderShippedEvent が発行される
    end note
```

---

## クラス図の読み方 早見表

| 記号 | 意味 | DDD での使い方 |
|------|------|-------------|
| `<<abstract>>` | 抽象クラス | `ValueObject`, `Entity<TId>` |
| `<<interface>>` | インターフェース | `IOrderRepository`, `IDomainEvent` |
| `<<AggregateRoot>>` | 集約のルート | `Order`, `Customer`, `Product` |
| `<<Entity>>` | 集約内部の Entity | `OrderItem` |
| `*--` | コンポジション | Aggregate 内部の直接参照 |
| `-->` | 関連 | ID 参照（別 Aggregate） |
| `..|>` | 実装 | `EfRepository ..|> IRepository` |
| `<|--` | 継承 | `Money <|-- ValueObject` |
| `$` | static メンバー | ファクトリメソッド `Order.Create()` |
| `?` | Nullable | `ShippedAt: DateTime?` |
| `~T~` | ジェネリック型 | `Entity<TId>`, `List<Order>` |

---

## まとめ

クラス図は DDD の「設計の会話」を可視化するツールです。コードを書く前に図を描き、ドメイン専門家とレビューすることで、モデルの誤りを早期に発見できます。

重要なのは「正確な UML」よりも「チームが共通理解を得られること」です。Mermaid のような軽量ツールで十分です。書いては議論し、議論しては直す — それが DDD のモデリングです。
