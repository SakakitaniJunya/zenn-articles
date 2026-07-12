---
title: "第23章: Read Model 設計 — CQRS の Query 側を徹底的に作る"
id: ch23-read-model-design
canonical: true
---

# 第 23 章: Read Model 設計 — CQRS の Query 側を徹底的に作る

---

## 0. TL;DR（3行）

Read Model は「画面のために作るデータ構造」であり、Domain Model とは完全に別物です。Write Model がドメインの整合性を守るために存在するのに対して、Read Model はパフォーマンスと画面要件だけに最適化されます。Projection（投影）がその橋渡しを担い、ドメインイベントを購読して Read Store を自動更新することで、クエリ側はシンプルな SELECT のみで完結します。

---

## 1. なぜ Read Model が必要か

### 1.1 N+1 問題の完全解説（計測付き）

「N+1 問題」は Web アプリケーション開発における最も頻出のパフォーマンス地雷のひとつです。名前の由来は、1 件の親クエリに対して N 件の子クエリが追加で実行されることにあります。受注管理システムを例に、問題の発生メカニズムと計測方法を丁寧に解説します。

**シナリオ**: 顧客の注文一覧画面。1 顧客が平均 50 件の注文を持ち、各注文に平均 5 件の明細がある。

```csharp
// NG パターン: Domain Aggregate をそのまま読み取りに使う
public async Task<IActionResult> GetOrderList(Guid customerId)
{
    // SQL 1発目: SELECT * FROM orders WHERE customer_id = @customerId
    var orders = await _orderRepository.FindByCustomerAsync(CustomerId.From(customerId));

    var result = new List<OrderSummaryDto>();

    foreach (var order in orders)   // ← orders が 50 件あるとする
    {
        // SQL N発目: SELECT * FROM order_items WHERE order_id = @orderId
        // 50回実行される ← これが N+1 の N
        var items = order.Items;    // 遅延ロード

        // さらに Product 名が欲しくて追加クエリ (N×M 問題に発展)
        foreach (var item in items)
        {
            // SELECT * FROM products WHERE id = @productId
            var product = await _productRepository.FindByIdAsync(item.ProductId);
        }

        result.Add(new OrderSummaryDto(/* ... */));
    }

    return Ok(result);
}
```

**実際の SQL 発行数の計算**:

| ステップ | SQL 発行数 | 説明 |
|---------|-----------|------|
| 注文一覧取得 | 1 | SELECT orders |
| 注文明細取得 | 50 | 注文1件につき1回 |
| 商品情報取得 | 250 | 明細5件×注文50件 |
| **合計** | **301** | 1 + 50 + 250 |

これが「N+1（正確には N×M+1）問題」の実態です。注文が 100 件になれば SQL は 601 回、1,000 件になれば 6,001 回に膨れ上がります。

**実際の計測方法（MiniProfiler + Dapper）**:

```csharp
// appsettings.Development.json
{
  "ConnectionStrings": {
    "Default": "..."
  },
  "MiniProfiler": {
    "Enabled": true
  }
}

// Program.cs に追加
builder.Services.AddMiniProfiler(options =>
{
    options.RouteBasePath = "/profiler";
    options.SqlFormatter = new StackExchange.Profiling.SqlFormatters.InlineFormatter();
}).AddEntityFramework();  // または AddDapper()

// ミドルウェア
app.UseMiniProfiler();
```

実際に計測すると、300 件の SQL が順次実行されるため、レイテンシが数百ミリ秒〜数秒になることが珍しくありません。PostgreSQL のラウンドトリップが 1ms だとしても、300回 × 1ms = 300ms のオーバーヘッドが純粋に加算されます。実環境ではネットワーク遅延やコネクションプールの競合も加わります。

**ベンチマーク比較（BenchmarkDotNet）**:

```csharp
[MemoryDiagnoser]
[SimpleJob(RuntimeMoniker.Net90)]
public class ReadModelBenchmarks
{
    private readonly string _connectionString = "...";

    [Benchmark(Baseline = true)]
    public async Task<List<OrderSummaryDto>> WithNPlusOneProblem()
    {
        // Domain Model 経由: SQL 301 回
        // 計測結果例: 1,240ms, 18.4 MB
        /* ... */
    }

    [Benchmark]
    public async Task<List<OrderSummaryDto>> WithReadModel()
    {
        // 専用 Read Model: SQL 1 回
        // 計測結果例: 12ms, 0.8 MB
        /* ... */
    }
}
// | Method               | Mean      | Gen0    | Allocated |
// |----------------------|-----------|---------|-----------|
// | WithNPlusOneProblem  | 1,240.3ms | 2300.00 | 18.4 MB   |
// | WithReadModel        |    12.1ms |   80.00 |  0.8 MB   |
// Read Model は約 103 倍高速、メモリ使用量は約 23 分の 1
```

### 1.2 ドメインモデルをそのまま画面に使う 5 つの問題

Read Model が必要な理由は N+1 だけではありません。ドメインモデルをそのまま画面に使うことには、構造的な問題が 5 つあります。

**問題①: 集約境界とUI要件の不一致**

ドメイン集約は整合性境界として設計されています。`Order` 集約が `Customer` の名前を持たないのは、それが正しいドメイン設計だからです。しかし画面では「注文一覧に顧客名を表示したい」という要件が当然のように来ます。集約を跨ぐ表示要件を、ドメインモデルの変形で解決しようとすると、集約の純粋性が壊れます。

**問題②: ビジネスロジックと表示ロジックの汚染**

`Order.CalculateTotal()` は課税ロジックを含む重要なドメインロジックです。しかし画面に「税抜き価格を赤字で表示する」という要件が来た時、この色情報やフォーマット情報をドメインオブジェクトに持たせてはいけません。ドメインモデルを画面に使うと、表示ロジックがドメイン層に滲み込んできます。

**問題③: 認可・フィルタリングの複雑化**

管理者には全フィールドを、一般ユーザーには一部フィールドのみ表示したい場合、ドメインモデルを共有すると認可ロジックが複雑になります。専用の Read DTO を作ればロールごとに別クラスを定義するだけで済みます。

**問題④: スキーマ変更の影響範囲拡大**

`Order` テーブルに新しいカラムを追加した場合、ドメインモデルを直接返すAPIではそのカラムが自動的に公開されてしまいます（過剰公開問題）。Read Model を挟めば、意図的にマッピングした項目だけが外部に出ます。

**問題⑤: キャッシュ戦略の困難さ**

ドメインオブジェクトは可変状態を持つため、キャッシュが難しいです。値オブジェクトと異なり、エンティティは同一性（identity）で追跡されます。一方、Read Model は不変（immutable）な DTO として設計できるため、Redis 等での積極的なキャッシュが可能になります。

