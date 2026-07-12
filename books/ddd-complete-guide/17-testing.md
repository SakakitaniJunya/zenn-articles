# 第17章: テスト戦略

> ドメインモデルの品質は、テストの質によって証明されます。コードが「動く」ことを示すのではなく、ビジネスルールが「守られている」ことを示すのがDDDのテスト戦略です。

---

## 0. TL;DR

- **DDDのテストピラミッドは70/20/10が基本**: Domain Layer（Aggregate・Value Object）のユニットテストを最多にし、高速・安定・安価なフィードバックループを確立します。
- **テスト名はビジネス語で書く**: `Given_OrderHasItems_When_PlaceOrder_Then_StatusBecomesPlaced` のような形式により、テストがドキュメントとして機能します。
- **モックは境界（Repository・外部サービス）のみに限定する**: Domain Logicをモックする設計は「実装詳細に依存したテスト」というアンチパターンです。
- **統合テストにはTestContainersで本物のDBを使う**: インメモリDBでは検出できない楽観的ロック競合・トランザクション境界のバグを本番同等の環境で発見できます。
- **テストはビジネスシナリオとして読める**: Given-When-Then構造により、エンジニアでない関係者もテストの意図を理解できます。

---

## 1. DDDシステムのテストピラミッド

### 1.1 なぜピラミッド形なのか

テストには「速度・安定性・メンテナンスコスト・検出力」のトレードオフがあります。ユニットテストは実行が数ミリ秒で完了し、CI/CDの度に数百本を走らせても数十秒で終わります。一方でE2Eテストは実際のブラウザやAPIサーバを起動するため数分かかり、ネットワーク遅延や外部サービスの不安定さに影響されます。

DDDにおいてこのトレードオフが特に有利に働くのが、**ドメインロジックがドメイン層に集中している**という設計原則です。Domain Layerは純粋な.NETのクラスであり、DBもHTTPも依存しません。したがってユニットテストで最大の価値のある検証が完結します。

| テスト種別       | 割合 | 速度    | 対象                              |
|----------------|------|---------|-----------------------------------|
| Unit           | 70%  | 数ms    | Aggregate / Value Object / Domain Service |
| Integration    | 20%  | 数秒    | Repository / Application Service  |
| E2E            | 10%  | 数分    | API エンドポイント / UI フロー     |

### 1.2 テストピラミッド図

```mermaid
graph TB
    subgraph Pyramid["テストピラミッド (DDD版)"]
        E2E["テスト最上位: E2E テスト\n10% | 数分/run\nAPIエンドポイント・UI"]
        Integration["テスト中間: 統合テスト\n20% | 数秒/run\nRepository・Application Service"]
        Unit["テスト基盤: ユニットテスト\n70% | 数ms/run\nAggregate・Value Object・Domain Service"]
    end

    Unit --> Integration --> E2E

    style Unit fill:#4ade80,color:#000
    style Integration fill:#fb923c,color:#000
    style E2E fill:#f87171,color:#fff
```

### 1.3 DDD固有のテスト対象マッピング

```mermaid
flowchart LR
    subgraph DomainLayer["Domain Layer"]
        AggRoot["Aggregate Root\nOrder"]
        VO["Value Objects\nMoney, Address"]
        DS["Domain Services\nPricingService"]
        DE["Domain Events\nOrderPlaced"]
    end

    subgraph AppLayer["Application Layer"]
        CH["CommandHandlers\nPlaceOrderHandler"]
        QH["QueryHandlers\nGetOrderQuery"]
    end

    subgraph InfraLayer["Infrastructure Layer"]
        Repo["Repositories\nOrderRepository"]
        DB[("PostgreSQL")]
    end

    subgraph TestTypes["テスト種別"]
        UT["Unit Tests\nxUnit + FluentAssertions\n70%"]
        IT["Integration Tests\nTestContainers\n20%"]
        E2E["E2E Tests\n10%"]
    end

    AggRoot & VO & DS --> UT
    CH & QH --> UT
    CH & QH --> IT
    Repo --> IT
    DB --> IT
    AggRoot & AppLayer & InfraLayer --> E2E
```

### 1.4 なぜUnit比率を高くするのか

**理由1: フィードバック速度**

1000本のユニットテストが10秒で完了すれば、開発者はコミットのたびに全体品質を確認できます。E2Eが1000本あれば数時間かかり、実質的にCIが形骸化します。

**理由2: テスト失敗の局所化**

ユニットテストはAggregateの単一メソッドを対象とするため、失敗時に原因がすぐ特定できます。E2Eテスト失敗はDBの問題かネットワークの問題かAPIの問題か特定に時間がかかります。

**理由3: DDDのドメインロジック集中という設計上の恩恵**

DDDでは「重要なビジネスルールはすべてドメイン層に置く」という原則があります。この原則が守られていれば、ユニットテストだけでビジネスルールの90%以上を検証できます。逆に言えば、Application Layerや Infrastructure Layerのテストカバレッジが低くても、ドメイン層さえしっかりテストされていれば致命的なビジネスロジックのバグはほぼ防げます。

---

## 2. Domain Layerのユニットテスト（Given-When-Then）

### 2.1 テスト構造の設計思想

Given-When-Thenはテストを「前提条件・操作・期待結果」の3ステップで構造化します。DDDにおいて重要なのは、**テスト名とコードがビジネス語で書かれていること**です。

```csharp
// 悪い例 (実装語)
[Fact]
public void Test_SetStatus_After_AddItem()

// 良い例 (ビジネス語)
[Fact]
public void Given_EmptyOrder_When_ItemAdded_Then_OrderContainsOneLineItem()
```

このようにテスト名をビジネス語にすることで、テストスイートがそのまま「ユーザーストーリーの仕様書」として機能します。ドメインエキスパートがテスト名の一覧を読んでも、システムがどのようなビジネスルールを持っているかが把握できるようになります。

### 2.2 プロジェクト構成

```
tests/
├── Domain.Tests/
│   ├── Aggregates/
│   │   ├── OrderAggregateTests.cs
│   │   └── OrderAggregateExceptionTests.cs
│   ├── ValueObjects/
│   │   ├── MoneyTests.cs
│   │   └── AddressTests.cs
│   └── DomainServices/
│       └── PricingServiceTests.cs
├── Application.Tests/
│   ├── Commands/
│   │   └── PlaceOrderHandlerTests.cs
│   └── Queries/
│       └── GetOrderQueryHandlerTests.cs
└── Infrastructure.Tests/
    └── Repositories/
        └── OrderRepositoryIntegrationTests.cs
```

### 2.3 ドメインモデルの定義（テスト対象）

```csharp
// src/Domain/Orders/Order.cs
namespace ECommerce.Domain.Orders;

public sealed class Order : AggregateRoot<OrderId>
{
    private readonly List<OrderLine> _lines = [];
    private readonly List<IDomainEvent> _domainEvents = [];

    public CustomerId CustomerId { get; private set; }
    public OrderStatus Status { get; private set; }
    public Money TotalAmount { get; private set; }
    public Address? ShippingAddress { get; private set; }
    public DateTimeOffset CreatedAt { get; private set; }
    public DateTimeOffset? PlacedAt { get; private set; }
    public IReadOnlyList<OrderLine> Lines => _lines.AsReadOnly();
    public IReadOnlyList<IDomainEvent> DomainEvents => _domainEvents.AsReadOnly();

    private Order() { } // EF Core用プライベートコンストラクタ

    public static Order Create(CustomerId customerId, DateTimeOffset createdAt)
    {
        var order = new Order
        {
            Id = OrderId.New(),
            CustomerId = customerId,
            Status = OrderStatus.Draft,
            TotalAmount = Money.Zero("JPY"),
            CreatedAt = createdAt
        };
        order._domainEvents.Add(new OrderCreatedEvent(order.Id, customerId, createdAt));
        return order;
    }

    public void AddItem(ProductId productId, ProductName productName, Money unitPrice, Quantity quantity)
    {
        if (Status != OrderStatus.Draft)
            throw new OrderNotEditableException(Id, Status);

        if (unitPrice.Amount <= 0)
            throw new InvalidProductPriceException(productId, unitPrice);

        var existingLine = _lines.FirstOrDefault(l => l.ProductId == productId);
        if (existingLine is not null)
        {
            var newQuantity = existingLine.Quantity + quantity;
            _lines.Remove(existingLine);
            _lines.Add(existingLine with { Quantity = newQuantity, SubTotal = unitPrice * newQuantity });
        }
        else
        {
            _lines.Add(new OrderLine(OrderLineId.New(), productId, productName, unitPrice, quantity, unitPrice * quantity));
        }

        RecalculateTotal();
        _domainEvents.Add(new OrderItemAddedEvent(Id, productId, quantity, unitPrice));
    }

    public void RemoveItem(ProductId productId)
    {
        if (Status != OrderStatus.Draft)
            throw new OrderNotEditableException(Id, Status);

        var line = _lines.FirstOrDefault(l => l.ProductId == productId)
            ?? throw new OrderLineNotFoundException(Id, productId);

        _lines.Remove(line);
        RecalculateTotal();
    }

    public void SetShippingAddress(Address address)
    {
        if (Status != OrderStatus.Draft)
            throw new OrderNotEditableException(Id, Status);

        ShippingAddress = address;
    }

    public void Place(DateTimeOffset placedAt)
    {
        if (Status != OrderStatus.Draft)
            throw new InvalidOrderStateTransitionException(Id, Status, OrderStatus.Placed);

        if (_lines.Count == 0)
            throw new CannotPlaceEmptyOrderException(Id);

        if (ShippingAddress is null)
            throw new ShippingAddressRequiredException(Id);

        Status = OrderStatus.Placed;
        PlacedAt = placedAt;
        _domainEvents.Add(new OrderPlacedEvent(Id, CustomerId, TotalAmount, placedAt));
    }

    public void Cancel(string reason)
    {
        if (Status == OrderStatus.Shipped || Status == OrderStatus.Delivered)
            throw new CannotCancelShippedOrderException(Id, Status);

        if (Status == OrderStatus.Cancelled)
            throw new OrderAlreadyCancelledException(Id);

        Status = OrderStatus.Cancelled;
        _domainEvents.Add(new OrderCancelledEvent(Id, reason, DateTimeOffset.UtcNow));
    }

    public void ClearDomainEvents() => _domainEvents.Clear();

    private void RecalculateTotal()
    {
        TotalAmount = _lines.Aggregate(Money.Zero("JPY"), (acc, line) => acc + line.SubTotal);
    }
}
```

### 2.4 OrderAggregateのユニットテスト（完全実装・22本）

