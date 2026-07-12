---
title: "付録C: DDD総合判断フローチャート"
---

# 付録 C: DDD 総合判断フローチャート

本付録では、DDD を実践する際に繰り返し直面する設計の判断ポイントを、フローチャートと説明文で整理します。「どこで DDD を使うか」から「個々のオブジェクトをどう設計するか」まで、6 つの判断フローを提供します。

---

## C.1 DDD を使うかどうかの判断フロー

### フローチャート

```mermaid
flowchart TD
    START([新しいシステム・機能の開発開始]) --> Q1{ドメインの複雑さは\n「高い」か？}

    Q1 -->|No: 単純なCRUD中心| SIMPLE[トランザクションスクリプト\nまたはActive Recordパターン\nで十分]
    Q1 -->|Yes| Q2{ドメインエキスパートと\n継続的に協働できるか？}

    Q2 -->|No: エキスパートがいない| WARN1[⚠️ DDDは難しい\nドキュメントから\nドメインを理解する努力を先行]
    Q2 -->|Yes| Q3{チームがOOPと\n設計パターンに習熟しているか？}

    Q3 -->|No: 学習コストが高い| WARN2[⚠️ 学習フェーズを設ける\nシンプルなパターンから始める]
    Q3 -->|Yes| Q4{プロジェクトのライフタイムは\n長期（1年以上）か？}

    Q4 -->|No: 短期プロジェクト| SIMPLE2[軽量なアプローチを選択\nDDDの用語だけ借用でも可]
    Q4 -->|Yes| Q5{ビジネスルールが\n頻繁に変更されるか？}

    Q5 -->|No: 安定したルール| PARTIAL[部分的にDDDを採用\nCore Domainのみに適用]
    Q5 -->|Yes| Q6{予算・スケジュールに\nDDDの学習コストを\n織り込めるか？}

    Q6 -->|No| WARN3[⚠️ スコープを絞って\nCore Domainのみに適用]
    Q6 -->|Yes| DDD_FULL[✅ DDD を本格採用\nEvent Stormingから開始]

    SIMPLE --> NOTE1([CRUD画面・管理ツール・\nレポート生成などに適する])
    DDD_FULL --> NOTE2([戦略的設計→戦術的設計の\n順序で進める])
```

### 判断ポイントの説明

DDD はすべてのシステムに適用すべき「銀の弾丸」ではありません。最初の判断軸は「ドメインの複雑さ」です。ドメインの複雑さとは、ビジネスルールの量・変更頻度・例外ケースの多さによって測られます。例えば、単純な商品マスタの CRUD 画面は DDD の恩恵を受けにくく、むしろオーバーエンジニアリングになります。一方、保険の引受審査・金融商品の価格計算・物流の配送ルート最適化などは、ルールが複雑で変化するため DDD が力を発揮します。

重要なのは「ドメインエキスパートとの協働可能性」です。DDD は開発者だけで実践できる手法ではなく、ビジネスの専門家との継続的な対話が前提です。エキスパートが協働できない場合、Ubiquitous Language の確立もモデルの検証もできません。

また「チームの習熟度」と「プロジェクト期間」も重要です。DDD の学習コスト（Value Object・Aggregate 設計・Event Storming の実践など）は 3〜6 ヶ月単位の投資です。短期プロジェクトではその回収が困難なため、軽量なアプローチを選ぶことが合理的です。

「すべてに DDD を適用する必要はない」という認識も大切です。Eric Evans 自身が Core Domain 以外への過剰適用を戒めています。まず Core Domain を特定し、そこにのみ DDD のパワーを集中させるアプローチが成功率を高めます。

---

## C.2 Value Object vs Entity の判断フロー

### フローチャート