### 1.3 データ駆動 vs モデル駆動の読み取り

「読み取りのために Domain Model を経由すべきか」は、CQRS 導入時の根本的な問いです。

**モデル駆動（Domain Model 経由）**:
- ドメインロジックが読み取り時にも動く（バリデーション等）
- 集約の整合性が保たれる
- しかし、読み取り専用なのにドメインロジックのオーバーヘッドを全て負担する

**データ駆動（SQL 直叩き）**:
- 画面要件に完全に最適化できる
- JOIN、集計、ページングが自由自在
- ドメインロジックが一切動かない（意図的に）

CQRS の核心的な主張は「**読み取り側でドメインモデルを経由する必要はない**」です。クエリとは本質的にデータ取得であり、ドメインルールの適用ではありません。Greg Young（CQRS 提唱者）は「Read side is just a SELECT」と表現しています。

```csharp
// モデル駆動（CQRS 以前の典型）
public class OrderQueryService_ModelDriven
{
    private readonly IOrderRepository _repo;

    public async Task<OrderListDto> GetOrderListAsync(Guid customerId)
    {
        // Domain Layer を通過 → Aggregate 復元コストが発生
        var orders = await _repo.FindByCustomerAsync(CustomerId.From(customerId));
        return orders.Select(o => new OrderListDto(o.Id.Value, o.TotalAmount.Amount)).ToList();
    }
}

// データ駆動（CQRS Query Side）
public class OrderQueryService_DataDriven
{
    private readonly IDbConnection _db;

    public async Task<IReadOnlyList<OrderSummaryDto>> GetOrderListAsync(Guid customerId)
    {
        // Aggregate 復元なし。SQL で直接必要なデータだけ取得
        const string sql = """
            SELECT o.id, o.created_at, c.name as customer_name,
                   COUNT(oi.id) as item_count,
                   SUM(oi.unit_price * oi.quantity) as total_amount
            FROM orders o
            JOIN customers c ON c.id = o.customer_id
            JOIN order_items oi ON oi.order_id = o.id
            WHERE o.customer_id = @customerId
            GROUP BY o.id, o.created_at, c.name
            ORDER BY o.created_at DESC
            """;

        return (await _db.QueryAsync<OrderSummaryDto>(sql, new { customerId })).ToList();
    }
}
```

---

## 2. Read Model の設計原則

### 2.1 画面に最適化された非正規化

Read Model の設計で最も重要な原則は「**非正規化を恐れない**」ことです。RDBMS の教科書では第三正規形（3NF）が美徳とされますが、Read Store は別の評価軸で設計します。

**非正規化 Read Model の例（注文サマリー）**:

```sql
-- Read Store テーブル: order_summaries
-- 複数テーブルのデータを一枚のテーブルに非正規化して持つ
CREATE TABLE order_summaries (
    id              UUID PRIMARY KEY,
    customer_id     UUID NOT NULL,
    customer_name   TEXT NOT NULL,    -- customers テーブルの重複持ち
    customer_email  TEXT NOT NULL,    -- 同上
    status          TEXT NOT NULL,
    item_count      INTEGER NOT NULL,
    total_amount    NUMERIC(12,2) NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL,
    updated_at      TIMESTAMPTZ NOT NULL,
    -- 検索用インデックス
    product_ids     UUID[] NOT NULL,  -- 含まれる商品 ID の配列
    tag_names       TEXT[] NOT NULL   -- 含まれるタグの配列
);

CREATE INDEX idx_order_summaries_customer ON order_summaries(customer_id);
CREATE INDEX idx_order_summaries_status ON order_summaries(status);
CREATE INDEX idx_order_summaries_created ON order_summaries(created_at DESC);
CREATE INDEX idx_order_summaries_products ON order_summaries USING GIN(product_ids);
```

この設計では `customers` の名前がコピーされています。「顧客名が変わったら？」と思うかもしれません。Read Model は**最終整合性**を受け入れます。顧客名変更イベントが発行され、Projection がそれを受けて `order_summaries` を更新します。わずかな遅延はトレードオフとして許容します。

### 2.2 Domain Layer を経由しない

```csharp
// NG: Application Layer → Domain Layer → Infra Layer の経路
public class OrderQueryService_Wrong
{
    private readonly IOrderRepository _repo;  // Domain Layer のインターフェース

    public async Task<OrderSummaryDto> GetAsync(Guid orderId)
    {
        var order = await _repo.FindByIdAsync(OrderId.From(orderId));  // Aggregate 復元
        return MapToDto(order);  // 必要なのは DTO なのに Aggregate を経由
    }
}

// OK: Application Layer → Read Infra Layer（Direct SQL）
public class OrderQueryService_Correct
{
    private readonly IOrderReadRepository _readRepo;  // Read 専用インターフェース

    public async Task<OrderSummaryDto> GetAsync(Guid orderId)
    {
        // Aggregate を復元しない。Read Store から直接取得
        return await _readRepo.GetSummaryAsync(orderId);
    }
}
```

`IOrderReadRepository` は Domain Layer に属しません。これは Application Layer または Infra Layer に属するクエリ専用のインターフェースです。Domain Layer の `IOrderRepository`（Write 側）とは完全に独立しています。

### 2.3 Mermaid 図でアーキテクチャを可視化

**CQRS 全体アーキテクチャ（Command / Query 分離）**:

```mermaid
flowchart TB
    subgraph CLIENT["クライアント層"]
        WEB["Web Browser"]
        APP["Mobile App"]
    end

    subgraph API["Application Layer"]
        CMD["Command Handler\n(Write Side)"]
        QRY["Query Handler\n(Read Side)"]
    end

    subgraph WRITE["Write 側 (Command Stack)"]
        AGG["Domain Aggregate\n(Order, Customer, etc.)"]
        WR["Write Repository\n(IOrderRepository)"]
        WSTORE["Write Store\n(PostgreSQL - Normalized)"]
    end

    subgraph PROJ["Projection 層"]
        SYNC["Synchronous Projector"]
        ASYNC["Async Projector\n(Message Queue)"]
    end

    subgraph READ["Read 側 (Query Stack)"]
        RR["Read Repository\n(IOrderReadRepository)"]
        RSTORE["Read Store\n(非正規化テーブル / Redis / ES)"]
    end

    WEB -->|Command| CMD
    WEB -->|Query| QRY
    APP -->|Command| CMD
    APP -->|Query| QRY

    CMD --> AGG
    AGG --> WR
    WR --> WSTORE
    AGG -->|Domain Event| SYNC
    SYNC --> RSTORE
    WSTORE -->|Outbox / CDC| ASYNC
    ASYNC --> RSTORE

    QRY --> RR
    RR --> RSTORE

    style WRITE fill:#fff3cd
    style READ fill:#d1ecf1
    style PROJ fill:#d4edda
```