```csharp
// tests/Domain.Tests/Aggregates/OrderAggregateTests.cs
namespace ECommerce.Domain.Tests.Aggregates;

using ECommerce.Domain.Orders;
using ECommerce.Domain.Orders.Events;
using ECommerce.Domain.Orders.Exceptions;
using ECommerce.Domain.Tests.TestHelpers;
using FluentAssertions;
using Xunit;

public sealed class OrderAggregateTests
{
    // ─────────────────────────────────────────────────────────
    // Order.Create のテスト群（4本）
    // ─────────────────────────────────────────────────────────

    [Fact]
    public void Given_ValidCustomerId_When_OrderCreated_Then_StatusIsDraft()
    {
        // Arrange
        var customerId = CustomerId.New();
        var now = DateTimeOffset.UtcNow;

        // Act
        var order = Order.Create(customerId, now);

        // Assert
        order.Status.Should().Be(OrderStatus.Draft);
    }

    [Fact]
    public void Given_ValidCustomerId_When_OrderCreated_Then_TotalAmountIsZero()
    {
        // Arrange
        var customerId = CustomerId.New();

        // Act
        var order = Order.Create(customerId, DateTimeOffset.UtcNow);

        // Assert
        order.TotalAmount.Should().Be(Money.Zero("JPY"));
    }

    [Fact]
    public void Given_ValidCustomerId_When_OrderCreated_Then_LinesAreEmpty()
    {
        // Arrange & Act
        var order = Order.Create(CustomerId.New(), DateTimeOffset.UtcNow);

        // Assert
        order.Lines.Should().BeEmpty();
    }

    [Fact]
    public void Given_ValidCustomerId_When_OrderCreated_Then_OrderCreatedEventIsRaised()
    {
        // Arrange
        var customerId = CustomerId.New();
        var now = DateTimeOffset.UtcNow;

        // Act
        var order = Order.Create(customerId, now);

        // Assert
        order.DomainEvents.Should().ContainSingle()
            .Which.Should().BeOfType<OrderCreatedEvent>()
            .Which.CustomerId.Should().Be(customerId);
    }

    // ─────────────────────────────────────────────────────────
    // AddItem のテスト群（8本）
    // ─────────────────────────────────────────────────────────

    [Fact]
    public void Given_EmptyDraftOrder_When_ItemAdded_Then_LineCountIsOne()
    {
        // Arrange
        var order = OrderBuilder.ANewDraftOrder().Build();
        var (productId, name, price) = ProductBuilder.AProduct().WithPrice(new Money(1000, "JPY")).Build();

        // Act
        order.AddItem(productId, name, price, Quantity.Of(1));

        // Assert
        order.Lines.Should().HaveCount(1);
    }

    [Fact]
    public void Given_DraftOrderWithItem_When_SameProductAdded_Then_QuantityIsAggregated()
    {
        // Arrange
        var (productId, name, price) = ProductBuilder.AProduct().WithPrice(new Money(500, "JPY")).Build();
        var order = OrderBuilder.ANewDraftOrder()
            .WithItem(productId, name, price, Quantity.Of(2))
            .Build();

        // Act
        order.AddItem(productId, name, price, Quantity.Of(3));

        // Assert
        order.Lines.Should().ContainSingle()
            .Which.Quantity.Should().Be(Quantity.Of(5));
    }

    [Fact]
    public void Given_DraftOrderWithItem_When_ItemAdded_Then_TotalAmountIsCorrect()
    {
        // Arrange
        var order = OrderBuilder.ANewDraftOrder().Build();
        var unitPrice = new Money(1500, "JPY");

        // Act
        order.AddItem(ProductId.New(), new ProductName("テスト商品"), unitPrice, Quantity.Of(3));

        // Assert
        order.TotalAmount.Should().Be(new Money(4500, "JPY"));
    }

    [Fact]
    public void Given_DraftOrderWithTwoProducts_When_BothItemsAdded_Then_TotalIsSumOfBoth()
    {
        // Arrange
        var order = OrderBuilder.ANewDraftOrder().Build();

        // Act
        order.AddItem(ProductId.New(), new ProductName("商品A"), new Money(1000, "JPY"), Quantity.Of(2));
        order.AddItem(ProductId.New(), new ProductName("商品B"), new Money(500, "JPY"), Quantity.Of(4));

        // Assert
        order.TotalAmount.Should().Be(new Money(4000, "JPY")); // 1000×2 + 500×4
    }

    [Fact]
    public void Given_DraftOrder_When_ItemWithZeroPriceAdded_Then_ThrowsInvalidProductPriceException()
    {
        // Arrange
        var order = OrderBuilder.ANewDraftOrder().Build();

        // Act
        var act = () => order.AddItem(ProductId.New(), new ProductName("商品"), Money.Zero("JPY"), Quantity.Of(1));

        // Assert
        act.Should().Throw<InvalidProductPriceException>();
    }

    [Fact]
    public void Given_PlacedOrder_When_ItemAdded_Then_ThrowsOrderNotEditableException()
    {
        // Arrange
        var order = OrderBuilder.APlacedOrder().Build();

        // Act
        var act = () => order.AddItem(ProductId.New(), new ProductName("商品"), new Money(1000, "JPY"), Quantity.Of(1));

        // Assert
        act.Should().Throw<OrderNotEditableException>()
            .Which.CurrentStatus.Should().Be(OrderStatus.Placed);
    }

    [Fact]
    public void Given_DraftOrder_When_ItemAdded_Then_OrderItemAddedEventIsRaised()
    {
        // Arrange
        var order = OrderBuilder.ANewDraftOrder().Build();
        var productId = ProductId.New();
        order.ClearDomainEvents();

        // Act
        order.AddItem(productId, new ProductName("商品"), new Money(1000, "JPY"), Quantity.Of(2));

        // Assert
        order.DomainEvents.Should().ContainSingle()
            .Which.Should().BeOfType<OrderItemAddedEvent>()
            .Which.ProductId.Should().Be(productId);
    }

    [Fact]
    public void Given_OrderWithExistingProduct_When_SameProductAddedAgain_Then_LineCountRemainsOne()
    {
        // Arrange
        var productId = ProductId.New();
        var order = OrderBuilder.ANewDraftOrder()
            .WithItem(productId, new ProductName("商品"), new Money(500, "JPY"), Quantity.Of(1))
            .Build();

        // Act
        order.AddItem(productId, new ProductName("商品"), new Money(500, "JPY"), Quantity.Of(2));

        // Assert
        order.Lines.Should().ContainSingle(); // 行数は増えない（同一商品は合算）
    }

    // ─────────────────────────────────────────────────────────
    // RemoveItem のテスト群（3本）
    // ─────────────────────────────────────────────────────────

    [Fact]
    public void Given_OrderWithOneItem_When_ItemRemoved_Then_LinesAreEmpty()
    {
        // Arrange
        var productId = ProductId.New();
        var order = OrderBuilder.ANewDraftOrder()
            .WithItem(productId, new ProductName("商品"), new Money(1000, "JPY"), Quantity.Of(1))
            .Build();

        // Act
        order.RemoveItem(productId);

        // Assert
        order.Lines.Should().BeEmpty();
    }

    [Fact]
    public void Given_OrderWithItem_When_ItemRemoved_Then_TotalAmountIsZero()
    {
        // Arrange
        var productId = ProductId.New();
        var order = OrderBuilder.ANewDraftOrder()
            .WithItem(productId, new ProductName("商品"), new Money(2000, "JPY"), Quantity.Of(3))
            .Build();

        // Act
        order.RemoveItem(productId);

        // Assert
        order.TotalAmount.Should().Be(Money.Zero("JPY"));
    }

    [Fact]
    public void Given_Order_When_NonExistentItemRemoved_Then_ThrowsOrderLineNotFoundException()
    {
        // Arrange
        var order = OrderBuilder.ANewDraftOrder().Build();

        // Act
        var act = () => order.RemoveItem(ProductId.New());

        // Assert
        act.Should().Throw<OrderLineNotFoundException>();
    }

    // ─────────────────────────────────────────────────────────
    // Place のテスト群（4本）
    // ─────────────────────────────────────────────────────────

    [Fact]
    public void Given_DraftOrderWithItemsAndAddress_When_Placed_Then_StatusIsPlaced()
    {
        // Arrange
        var order = OrderBuilder.ANewDraftOrder()
            .WithItem(ProductId.New(), new ProductName("商品"), new Money(1000, "JPY"), Quantity.Of(1))
            .WithShippingAddress(AddressBuilder.AValidAddress().Build())
            .Build();

        // Act
        order.Place(DateTimeOffset.UtcNow);

        // Assert
        order.Status.Should().Be(OrderStatus.Placed);
    }

    [Fact]
    public void Given_DraftOrderWithItemsAndAddress_When_Placed_Then_PlacedAtIsSet()
    {
        // Arrange
        var order = OrderBuilder.ANewDraftOrder()
            .WithItem(ProductId.New(), new ProductName("商品"), new Money(1000, "JPY"), Quantity.Of(1))
            .WithShippingAddress(AddressBuilder.AValidAddress().Build())
            .Build();
        var placedAt = new DateTimeOffset(2026, 7, 11, 10, 0, 0, TimeSpan.Zero);

        // Act
        order.Place(placedAt);

        // Assert
        order.PlacedAt.Should().Be(placedAt);
    }

    [Fact]
    public void Given_DraftOrderWithItemsAndAddress_When_Placed_Then_OrderPlacedEventIsRaised()
    {
        // Arrange
        var order = OrderBuilder.ANewDraftOrder()
            .WithItem(ProductId.New(), new ProductName("商品"), new Money(3000, "JPY"), Quantity.Of(2))
            .WithShippingAddress(AddressBuilder.AValidAddress().Build())
            .Build();
        order.ClearDomainEvents();

        // Act
        order.Place(DateTimeOffset.UtcNow);

        // Assert
        var placedEvent = order.DomainEvents.Should().ContainSingle()
            .Which.Should().BeOfType<OrderPlacedEvent>().Subject;
        placedEvent.TotalAmount.Should().Be(new Money(6000, "JPY"));
    }

    [Fact]
    public void Given_EmptyDraftOrder_When_Placed_Then_ThrowsCannotPlaceEmptyOrderException()
    {
        // Arrange
        var order = OrderBuilder.ANewDraftOrder().Build();

        // Act
        var act = () => order.Place(DateTimeOffset.UtcNow);

        // Assert
        act.Should().Throw<CannotPlaceEmptyOrderException>();
    }

    [Fact]
    public void Given_DraftOrderWithItemsButNoAddress_When_Placed_Then_ThrowsShippingAddressRequiredException()
    {
        // Arrange
        var order = OrderBuilder.ANewDraftOrder()
            .WithItem(ProductId.New(), new ProductName("商品"), new Money(1000, "JPY"), Quantity.Of(1))
            .Build();

        // Act
        var act = () => order.Place(DateTimeOffset.UtcNow);

        // Assert
        act.Should().Throw<ShippingAddressRequiredException>();
    }

    [Fact]
    public void Given_PlacedOrder_When_PlacedAgain_Then_ThrowsInvalidOrderStateTransitionException()
    {
        // Arrange
        var order = OrderBuilder.APlacedOrder().Build();

        // Act
        var act = () => order.Place(DateTimeOffset.UtcNow);

        // Assert
        act.Should().Throw<InvalidOrderStateTransitionException>();
    }

    // ─────────────────────────────────────────────────────────
    // Cancel のテスト群（3本）
    // ─────────────────────────────────────────────────────────

    [Fact]
    public void Given_PlacedOrder_When_Cancelled_Then_StatusIsCancelled()
    {
        // Arrange
        var order = OrderBuilder.APlacedOrder().Build();

        // Act
        order.Cancel("顧客都合");

        // Assert
        order.Status.Should().Be(OrderStatus.Cancelled);
    }

    [Fact]
    public void Given_ShippedOrder_When_Cancelled_Then_ThrowsCannotCancelShippedOrderException()
    {
        // Arrange
        var order = OrderBuilder.AShippedOrder().Build();

        // Act
        var act = () => order.Cancel("キャンセル試行");

        // Assert
        act.Should().Throw<CannotCancelShippedOrderException>()
            .Which.CurrentStatus.Should().Be(OrderStatus.Shipped);
    }

    [Fact]
    public void Given_CancelledOrder_When_CancelledAgain_Then_ThrowsOrderAlreadyCancelledException()
    {
        // Arrange
        var order = OrderBuilder.ACancelledOrder().Build();

        // Act
        var act = () => order.Cancel("再度キャンセル");

        // Assert
        act.Should().Throw<OrderAlreadyCancelledException>();
    }
}
```

