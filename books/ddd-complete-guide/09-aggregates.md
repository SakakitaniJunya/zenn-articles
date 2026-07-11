---
title: "第9章: Aggregate — Vernon の4原則で整合性を守る"
---


## Aggregateの本質とは何か

Aggregateとは、「ビジネスルールの整合性を常に保証しなければならないオブジェクトの集合体」です。言い換えると、**整合性の境界（Consistency Boundary）**そのものです。

よくある誤解として、「Aggregateは単なるオブジェクトのグループ」という認識があります。しかしそれは表面的な理解にすぎません。Aggregateの本質は「その境界の内側では、どんな操作をしても不変条件（Invariant）が必ず満たされること」を保証することにあります。

Aggregate内には必ず1つの**Aggregate Root**が存在し、外部からはこのRoot経由でのみアクセスできます。

## Vaughn Vernonの「Aggregateデザイン4原則」

DDDの実践書「Implementing Domain-Driven Design」の著者Vaughn Vernonは、Aggregateを設計する際の4つの原則を提唱しています。

### 原則1: 真の不変条件のみをAggregateに含める

「注文の合計金額は、各明細の金額合計と一致しなければならない」——これは真の不変条件です。一方、「注文と顧客は同じ住所を持つべき」というルールは、必ずしも同一トランザクション内で保証する必要はありません。後者は**結果整合性**で対応できます。

### 原則2: 小さなAggregateを設計する

Aggregateが大きくなればなるほど、ロードコスト・ロック競合・複雑性が増大します。「できるだけ小さく保つ」が鉄則です。

### 原則3: ID参照で他のAggregateを参照する

Aggregate間でオブジェクト参照（`Customer customer`）を持つと、トランザクション境界が曖昧になります。代わりに`CustomerId customerId`のようにIDのみを保持します。

### 原則4: 結果整合性で境界外を更新する

Aggregate外部の状態変更は、Domain Eventを介して非同期に行います。これにより、各Aggregateが独立したトランザクション境界を保てます。

## Aggregate境界図

```mermaid
graph TB
    subgraph OrderAggregate["Order Aggregate (整合性境界)"]
        direction TB
        OR[Order<br/>Aggregate Root]
        OI1[OrderItem 1]
        OI2[OrderItem 2]
        OI3[OrderItem 3]
        OR --> OI1
        OR --> OI2
        OR --> OI3
    end

    subgraph CustomerAggregate["Customer Aggregate (独立した境界)"]
        direction TB
        CU[Customer<br/>Aggregate Root]
        AD[Address]
        CU --> AD
    end

    subgraph ProductAggregate["Product Aggregate (独立した境界)"]
        direction TB
        PR[Product<br/>Aggregate Root]
    end

    OR -.->|CustomerId (ID参照のみ)| CU
    OI1 -.->|ProductId (ID参照のみ)| PR

    style OrderAggregate fill:#e8f4f8,stroke:#2980b9,stroke-width:2px
    style CustomerAggregate fill:#e8f8e8,stroke:#27ae60,stroke-width:2px
    style ProductAggregate fill:#f8f4e8,stroke:#e67e22,stroke-width:2px
```

## Before/After: Aggregateの設計

### Before: 巨大で問題のあるAggregate

```csharp
// 悪い例: Customerが全てを抱え込んでいる
public class Customer
{
    public Guid Id { get; private set; }
    public string Name { get; private set; }
    public List<Order> Orders { get; private set; }      // 全注文履歴
    public List<Address> Addresses { get; private set; } // 複数住所
    public List<Review> Reviews { get; private set; }    // レビュー履歴
    public ShoppingCart Cart { get; private set; }       // カート

    // 問題点:
    // 1. ロード時に全注文・全住所・全レビューをDBから取得
    // 2. 「カートに商品追加」だけなのに全注文をロックする
    // 3. 複数ユーザーが同時操作すると競合が頻発する
}
```

### After: 小さく整合性の高いAggregate

