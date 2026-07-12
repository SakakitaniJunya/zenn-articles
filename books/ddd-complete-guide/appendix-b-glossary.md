---
title: "付録B: DDD用語集"
---

# 付録 B: DDD 用語集

DDD で使われる用語を定義順ではなくアルファベット順（日本語は読み順）で並べます。各用語の後に「→ 第N章」で参照先を示します。

---

## A

**Aggregate（集約）**
整合性の境界を共有する Entity と Value Object のグループ。Aggregate Root を通じてのみ外部からアクセスできる。1 つのトランザクションで更新する単位でもある。→ 第9章

**Aggregate Root（集約ルート）**
Aggregate の入口となる Entity。外部からは Aggregate Root のみが直接参照でき、内部 Entity へのアクセスは Root を経由する。→ 第9章

**Anemic Domain Model（貧血ドメインモデル）**
Martin Fowler が命名したアンチパターン。Entity にプロパティのみが存在し、ビジネスロジックはすべて外部のサービスクラスに書かれている状態。ドメインの表現力が失われる。→ 第20章

**Anti-Corruption Layer / ACL（腐敗防止層）**
異なる Bounded Context やレガシーシステムとの統合時に、外部のモデルが内部のドメインモデルを汚染しないよう変換・隔離する層。Context Map の統合パターンのひとつ。→ 第5章

**Application Service（アプリケーションサービス）**
ユースケースをオーケストレーションする役割。ビジネスルール自体は持たず、Domain オブジェクトを組み合わせてユースケースの手順を束ねる。→ 第12章

---

## B

**Big Ball of Mud（大きな泥団子）**
境界が不明確で構造が混沌としたシステムを指す。Context Map のひとつのパターンとして、現実のレガシーシステムの状態を表現するために使われる。→ 第5章

**Bounded Context（境界づけられたコンテキスト）**
DDD の最重要戦略パターン。ドメインモデルとユビキタス言語が一貫して通用する境界。境界の外では同じ言葉でも別の意味を持つ場合がある。→ 第4章

---

## C

**Command（コマンド）**
CQRS における「書き込み」操作の表現。システムの状態を変化させる意図を表す。`PlaceOrderCommand` のように過去形でなく命令形で命名する。→ 第15章

**Conformist（順応者）**
Context Map の統合パターンのひとつ。下流が上流のモデルに完全に従う関係。変換コストはないが上流への依存が強い。→ 第5章

**Context Map（コンテキストマップ）**
複数の Bounded Context の関係を可視化した図・ドキュメント。9 つの統合パターン（Shared Kernel / Customer-Supplier / Conformist / ACL / Open-Host Service / Published Language / Separate Ways / Partnership / Big Ball of Mud）で関係を表現する。→ 第5章

**Core Domain（コアドメイン）**
ビジネスに競争優位をもたらす最も重要なドメイン。最も優秀なエンジニアを配置し、最も深くモデリングすべき領域。→ 第3章

**CQRS（Command Query Responsibility Segregation）**
Greg Young が2010年に提唱したパターン。コマンド（書き込み）とクエリ（読み取り）の責務を完全に分離する。Write Model は複雑なドメインルールを守り、Read Model はパフォーマンスに最適化する。→ 第15章

**Customer-Supplier（顧客-供給者）**
Context Map の統合パターン。上流（Supplier）が下流（Customer）のニーズに応える関係。上流チームが優先権を持つ。→ 第5章

---

## D

**Domain（ドメイン）**
ソフトウェアが解こうとしているビジネスの問題空間全体。EC サイトであれば「注文」「在庫」「請求」「配送」などがドメインに含まれる。→ 第1章

**Domain Event（ドメインイベント）**
ドメイン内で起きた「事実」を表す不変オブジェクト。`OrderPlaced`（注文が確定した）のように過去形で命名する。他のコンポーネントへの疎結合な通知手段。→ 第10章

**Domain Model（ドメインモデル）**
ビジネスの概念・ルール・関係をコードで表現したもの。Entity / Value Object / Aggregate / Domain Service などで構成される。→ 第1章

**Domain Service（ドメインサービス）**
単一の Entity や Value Object に属さないビジネスロジックを置く場所。複数の Aggregate をまたぐ計算や判断を担う。状態を持たないのが原則。→ 第12章

---

## E

**Entity（エンティティ）**
同一性（ID）を持つドメインオブジェクト。状態が変化しても「同じオブジェクト」として扱われる。顧客・注文・商品などが典型例。→ 第8章

**Event Sourcing（イベントソーシング）**
現在状態ではなく「起きたこと（イベント）の履歴」を永続化するパターン。Greg Young が普及させた。Aggregate の状態はイベントを再生（Replay）して復元する。→ 第16章

**Event Storming（イベントストーミング）**
Alberto Brandolini が2013年に考案したドメイン探索ワークショップ。付箋を使い、ドメイン専門家とエンジニアが協働してドメインイベントを中心にモデルを発見する手法。→ 第6章

---

## F

**Factory（ファクトリ）**
複雑な Aggregate や Entity の生成ロジックをカプセル化するパターン。コンストラクタが複雑になる場合、またはドメインイベントの発行を伴う生成に使う。→ 第13章