### 2.5 Value Objectのテスト（Money・Address）

Value Objectのテストで最も重要なのは「等値性（Equality）のテスト」と「バリデーションのテスト」の2種類です。Value Objectはrecordで実装されている場合が多いため、構造的等値性が自動で保証されますが、カスタム等値比較を実装する場合は特に念入りにテストする必要があります。

```csharp
// tests/Domain.Tests/ValueObjects/MoneyTests.cs
namespace ECommerce.Domain.Tests.ValueObjects;

using FluentAssertions;
using Xunit;

public sealed class MoneyTests
{
    [Fact]
    public void Given_SameAmountAndCurrency_When_Compared_Then_AreEqual()
    {
        // Arrange
        var money1 = new Money(1000, "JPY");
        var money2 = new Money(1000, "JPY");

        // Assert
        money1.Should().Be(money2);
    }

    [Fact]
    public void Given_DifferentAmounts_When_Compared_Then_AreNotEqual()
    {
        var money1 = new Money(1000, "JPY");
        var money2 = new Money(2000, "JPY");
        money1.Should().NotBe(money2);
    }

    [Fact]
    public void Given_DifferentCurrencies_When_Compared_Then_AreNotEqual()
    {
        var jpy = new Money(1000, "JPY");
        var usd = new Money(1000, "USD");
        jpy.Should().NotBe(usd);
    }

    [Theory]
    [InlineData(1000, "JPY", 500, "JPY", 1500, "JPY")]
    [InlineData(100, "USD", 200, "USD", 300, "USD")]
    [InlineData(0, "JPY", 500, "JPY", 500, "JPY")]
    public void Given_TwoMoneyValues_When_Added_Then_SumIsCorrect(
        decimal amount1, string currency1,
        decimal amount2, string currency2,
        decimal expectedAmount, string expectedCurrency)
    {
        var money1 = new Money(amount1, currency1);
        var money2 = new Money(amount2, currency2);

        var result = money1 + money2;

        result.Should().Be(new Money(expectedAmount, expectedCurrency));
    }

    [Fact]
    public void Given_MoneyInJPY_When_AddedWithUSD_Then_ThrowsCurrencyMismatchException()
    {
        var jpy = new Money(1000, "JPY");
        var usd = new Money(100, "USD");

        var act = () => { var _ = jpy + usd; };

        act.Should().Throw<CurrencyMismatchException>();
    }

    [Fact]
    public void Given_Money_When_MultipliedByQuantity_Then_AmountIsMultiplied()
    {
        var price = new Money(500, "JPY");

        var result = price * Quantity.Of(3);

        result.Should().Be(new Money(1500, "JPY"));
    }

    [Theory]
    [InlineData(-1, "JPY")]
    [InlineData(100, "")]
    [InlineData(100, "INVALID_CURRENCY_CODE")]
    public void Given_InvalidParameters_When_MoneyCreated_Then_ThrowsArgumentException(
        decimal amount, string currency)
    {
        var act = () => new Money(amount, currency);
        act.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void Given_ZeroMoney_When_MultipliedByQuantity_Then_RemainsZero()
    {
        var zero = Money.Zero("JPY");

        var result = zero * Quantity.Of(100);

        result.Should().Be(Money.Zero("JPY"));
    }

    [Fact]
    public void Given_Money_When_UsedAsHashSetKey_Then_DuplicatesAreEliminated()
    {
        // Value Object はハッシュセットで正しく重複排除される
        var set = new HashSet<Money>
        {
            new Money(1000, "JPY"),
            new Money(1000, "JPY"), // 重複
            new Money(2000, "JPY")
        };

        set.Should().HaveCount(2);
    }
}
```

### 2.6 Domain Serviceのテスト

```csharp
// tests/Domain.Tests/DomainServices/PricingServiceTests.cs
namespace ECommerce.Domain.Tests.DomainServices;

public sealed class PricingServiceTests
{
    private readonly PricingService _sut = new(new TaxCalculator(taxRate: 0.10m));

    [Fact]
    public void Given_OrderWithItems_When_CalculateTotalWithTax_Then_TaxIsApplied()
    {
        // Arrange
        var order = OrderBuilder.ANewDraftOrder()
            .WithItem(ProductId.New(), new ProductName("商品"), new Money(1000, "JPY"), Quantity.Of(1))
            .Build();

        // Act
        var total = _sut.CalculateTotalWithTax(order);

        // Assert
        total.Should().Be(new Money(1100, "JPY")); // 1000 + 10%税
    }

    [Fact]
    public void Given_OrderWithMultipleItems_When_CalculateTotalWithTax_Then_TaxIsAppliedOnSum()
    {
        // Arrange
        var order = OrderBuilder.ANewDraftOrder()
            .WithItem(ProductId.New(), new ProductName("商品A"), new Money(1000, "JPY"), Quantity.Of(2))
            .WithItem(ProductId.New(), new ProductName("商品B"), new Money(500, "JPY"), Quantity.Of(2))
            .Build();

        // Act
        var total = _sut.CalculateTotalWithTax(order);

        // Assert: (1000×2 + 500×2) × 1.1 = 3300円
        total.Should().Be(new Money(3300, "JPY"));
    }

    [Fact]
    public void Given_EmptyOrder_When_CalculateTotalWithTax_Then_TotalIsZero()
    {
        var order = OrderBuilder.ANewDraftOrder().Build();

        var total = _sut.CalculateTotalWithTax(order);

        total.Should().Be(Money.Zero("JPY"));
    }
}
```

---

## 3. Application Serviceのテスト

### 3.1 何をモックすべきか

Application Serviceのテストでモックするのは**インフラ依存の境界**のみです。Repository・外部APIクライアント・メッセージキュー・時刻プロバイダはモックします。Domain Serviceをモックするのはアンチパターンです。その理由は、Domain Serviceをモックしてしまうと、「ドメインロジックが正しく呼び出されるか」ではなく「モックが正しく設定されているか」をテストすることになり、テストの価値が著しく低下するからです。

```
モックすべき              |  モックすべきでない
─────────────────────────|──────────────────────────
IOrderRepository         |  PricingService（Domain Service）
IPaymentGateway          |  OrderAggregate
IEmailService            |  Value Objects
IDateTimeProvider        |  ビジネスルールの計算処理
IUnitOfWork              |  Domain Eventの発行ロジック
```

### 3.2 CommandHandlerのテスト（PlaceOrderHandler完全実装）

```csharp
// src/Application/Orders/Commands/PlaceOrderCommand.cs
namespace ECommerce.Application.Orders.Commands;

public sealed record PlaceOrderCommand(Guid OrderId) : ICommand;

public sealed class PlaceOrderHandler(
    IOrderRepository orderRepository,
    IDateTimeProvider dateTime,
    IUnitOfWork unitOfWork) : ICommandHandler<PlaceOrderCommand>
{
    public async Task HandleAsync(PlaceOrderCommand command, CancellationToken ct)
    {
        var orderId = new OrderId(command.OrderId);
        var order = await orderRepository.GetByIdAsync(orderId, ct)
            ?? throw new OrderNotFoundException(orderId);

        order.Place(dateTime.UtcNow);

        await unitOfWork.SaveChangesAsync(ct);
    }
}
```

```csharp
// tests/Application.Tests/Commands/PlaceOrderHandlerTests.cs
namespace ECommerce.Application.Tests.Commands;

using NSubstitute;
using NSubstitute.ExceptionExtensions;
using FluentAssertions;
using Xunit;

public sealed class PlaceOrderHandlerTests
{
    private readonly IOrderRepository _orderRepository = Substitute.For<IOrderRepository>();
    private readonly IDateTimeProvider _dateTime = Substitute.For<IDateTimeProvider>();
    private readonly IUnitOfWork _unitOfWork = Substitute.For<IUnitOfWork>();
    private readonly PlaceOrderHandler _sut;

    public PlaceOrderHandlerTests()
    {
        _sut = new PlaceOrderHandler(_orderRepository, _dateTime, _unitOfWork);
        _dateTime.UtcNow.Returns(new DateTimeOffset(2026, 7, 11, 9, 0, 0, TimeSpan.Zero));
    }

    [Fact]
    public async Task Given_ValidOrder_When_PlaceOrderCommandHandled_Then_OrderStatusBecomesPlaced()
    {
        // Arrange
        var order = OrderBuilder.ANewDraftOrder()
            .WithItem(ProductId.New(), new ProductName("商品"), new Money(1000, "JPY"), Quantity.Of(1))
            .WithShippingAddress(AddressBuilder.AValidAddress().Build())
            .Build();
        _orderRepository.GetByIdAsync(order.Id, Arg.Any<CancellationToken>()).Returns(order);
        var command = new PlaceOrderCommand(order.Id.Value);

        // Act
        await _sut.HandleAsync(command, CancellationToken.None);

        // Assert
        order.Status.Should().Be(OrderStatus.Placed);
    }

    [Fact]
    public async Task Given_ValidOrder_When_PlaceOrderCommandHandled_Then_UnitOfWorkSaveChangesIsCalled()
    {
        // Arrange
        var order = OrderBuilder.ANewDraftOrder()
            .WithItem(ProductId.New(), new ProductName("商品"), new Money(1000, "JPY"), Quantity.Of(1))
            .WithShippingAddress(AddressBuilder.AValidAddress().Build())
            .Build();
        _orderRepository.GetByIdAsync(order.Id, Arg.Any<CancellationToken>()).Returns(order);

        // Act
        await _sut.HandleAsync(new PlaceOrderCommand(order.Id.Value), CancellationToken.None);

        // Assert: SaveChanges が正確に1回呼ばれたことを確認（永続化の副作用）
        await _unitOfWork.Received(1).SaveChangesAsync(Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task Given_NonExistentOrder_When_PlaceOrderCommandHandled_Then_ThrowsOrderNotFoundException()
    {
        // Arrange
        var nonExistentOrderId = Guid.NewGuid();
        _orderRepository.GetByIdAsync(Arg.Any<OrderId>(), Arg.Any<CancellationToken>())
            .Returns((Order?)null);

        // Act
        var act = () => _sut.HandleAsync(new PlaceOrderCommand(nonExistentOrderId), CancellationToken.None);

        // Assert
        await act.Should().ThrowAsync<OrderNotFoundException>();
    }

    [Fact]
    public async Task Given_NonExistentOrder_When_PlaceOrderCommandHandled_Then_SaveChangesIsNotCalled()
    {
        // Arrange
        _orderRepository.GetByIdAsync(Arg.Any<OrderId>(), Arg.Any<CancellationToken>())
            .Returns((Order?)null);

        // Act
        try { await _sut.HandleAsync(new PlaceOrderCommand(Guid.NewGuid()), CancellationToken.None); }
        catch { /* 例外は期待内 */ }

        // Assert: 注文が見つからない場合はDBへの書き込みは起きない
        await _unitOfWork.DidNotReceive().SaveChangesAsync(Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task Given_EmptyDraftOrder_When_PlaceOrderCommandHandled_Then_ThrowsCannotPlaceEmptyOrderException()
    {
        // Arrange
        var order = OrderBuilder.ANewDraftOrder().Build(); // アイテムなし
        _orderRepository.GetByIdAsync(order.Id, Arg.Any<CancellationToken>()).Returns(order);

        // Act
        var act = () => _sut.HandleAsync(new PlaceOrderCommand(order.Id.Value), CancellationToken.None);

        // Assert
        await act.Should().ThrowAsync<CannotPlaceEmptyOrderException>();
        await _unitOfWork.DidNotReceive().SaveChangesAsync(Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task Given_ValidOrder_When_PlaceOrderCommandHandled_Then_PlacedAtMatchesDateTimeProvider()
    {
        // Arrange
        var expectedPlacedAt = new DateTimeOffset(2026, 7, 11, 15, 30, 0, TimeSpan.Zero);
        _dateTime.UtcNow.Returns(expectedPlacedAt);

        var order = OrderBuilder.ANewDraftOrder()
            .WithItem(ProductId.New(), new ProductName("商品"), new Money(1000, "JPY"), Quantity.Of(1))
            .WithShippingAddress(AddressBuilder.AValidAddress().Build())
            .Build();
        _orderRepository.GetByIdAsync(order.Id, Arg.Any<CancellationToken>()).Returns(order);

        // Act
        await _sut.HandleAsync(new PlaceOrderCommand(order.Id.Value), CancellationToken.None);

        // Assert: 時刻はIDateTimeProviderから取得されること（固定可能・テスタブル）
        order.PlacedAt.Should().Be(expectedPlacedAt);
    }

    [Fact]
    public async Task Given_RepositoryThrowsException_When_HandleAsync_Then_ExceptionIsPropagatedAndSaveChangesNotCalled()
    {
        // Arrange
        _orderRepository.GetByIdAsync(Arg.Any<OrderId>(), Arg.Any<CancellationToken>())
            .ThrowsAsync(new RepositoryException("DB接続エラー"));

        // Act
        var act = () => _sut.HandleAsync(new PlaceOrderCommand(Guid.NewGuid()), CancellationToken.None);

        // Assert
        await act.Should().ThrowAsync<RepositoryException>();
        await _unitOfWork.DidNotReceive().SaveChangesAsync(Arg.Any<CancellationToken>());
    }
}
```