```csharp
// 良い例: Order Aggregateの完全実装
public class Order : AggregateRoot
{
    private readonly List<OrderItem> _items = new();

    public Guid Id { get; private set; }
    public Guid CustomerId { get; private set; }  // ID参照のみ
    public OrderStatus Status { get; private set; }
    public Money TotalAmount { get; private set; }
    public IReadOnlyList<OrderItem> Items => _items.AsReadOnly();

    // ファクトリメソッド（Chapter 13で詳述）
    public static Order Create(Guid customerId)
    {
        var order = new Order
        {
            Id = Guid.NewGuid(),
            CustomerId = customerId,
            Status = OrderStatus.Draft,
            TotalAmount = Money.Zero
        };
        order.RaiseDomainEvent(new OrderCreated(order.Id, customerId));
        return order;
    }

    // 不変条件を保護するメソッド
    public void AddItem(Guid productId, string productName, Money price, int quantity)
    {
        // 不変条件チェック: Draftステータスの注文のみ追加可能
        if (Status != OrderStatus.Draft)
            throw new DomainException("確定済みの注文に商品を追加できません。");

        // 不変条件チェック: 数量は1以上
        if (quantity <= 0)
            throw new DomainException("数量は1以上を指定してください。");

        var existingItem = _items.FirstOrDefault(i => i.ProductId == productId);
        if (existingItem != null)
        {
            existingItem.IncreaseQuantity(quantity);
        }
        else
        {
            _items.Add(new OrderItem(Id, productId, productName, price, quantity));
        }

        // 合計金額を再計算（不変条件を維持）
        RecalculateTotalAmount();
    }

    public void PlaceOrder()
    {
        // 不変条件チェック: 1件以上の商品が必要
        if (!_items.Any())
            throw new DomainException("商品を1件以上追加してから注文を確定してください。");

        Status = OrderStatus.Placed;
        RaiseDomainEvent(new OrderPlaced(Id, CustomerId, TotalAmount, DateTime.UtcNow));
    }

    private void RecalculateTotalAmount()
    {
        // 合計金額 = 各明細の小計の合計（不変条件）
        TotalAmount = _items
            .Select(i => i.SubTotal)
            .Aggregate(Money.Zero, (acc, sub) => acc.Add(sub));
    }
}

public class OrderItem : Entity
{
    public Guid Id { get; private set; }
    public Guid OrderId { get; private set; }
    public Guid ProductId { get; private set; }  // ID参照のみ
    public string ProductName { get; private set; }
    public Money UnitPrice { get; private set; }
    public int Quantity { get; private set; }
    public Money SubTotal => UnitPrice.Multiply(Quantity);  // 計算で導出

    // OrderItemはOrderを通じてのみ生成可能（internal修飾子でもよい）
    internal OrderItem(Guid orderId, Guid productId, string productName,
                       Money price, int quantity)
    {
        Id = Guid.NewGuid();
        OrderId = orderId;
        ProductId = productId;
        ProductName = productName;
        UnitPrice = price;
        Quantity = quantity;
    }

    internal void IncreaseQuantity(int additionalQty)
    {
        if (additionalQty <= 0)
            throw new DomainException("追加数量は1以上である必要があります。");
        Quantity += additionalQty;
    }
}
```

## Aggregateが大きすぎる場合の問題点

Aggregateを大きく設計してしまうと、以下の問題が連鎖的に発生します。

1. **パフォーマンス劣化**: 1つの操作に無関係なデータまでDBからロードされる
2. **ロック競合の増大**: 複数ユーザーが同じAggregateを同時操作しようとするとデッドロックが発生しやすくなる
3. **テストの困難化**: テストデータのセットアップが複雑になる
4. **変更の影響範囲拡大**: 小さな仕様変更が多くのコードに波及する

> **専門家の視点**
>
> Vaughn Vernonは「Aggregateのサイズに関するほとんどのミスは、Aggregateが大きすぎる方向に起きる」と指摘しています。
>
> 実務での判断基準として筆者が推奨するのは、「このAggregateに含まれる全エンティティを1つのトランザクションで更新する必要が本当にあるか?」という問いかけです。答えが「Noかもしれない」なら、分割を検討すべきシグナルです。
>
> また、「データベースのテーブルとAggregateを1対1でマッピングしたい」という誘惑に負けないことも重要です。Aggregateはビジネスの整合性境界であり、データの永続化の都合ではありません。

## まとめ

Aggregateは「ビジネスルールの守護者」です。Aggregate Rootを唯一の入口とし、内部の不変条件を常に満たし、外部へはIDのみで参照する——この3つの鉄則を守ることで、ドメインロジックの整合性を確実に保証できます。次章では、Aggregate内で起きた出来事を外部に伝える「Domain Event」を解説します。