**Read Model の内部構造（Projection フロー）**:

```mermaid
sequenceDiagram
    participant Cmd as Command Handler
    participant Agg as Order Aggregate
    participant Bus as Domain Event Bus
    participant Proj as OrderSummaryProjector
    participant Store as Read Store (PostgreSQL)
    participant Query as Query Handler

    Cmd->>Agg: PlaceOrder(command)
    Agg->>Agg: ビジネスロジック実行
    Agg->>Bus: OrderPlaced イベント発行
    Bus->>Proj: OnOrderPlaced(event)
    Proj->>Store: UPSERT order_summaries SET ...
    Note over Store: Read Model 更新完了

    Query->>Store: SELECT FROM order_summaries WHERE ...
    Store-->>Query: OrderSummaryDto[]
    Note over Query: Aggregate 復元ゼロ
```

---

## 3. Projection パターン全 4 種

Projection（投影）とは「Write Store（または Domain Event）の状態変化を Read Store に伝播する仕組み」のことです。4 種のパターンを使い分けます。

### 3.1 Synchronous Projection（同期）

**適用場面**: 強い整合性が求められる場面。コマンドのトランザクション内で Read Model も同時に更新します。

**特徴**:
- Write と Read が同一トランザクション内（または同一 DB への 2 テーブル更新）
- レスポンスが返った時点で Read Model も最新
- 単一障害点（Read Store 更新失敗 → コマンド全体ロールバック）
- Read Store が重い更新処理の場合、コマンドの遅延に直結

```csharp
// Synchronous Projector 実装例
public class OrderSummaryProjector : IProjector
{
    private readonly NpgsqlDataSource _dataSource;

    public OrderSummaryProjector(NpgsqlDataSource dataSource)
    {
        _dataSource = dataSource;
    }

    // Domain Event Handler として登録
    public async Task OnOrderPlacedAsync(
        OrderPlaced @event,
        NpgsqlTransaction? transaction = null)
    {
        const string sql = """
            INSERT INTO order_summaries (
                id, customer_id, customer_name, customer_email,
                status, item_count, total_amount, created_at, updated_at,
                product_ids, tag_names
            ) VALUES (
                @Id, @CustomerId, @CustomerName, @CustomerEmail,
                @Status, @ItemCount, @TotalAmount, @CreatedAt, @UpdatedAt,
                @ProductIds, @TagNames
            )
            ON CONFLICT (id) DO UPDATE SET
                status       = EXCLUDED.status,
                item_count   = EXCLUDED.item_count,
                total_amount = EXCLUDED.total_amount,
                updated_at   = EXCLUDED.updated_at,
                product_ids  = EXCLUDED.product_ids,
                tag_names    = EXCLUDED.tag_names
            """;

        await using var conn = await _dataSource.OpenConnectionAsync();

        // 既存のトランザクションに参加する（同期投影の核心）
        await conn.ExecuteAsync(sql, new
        {
            Id           = @event.OrderId,
            CustomerId   = @event.CustomerId,
            CustomerName = @event.CustomerName,
            CustomerEmail = @event.CustomerEmail,
            Status       = "Placed",
            ItemCount    = @event.Items.Count,
            TotalAmount  = @event.Items.Sum(i => i.UnitPrice * i.Quantity),
            CreatedAt    = @event.OccurredAt,
            UpdatedAt    = @event.OccurredAt,
            ProductIds   = @event.Items.Select(i => i.ProductId).ToArray(),
            TagNames     = Array.Empty<string>()
        }, transaction);
    }

    public async Task OnOrderCancelledAsync(
        OrderCancelled @event,
        NpgsqlTransaction? transaction = null)
    {
        const string sql = """
            UPDATE order_summaries
            SET status = 'Cancelled', updated_at = @UpdatedAt
            WHERE id = @Id
            """;

        await using var conn = await _dataSource.OpenConnectionAsync();
        await conn.ExecuteAsync(sql, new
        {
            Id        = @event.OrderId,
            UpdatedAt = @event.OccurredAt
        }, transaction);
    }
}

// Command Handler との統合
public class PlaceOrderCommandHandler
{
    private readonly IOrderRepository _repo;
    private readonly OrderSummaryProjector _projector;

    public async Task HandleAsync(PlaceOrderCommand cmd)
    {
        await using var conn = await _dataSource.OpenConnectionAsync();
        await using var tx  = await conn.BeginTransactionAsync();

        try
        {
            var order = Order.Place(/* ... */);
            await _repo.SaveAsync(order, tx);

            // 同一トランザクション内で Read Model も更新
            var @event = order.DomainEvents.OfType<OrderPlaced>().Single();
            await _projector.OnOrderPlacedAsync(@event, tx);

            await tx.CommitAsync();
        }
        catch
        {
            await tx.RollbackAsync();
            throw;
        }
    }
}
```

### 3.2 Asynchronous Projection（非同期・Outbox 経由）

**適用場面**: コマンドのレイテンシを最小化したい、Read Store が別サービス・別 DB にある場合。

**特徴**:
- Transactional Outbox パターンを使い、イベントをアトミックに DB に保存
- バックグラウンドで Outbox を読み取り、Read Store を更新
- コマンドのレスポンスが最速（Read Store 更新を待たない）
- Read Model は最終整合性（数百ミリ秒〜数秒の遅延）