### 3.3 QueryHandlerのテスト

QueryHandlerはReadモデル（DTO）を返すだけのため、テストは「正しいパラメータでRepositoryが呼ばれること」と「返り値がそのままマッピングされること」の2点を確認します。

```csharp
// tests/Application.Tests/Queries/GetOrderQueryHandlerTests.cs
namespace ECommerce.Application.Tests.Queries;

public sealed class GetOrderQueryHandlerTests
{
    private readonly IOrderReadRepository _readRepository = Substitute.For<IOrderReadRepository>();
    private readonly GetOrderQueryHandler _sut;

    public GetOrderQueryHandlerTests()
    {
        _sut = new GetOrderQueryHandler(_readRepository);
    }

    [Fact]
    public async Task Given_ExistingOrder_When_QueryHandled_Then_ReturnsOrderDto()
    {
        // Arrange
        var orderId = Guid.NewGuid();
        var expectedDto = new OrderDto(orderId, "DRAFT", 3000m, []);
        _readRepository.FindByIdAsync(new OrderId(orderId), Arg.Any<CancellationToken>())
            .Returns(expectedDto);

        // Act
        var result = await _sut.HandleAsync(new GetOrderQuery(orderId), CancellationToken.None);

        // Assert
        result.Should().NotBeNull();
        result!.OrderId.Should().Be(orderId);
        result.Status.Should().Be("DRAFT");
    }

    [Fact]
    public async Task Given_NonExistentOrder_When_QueryHandled_Then_ReturnsNull()
    {
        // Arrange
        _readRepository.FindByIdAsync(Arg.Any<OrderId>(), Arg.Any<CancellationToken>())
            .Returns((OrderDto?)null);

        // Act
        var result = await _sut.HandleAsync(new GetOrderQuery(Guid.NewGuid()), CancellationToken.None);

        // Assert
        result.Should().BeNull();
    }

    [Fact]
    public async Task Given_ValidQuery_When_Handled_Then_RepositoryIsCalledWithCorrectOrderId()
    {
        // Arrange
        var orderId = Guid.NewGuid();
        _readRepository.FindByIdAsync(Arg.Any<OrderId>(), Arg.Any<CancellationToken>())
            .Returns((OrderDto?)null);

        // Act
        await _sut.HandleAsync(new GetOrderQuery(orderId), CancellationToken.None);

        // Assert: 正しいIDでRepositoryが呼び出されていることを確認
        await _readRepository.Received(1)
            .FindByIdAsync(new OrderId(orderId), Arg.Any<CancellationToken>());
    }
}
```

---

## 4. Repositoryの統合テスト

### 4.1 TestContainersの思想

統合テストにインメモリDBを使うと「本番で動かない」バグが発生します。例えば以下のケースがあります。

- PostgreSQLの楽観的ロック（`xmin`列やRowVersion）はインメモリDBには存在しない
- 文字列のcollation差異によるソート順の違い
- トランザクション分離レベルの動作の違い（PostgreSQL vs SQLite）
- JSONBカラム・配列型など PostgreSQL固有型のマッピング

TestContainersはDocker上に本物のPostgreSQLコンテナを起動し、テスト終了後に自動で破棄します。これにより「本番と同じDB」で統合テストが実行され、環境差異によるバグを事前に検出できます。

### 4.2 統合テストの設定クラス

```csharp
// tests/Infrastructure.Tests/Fixtures/PostgreSqlTestFixture.cs
namespace ECommerce.Infrastructure.Tests.Fixtures;

using Testcontainers.PostgreSql;
using Microsoft.EntityFrameworkCore;

/// <summary>
/// xUnit の IAsyncLifetime を実装することで、テストクラスの初期化・後片付けを
/// async で行えるようにします。コンテナの起動はTestごとに行うとコストが高いため、
/// IClassFixture で共有するパターンが有効です。
/// </summary>
public sealed class PostgreSqlTestFixture : IAsyncLifetime
{
    private readonly PostgreSqlContainer _postgres = new PostgreSqlBuilder()
        .WithImage("postgres:16-alpine")
        .WithDatabase("ecommerce_test")
        .WithUsername("test_user")
        .WithPassword("test_password")
        .Build();

    public string ConnectionString => _postgres.GetConnectionString();

    public async Task InitializeAsync()
    {
        await _postgres.StartAsync();

        // マイグレーション適用
        var options = CreateDbContextOptions();
        await using var context = new ECommerceDbContext(options);
        await context.Database.MigrateAsync();
    }

    public async Task DisposeAsync()
    {
        await _postgres.DisposeAsync();
    }

    public DbContextOptions<ECommerceDbContext> CreateDbContextOptions() =>
        new DbContextOptionsBuilder<ECommerceDbContext>()
            .UseNpgsql(ConnectionString)
            .Options;
}
```

### 4.3 OrderRepositoryの統合テスト完全実装

```csharp
// tests/Infrastructure.Tests/Repositories/OrderRepositoryIntegrationTests.cs
namespace ECommerce.Infrastructure.Tests.Repositories;

using ECommerce.Infrastructure.Tests.Fixtures;
using Xunit;
using FluentAssertions;
using Microsoft.EntityFrameworkCore;

[Collection("PostgreSQL")]
public sealed class OrderRepositoryIntegrationTests : IAsyncLifetime
{
    private readonly PostgreSqlTestFixture _fixture;
    private ECommerceDbContext _context = null!;
    private OrderRepository _sut = null!;

    public OrderRepositoryIntegrationTests(PostgreSqlTestFixture fixture)
    {
        _fixture = fixture;
    }

    public async Task InitializeAsync()
    {
        // 各テスト前に新しいDbContextを作成（テスト間の独立性を保証）
        _context = new ECommerceDbContext(_fixture.CreateDbContextOptions());
        _sut = new OrderRepository(_context);

        // 各テスト前にテーブルをクリア
        await _context.Database.ExecuteSqlRawAsync("TRUNCATE TABLE orders CASCADE");
    }

    public async Task DisposeAsync()
    {
        await _context.DisposeAsync();
    }

    // ─────────────────────────────────────────────────────────
    // Save / FindById テスト
    // ─────────────────────────────────────────────────────────

    [Fact]
    public async Task Given_NewOrder_When_Saved_Then_CanBeRetrievedById()
    {
        // Arrange
        var order = Order.Create(CustomerId.New(), DateTimeOffset.UtcNow);

        // Act
        await _sut.AddAsync(order, CancellationToken.None);
        await _context.SaveChangesAsync();

        _context.ChangeTracker.Clear(); // キャッシュをクリア（真のDB往復を確認）
        var retrieved = await _sut.GetByIdAsync(order.Id, CancellationToken.None);

        // Assert
        retrieved.Should().NotBeNull();
        retrieved!.Id.Should().Be(order.Id);
        retrieved.Status.Should().Be(OrderStatus.Draft);
    }

    [Fact]
    public async Task Given_OrderWithLines_When_Saved_Then_LinesArePersisted()
    {
        // Arrange
        var order = Order.Create(CustomerId.New(), DateTimeOffset.UtcNow);
        var productId = ProductId.New();
        order.AddItem(productId, new ProductName("テスト商品"), new Money(2000, "JPY"), Quantity.Of(3));

        // Act
        await _sut.AddAsync(order, CancellationToken.None);
        await _context.SaveChangesAsync();
        _context.ChangeTracker.Clear();

        var retrieved = await _sut.GetByIdAsync(order.Id, CancellationToken.None);

        // Assert
        retrieved!.Lines.Should().HaveCount(1);
        retrieved.Lines[0].ProductId.Should().Be(productId);
        retrieved.Lines[0].Quantity.Should().Be(Quantity.Of(3));
        retrieved.TotalAmount.Should().Be(new Money(6000, "JPY"));
    }

    [Fact]
    public async Task Given_NonExistentId_When_GetByIdAsync_Then_ReturnsNull()
    {
        // Act
        var result = await _sut.GetByIdAsync(OrderId.New(), CancellationToken.None);

        // Assert
        result.Should().BeNull();
    }

    // ─────────────────────────────────────────────────────────
    // 楽観的ロック競合テスト
    // ─────────────────────────────────────────────────────────

    [Fact]
    public async Task Given_TwoConcurrentUpdates_When_SecondCommits_Then_ThrowsOptimisticConcurrencyException()
    {
        // Arrange: 注文を作成してDBに保存
        var order = Order.Create(CustomerId.New(), DateTimeOffset.UtcNow);
        await _sut.AddAsync(order, CancellationToken.None);
        await _context.SaveChangesAsync();
        var orderId = order.Id;

        // Arrange: 2つの独立したDbContextで同じ注文を取得（同時並行を模擬）
        var options = _fixture.CreateDbContextOptions();
        await using var context1 = new ECommerceDbContext(options);
        await using var context2 = new ECommerceDbContext(options);

        var order1 = await new OrderRepository(context1).GetByIdAsync(orderId, CancellationToken.None);
        var order2 = await new OrderRepository(context2).GetByIdAsync(orderId, CancellationToken.None);

        // Act: context1 が先にキャンセル（コミット成功）
        order1!.Cancel("コンテキスト1からキャンセル");
        await context1.SaveChangesAsync();

        // Act: context2 も同じ注文をキャンセルしようとする
        order2!.Cancel("コンテキスト2からキャンセル");
        var act = () => context2.SaveChangesAsync();

        // Assert: 楽観的ロック例外が発生する（インメモリDBでは検出できない）
        await act.Should().ThrowAsync<DbUpdateConcurrencyException>(
            because: "同一レコードを2つのコンテキストが同時に更新しようとした場合、楽観的ロックで弾かれるべき");
    }

    // ─────────────────────────────────────────────────────────
    // トランザクションテスト
    // ─────────────────────────────────────────────────────────

    [Fact]
    public async Task Given_ExceptionDuringTransaction_When_SaveAttempted_Then_NothingIsPersisted()
    {
        // Arrange
        var createdOrderId = OrderId.New();

        // Act: トランザクション内で例外を発生させてロールバック
        await using var transaction = await _context.Database.BeginTransactionAsync();
        try
        {
            var order = Order.Create(CustomerId.New(), DateTimeOffset.UtcNow);
            await _sut.AddAsync(order, CancellationToken.None);
            await _context.SaveChangesAsync();

            // 意図的に例外を発生させてロールバックを確認
            throw new InvalidOperationException("ロールバック確認用の例外");
        }
        catch (InvalidOperationException)
        {
            await transaction.RollbackAsync();
        }

        // Assert: ロールバックにより何も保存されていない
        _context.ChangeTracker.Clear();
        var retrieved = await _sut.GetByIdAsync(createdOrderId, CancellationToken.None);
        retrieved.Should().BeNull();
    }

    [Fact]
    public async Task Given_MultipleOrders_When_FindByCustomerId_Then_ReturnsOnlyMatchingOrders()
    {
        // Arrange
        var targetCustomerId = CustomerId.New();
        var otherCustomerId = CustomerId.New();

        var targetOrder1 = Order.Create(targetCustomerId, DateTimeOffset.UtcNow);
        var targetOrder2 = Order.Create(targetCustomerId, DateTimeOffset.UtcNow);
        var otherOrder = Order.Create(otherCustomerId, DateTimeOffset.UtcNow);

        await _sut.AddAsync(targetOrder1, CancellationToken.None);
        await _sut.AddAsync(targetOrder2, CancellationToken.None);
        await _sut.AddAsync(otherOrder, CancellationToken.None);
        await _context.SaveChangesAsync();
        _context.ChangeTracker.Clear();

        // Act
        var results = await _sut.FindByCustomerIdAsync(targetCustomerId, CancellationToken.None);

        // Assert
        results.Should().HaveCount(2);
        results.Should().AllSatisfy(o => o.CustomerId.Should().Be(targetCustomerId));
    }
}
```