```mermaid
flowchart TD
    START([新しいドメイン概念の設計]) --> Q1{この概念は\n「識別子」が必要か？\n同じ値でも別物として\n区別する必要があるか？}

    Q1 -->|Yes: 個体を追跡する| ENTITY_PATH[Entityの方向へ]
    Q1 -->|No: 値が等しければ同じ| VO_PATH[Value Objectの方向へ]

    VO_PATH --> QV1{不変（イミュータブル）\nにできるか？}
    QV1 -->|Yes| QV2{ドメインのルール\n（バリデーション）を\nコンストラクタで\n強制できるか？}
    QV2 -->|Yes| VO[✅ Value Object\nC#: record型で実装\n例: Money, Email,\nAddress, DateRange]
    QV2 -->|No: ルールが複雑すぎる| CONSIDER[Domain Serviceで\nバリデーションを分離]
    QV1 -->|No: 状態が変わる| RETHINK[概念の再考が必要\n変化するなら識別子が\n必要な可能性がある]

    ENTITY_PATH --> QE1{この概念は\nAggregateのルートか？\n外部から直接参照され\nリポジトリで取得されるか？}
    QE1 -->|Yes| AGG_ROOT[Aggregate Root\nとしてのEntity\n例: Order, Customer]
    QE1 -->|No: Aggregate内の子| CHILD_ENTITY[Aggregate内の\n子Entityとして実装\n例: OrderLine,\nOrderPayment]

    AGG_ROOT --> NOTE1([グローバルなIDを持つ\nRepositoryの対象])
    CHILD_ENTITY --> NOTE2([Aggregate Root経由でのみ\nアクセス可能])
    VO --> NOTE3([等価比較はすべての\nプロパティの値で判断])
```

### 判断ポイントの説明

Value Object と Entity の判断は「同一性をどう定義するか」という哲学的な問いです。最初に問うべきは「この 2 つのインスタンスが同じかどうかを、どうやって判断するか？」です。

「1000 円」という金額は、どの 1000 円でも同じです。誰の財布にある 1000 円かを追跡する必要はありません。これが Value Object の特性です。一方「顧客 ID: C001 の田中さん」は、名前が「山田さん」に変わっても同じ顧客として追跡する必要があります。これが Entity の特性です。

Value Object は不変性が必須です。一度作られた Value Object は変更されず、値を変えたい場合は新しい Value Object を作成します（例：`money.Add(new Money(500, "JPY"))` は `money` を変えず新しい `Money` を返す）。この不変性により、副作用のない安全なオブジェクトが実現します。

C# の `record` 型は Value Object に最適です。`record Money(decimal Amount, string Currency)` と定義するだけで、値ベースの等価比較（`==` 演算子で両フィールドを比較）が自動的に実装されます。

Entity を設計する際は「Aggregate Root かどうか」のさらなる判断が必要です。Repository の対象となり外部から直接取得されるものは Aggregate Root、Aggregate の内部にのみ存在するものは子 Entity です。子 Entity は Aggregate Root を経由してのみアクセスできます。

---

## C.3 Aggregate 境界の決定フロー

### フローチャート

```mermaid
flowchart TD
    START([Aggregateの境界を設計する]) --> Q1{この Aggregate が守るべき\nInvariant（不変条件）は何か？\nを列挙する}

    Q1 --> Q2{Invariantの検証に\n他の Aggregate の\nデータが必要か？}

    Q2 -->|No: 自分のデータのみ| GOOD_BOUNDARY[境界が適切な可能性が高い]
    Q2 -->|Yes| Q3{その整合性は\n「即時」に必要か？}

    Q3 -->|No: 数秒後でもよい| EVENTUAL[Eventual Consistency\nで解決\nDomain Event → 別Aggregateへ通知]
    Q3 -->|Yes: ビジネス上即時必須| EXPAND[Aggregate境界の\n拡張を検討\n※慎重に！]

    GOOD_BOUNDARY --> Q4{Aggregateのサイズは\n小さいか？\n（含むEntityが3〜5以下）}

    Q4 -->|Yes| Q5{一度のトランザクションで\n1つのAggregateのみを\n変更できるか？}
    Q4 -->|No: 大きすぎる| SPLIT[Aggregateの分割を検討\nどのEntityが本当に必要か再考]

    Q5 -->|Yes| VALID_AGG[✅ 適切なAggregate設計]
    Q5 -->|No: 複数変更が必要| Q6{その必要性はUIの\n都合ではないか？}

    Q6 -->|Yes: UIの都合| UI_FIX[UIを修正するか\nSagaを使って\n結果整合に変更]
    Q6 -->|No: ビジネス要件| SAGA_PATH[Sagaまたは\nProcess Managerで\n複数Aggregateを協調]

    EXPAND --> WARNING[⚠️ 大きいAggregateは\n並行性問題を起こしやすい\n本当に必要か再検討]
    SPLIT --> NOTE([例: Order → OrderHeader + OrderPayment\nに分割できないか？])
```