```csharp
// Outbox テーブル（Write DB 内）
// CREATE TABLE outbox_events (
//     id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
//     event_type    TEXT NOT NULL,
//     payload       JSONB NOT NULL,
//     created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
//     processed_at  TIMESTAMPTZ,
//     retry_count   INTEGER NOT NULL DEFAULT 0
// );

// Outbox への書き込み（Command Handler 内、同一トランザクション）
public class PlaceOrderCommandHandler_WithOutbox
{
    public async Task HandleAsync(PlaceOrderCommand cmd, NpgsqlConnection conn, NpgsqlTransaction tx)
    {
        var order = Order.Place(/* ... */);
        await _repo.SaveAsync(order, tx);

        // Outbox に書き込む（同一 TX → Aggregate 保存と原子的）
        const string outboxSql = """
            INSERT INTO outbox_events (event_type, payload, created_at)
            VALUES (@EventType, @Payload::jsonb, @CreatedAt)
            """;

        foreach (var domainEvent in order.DomainEvents)
        {
            await conn.ExecuteAsync(outboxSql, new
            {
                EventType = domainEvent.GetType().Name,
                Payload   = JsonSerializer.Serialize(domainEvent, domainEvent.GetType()),
                CreatedAt = domainEvent.OccurredAt
            }, tx);
        }

        await tx.CommitAsync();
        // ここで return。Read Store 更新はバックグラウンドに委ねる
    }
}

// Outbox Processor（バックグラウンドサービス）
public class OutboxProcessor : BackgroundService
{
    private readonly NpgsqlDataSource _writeDb;
    private readonly OrderSummaryProjector _projector;
    private readonly ILogger<OutboxProcessor> _logger;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            await ProcessBatchAsync(stoppingToken);
            await Task.Delay(TimeSpan.FromMilliseconds(200), stoppingToken);
        }
    }

    private async Task ProcessBatchAsync(CancellationToken ct)
    {
        await using var conn = await _writeDb.OpenConnectionAsync(ct);
        await using var tx   = await conn.BeginTransactionAsync(ct);

        // 未処理イベントを先頭から最大 100 件取得（悲観ロック）
        const string selectSql = """
            SELECT id, event_type, payload
            FROM outbox_events
            WHERE processed_at IS NULL AND retry_count < 3
            ORDER BY created_at ASC
            LIMIT 100
            FOR UPDATE SKIP LOCKED
            """;

        var events = (await conn.QueryAsync<OutboxEvent>(selectSql, transaction: tx)).ToList();

        foreach (var outboxEvent in events)
        {
            try
            {
                await DispatchToProjectorAsync(outboxEvent);

                const string markDoneSql = """
                    UPDATE outbox_events SET processed_at = now()
                    WHERE id = @Id
                    """;
                await conn.ExecuteAsync(markDoneSql, new { outboxEvent.Id }, tx);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Projection failed for event {EventId}", outboxEvent.Id);

                const string retryIncrSql = """
                    UPDATE outbox_events SET retry_count = retry_count + 1
                    WHERE id = @Id
                    """;
                await conn.ExecuteAsync(retryIncrSql, new { outboxEvent.Id }, tx);
            }
        }

        await tx.CommitAsync(ct);
    }

    private async Task DispatchToProjectorAsync(OutboxEvent outboxEvent)
    {
        switch (outboxEvent.EventType)
        {
            case nameof(OrderPlaced):
                var placed = JsonSerializer.Deserialize<OrderPlaced>(outboxEvent.Payload)!;
                await _projector.OnOrderPlacedAsync(placed);
                break;

            case nameof(OrderCancelled):
                var cancelled = JsonSerializer.Deserialize<OrderCancelled>(outboxEvent.Payload)!;
                await _projector.OnOrderCancelledAsync(cancelled);
                break;

            default:
                // 未知イベントはスキップ（新イベント追加時の前方互換性）
                break;
        }
    }
}
```

### 3.3 Catch-up Projection（既存イベント全件再生）

**適用場面**: Read Model を新規作成したい場合、Read Model のスキーマを変更したい場合、バグ修正後に Read Store を作り直したい場合。

**特徴**:
- Event Store に保存された全イベントを最初から再生する
- 既存の Read Store を一度クリアして再構築する
- 再生中は古い Read Store を提供し、切り替え時点で Swap する（Blue-Green）
- Event Sourcing と組み合わせることで真の力を発揮

```csharp
// Catch-up Projection の実装
public class CatchUpProjectionRunner
{
    private readonly IEventStore _eventStore;
    private readonly OrderSummaryProjector _projector;
    private readonly NpgsqlDataSource _readDb;
    private readonly ILogger<CatchUpProjectionRunner> _logger;

    public async Task RunAsync(
        string targetTableName = "order_summaries",
        CancellationToken ct = default)
    {
        _logger.LogInformation("Catch-up projection started for {Table}", targetTableName);

        // Step 1: テンポラリテーブルを作成（Blue-Green Swap の準備）
        var tempTableName = $"{targetTableName}_new_{DateTime.UtcNow:yyyyMMddHHmmss}";
        await CreateTempTableAsync(tempTableName, ct);

        // Step 2: 全イベントをページング再生
        var position  = 0L;
        var batchSize = 500;
        var processed = 0;

        while (true)
        {
            var events = await _eventStore.ReadAllAsync(position, batchSize, ct);
            if (events.Count == 0) break;

            foreach (var @event in events)
            {
                await _projector.ApplyToTableAsync(@event, tempTableName, ct);
                processed++;
            }

            position = events[^1].GlobalPosition + 1;
            _logger.LogInformation("Processed {Count} events (position: {Pos})", processed, position);

            await Task.Delay(10, ct); // バックプレッシャー制御
        }

        // Step 3: テーブルをアトミックにスワップ（サービス無停止で切り替え）
        await SwapTablesAsync(targetTableName, tempTableName, ct);

        _logger.LogInformation(
            "Catch-up projection completed. Processed {Count} events.", processed);
    }

    private async Task SwapTablesAsync(string current, string next, CancellationToken ct)
    {
        await using var conn = await _readDb.OpenConnectionAsync(ct);
        await using var tx   = await conn.BeginTransactionAsync(ct);

        // PostgreSQL ではテーブル名変更がほぼ瞬間で完了（メタデータ操作のみ）
        await conn.ExecuteAsync($"""
            ALTER TABLE {current} RENAME TO {current}_old;
            ALTER TABLE {next} RENAME TO {current};
            DROP TABLE {current}_old;
            """, transaction: tx);

        await tx.CommitAsync(ct);
        _logger.LogInformation("Table swap completed: {Next} → {Current}", next, current);
    }

    private async Task CreateTempTableAsync(string tableName, CancellationToken ct)
    {
        await using var conn = await _readDb.OpenConnectionAsync(ct);
        await conn.ExecuteAsync($"""
            CREATE TABLE {tableName} (LIKE order_summaries INCLUDING ALL);
            """);
    }
}
```

### 3.4 Snapshot Projection（集計値のスナップショット）

**適用場面**: 計算コストの高い集計値を事前に保存しておきたい場合。売上集計、ランキング、ダッシュボード数値など。

**特徴**:
- イベント発生の度に毎回集計しない（事前計算）
- 定期バッチ（cronベース）またはイベントトリガーで更新
- リアルタイム性より計算コスト削減を優先
- 「この数値は X 分前の値です」と明示するUI設計が望ましい