---

## 5. BDD（Behavior-Driven Development）

### 5.1 BDDの目的

BDDはテストをビジネスシナリオとして記述することで、エンジニアとビジネスサイドの共通言語を作ります。DDDのユビキタス言語をそのままテスト名に使えるため、特に相性が良いアプローチです。BDDのテストを読めば、そのシステムがどのようなビジネスシナリオをサポートしているかが一目で分かります。

### 5.2 xUnitのTheory + InlineDataで複数シナリオ

```csharp
// tests/Domain.Tests/BDD/OrderPlacementScenarios.cs
namespace ECommerce.Domain.Tests.BDD;

/// <summary>
/// ビジネスシナリオ: 注文の確定
/// ステークホルダー: 購買担当者
/// 目的: 商品をカートに入れた後、配送先を設定すれば注文を確定できる
/// このテストクラスはドメインエキスパートが読んでも理解できることを意識している
/// </summary>
public sealed class OrderPlacementScenarios
{
    [Theory]
    [InlineData(1, 1000, 1000)]     // 1点購入
    [InlineData(3, 500, 1500)]      // 3点購入（単価×数量）
    [InlineData(10, 100, 1000)]     // まとめ買い
    public void Given_DraftOrderWithItems_When_CustomerConfirmsOrder_Then_TotalAmountIsUnitPriceTimesQuantity(
        int quantity, decimal unitPriceAmount, decimal expectedTotalAmount)
    {
        // Given: 顧客がカートに商品を入れた
        var order = OrderBuilder.ANewDraftOrder().Build();
        order.AddItem(
            ProductId.New(),
            new ProductName("テスト商品"),
            new Money(unitPriceAmount, "JPY"),
            Quantity.Of(quantity));
        order.SetShippingAddress(AddressBuilder.AValidAddress().Build());

        // When: 注文を確定する
        order.Place(DateTimeOffset.UtcNow);

        // Then: 合計金額は数量×単価
        order.TotalAmount.Should().Be(new Money(expectedTotalAmount, "JPY"));
    }

    public static IEnumerable<object[]> CancellableStatuses =>
    [
        [OrderStatus.Draft, "ドラフト中のキャンセル"],
        [OrderStatus.Placed, "注文確定後のキャンセル"],
        [OrderStatus.Processing, "処理中のキャンセル"],
    ];

    [Theory]
    [MemberData(nameof(CancellableStatuses))]
    public void Given_OrderInCancellableStatus_When_CustomerCancels_Then_OrderStatusIsCancelled(
        OrderStatus initialStatus, string scenario)
    {
        // Given: 対象ステータスの注文
        var order = OrderBuilder.AnOrderWithStatus(initialStatus).Build();

        // When: 顧客がキャンセルする
        order.Cancel($"テストシナリオ: {scenario}");

        // Then: キャンセル済みになる
        order.Status.Should().Be(OrderStatus.Cancelled,
            because: $"シナリオ「{scenario}」ではキャンセル可能なはず");
    }

    public static IEnumerable<object[]> NonCancellableStatuses =>
    [
        [OrderStatus.Shipped],
        [OrderStatus.Delivered],
        [OrderStatus.Cancelled],
    ];

    [Theory]
    [MemberData(nameof(NonCancellableStatuses))]
    public void Given_OrderInNonCancellableStatus_When_CancelAttempted_Then_BusinessRuleViolationIsThrown(
        OrderStatus nonCancellableStatus)
    {
        // Given: キャンセル不可ステータスの注文
        var order = OrderBuilder.AnOrderWithStatus(nonCancellableStatus).Build();

        // When/Then: キャンセルしようとするとビジネスルール違反
        var act = () => order.Cancel("キャンセル試行");
        act.Should().Throw<Exception>(
            because: $"ステータス {nonCancellableStatus} はビジネスルール上キャンセルできない");
    }

    /// <summary>
    /// シナリオ: 同一商品を複数回追加した場合は数量が合算される
    /// ユーザーストーリー: 顧客がカート画面で同じ商品を複数回追加しても、行数が増えず正しく合算されること
    /// </summary>
    [Fact]
    public void Given_CartWithExistingProduct_When_CustomerAddsSameProductAgain_Then_QuantityMergesNotDuplicatesLine()
    {
        // Given: 顧客が商品Aを2個カートに入れた
        var productId = ProductId.New();
        var order = OrderBuilder.ANewDraftOrder().Build();
        order.AddItem(productId, new ProductName("商品A"), new Money(300, "JPY"), Quantity.Of(2));

        // When: 同じ商品Aをさらに3個追加した
        order.AddItem(productId, new ProductName("商品A"), new Money(300, "JPY"), Quantity.Of(3));

        // Then: カートのラインは1行のまま、数量は合算5個
        order.Lines.Should().ContainSingle(
            because: "同一商品の重複ラインはユーザー体験を損なう");
        order.Lines[0].Quantity.Should().Be(Quantity.Of(5));
        order.TotalAmount.Should().Be(new Money(1500, "JPY")); // 300 × 5
    }
}
```

### 5.3 SpecFlowを使ったBDD（参考実装）

SpecFlowを使うと、Gherkin記法（自然言語に近い記述）でシナリオを書くことができ、非エンジニアのステークホルダーでもレビューに参加できます。

```gherkin
# features/OrderPlacement.feature
Feature: 注文の確定
  ビジネス価値: 顧客が商品を正しく購入できること

  Background:
    Given 顧客がログインしている

  Scenario: 商品を1つカートに入れて注文を確定する
    Given 注文がドラフト状態である
    And 商品「テスト商品」を単価1000円で1個カートに入れた
    And 配送先住所を設定した
    When 注文を確定する
    Then 注文ステータスは「Placed」である
    And 合計金額は1000円である

  Scenario Outline: 複数個注文の合計金額確認
    Given 注文がドラフト状態である
    And 商品を単価<unit_price>円で<quantity>個カートに入れた
    And 配送先住所を設定した
    When 注文を確定する
    Then 合計金額は<total>円である

    Examples:
      | unit_price | quantity | total |
      | 1000       | 1        | 1000  |
      | 500        | 3        | 1500  |
      | 100        | 10       | 1000  |
```

```csharp
// features/steps/OrderPlacementSteps.cs
namespace ECommerce.Domain.Tests.BDD.Steps;

[Binding]
public sealed class OrderPlacementSteps(ScenarioContext context)
{
    [Given(@"注文がドラフト状態である")]
    public void GivenOrderIsDraft()
    {
        var order = Order.Create(CustomerId.New(), DateTimeOffset.UtcNow);
        context["order"] = order;
    }

    [Given(@"商品「(.+)」を単価(\d+)円で(\d+)個カートに入れた")]
    public void GivenItemAddedToCart(string productName, decimal unitPrice, int quantity)
    {
        var order = (Order)context["order"];
        order.AddItem(
            ProductId.New(),
            new ProductName(productName),
            new Money(unitPrice, "JPY"),
            Quantity.Of(quantity));
    }

    [Given(@"配送先住所を設定した")]
    public void GivenShippingAddressSet()
    {
        var order = (Order)context["order"];
        order.SetShippingAddress(AddressBuilder.AValidAddress().Build());
    }

    [When(@"注文を確定する")]
    public void WhenOrderPlaced()
    {
        var order = (Order)context["order"];
        order.Place(DateTimeOffset.UtcNow);
    }

    [Then(@"注文ステータスは「(.+)」である")]
    public void ThenOrderStatusIs(string expectedStatus)
    {
        var order = (Order)context["order"];
        var expected = Enum.Parse<OrderStatus>(expectedStatus);
        order.Status.Should().Be(expected);
    }

    [Then(@"合計金額は(\d+)円である")]
    public void ThenTotalAmountIs(decimal expectedAmount)
    {
        var order = (Order)context["order"];
        order.TotalAmount.Should().Be(new Money(expectedAmount, "JPY"));
    }
}
```

---

## 6. アンチパターン: テストの悪例

### 6.1 実装詳細に依存したテスト（Before/After）

**Before: 内部フィールドをリフレクションで確認している**

```csharp
// NG: private フィールドへのリフレクション（実装詳細への依存）
[Fact]
public void Bad_Test_InspectingPrivateField()
{
    var order = Order.Create(CustomerId.New(), DateTimeOffset.UtcNow);
    order.AddItem(ProductId.New(), new ProductName("商品"), new Money(1000, "JPY"), Quantity.Of(1));

    // リフレクションで内部リストを直接確認 → 内部実装が変わればテストが壊れる
    var linesField = typeof(Order)
        .GetField("_lines", BindingFlags.NonPublic | BindingFlags.Instance);
    var lines = (List<OrderLine>)linesField!.GetValue(order)!;

    lines.Count.Should().Be(1);
    // 問題: List<T> を Set<T> に変えただけでテストが壊れる
    // 問題: テストがドメインの意図ではなく実装を縛っている
}
```

**After: 公開APIのみを使う**

```csharp
// OK: 公開プロパティ Lines を通して確認
[Fact]
public void Given_EmptyOrder_When_ItemAdded_Then_OrderContainsOneLineItem()
{
    var order = Order.Create(CustomerId.New(), DateTimeOffset.UtcNow);
    order.AddItem(ProductId.New(), new ProductName("商品"), new Money(1000, "JPY"), Quantity.Of(1));

    // 公開APIのみを使うことで、内部実装の変更に影響されない
    order.Lines.Should().HaveCount(1);
}
```

### 6.2 モックを使いすぎたテスト（Before/After）

**Before: ドメインロジックをモックしている**