### 判断ポイントの説明

Aggregate の境界設計は DDD 実践において最も難しい判断の一つです。Vaughn Vernon は「できる限り小さな Aggregate を設計し、必要な場合のみ拡張せよ」と述べています。

最初のステップは「Invariant の列挙」です。例えば Order Aggregate なら「注文アイテムの合計金額は正でなければならない」「確定済み注文のアイテムは変更できない」などです。これらの Invariant を保護するために最低限必要なエンティティ・値オブジェクトの集合が Aggregate の境界候補となります。

次の重要な問いは「整合性は即時に必要か」です。多くの場合、ビジネスルールが「即時整合性が必須」に見えても、実際には数秒〜数分のずれが許容されます。例えば「注文後に在庫を減らす」は、即時である必要はなく Eventual Consistency で十分です（在庫引き当ての失敗を後処理で対応）。この判断を誤り、多くのエンティティを一つの Aggregate に詰め込むと、トランザクション競合・パフォーマンス低下・テストの複雑化などの問題が起きます。

「一つのトランザクションで一つの Aggregate のみを変更する」原則は、特に現場で抵抗を受けやすい指針です。しかし、この原則を守ることで、システムの並行性が格段に向上します。複数の Aggregate を変更したい場合は、Saga や Domain Event を使って非同期に処理します。

---

## C.4 Domain Service vs Application Service の判断フロー

### フローチャート

```mermaid
flowchart TD
    START([サービスクラスの配置を決める]) --> Q1{このロジックに\nドメインのルール・知識が\n含まれているか？}

    Q1 -->|No: インフラ・調整のみ| APP_SVC[Application Service\nまたはCommand Handler\nとして実装]
    Q1 -->|Yes: ビジネスロジックあり| Q2{そのロジックは\n単一のEntityまたは\nAggregateに自然に\n収まるか？}

    Q2 -->|Yes: 自然に収まる| MOVE_TO_ENTITY[そのEntity/Aggregateの\nメソッドとして実装\nAnemic Domain Model回避]
    Q2 -->|No: 複数のオブジェクトを扱う| Q3{外部システムや\nインフラ（DB・API）への\nアクセスが必要か？}

    Q3 -->|No: 純粋なドメイン計算| DOMAIN_SVC_PURE[✅ Domain Service\n（ドメイン層に配置）\n例: TransferService,\nPricingService]
    Q3 -->|Yes: 外部アクセスが必要| Q4{その外部依存を\nインターフェースとして\nドメイン層に定義できるか？}

    Q4 -->|Yes| DOMAIN_SVC_IFACE[✅ Domain Service\nインターフェースをドメイン層に\n実装をインフラ層に配置\n例: IInventoryChecker]
    Q4 -->|No: 分離困難| APP_SVC2[Application Service\nとして実装\nドメイン層への侵食を避ける]

    APP_SVC --> NOTE1([ユースケース調整・\nトランザクション管理・\nリポジトリ呼び出し])
    DOMAIN_SVC_PURE --> NOTE2([ステートレス・\n副作用なし・\nドメイン用語で記述])
    DOMAIN_SVC_IFACE --> NOTE3([実装はインフラ層\nテスト時はモックに差し替え])
```