```csharp
// Snapshot Read Model テーブル
// CREATE TABLE revenue_snapshots (
//     id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
//     snapshot_date DATE NOT NULL,
//     period        TEXT NOT NULL,  -- 'daily' | 'monthly' | 'yearly'
//     total_revenue NUMERIC(14,2) NOT NULL,
//     order_count   INTEGER NOT NULL,
//     avg_order_value NUMERIC(10,2) NOT NULL,
//     top_products  JSONB NOT NULL,  -- [{product_id, revenue, count}]
//     computed_at   TIMESTAMPTZ NOT NULL,
//     UNIQUE(snapshot_date, period)
// );

public class RevenueSnapshotProjector
{
    private readonly NpgsqlDataSource _writeDb;   // 元データ（Write Store）
    private readonly NpgsqlDataSource _readDb;    // 保存先（Read Store）

    // 日次スナップショット更新（前日分を対象）
    public async Task UpdateDailySnapshotAsync(DateOnly targetDate, CancellationToken ct = default)
    {
        // Write Store から集計（重い処理だが1日1回）
        const string aggregateSql = """
            SELECT
                COALESCE(SUM(oi.unit_price * oi.quantity), 0) AS total_revenue,
                COUNT(DISTINCT o.id)                          AS order_count,
                COALESCE(AVG(o.total_amount), 0)              AS avg_order_value
            FROM orders o
            JOIN order_items oi ON oi.order_id = o.id
            WHERE o.status = 'Completed'
              AND DATE(o.completed_at) = @TargetDate
            """;

        await using var writeConn = await _writeDb.OpenConnectionAsync(ct);
        var aggregate = await writeConn.QuerySingleAsync<RevenueAggregate>(
            aggregateSql, new { TargetDate = targetDate });

        const string topProductsSql = """
            SELECT
                oi.product_id,
                SUM(oi.unit_price * oi.quantity) AS revenue,
                SUM(oi.quantity)                 AS item_count
            FROM orders o
            JOIN order_items oi ON oi.order_id = o.id
            WHERE o.status = 'Completed'
              AND DATE(o.completed_at) = @TargetDate
            GROUP BY oi.product_id
            ORDER BY revenue DESC
            LIMIT 10
            """;

        var topProducts = (await writeConn.QueryAsync<TopProductRow>(
            topProductsSql, new { TargetDate = targetDate })).ToList();

        // Read Store に Upsert
        const string upsertSql = """
            INSERT INTO revenue_snapshots
                (snapshot_date, period, total_revenue, order_count, avg_order_value, top_products, computed_at)
            VALUES
                (@SnapshotDate, 'daily', @TotalRevenue, @OrderCount, @AvgOrderValue, @TopProducts::jsonb, now())
            ON CONFLICT (snapshot_date, period) DO UPDATE SET
                total_revenue   = EXCLUDED.total_revenue,
                order_count     = EXCLUDED.order_count,
                avg_order_value = EXCLUDED.avg_order_value,
                top_products    = EXCLUDED.top_products,
                computed_at     = EXCLUDED.computed_at
            """;

        await using var readConn = await _readDb.OpenConnectionAsync(ct);
        await readConn.ExecuteAsync(upsertSql, new
        {
            SnapshotDate  = targetDate,
            aggregate.TotalRevenue,
            aggregate.OrderCount,
            aggregate.AvgOrderValue,
            TopProducts   = JsonSerializer.Serialize(topProducts)
        });
    }
}
```

---

## 4. Read Model Store の選択

### 4.1 選択基準マトリクス

| 要件 | PostgreSQL (正規化) | PostgreSQL (非正規化) | Redis | Elasticsearch |
|------|--------------------|-----------------------|-------|---------------|
| 複雑な関係性クエリ | ◎ | △ | × | △ |
| 全文検索 | △ | △ | × | ◎ |
| 集計・分析 | ○ | ◎ | × | ○ |
| サブミリ秒レスポンス | × | △ | ◎ | △ |
| セッション単位データ | × | × | ◎ | × |
| スキーマ柔軟性 | × | △ | ◎ | ◎ |
| データ量（大規模） | ○ | ○ | △ | ◎ |
| トランザクション | ◎ | ◎ | × | × |
| 運用コスト | ○ | ○ | ○ | △ |

**判断フローチャート**:

```mermaid
flowchart TD
    Q1{全文検索が必要?}
    Q2{ミリ秒以下の応答が必要?}
    Q3{データ量 > 数億件?}
    Q4{複雑な関係性・JOIN?}
    ES["Elasticsearch"]
    REDIS["Redis Cache"]
    PG_NON["PostgreSQL\n非正規化テーブル"]
    PG_NORM["PostgreSQL\nMaterialized View"]

    Q1 -->|Yes| ES
    Q1 -->|No| Q2
    Q2 -->|Yes| REDIS
    Q2 -->|No| Q3
    Q3 -->|Yes| PG_NON
    Q3 -->|No| Q4
    Q4 -->|Yes| PG_NORM
    Q4 -->|No| PG_NON
```

### 4.2 PostgreSQL Materialized View（C# 実装）

Materialized View は PostgreSQL が管理する「クエリ結果の物理コピー」です。定期的に `REFRESH MATERIALIZED VIEW` を実行することで最新状態に保ちます。

```sql
-- Materialized View の定義
CREATE MATERIALIZED VIEW mv_order_summaries AS
SELECT
    o.id,
    o.customer_id,
    c.name        AS customer_name,
    c.email       AS customer_email,
    o.status,
    COUNT(oi.id)  AS item_count,
    SUM(oi.unit_price * oi.quantity) AS total_amount,
    o.created_at,
    o.updated_at,
    ARRAY_AGG(DISTINCT oi.product_id) AS product_ids
FROM orders o
JOIN customers c ON c.id = o.customer_id
JOIN order_items oi ON oi.order_id = o.id
GROUP BY o.id, o.customer_id, c.name, c.email, o.status, o.created_at, o.updated_at
WITH DATA;  -- 定義と同時にデータも生成

-- 並行リフレッシュ（ロック最小化）← CONCURRENTLY は UNIQUE INDEX が必要
CREATE UNIQUE INDEX idx_mv_order_summaries_id ON mv_order_summaries(id);

-- リフレッシュ（ロックなしで実行可能）
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_order_summaries;
```

```csharp
// C# からのリフレッシュ制御
public class MaterializedViewRefresher : BackgroundService
{
    private readonly NpgsqlDataSource _db;
    private readonly ILogger<MaterializedViewRefresher> _logger;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        // 5分ごとにリフレッシュ
        using var timer = new PeriodicTimer(TimeSpan.FromMinutes(5));

        while (await timer.WaitForNextTickAsync(stoppingToken))
        {
            await RefreshAsync(stoppingToken);
        }
    }

    public async Task RefreshAsync(CancellationToken ct = default)
    {
        var sw = Stopwatch.StartNew();
        await using var conn = await _db.OpenConnectionAsync(ct);

        try
        {
            // CONCURRENTLY: 読み取りをブロックせずリフレッシュ
            await conn.ExecuteAsync(
                "REFRESH MATERIALIZED VIEW CONCURRENTLY mv_order_summaries");

            _logger.LogInformation(
                "Materialized view refreshed in {Elapsed}ms", sw.ElapsedMilliseconds);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to refresh materialized view");
        }
    }
}

// クエリの実装
public class OrderQueryRepository
{
    private readonly NpgsqlDataSource _db;

    public async Task<PagedResult<OrderSummaryDto>> GetOrderSummariesAsync(
        OrderSummaryQuery query, CancellationToken ct = default)
    {
        await using var conn = await _db.OpenConnectionAsync(ct);

        // Materialized View から直接 SELECT（非常に高速）
        const string sql = """
            SELECT id, customer_id, customer_name, status,
                   item_count, total_amount, created_at
            FROM mv_order_summaries
            WHERE (@CustomerId IS NULL OR customer_id = @CustomerId)
              AND (@Status IS NULL OR status = @Status)
            ORDER BY created_at DESC
            LIMIT @PageSize OFFSET @Offset
            """;

        var rows = await conn.QueryAsync<OrderSummaryDto>(sql, new
        {
            CustomerId = query.CustomerId,
            Status     = query.Status,
            PageSize   = query.PageSize,
            Offset     = (query.Page - 1) * query.PageSize
        });

        return new PagedResult<OrderSummaryDto>(rows.ToList(), /* count= */ 0);
    }
}
```