```csharp
// NG: PricingService（Domain Service）をモック
[Fact]
public async Task Bad_PlaceOrder_MockingDomainService()
{
    // Domain Service をモックしている → ドメインロジックを検証していない
    var pricingService = Substitute.For<IPricingService>();
    pricingService.CalculateTotalWithTax(Arg.Any<Order>()).Returns(new Money(1100, "JPY"));
    // ↑ このモックが「税率10%で計算される」という事実を証明していない
    //   モックの設定が正しいかどうかしか証明していない
    //   本番のPricingServiceにバグがあってもこのテストは通る

    var handler = new PlaceOrderHandler(orderRepository, pricingService, unitOfWork);
    await handler.HandleAsync(command, CancellationToken.None);
    // テストが通っても「実際の税計算が正しい」は証明されていない
}
```

**After: 本物のDomain Serviceを使う**

```csharp
// OK: Domain Service は本物を使い、Repository だけモック
[Fact]
public async Task Given_ValidOrder_When_Placed_Then_TotalAmountIsCalculatedByRealDomainLogic()
{
    // Domain Service は本物を使う → ドメインロジックが正しく呼び出されることを検証
    var pricingService = new PricingService(new TaxCalculator(taxRate: 0.10m));
    var orderRepository = Substitute.For<IOrderRepository>(); // Repository はモック（DB不要）
    var unitOfWork = Substitute.For<IUnitOfWork>();

    var order = OrderBuilder.ANewDraftOrder()
        .WithItem(ProductId.New(), new ProductName("商品"), new Money(1000, "JPY"), Quantity.Of(1))
        .WithShippingAddress(AddressBuilder.AValidAddress().Build())
        .Build();
    orderRepository.GetByIdAsync(order.Id, Arg.Any<CancellationToken>()).Returns(order);

    var handler = new PlaceOrderHandler(orderRepository, pricingService, unitOfWork);
    await handler.HandleAsync(new PlaceOrderCommand(order.Id.Value), CancellationToken.None);

    // 本物の税計算ロジックが動いた結果を確認
    order.TotalAmount.Should().Be(new Money(1100, "JPY")); // 1000円 + 10%税
}
```

### 6.3 テストがドメイン語を使っていない（Before/After）

**Before: 技術語で書かれたテスト名**

```csharp
// NG: 技術語のみ → 何のビジネスルールを検証しているか分からない
[Fact]
public void Test_SetStatusField_To_Placed_After_CallPlaceMethod_When_LinesListNotEmpty()
{
    // テスト名を読んでも「なぜこのテストが必要か」が分からない
}

[Fact]
public void Test_AddItem_IncrementsTotalAmount()
{
    // "IncrementsTotalAmount" は実装語。ビジネス的に何が起きるかが分からない
}
```

**After: ビジネス語で書かれたテスト名**

```csharp
// OK: ビジネス用語でシナリオを表現 → ドキュメントとして機能する
[Fact]
public void Given_DraftOrderWithItemsAndShippingAddress_When_CustomerConfirmsOrder_Then_OrderStatusBecomesPlaced()
{
    // テスト名だけで「誰が・何のために・どういう結果を期待するか」が分かる
}

[Fact]
public void Given_CartWithProduct_When_ProductAddedToCart_Then_PurchaseTotalReflectsUnitPriceTimesQuantity()
{
    // ビジネス視点でテストを説明している
}
```

### 6.4 Assertionが不十分なテスト（Before/After）

**Before: 例外が出ないことしか確認していない**

```csharp
// NG: 副作用をまったく確認していない → 例外が出なければ何でもOKという誤った安心感
[Fact]
public async Task PlaceOrder_DoesNotThrow()
{
    var handler = BuildHandler();
    await handler.HandleAsync(new PlaceOrderCommand(validOrderId), CancellationToken.None);
    // ← ここで何も確認していない！
    // 注文ステータスが変わらなくても、SaveChangesが呼ばれなくても、このテストはGREENになる
}
```

**After: 状態変化・ドメインイベント・副作用を全て確認**

```csharp
// OK: ステータス変化 + ドメインイベント + 永続化呼び出し を漏れなく確認
[Fact]
public async Task Given_ValidOrder_When_PlaceOrderHandled_Then_AllExpectedSideEffectsOccur()
{
    // Arrange...
    var order = SetupValidOrder();

    // Act
    await _sut.HandleAsync(new PlaceOrderCommand(order.Id.Value), CancellationToken.None);

    // Assert 1: ドメイン状態の変化
    order.Status.Should().Be(OrderStatus.Placed);
    order.PlacedAt.Should().NotBeNull();

    // Assert 2: ドメインイベントの発行
    order.DomainEvents.Should().ContainSingle(e => e is OrderPlacedEvent,
        because: "注文確定時は OrderPlacedEvent が発行されなければならない");

    // Assert 3: インフラへの副作用（永続化）
    await _unitOfWork.Received(1).SaveChangesAsync(Arg.Any<CancellationToken>());
}
```

---

## 7. テスト容易性のための設計

### 7.1 Test Builderパターン（OrderBuilder完全実装）

Test Builderは「テストデータの組み立てをビジネス語で表現する」パターンです。これにより、テストコードが「何を前提とするか」を宣言的に記述でき、テストの意図が明確になります。また、ドメインモデルの構造が変わったときに修正箇所をBuilderに集約できるため、テストのメンテナンスコストを大幅に削減できます。

```csharp
// tests/TestHelpers/OrderBuilder.cs
namespace ECommerce.Domain.Tests.TestHelpers;

/// <summary>
/// テスト用の Order 組み立てヘルパー。
/// ビジネスシナリオ別のファクトリメソッドを提供することで、
/// テストコードが「前提条件」を宣言的に記述できるようにする。
/// </summary>
public sealed class OrderBuilder
{
    private CustomerId _customerId = CustomerId.New();
    private DateTimeOffset _createdAt = DateTimeOffset.UtcNow;
    private readonly List<(ProductId, ProductName, Money, Quantity)> _items = [];
    private Address? _shippingAddress;
    private OrderStatus? _forcedStatus;

    // ─── ビジネスシナリオ別ファクトリメソッド ───

    /// <summary>新規ドラフト注文（アイテムなし）</summary>
    public static OrderBuilder ANewDraftOrder() => new();

    /// <summary>注文確定済み（アイテム + 配送先 設定済み）</summary>
    public static OrderBuilder APlacedOrder() => new OrderBuilder()
        .WithItem(ProductId.New(), new ProductName("標準商品"), new Money(1000, "JPY"), Quantity.Of(1))
        .WithShippingAddress(AddressBuilder.AValidAddress().Build())
        .ThatWillBePlaced();

    /// <summary>発送済み注文</summary>
    public static OrderBuilder AShippedOrder() => APlacedOrder()
        .WithForcedStatus(OrderStatus.Shipped);

    /// <summary>配送完了注文</summary>
    public static OrderBuilder ADeliveredOrder() => APlacedOrder()
        .WithForcedStatus(OrderStatus.Delivered);

    /// <summary>キャンセル済み注文</summary>
    public static OrderBuilder ACancelledOrder() => APlacedOrder()
        .WithForcedStatus(OrderStatus.Cancelled);

    /// <summary>任意のステータスの注文（ステータス遷移テスト用）</summary>
    public static OrderBuilder AnOrderWithStatus(OrderStatus status) => status switch
    {
        OrderStatus.Draft      => ANewDraftOrder(),
        OrderStatus.Placed     => APlacedOrder(),
        OrderStatus.Processing => APlacedOrder().WithForcedStatus(OrderStatus.Processing),
        OrderStatus.Shipped    => AShippedOrder(),
        OrderStatus.Delivered  => ADeliveredOrder(),
        OrderStatus.Cancelled  => ACancelledOrder(),
        _ => ANewDraftOrder().WithForcedStatus(status)
    };

    // ─── Withメソッド群 ───

    public OrderBuilder ForCustomer(CustomerId customerId)
    {
        _customerId = customerId;
        return this;
    }

    public OrderBuilder CreatedAt(DateTimeOffset createdAt)
    {
        _createdAt = createdAt;
        return this;
    }

    public OrderBuilder WithItem(ProductId productId, ProductName name, Money price, Quantity quantity)
    {
        _items.Add((productId, name, price, quantity));
        return this;
    }

    public OrderBuilder WithShippingAddress(Address address)
    {
        _shippingAddress = address;
        return this;
    }

    private OrderBuilder ThatWillBePlaced()
    {
        _forcedStatus = OrderStatus.Placed;
        return this;
    }

    private OrderBuilder WithForcedStatus(OrderStatus status)
    {
        _forcedStatus = status;
        return this;
    }

    // ─── Build ───

    public Order Build()
    {
        var order = Order.Create(_customerId, _createdAt);

        foreach (var (productId, name, price, quantity) in _items)
            order.AddItem(productId, name, price, quantity);

        if (_shippingAddress is not null)
            order.SetShippingAddress(_shippingAddress);

        if (_forcedStatus.HasValue)
            ForceStatus(order, _forcedStatus.Value);

        return order;
    }

    /// <summary>
    /// テスト専用: ドメインロジックを通さずにステータスを強制設定する。
    /// 特定ステータスを「前提条件」として設定したい場合のみ使用すること。
    /// 本番コードでは絶対に使用してはならない。
    /// </summary>
    private static void ForceStatus(Order order, OrderStatus targetStatus)
    {
        typeof(Order)
            .GetProperty(nameof(Order.Status))!
            .SetValue(order, targetStatus);
    }
}
```

```csharp
// tests/TestHelpers/AddressBuilder.cs
namespace ECommerce.Domain.Tests.TestHelpers;

public sealed class AddressBuilder
{
    private string _postalCode = "112-0012";
    private string _prefecture = "東京都";
    private string _city = "文京区";
    private string _street = "大塚1-1-1";
    private string _building = "";

    public static AddressBuilder AValidAddress() => new();

    public static AddressBuilder AnInvalidAddressWithoutPostalCode() =>
        new AddressBuilder { _postalCode = "" };

    public AddressBuilder WithPostalCode(string postalCode)
    {
        _postalCode = postalCode;
        return this;
    }

    public AddressBuilder InCity(string city)
    {
        _city = city;
        return this;
    }

    public Address Build() => new(
        PostalCode: new PostalCode(_postalCode),
        Prefecture: _prefecture,
        City: _city,
        Street: _street,
        Building: _building);
}
```

```csharp
// tests/TestHelpers/ProductBuilder.cs
namespace ECommerce.Domain.Tests.TestHelpers;

public sealed class ProductBuilder
{
    private readonly ProductId _id = ProductId.New();
    private ProductName _name = new("テスト商品");
    private Money _price = new(1000, "JPY");

    public static ProductBuilder AProduct() => new();
    public static ProductBuilder AnExpensiveProduct() => new ProductBuilder().WithPrice(new Money(50000, "JPY"));
    public static ProductBuilder AFreeProduct() => new ProductBuilder().WithPrice(Money.Zero("JPY"));

    public ProductBuilder WithPrice(Money price) { _price = price; return this; }
    public ProductBuilder WithName(string name) { _name = new ProductName(name); return this; }

    public (ProductId Id, ProductName Name, Money Price) Build() => (_id, _name, _price);
}
```

### 7.2 テスト用の時刻プロバイダ