---

## G

**Generic Subdomain（汎用サブドメイン）**
ビジネスに競争優位をもたらさない汎用的なドメイン。メール送信・認証・課金処理など。OSS やSaaS を利用するのが合理的な選択。→ 第3章

---

## I

**Infrastructure Service（インフラストラクチャサービス）**
DB・外部API・メール送信など、技術的関心事を扱うサービス。Domain Layer からインターフェース経由で呼び出され、実装は Infrastructure Layer に置く。→ 第12章

**Invariant（不変条件）**
Aggregate が常に満たさなければならないビジネスルール。「注文アイテムが0件のまま確定できない」「合計金額がマイナスにならない」など。Aggregate Root がこれを守る責務を持つ。→ 第9章

---

## L

**Layered Architecture（レイヤードアーキテクチャ）**
Presentation / Application / Domain / Infrastructure の4層に責務を分離する設計。Domain Layer は上位層に依存しない。→ 第14章

---

## O

**Open-Host Service（公開ホストサービス）**
Context Map の統合パターン。上流が明確なプロトコル（REST API / GraphQL など）を公開し、多くの下流が利用できるようにする。Published Language とセットで使うことが多い。→ 第5章

---

## P

**Partnership（パートナーシップ）**
Context Map の統合パターン。2 つの Bounded Context が双方向に協調する関係。同時リリースが必要な密結合チーム間で生じる。→ 第5章

**Ports & Adapters（ポートとアダプター）**
Alistair Cockburn が2005年に提唱したアーキテクチャ。ドメインを中心に置き、外部との接続（DB・UI・外部API）をアダプターとして差し替え可能にする。ヘキサゴナルアーキテクチャとも呼ばれる。→ 第14章

**Process Manager（プロセスマネージャー）**
長期間にわたるビジネスプロセスを中央集権的にオーケストレーションするコンポーネント。Saga の Orchestration パターンの実装形態。状態を永続化し、タイムアウトも管理する。→ 第22章

**Published Language（公開言語）**
Context Map の統合パターン。共有の言語仕様（JSON Schema / Protobuf / OpenAPI など）を使ってコンテキスト間のデータ交換を標準化する。→ 第5章

---

## Q

**Query（クエリ）**
CQRS における「読み取り」操作の表現。システムの状態を変化させない。Read Model から最適化されたデータを返す。→ 第15章・第23章

---

## R

**Read Model（読み取りモデル）**
CQRS の Query 側モデル。表示・集計に最適化された非正規化データ構造。Domain Model の制約を受けず、UI が必要な形でデータを返す。→ 第15章・第23章

**Repository（リポジトリ）**
Aggregate の永続化を抽象化するインターフェース。ドメイン層に Interface を置き、実装はインフラ層に置く（依存逆転）。「Aggregate のコレクションのふりをする」のが役割。→ 第11章

---

## S

**Saga（サガ）**
複数の Bounded Context やマイクロサービスをまたぐ長期トランザクションを管理するパターン。Choreography（イベント駆動）と Orchestration（中央指揮者）の2種類がある。→ 第22章

**Separate Ways（分かれた道）**
Context Map の統合パターン。統合のコストが高すぎる場合に、あえて統合をやめる判断。重複を許容する。→ 第5章

**Shared Kernel（共有カーネル）**
Context Map の統合パターン。2 つの Bounded Context が共有するモデルの小さな集合。変更が双方に影響するため、慎重な合意が必要。→ 第5章

**Specification（仕様）**
ビジネスルールをオブジェクトとして表現するパターン。Repository と組み合わせて複雑な検索条件を表現するのに使う。`IsSatisfiedBy(entity)` が基本インターフェース。→ 第11章

**Strategic Design（戦略的設計）**
DDD の上位レベルの設計。Bounded Context・Context Map・Ubiquitous Language・ドメインの分類（Core / Supporting / Generic）を扱う。コードを書く前にチームで合意すべき設計。→ 第1〜6章

**Supporting Subdomain（支援サブドメイン）**
Core Domain を補助するドメイン。重要だが競争優位にはならない。社内開発するが最低限の実装で十分。→ 第3章

---

## T

**Tactical Design（戦術的設計）**
DDD のコードレベルの設計。Entity・Value Object・Aggregate・Repository・Domain Service・Domain Event・Factory などのパターンを扱う。→ 第7〜13章

---

## U

**Ubiquitous Language（ユビキタス言語）**
ドメイン専門家とエンジニアが共通して使う言語。コードの命名・会話・ドキュメントすべてで同じ言葉を使う。DDD において最も重要な概念のひとつ。→ 第2章

**Unit of Work（作業単位）**
1 つのビジネス操作で変更されたオブジェクトを追跡し、まとめてコミットするパターン。EF Core の `SaveChanges()` が典型的な実装。→ 第11章

---

## V

**Value Object（値オブジェクト）**
ID を持たず、値そのものが意味を持つドメインオブジェクト。不変（Immutable）・等値比較（全フィールドで判定）・自己検証が3つの特性。Money・EmailAddress・Address などが典型例。→ 第7章