### 4.3 Redis キャッシュ（C# 実装）

```csharp
// Redis を使った Read Model キャッシュ
public class CachedOrderQueryRepository : IOrderQueryRepository
{
    private readonly IOrderQueryRepository _inner;   // 実際のDBアクセス
    private readonly IConnectionMultiplexer _redis;
    private readonly ILogger<CachedOrderQueryRepository> _logger;
    private static readonly TimeSpan _ttl = TimeSpan.FromMinutes(10);

    public async Task<OrderSummaryDto?> GetByIdAsync(Guid orderId, CancellationToken ct = default)
    {
        var db  = _redis.GetDatabase();
        var key = $"order_summary:{orderId}";

        // Cache Hit
        var cached = await db.StringGetAsync(key);
        if (cached.HasValue)
        {
            _logger.LogDebug("Cache HIT for order {OrderId}", orderId);
            return JsonSerializer.Deserialize<OrderSummaryDto>(cached.ToString());
        }

        // Cache Miss → DB から取得
        _logger.LogDebug("Cache MISS for order {OrderId}", orderId);
        var dto = await _inner.GetByIdAsync(orderId, ct);

        if (dto is not null)
        {
            // キャッシュに保存
            await db.StringSetAsync(key, JsonSerializer.Serialize(dto), _ttl);
        }

        return dto;
    }

    // Projection が Read Model を更新した時にキャッシュを無効化
    public async Task InvalidateCacheAsync(Guid orderId)
    {
        var db  = _redis.GetDatabase();
        var key = $"order_summary:{orderId}";
        await db.KeyDeleteAsync(key);
        _logger.LogInformation("Cache invalidated for order {OrderId}", orderId);
    }
}

// IServiceCollection 登録（Decorator パターン）
services.AddScoped<IOrderQueryRepository, OrderQueryRepository>();
services.Decorate<IOrderQueryRepository, CachedOrderQueryRepository>();
```

### 4.4 Elasticsearch（全文検索、C# 実装）

```csharp
// Elasticsearch 用 Read Model Document
public record OrderSearchDocument
{
    public string Id           { get; init; } = "";
    public string CustomerName { get; init; } = "";
    public string Status       { get; init; } = "";
    public decimal TotalAmount { get; init; }
    public DateTime CreatedAt  { get; init; }
    public List<string> ProductNames { get; init; } = new();
    public List<string> Tags         { get; init; } = new();
    public string Notes              { get; init; } = "";  // 自由記述（全文検索対象）
}

// Elasticsearch Projector
public class OrderSearchProjector
{
    private readonly ElasticsearchClient _esClient;
    private const string IndexName = "orders";

    public async Task OnOrderPlacedAsync(OrderPlaced @event)
    {
        var doc = new OrderSearchDocument
        {
            Id           = @event.OrderId.ToString(),
            CustomerName = @event.CustomerName,
            Status       = "Placed",
            TotalAmount  = @event.Items.Sum(i => i.UnitPrice * i.Quantity),
            CreatedAt    = @event.OccurredAt,
            ProductNames = @event.Items.Select(i => i.ProductName).ToList(),
            Tags         = @event.Tags,
            Notes        = @event.Notes ?? ""
        };

        var response = await _esClient.IndexAsync(doc, idx => idx
            .Index(IndexName)
            .Id(doc.Id));

        if (!response.IsSuccess())
        {
            throw new InvalidOperationException(
                $"ES index failed: {response.ElasticsearchServerError?.Error.Reason}");
        }
    }

    // 全文検索クエリ
    public async Task<List<OrderSearchDocument>> SearchAsync(string keyword, int page, int size)
    {
        var response = await _esClient.SearchAsync<OrderSearchDocument>(s => s
            .Index(IndexName)
            .From((page - 1) * size)
            .Size(size)
            .Query(q => q
                .MultiMatch(mm => mm
                    .Fields(f => f
                        .Field(d => d.CustomerName, boost: 2.0)
                        .Field(d => d.ProductNames, boost: 1.5)
                        .Field(d => d.Notes))
                    .Query(keyword)
                    .Type(TextQueryType.BestFields)
                    .Fuzziness(new Fuzziness("AUTO")))));

        return response.Documents.ToList();
    }
}
```

---

## 5. Dapper での Query 実装（完全版）

### 5.1 基盤クラスと接続管理

```csharp
// Query Repository の基底クラス
public abstract class DapperQueryRepositoryBase
{
    protected readonly NpgsqlDataSource DataSource;
    protected readonly ILogger Logger;

    protected DapperQueryRepositoryBase(NpgsqlDataSource dataSource, ILogger logger)
    {
        DataSource = dataSource;
        Logger     = logger;
    }

    protected async Task<T?> QuerySingleOrDefaultAsync<T>(
        string sql,
        object? param = null,
        CancellationToken ct = default)
    {
        await using var conn = await DataSource.OpenConnectionAsync(ct);
        return await conn.QuerySingleOrDefaultAsync<T>(sql, param);
    }

    protected async Task<IReadOnlyList<T>> QueryAsync<T>(
        string sql,
        object? param = null,
        CancellationToken ct = default)
    {
        await using var conn = await DataSource.OpenConnectionAsync(ct);
        return (await conn.QueryAsync<T>(sql, param)).ToList();
    }

    protected async Task<PagedResult<T>> QueryPagedAsync<T>(
        string dataSql,
        string countSql,
        object param,
        CancellationToken ct = default)
    {
        await using var conn = await DataSource.OpenConnectionAsync(ct);

        // 並列実行でページデータと総件数を同時取得
        var dataTask  = conn.QueryAsync<T>(dataSql, param);
        var countTask = conn.QuerySingleAsync<int>(countSql, param);

        await Task.WhenAll(dataTask, countTask);

        return new PagedResult<T>(
            Items:      (await dataTask).ToList(),
            TotalCount: await countTask);
    }
}
```