### 判断ポイントの説明

Domain Service と Application Service の混乱は DDD 実践でよく起こる問題です。両者の最大の違いは「ドメインロジックを持つかどうか」です。

Application Service（MediatR では Command Handler）はユースケースの調整役です。「リポジトリから Aggregate を取得する」「Aggregate のメソッドを呼ぶ」「変更を保存する」「Domain Event を発行する」という手順を管理しますが、自らビジネスの判断を下しません。Application Service が「もし〇〇なら△△する」という条件分岐を多数持ち始めたら、ドメインロジックが漏れ出しているサインです。

Domain Service はドメイン知識を持ちますが、特定のエンティティや値オブジェクトに自然に属さないロジックを担当します。典型例は「送金サービス（TransferService）」です。送金は「Source Account」と「Destination Account」の 2 つの Aggregate にまたがる操作であり、どちらか一方のメソッドとして実装するのは不自然です。こういった「複数のドメインオブジェクトを使ったドメインルールの適用」が Domain Service の出番です。

Domain Service が外部システム（在庫確認 API など）に依存する場合は、インターフェースをドメイン層に定義し（`IInventoryChecker`）、実装をインフラ層に置くことで依存性を逆転させます。これにより Domain Service のユニットテストでモックが利用できます。

「このロジックはどこに置くべきか」と迷った際のチェックリスト：(1) エンティティのメソッドにできないか？→まずここを検討 (2) 複数のドメインオブジェクトを使うか？→Domain Service (3) ビジネスルールなしに手順を調整するだけか？→Application Service

---

## C.5 Repository vs Direct Query の判断フロー

### フローチャート

```mermaid
flowchart TD
    START([データアクセスの実装方法を選ぶ]) --> Q1{この操作は\nデータの「書き込み」か\n「読み取り」か？}

    Q1 -->|書き込み（Command）| WRITE_PATH[書き込みパス]
    Q1 -->|読み取り（Query）| READ_PATH[読み取りパス]

    WRITE_PATH --> Q2{Aggregateの整合性を\n保護する必要があるか？\n（Invariantの検証あり）}
    Q2 -->|Yes| USE_REPO[✅ Repository を使用\nAggregate全体を取得→\nメソッド呼び出し→保存]
    Q2 -->|No: 単純な更新| Q3{それは本当に\nドメインロジックなしで\n安全か再確認}
    Q3 -->|確認OK| DIRECT_WRITE[⚠️ 直接更新可\nただし例外的ケースとして扱う]
    Q3 -->|要確認| USE_REPO

    READ_PATH --> Q4{取得した結果を\nビジネスロジックに\n使用するか？\n（Aggregateのメソッドを呼ぶか）}
    Q4 -->|Yes: ドメイン操作に使う| REPO_READ[Repository で\nAggregateを取得\n（EF Core）]
    Q4 -->|No: 表示・レポートのみ| Q5{複数テーブルを\nJOINする複雑な\nクエリが必要か？}

    Q5 -->|No: 単純な取得| SIMPLE_QUERY[どちらでも可\nRead Model Repositoryも選択肢]
    Q5 -->|Yes: 複雑なクエリ| DIRECT_QUERY[✅ Direct Query\n（Dapper + SQL）\nRead Model DTOを返す]

    DIRECT_QUERY --> NOTE1([CQRSのRead側\nEF Coreより高速\nドメインモデル不要])
    REPO_READ --> NOTE2([ドメインオブジェクトとして取得\n変更追跡あり])
    USE_REPO --> NOTE3([GetByIdAsync → ビジネスメソッド\n→ SaveAsync の流れ])
```

### 判断ポイントの説明

Repository を使うかどうかの判断は、CQRS の文脈で「Write 側か Read 側か」という問いに帰着します。