```csharp
// tests/TestHelpers/FakeDateTimeProvider.cs
namespace ECommerce.Domain.Tests.TestHelpers;

/// <summary>
/// テスト用の固定時刻プロバイダ。
/// DateTimeOffset.UtcNow を直接使うとテストが非決定的になるため、
/// IDateTimeProvider を経由して時刻を注入する設計が必須。
/// このクラスはその設計の恩恵を受けるテスト実装例。
/// </summary>
public sealed class FakeDateTimeProvider(DateTimeOffset fixedTime) : IDateTimeProvider
{
    public DateTimeOffset UtcNow => fixedTime;

    public static FakeDateTimeProvider At(int year, int month, int day, int hour = 0, int minute = 0) =>
        new(new DateTimeOffset(year, month, day, hour, minute, 0, TimeSpan.Zero));

    public static FakeDateTimeProvider At(DateTimeOffset time) => new(time);
}
```

### 7.3 Domain Eventのキャプチャヘルパー

```csharp
// tests/TestHelpers/DomainEventAssertions.cs
namespace ECommerce.Domain.Tests.TestHelpers;

/// <summary>
/// Aggregate の DomainEvents を検証するためのヘルパー拡張メソッド群。
/// FluentAssertionsと組み合わせて使用する。
/// </summary>
public static class DomainEventAssertions
{
    /// <summary>指定した型のイベントが正確に1件発行されていることを確認し、そのイベントを返す</summary>
    public static T ShouldHaveRaisedSingleEvent<T>(this Order order) where T : IDomainEvent =>
        order.DomainEvents.OfType<T>().Should().ContainSingle(
            because: $"Order は {typeof(T).Name} を1件だけ発行するはず").Subject;

    /// <summary>指定した型のイベントが1件も発行されていないことを確認する</summary>
    public static void ShouldNotHaveRaisedEvent<T>(this Order order) where T : IDomainEvent =>
        order.DomainEvents.OfType<T>().Should().BeEmpty(
            because: $"このシナリオでは {typeof(T).Name} は発行されないはず");

    /// <summary>ドメインイベントが一切発行されていないことを確認する</summary>
    public static void ShouldHaveRaisedNoEvents(this Order order) =>
        order.DomainEvents.Should().BeEmpty(because: "このシナリオではイベント発行は期待されない");
}

// 使用例
[Fact]
public void Given_PlacedOrder_When_Cancelled_Then_OrderCancelledEventContainsCorrectReason()
{
    var order = OrderBuilder.APlacedOrder().Build();
    order.ClearDomainEvents();

    order.Cancel("在庫切れ");

    var cancelledEvent = order.ShouldHaveRaisedSingleEvent<OrderCancelledEvent>();
    cancelledEvent.Reason.Should().Be("在庫切れ");
    cancelledEvent.OrderId.Should().Be(order.Id);
}
```

---

## 8. コードカバレッジの考え方

### 8.1 行カバレッジ vs 分岐カバレッジ

行カバレッジは「テストが通過したコード行の割合」、分岐カバレッジは「if文のtrueとfalseの両方を通過した割合」です。

```csharp
// このコードで行カバレッジ100%でも分岐カバレッジは不十分
public void Cancel(string reason)
{
    if (Status == OrderStatus.Shipped || Status == OrderStatus.Delivered)  // ← true のみテストした場合
        throw new CannotCancelShippedOrderException(Id, Status);

    if (Status == OrderStatus.Cancelled)   // ← false のみテストした場合
        throw new OrderAlreadyCancelledException(Id);

    Status = OrderStatus.Cancelled;        // ← この行には到達しているが...
    _domainEvents.Add(new OrderCancelledEvent(Id, reason, DateTimeOffset.UtcNow));
}
// 行カバレッジ: 100% / 分岐カバレッジ: 50%（各ifのfalseケースが未テスト）
```

DDDのドメインロジックにおいては**分岐カバレッジを重視**すべきです。ビジネスルールの「条件分岐」こそがバグの温床であるため、各条件のtrueとfalseの両パスを必ずカバーします。

### 8.2 カバレッジ計測の設定

```xml
<!-- tests/Domain.Tests/Domain.Tests.csproj -->
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net9.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <!-- カバレッジ設定 -->
    <CollectCoverage>true</CollectCoverage>
    <CoverletOutputFormat>cobertura</CoverletOutputFormat>
    <CoverletOutput>./coverage/</CoverletOutput>
    <Threshold>80</Threshold>
    <ThresholdType>branch</ThresholdType>      <!-- 分岐カバレッジを基準にする -->
    <ThresholdStat>Total</ThresholdStat>
    <!-- ドメインモデルのみを対象とし、生成コードは除外 -->
    <ExcludeByAttribute>System.Runtime.CompilerServices.CompilerGeneratedAttribute</ExcludeByAttribute>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="xunit" Version="2.9.*" />
    <PackageReference Include="xunit.runner.visualstudio" Version="2.8.*" />
    <PackageReference Include="FluentAssertions" Version="6.12.*" />
    <PackageReference Include="NSubstitute" Version="5.3.*" />
    <PackageReference Include="NSubstitute.Analyzers.CSharp" Version="1.0.*">
      <PrivateAssets>all</PrivateAssets>
    </PackageReference>
    <PackageReference Include="Testcontainers.PostgreSql" Version="3.9.*" />
    <PackageReference Include="coverlet.collector" Version="6.0.*">
      <PrivateAssets>all</PrivateAssets>
    </PackageReference>
    <PackageReference Include="ReportGenerator" Version="5.2.*">
      <PrivateAssets>all</PrivateAssets>
    </PackageReference>
  </ItemGroup>
</Project>
```

```bash
# カバレッジ付きでテスト実行
dotnet test --collect:"XPlat Code Coverage" \
            --results-directory ./TestResults

# HTMLレポート生成
reportgenerator \
  -reports:"./TestResults/**/coverage.cobertura.xml" \
  -targetdir:"./coverage-report" \
  -reporttypes:"HtmlInline_AzurePipelines;Badges" \
  -assemblyfilters:"+ECommerce.Domain;+ECommerce.Application;-ECommerce.Infrastructure"
```

### 8.3 80%ルールの根拠と限界

**80%の根拠:**

100%を目指すと「カバレッジのためのテスト」が増え、テストの質が下がります。DDDでは残り20%に「EF Core生成コード・DIの配線・プリミティブなゲッター」が含まれることが多く、これらをテストすることの価値は低いです。Aggregate・Value Object・Domain Service（重要なビジネスロジック）は90%以上を狙うべきで、Infrastructure層のDTOマッパーは50%でも許容できます。

**限界:**

```csharp
// カバレッジ100%でもテストの質がゼロの例
[Fact]
public void Order_HasStatus_Property_ThatReturnsStatus()
{
    var order = Order.Create(CustomerId.New(), DateTimeOffset.UtcNow);
    // ← ここで order.Status を読むだけで行カバレッジが上がる
    var _ = order.Status;
    // 何も Assert していない → このテストはバグを1つも検出できない
}
```

カバレッジは「テストが通過したかどうか」を測るだけで「テストが正しいかどうか」は測れません。**カバレッジはバグの上限を示すが、バグがないことは証明しない**という原則を常に意識することが重要です。

### 8.4 レイヤー別のカバレッジ目標

```
レイヤー               | 目標値          | 理由
──────────────────────|──────────────---|──────────────────────────────
Domain Layer          | Branch 90%以上  | ビジネスロジックが集中するため最重要
Application Layer     | Branch 80%以上  | フロー制御・副作用の検証
Infrastructure Layer  | Line 70%以上    | 統合テストと組み合わせで補完
Presentation Layer    | E2Eテストでカバー| 単体テストより統合確認が効果的
```

---

## 9. 演習問題（3問・解答付き）

### 演習1: Value Objectのテスト設計

**問題**: 以下の `EmailAddress` Value Objectに対するユニットテストを10本以上設計してください。テスト名はビジネス語で記述し、Given-When-Then形式を守ること。

```csharp
namespace ECommerce.Domain.Customers;

public sealed record EmailAddress
{
    public string Value { get; }

    public EmailAddress(string value)
    {
        if (string.IsNullOrWhiteSpace(value))
            throw new ArgumentException("メールアドレスは空にできません");

        if (!value.Contains('@'))
            throw new ArgumentException("無効なメールアドレス形式です");

        if (value.Length > 254)
            throw new ArgumentException("メールアドレスが長すぎます");

        Value = value.Trim().ToLowerInvariant();
    }
}
```

**解答**:

```csharp
// tests/Domain.Tests/ValueObjects/EmailAddressTests.cs
namespace ECommerce.Domain.Tests.ValueObjects;

public sealed class EmailAddressTests
{
    [Fact]
    public void Given_ValidEmailWithMixedCase_When_Created_Then_ValueIsNormalizedToLowercase()
    {
        // Arrange & Act
        var email = new EmailAddress("  USER@EXAMPLE.COM  ");

        // Assert: 前後の空白除去 + 小文字正規化が行われる
        email.Value.Should().Be("user@example.com");
    }

    [Fact]
    public void Given_SameEmailAddress_When_Compared_Then_AreEqual()
    {
        // Value Object の等値性: 参照ではなく値で比較されること
        var email1 = new EmailAddress("user@example.com");
        var email2 = new EmailAddress("user@example.com");
        email1.Should().Be(email2);
    }

    [Fact]
    public void Given_SameEmailWithDifferentCase_When_Compared_Then_AreEqualBecauseNormalized()
    {
        // 正規化後は大文字小文字を問わず同一扱い
        var email1 = new EmailAddress("USER@EXAMPLE.COM");
        var email2 = new EmailAddress("user@example.com");
        email1.Should().Be(email2);
    }

    [Fact]
    public void Given_DifferentEmailAddresses_When_Compared_Then_AreNotEqual()
    {
        var email1 = new EmailAddress("user1@example.com");
        var email2 = new EmailAddress("user2@example.com");
        email1.Should().NotBe(email2);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public void Given_EmptyOrWhitespaceEmail_When_Created_Then_ThrowsArgumentExceptionWithClearMessage(
        string invalidEmail)
    {
        var act = () => new EmailAddress(invalidEmail);
        act.Should().Throw<ArgumentException>()
            .WithMessage("*メールアドレスは空にできません*");
    }

    [Fact]
    public void Given_NullEmail_When_Created_Then_ThrowsArgumentException()
    {
        var act = () => new EmailAddress(null!);
        act.Should().Throw<ArgumentException>();
    }

    [Fact]
    public void Given_EmailWithoutAtSign_When_Created_Then_ThrowsArgumentExceptionIndicatingInvalidFormat()
    {
        var act = () => new EmailAddress("invalidemail.com");
        act.Should().Throw<ArgumentException>()
            .WithMessage("*無効なメールアドレス形式*");
    }

    [Fact]
    public void Given_EmailExceeding254Characters_When_Created_Then_ThrowsArgumentException()
    {
        // 254文字制限はRFC 5321に基づく
        var longEmail = new string('a', 244) + "@example.com"; // 256文字
        var act = () => new EmailAddress(longEmail);
        act.Should().Throw<ArgumentException>()
            .WithMessage("*長すぎ*");
    }

    [Fact]
    public void Given_EmailExactly254Characters_When_Created_Then_Succeeds()
    {
        // 境界値: ちょうど254文字は許容される
        var email254Chars = new string('a', 242) + "@example.com"; // 254文字
        var act = () => new EmailAddress(email254Chars);
        act.Should().NotThrow();
    }

    [Theory]
    [InlineData("user@example.com")]
    [InlineData("user+tag@sub.example.co.jp")]
    [InlineData("123@456.com")]
    [InlineData("user.name@domain.org")]
    public void Given_ValidEmailFormats_When_Created_Then_Succeeds(string validEmail)
    {
        // 多様な有効フォーマットをパラメータ化テストで網羅
        var act = () => new EmailAddress(validEmail);
        act.Should().NotThrow(because: $"「{validEmail}」は有効なメールアドレス形式のはず");
    }

    [Fact]
    public void Given_ValidEmail_When_UsedAsHashSetKey_Then_DuplicatesAreEliminated()
    {
        // Value Object はハッシュセットで正しく重複排除される（等値性の一貫性確認）
        var set = new HashSet<EmailAddress>
        {
            new EmailAddress("user@example.com"),
            new EmailAddress("USER@EXAMPLE.COM"), // 正規化後は同一
            new EmailAddress("admin@example.com")
        };

        set.Should().HaveCount(2, because: "正規化後に同一のアドレスはSetで重複排除されるべき");
    }
}
```