### 5.2 ページング・ソート・複合フィルタ・集計クエリ

```csharp
public class OrderQueryRepository : DapperQueryRepositoryBase, IOrderQueryRepository
{
    public OrderQueryRepository(NpgsqlDataSource dataSource, ILogger<OrderQueryRepository> logger)
        : base(dataSource, logger) { }

    // ページング + ソート + 複合フィルタ
    public async Task<PagedResult<OrderSummaryDto>> SearchAsync(
        OrderSearchQuery query,
        CancellationToken ct = default)
    {
        // ホワイトリスト方式でソートカラムを検証（SQLインジェクション対策）
        var allowedSortColumns = new HashSet<string>
        {
            "created_at", "total_amount", "item_count", "customer_name"
        };

        var sortColumn = allowedSortColumns.Contains(query.SortBy)
            ? query.SortBy
            : "created_at";

        var sortDirection = query.SortDesc ? "DESC" : "ASC";

        // 動的 WHERE 句の構築（Dapper DynamicParameters を使用）
        var conditions = new List<string> { "1 = 1" };
        var parameters = new DynamicParameters();

        if (query.CustomerId.HasValue)
        {
            conditions.Add("os.customer_id = @CustomerId");
            parameters.Add("CustomerId", query.CustomerId.Value);
        }

        if (!string.IsNullOrWhiteSpace(query.Status))
        {
            conditions.Add("os.status = @Status");
            parameters.Add("Status", query.Status);
        }

        if (query.MinAmount.HasValue)
        {
            conditions.Add("os.total_amount >= @MinAmount");
            parameters.Add("MinAmount", query.MinAmount.Value);
        }

        if (query.MaxAmount.HasValue)
        {
            conditions.Add("os.total_amount <= @MaxAmount");
            parameters.Add("MaxAmount", query.MaxAmount.Value);
        }

        if (query.FromDate.HasValue)
        {
            conditions.Add("os.created_at >= @FromDate");
            parameters.Add("FromDate", query.FromDate.Value);
        }

        if (query.ToDate.HasValue)
        {
            conditions.Add("os.created_at < @ToDate");
            parameters.Add("ToDate", query.ToDate.Value);
        }

        if (query.ProductIds is { Count: > 0 })
        {
            // 配列のオーバーラップ演算子（&& = 任意の要素が含まれる）
            conditions.Add("os.product_ids && @ProductIds");
            parameters.Add("ProductIds", query.ProductIds.ToArray());
        }

        var whereClause = string.Join(" AND ", conditions);

        // ページネーション用パラメータ
        parameters.Add("PageSize", query.PageSize);
        parameters.Add("Offset",   (query.Page - 1) * query.PageSize);

        // データクエリ（ソート・ページング適用）
        // ※ sortColumn と sortDirection は ホワイトリスト検証済みのため文字列補間 OK
        var dataSql = $"""
            SELECT
                os.id,
                os.customer_id,
                os.customer_name,
                os.customer_email,
                os.status,
                os.item_count,
                os.total_amount,
                os.created_at,
                os.updated_at
            FROM order_summaries os
            WHERE {whereClause}
            ORDER BY os.{sortColumn} {sortDirection}
            LIMIT @PageSize OFFSET @Offset
            """;

        // カウントクエリ（ソート・ページング なし）
        var countSql = $"""
            SELECT COUNT(*)
            FROM order_summaries os
            WHERE {whereClause}
            """;

        return await QueryPagedAsync<OrderSummaryDto>(dataSql, countSql, parameters, ct);
    }

    // N+1 を避ける JOIN の書き方（Order + Items を一発で取得）
    public async Task<OrderDetailDto?> GetDetailAsync(Guid orderId, CancellationToken ct = default)
    {
        // 1クエリで Order と OrderItems を結合取得
        // Dapper の Multi-Mapping を使い、C# 側でグルーピングする
        const string sql = """
            SELECT
                o.id,
                o.customer_id,
                o.customer_name,
                o.customer_email,
                o.status,
                o.total_amount,
                o.created_at,
                -- OrderItem fields（別名でコンフリクト回避）
                oi.id         AS item_id,
                oi.product_id,
                oi.product_name,
                oi.unit_price,
                oi.quantity,
                oi.subtotal
            FROM order_summaries o
            LEFT JOIN order_item_summaries oi ON oi.order_id = o.id
            WHERE o.id = @OrderId
            ORDER BY oi.sort_order
            """;

        await using var conn = await DataSource.OpenConnectionAsync(ct);

        OrderDetailDto? result = null;

        await conn.QueryAsync<OrderDetailDto, OrderItemDto, OrderDetailDto>(
            sql,
            (order, item) =>
            {
                // 初回: order 本体をセット
                result ??= order with { Items = new List<OrderItemDto>() };

                // item が null でなければ追加（LEFT JOIN の空結果対応）
                if (item?.ItemId != Guid.Empty)
                {
                    ((List<OrderItemDto>)result.Items).Add(item!);
                }

                return result;
            },
            new { OrderId = orderId },
            splitOn: "item_id");

        return result;
    }

    // 集計クエリ（ダッシュボード用）
    public async Task<OrderAggregateDto> GetAggregateAsync(
        DateOnly from, DateOnly to, CancellationToken ct = default)
    {
        const string sql = """
            SELECT
                COUNT(*)                                AS total_orders,
                COALESCE(SUM(total_amount), 0)         AS total_revenue,
                COALESCE(AVG(total_amount), 0)         AS avg_order_value,
                COALESCE(MAX(total_amount), 0)         AS max_order_value,
                COUNT(*) FILTER (WHERE status = 'Completed')  AS completed_count,
                COUNT(*) FILTER (WHERE status = 'Cancelled')  AS cancelled_count,
                COUNT(DISTINCT customer_id)            AS unique_customers
            FROM order_summaries
            WHERE created_at >= @From AND created_at < @To
            """;

        return await QuerySingleOrDefaultAsync<OrderAggregateDto>(sql, new
        {
            From = from.ToDateTime(TimeOnly.MinValue, DateTimeKind.Utc),
            To   = to.AddDays(1).ToDateTime(TimeOnly.MinValue, DateTimeKind.Utc)
        }, ct) ?? new OrderAggregateDto();
    }

    // 日次時系列集計（グラフ用）
    public async Task<IReadOnlyList<DailyRevenueDto>> GetDailyRevenueAsync(
        DateOnly from, DateOnly to, CancellationToken ct = default)
    {
        const string sql = """
            WITH date_series AS (
                SELECT generate_series(@From::date, @To::date, '1 day'::interval)::date AS dt
            )
            SELECT
                ds.dt                                         AS date,
                COALESCE(COUNT(os.id), 0)                    AS order_count,
                COALESCE(SUM(os.total_amount), 0)            AS revenue
            FROM date_series ds
            LEFT JOIN order_summaries os
                ON DATE(os.created_at) = ds.dt
                AND os.status = 'Completed'
            GROUP BY ds.dt
            ORDER BY ds.dt
            """;

        return await QueryAsync<DailyRevenueDto>(sql, new { From = from, To = to }, ct);
    }

    // 全文検索（PostgreSQL の tsvector を使う場合）
    public async Task<IReadOnlyList<OrderSummaryDto>> FullTextSearchAsync(
        string keyword, int limit = 20, CancellationToken ct = default)
    {
        // SQLインジェクション対策: to_tsquery はパラメータで渡す
        // plainto_tsquery は任意文字列を安全に変換する関数
        const string sql = """
            SELECT id, customer_name, status, total_amount, created_at
            FROM order_summaries
            WHERE search_vector @@ plainto_tsquery('japanese', @Keyword)
            ORDER BY ts_rank(search_vector, plainto_tsquery('japanese', @Keyword)) DESC
            LIMIT @Limit
            """;

        return await QueryAsync<OrderSummaryDto>(sql, new { Keyword = keyword, Limit = limit }, ct);
    }
}
```