Write 側（Command 処理）では、原則として Repository を通じて Aggregate を取得します。理由は、Repository が Unit of Work（変更追跡）を通じて Aggregate の変更を自動的に検出し、保存時に整合性のある状態で永続化するためです。直接 SQL で UPDATE することは Aggregate の Invariant チェックを回避するリスクがあります（例：直接 ORDER 行を UPDATE すると、在庫との整合性チェックが実行されない）。

Read 側（Query 処理）では、多くの場合 Repository を使う必要がありません。Read 用のクエリは複数テーブルの JOIN・集計・ページング等を含むことが多く、Aggregate の形にデシリアライズしてから DTO に変換するのは無駄なコストです。Dapper を使った直接 SQL で Read Model DTO を返すアプローチが効率的です。

ただし例外もあります。ページネーションやフィルタリングが不要で、1 件の Aggregate を取得して表示するだけなら、EF Core の AsNoTracking() を使った Repository 経由でも十分なパフォーマンスが得られます。「パフォーマンスの問題が発生してから最適化する」というアプローチも合理的です。

EF Core と Dapper を共存させる設計（EF Core は Write 側・Dapper は Read 側）は多くの DDD プロジェクトで採用されており、実績のあるアプローチです。両方が同じ接続文字列とトランザクションを使えるよう、`IDbConnection` を `DbContext` から取得する形で統合します。

---

## C.6 Bounded Context の分割判断フロー

### フローチャート

```mermaid
flowchart TD
    START([Bounded Contextの\n分割が必要かを判断する]) --> Q1{現在のコンテキストで\n同じ用語が\n異なる意味を持つか？}

    Q1 -->|Yes: 用語の意味が異なる| SPLIT_CANDIDATE[分割の候補あり]
    Q1 -->|No: 用語は一貫| Q2{単一チームが\nすべてを\n管理できるか？}

    Q2 -->|Yes: 管理可能| Q3{変更が頻繁に\n影響し合う部分が\nあるか？}
    Q3 -->|No: 独立して変更可| SINGLE_OK[✅ 単一Bounded Contextで問題なし\n分割は不要]
    Q3 -->|Yes: 密結合| REFACTOR[内部の整理を検討\n分割前にモジュール化]

    Q2 -->|No: チームが大きくなった| TEAM_SPLIT[チーム分割に合わせて\nContext分割を検討\nConway's Lawを活用]

    SPLIT_CANDIDATE --> Q4{それぞれのモデルは\n独立してデプロイ・\nスケールする必要があるか？}
    Q4 -->|Yes| INDEPENDENT_DEPLOY[独立したマイクロサービスとして\n分割する価値が高い]
    Q4 -->|No: 同一デプロイでよい| Q5{チームが異なるか\nまたは将来分かれるか？}

    Q5 -->|Yes| MODULAR_MONOLITH[モジュラーモノリスとして\n内部でContextを分離\n将来のマイクロサービス化に備える]
    Q5 -->|No: 同一チーム| SINGLE_LARGE[単一Contextを維持しつつ\n内部でモジュール分割\nフォルダ・名前空間で境界を明示]

    INDEPENDENT_DEPLOY --> Q6{Contextの境界は\n安定しているか？\n頻繁に変わらないか？}
    Q6 -->|Yes: 安定| MICRO_SVC[✅ マイクロサービスとして分割\nIntegration EventとACLで統合]
    Q6 -->|No: まだ揺れている| WAIT[境界が安定するまで\nモジュラーモノリスで待機\n早すぎる分割は技術的負債]

    MODULAR_MONOLITH --> NOTE1([同一プロセス・別アセンブリ\nContextをまたぐ直接参照禁止\nドメインイベントで疎結合])
    MICRO_SVC --> NOTE2([API/メッセージング経由の通信\n独立したデータストア\nACLで翻訳])
```

### 判断ポイントの説明