---

### 演習2: CommandHandlerの副作用テスト

**問題**: 以下の `CancelOrderHandler` のユニットテストを設計してください。キャンセルが成功した場合・注文が存在しない場合・キャンセル不可ステータスの場合の3つのシナリオを実装し、副作用（UnitOfWork.SaveChangesの呼び出し有無）を必ず検証すること。

```csharp
namespace ECommerce.Application.Orders.Commands;

public sealed record CancelOrderCommand(Guid OrderId, string Reason) : ICommand;

public sealed class CancelOrderHandler(
    IOrderRepository orderRepository,
    IUnitOfWork unitOfWork) : ICommandHandler<CancelOrderCommand>
{
    public async Task HandleAsync(CancelOrderCommand command, CancellationToken ct)
    {
        var orderId = new OrderId(command.OrderId);
        var order = await orderRepository.GetByIdAsync(orderId, ct)
            ?? throw new OrderNotFoundException(orderId);

        order.Cancel(command.Reason);
        await unitOfWork.SaveChangesAsync(ct);
    }
}
```

**解答**:

```csharp
// tests/Application.Tests/Commands/CancelOrderHandlerTests.cs
namespace ECommerce.Application.Tests.Commands;

public sealed class CancelOrderHandlerTests
{
    private readonly IOrderRepository _orderRepository = Substitute.For<IOrderRepository>();
    private readonly IUnitOfWork _unitOfWork = Substitute.For<IUnitOfWork>();
    private readonly CancelOrderHandler _sut;

    public CancelOrderHandlerTests()
        => _sut = new CancelOrderHandler(_orderRepository, _unitOfWork);

    [Fact]
    public async Task Given_PlacedOrder_When_CancelCommandHandled_Then_OrderStatusIsCancelled()
    {
        // Arrange: 注文確定済みの注文
        var order = OrderBuilder.APlacedOrder().Build();
        _orderRepository.GetByIdAsync(order.Id, Arg.Any<CancellationToken>()).Returns(order);

        // Act
        await _sut.HandleAsync(new CancelOrderCommand(order.Id.Value, "顧客都合"), CancellationToken.None);

        // Assert 1: ステータス変化
        order.Status.Should().Be(OrderStatus.Cancelled);
        // Assert 2: 永続化の副作用
        await _unitOfWork.Received(1).SaveChangesAsync(Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task Given_PlacedOrder_When_CancelCommandHandled_Then_CancellationReasonIsRecorded()
    {
        // Arrange
        var order = OrderBuilder.APlacedOrder().Build();
        _orderRepository.GetByIdAsync(order.Id, Arg.Any<CancellationToken>()).Returns(order);
        order.ClearDomainEvents();

        // Act
        await _sut.HandleAsync(new CancelOrderCommand(order.Id.Value, "在庫切れ"), CancellationToken.None);

        // Assert: キャンセル理由がドメインイベントに記録される
        var cancelEvent = order.ShouldHaveRaisedSingleEvent<OrderCancelledEvent>();
        cancelEvent.Reason.Should().Be("在庫切れ");
    }

    [Fact]
    public async Task Given_NonExistentOrder_When_CancelCommandHandled_Then_ThrowsOrderNotFoundException()
    {
        // Arrange: 存在しない注文ID
        _orderRepository.GetByIdAsync(Arg.Any<OrderId>(), Arg.Any<CancellationToken>())
            .Returns((Order?)null);

        // Act
        var act = () => _sut.HandleAsync(new CancelOrderCommand(Guid.NewGuid(), "理由"), CancellationToken.None);

        // Assert: 例外が発生し、DBへの書き込みは起きない
        await act.Should().ThrowAsync<OrderNotFoundException>();
        await _unitOfWork.DidNotReceive().SaveChangesAsync(Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task Given_ShippedOrder_When_CancelCommandHandled_Then_ThrowsBusinessRuleViolationAndDoesNotSave()
    {
        // Arrange: 発送済み注文（キャンセル不可）
        var order = OrderBuilder.AShippedOrder().Build();
        _orderRepository.GetByIdAsync(order.Id, Arg.Any<CancellationToken>()).Returns(order);

        // Act
        var act = () => _sut.HandleAsync(new CancelOrderCommand(order.Id.Value, "理由"), CancellationToken.None);

        // Assert: ビジネスルール違反例外 + SaveChangesは呼ばれない
        await act.Should().ThrowAsync<CannotCancelShippedOrderException>();
        await _unitOfWork.DidNotReceive().SaveChangesAsync(Arg.Any<CancellationToken>());
    }

    [Fact]
    public async Task Given_AlreadyCancelledOrder_When_CancelCommandHandled_Then_ThrowsOrderAlreadyCancelledException()
    {
        // Arrange: すでにキャンセル済みの注文
        var order = OrderBuilder.ACancelledOrder().Build();
        _orderRepository.GetByIdAsync(order.Id, Arg.Any<CancellationToken>()).Returns(order);

        // Act
        var act = () => _sut.HandleAsync(new CancelOrderCommand(order.Id.Value, "二重キャンセル"), CancellationToken.None);

        // Assert
        await act.Should().ThrowAsync<OrderAlreadyCancelledException>();
        await _unitOfWork.DidNotReceive().SaveChangesAsync(Arg.Any<CancellationToken>());
    }
}
```

---

### 演習3: 統合テストのシナリオ設計

**問題**: TestContainersを使って「注文作成 → 注文確定 → キャンセル → 再確定は不可」というライフサイクルを通した統合シナリオをテストしてください。各ステップで `ChangeTracker.Clear()` を呼んでキャッシュ効果を排除することを意識して実装すること。

**解答**:

```csharp
// tests/Infrastructure.Tests/Repositories/OrderLifecycleIntegrationTests.cs
namespace ECommerce.Infrastructure.Tests.Repositories;

[Collection("PostgreSQL")]
public sealed class OrderLifecycleIntegrationTests : IAsyncLifetime
{
    private readonly PostgreSqlTestFixture _fixture;
    private ECommerceDbContext _context = null!;
    private OrderRepository _repository = null!;

    public OrderLifecycleIntegrationTests(PostgreSqlTestFixture fixture)
    {
        _fixture = fixture;
    }

    public async Task InitializeAsync()
    {
        _context = new ECommerceDbContext(_fixture.CreateDbContextOptions());
        _repository = new OrderRepository(_context);
        await _context.Database.ExecuteSqlRawAsync("TRUNCATE TABLE orders CASCADE");
    }

    public async Task DisposeAsync() => await _context.DisposeAsync();

    [Fact]
    public async Task Given_OrderLifecycle_When_PlacedThenCancelledThenAttemptReplace_Then_SecondPlaceThrowsException()
    {
        // ─── Step 1: 注文を作成してDBに保存 ───
        var customerId = CustomerId.New();
        var order = OrderBuilder.ANewDraftOrder()
            .ForCustomer(customerId)
            .WithItem(ProductId.New(), new ProductName("商品A"), new Money(1000, "JPY"), Quantity.Of(2))
            .WithShippingAddress(AddressBuilder.AValidAddress().Build())
            .Build();

        await _repository.AddAsync(order, CancellationToken.None);
        await _context.SaveChangesAsync();
        var orderId = order.Id;

        // ─── Step 2: 注文を確定（DBから再取得してキャッシュ効果を排除）───
        _context.ChangeTracker.Clear();
        var orderToPlace = await _repository.GetByIdAsync(orderId, CancellationToken.None);
        orderToPlace!.Place(DateTimeOffset.UtcNow);
        await _context.SaveChangesAsync();

        // Step 2 の検証: DBに Placed として保存されていること
        _context.ChangeTracker.Clear();
        var placedOrder = await _repository.GetByIdAsync(orderId, CancellationToken.None);
        placedOrder!.Status.Should().Be(OrderStatus.Placed, because: "Step2で確定されたはず");

        // ─── Step 3: キャンセル ───
        _context.ChangeTracker.Clear();
        var orderToCancel = await _repository.GetByIdAsync(orderId, CancellationToken.None);
        orderToCancel!.Cancel("ユーザーがキャンセルした");
        await _context.SaveChangesAsync();

        // Step 3 の検証: DBに Cancelled として保存されていること
        _context.ChangeTracker.Clear();
        var cancelledOrder = await _repository.GetByIdAsync(orderId, CancellationToken.None);
        cancelledOrder!.Status.Should().Be(OrderStatus.Cancelled, because: "Step3でキャンセルされたはず");

        // ─── Step 4: キャンセル済み注文を再確定しようとする ───
        // ドメインルール: Cancelled -> Placed への遷移は許可されない
        var act = () => cancelledOrder.Place(DateTimeOffset.UtcNow);

        // Assert: ビジネスルール違反例外が発生する
        act.Should().Throw<InvalidOrderStateTransitionException>(
            because: "キャンセル済みの注文は再確定できないビジネスルールがあるはず");
    }

    [Fact]
    public async Task Given_LargeOrderWithManyItems_When_SavedAndRetrieved_Then_AllItemsArePersisted()
    {
        // 多数のラインアイテムを持つ注文の永続化テスト（N+1問題の検出にも使える）
        var order = OrderBuilder.ANewDraftOrder().Build();
        const int itemCount = 50;

        for (int i = 0; i < itemCount; i++)
            order.AddItem(ProductId.New(), new ProductName($"商品{i}"), new Money(100, "JPY"), Quantity.Of(1));

        await _repository.AddAsync(order, CancellationToken.None);
        await _context.SaveChangesAsync();
        _context.ChangeTracker.Clear();

        var retrieved = await _repository.GetByIdAsync(order.Id, CancellationToken.None);

        retrieved!.Lines.Should().HaveCount(itemCount);
        retrieved.TotalAmount.Should().Be(new Money(100 * itemCount, "JPY"));
    }
}
```

---

## まとめ

本章では、DDDシステムにおけるテスト戦略を体系的に解説しました。重要なポイントを整理します。

| 原則 | 内容 |
|------|------|
| ピラミッド70/20/10 | Unit中心でフィードバックを最速化する |
| ビジネス語のテスト名 | Given-When-Then + ドメイン用語でドキュメントとして機能させる |
| モックは境界のみ | Repository・外部APIだけをモックし、Domain Serviceは本物を使う |
| TestContainersで本番同等 | 楽観的ロック・トランザクション境界のバグを本物のDBで検出する |
| Test Builderで可読性 | OrderBuilderでテスト準備コードをビジネス語化する |
| 分岐カバレッジ80%以上 | 行カバレッジではなく分岐カバレッジを基準にし、ビジネスルールの境界値を網羅する |

DDDにおけるテストの最終目標は「コードが動くこと」の証明ではなく、「ビジネスルールが守られていること」の証明です。テストスイートが「システムがどのようなビジネスシナリオをサポートしているか」を読めるドキュメントとして機能することを常に意識して設計してください。

次章（第18章）では、これらのテストをCI/CDパイプラインに組み込み、品質ゲートとして機能させる方法を解説します。