### 5.3 SQL インジェクション対策の完全チェックリスト

```csharp
// NG 例 — 文字列連結でパラメータを組み立てる
var badSql = $"SELECT * FROM orders WHERE status = '{query.Status}'";
// → status = 'Placed'; DROP TABLE orders; -- が通ってしまう

// OK 例 — Dapper パラメータを常に使う
var goodSql = "SELECT * FROM orders WHERE status = @Status";
await conn.QueryAsync(goodSql, new { query.Status });

// NG 例 — ソートカラムをそのまま補間
var badSort = $"ORDER BY {query.SortBy} {query.SortDirection}";

// OK 例 — ホワイトリスト検証後に補間
var allowedColumns   = new HashSet<string> { "created_at", "total_amount" };
var allowedDirections = new HashSet<string> { "ASC", "DESC" };
var col = allowedColumns.Contains(query.SortBy)   ? query.SortBy       : "created_at";
var dir = allowedDirections.Contains(query.Dir)   ? query.Dir           : "DESC";
var goodSort = $"ORDER BY {col} {dir}";  // 補間対象がホワイトリスト検証済み

// NG 例 — IN 句を手動構築
var ids  = new[] { id1, id2, id3 };
var badIn = $"WHERE id IN ({string.Join(",", ids)})";  // UUIDでも文字操作は危険

// OK 例 — Dapper の配列パラメータを使う
await conn.QueryAsync("WHERE id = ANY(@Ids)", new { Ids = ids });
```

---

## 6. Read Model の整合性戦略

### 6.1 即時整合性 vs 最終整合性

| 項目 | 即時整合性 | 最終整合性 |
|------|-----------|-----------|
| 実装パターン | Synchronous Projection | Async Projection (Outbox) |
| コマンドのレイテンシ | 遅い（Read Store 更新分の追加時間） | 速い（Read Store 更新は別スレッド） |
| データの鮮度 | コマンド完了と同時に最新 | 数百ms〜数秒の遅延 |
| 障害時の挙動 | Read Store 更新失敗 → コマンド全体ロールバック | コマンドは成功。Projection は後でリトライ |
| 適用場面 | 金融取引、在庫管理など整合性が最優先 | SNS、ECの一覧画面など多少の遅延が許容される |

**使い分けの原則**: 「ユーザーが今書いたものを、すぐに読み返す」操作は即時整合性を使いましょう。「一覧ページのサマリーを表示する」操作は最終整合性で十分です。

### 6.2 クライアントに「更新されていない可能性」を伝える

最終整合性の世界では、クライアントに「このデータは最新ではないかもしれない」という情報を伝えることが重要です。

```csharp
// Read Model に computed_at を持たせる
public record OrderSummaryDto
{
    public Guid     Id          { get; init; }
    public string   Status      { get; init; } = "";
    public decimal  TotalAmount { get; init; }
    public DateTime CreatedAt   { get; init; }
    public DateTime ComputedAt  { get; init; }  // この Read Model が最後に更新された時刻
}

// API レスポンスに staleness 情報を付与
public record PagedOrderSummaryResponse(
    IReadOnlyList<OrderSummaryDto> Items,
    int TotalCount,
    DateTime ProjectionLagThreshold,  // この時刻以降のデータは最新でない可能性
    bool IsStale);                     // 遅延が閾値超えているか

// Controller での staleness 判定
[HttpGet("orders")]
public async Task<IActionResult> GetOrders([FromQuery] OrderSearchQuery query)
{
    var result = await _queryService.SearchAsync(query);

    var threshold      = DateTime.UtcNow - TimeSpan.FromSeconds(30);
    var oldestComputed = result.Items.MinBy(i => i.ComputedAt)?.ComputedAt ?? DateTime.UtcNow;
    var isStale        = oldestComputed < threshold;

    return Ok(new PagedOrderSummaryResponse(
        Items:                   result.Items,
        TotalCount:              result.TotalCount,
        ProjectionLagThreshold:  threshold,
        IsStale:                 isStale));
}
```

### 6.3 WebSocket / Server-Sent Events との組み合わせ

```csharp
// Server-Sent Events でリアルタイム更新通知
[HttpGet("orders/stream")]
public async Task StreamOrderUpdates(
    [FromQuery] Guid customerId,
    CancellationToken ct)
{
    Response.Headers["Content-Type"]  = "text/event-stream";
    Response.Headers["Cache-Control"] = "no-cache";
    Response.Headers["Connection"]    = "keep-alive";

    // Projection 完了イベントを購読
    await foreach (var update in _projectionEventChannel.ReadAsync(customerId, ct))
    {
        var json  = JsonSerializer.Serialize(update);
        var data  = $"data: {json}\n\n";
        var bytes = Encoding.UTF8.GetBytes(data);

        await Response.Body.WriteAsync(bytes, ct);
        await Response.Body.FlushAsync(ct);
    }
}

// Projector から更新通知を発行
public class OrderSummaryProjector
{
    private readonly Channel<OrderUpdateNotification> _channel;

    public async Task OnOrderPlacedAsync(OrderPlaced @event)
    {
        // Read Store を更新
        await UpdateReadStoreAsync(@event);

        // SSE クライアントに通知
        await _channel.Writer.WriteAsync(new OrderUpdateNotification(
            CustomerId: @event.CustomerId,
            OrderId:    @event.OrderId,
            EventType:  "OrderPlaced"));
    }
}
```

---