Bounded Context の分割は「いつ・どう分けるか」が問題です。分割が早すぎると境界の設定ミスにより後の修正コストが膨大になり、遅すぎるとモデルが肥大化して一貫性を失います。

最初に問うべきは「同じ用語が異なる意味を持つか」です。例えば「顧客（Customer）」という概念が、Sales Context では「見込み顧客・見積相手」を意味し、Shipping Context では「配送先の住所持ち主」を意味するなら、明確な分割のサインです。同じ「Customer」クラスに両方の属性を詰め込もうとすると、どちらの関心も上手く表現できない中途半端なモデルになります。

チームの構造は Bounded Context の分割に直結します（Conway's Law）。「マイクロサービス化したい」という技術的な要望の前に「チームが分かれているか」を確認します。同一チームが管理するなら、技術的には単一 Bounded Context（または内部分割したモジュラーモノリス）で十分なことが多いです。

「分割するが、マイクロサービスにするかどうか」は別の判断です。まずはモジュラーモノリスとして同一プロセス内で Bounded Context を分離し、境界が安定してから独立したサービスに切り出すアプローチが、近年多く推奨されています。マイクロサービス化による運用コスト（独立したデプロイ・ネットワーク障害対応・分散トレーシングなど）を理解した上で意思決定します。

モジュラーモノリスの実装では、Context をまたぐ直接参照（別 Context のクラスを直接 `new`、または `using` で参照する）を禁止し、Domain Event またはメッセージングで疎結合を維持します。C# プロジェクトでは、各 Bounded Context を別アセンブリ（プロジェクト）として定義し、コンパイル時に境界違反を検出できるようにするアプローチが効果的です。

---

## C.7 フローチャートの使い方ガイド

### 設計判断フローを実務に活かす方法

本付録のフローチャートは、設計判断の「正解を自動的に導くツール」ではなく、「見落としがちな判断軸を提示するチェックリスト」として活用してください。

**Event Storming との組み合わせ**

Event Storming でドメインの全体像を把握した後、以下の順序でフローチャートを参照することを推奨します。

1. **C.1**（DDD 採用判断）→ 対象ドメインに DDD を適用するかを決める
2. **C.6**（Bounded Context 分割）→ コンテキストマップを作成する
3. **C.3**（Aggregate 境界）→ 各コンテキスト内の Aggregate を設計する
4. **C.2**（Value Object vs Entity）→ 個々のドメインオブジェクトを設計する
5. **C.4**（Domain Service vs Application Service）→ サービス層を設計する
6. **C.5**（Repository vs Direct Query）→ データアクセス層を設計する

**レビューでの活用**

プルリクエストのレビューで「この設計判断は正しいか」を議論する際、フローチャートを参照することで客観的な判断軸を共有できます。「なぜ Entity にしたのか」「なぜ Aggregate を分割しなかったのか」という問いに対して、フローを辿ることで根拠を明示できます。

**段階的な適用**

DDD を初めて適用するチームでは、最初からすべてのパターンを使おうとせず、以下の優先順位で段階的に導入することを推奨します。

- **フェーズ 1**: Value Object・Entity・Aggregate・Repository（C.2・C.3・C.5 を参照）
- **フェーズ 2**: Domain Event・Application Service・Domain Service（C.4 を参照）
- **フェーズ 3**: Bounded Context 分割・CQRS・Outbox Pattern（C.6 を参照）
- **フェーズ 4**: Event Sourcing・Saga・Process Manager（十分な経験を積んだ後）

各フェーズの移行タイミングは、「現在の実装に限界を感じた時」が最良です。技術的な完璧さを先取りするのではなく、ビジネスの問題解決を優先することが DDD 実践の本質です。

---

*本付録のフローチャートは Mermaid 形式で記述されています。GitHub・GitLab・Notion・VS Code（Markdown Preview Mermaid Support 拡張）などでレンダリングできます。チームのドキュメントとして共有する際はそのままコピーしてご利用ください。*
