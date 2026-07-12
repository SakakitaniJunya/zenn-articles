---
title: "付録C: DDD総合判断フローチャート"
---

# 付録 C: DDD 総合判断フローチャート

「このロジックはどこに書けばいいか」「これは Entity か Value Object か」——DDD を実践する中で繰り返し直面する判断を、1枚のフローチャートで整理します。

---

## フローチャート1: DDD を使うべきか

```mermaid
flowchart TD
    Q1{"ドメインの複雑さは?"}
    Q2{"運用期間は?"}
    Q3{"ドメイン専門家と\n継続的に話せるか?"}
    Q4{"チームが DDD を\n学ぶ意欲があるか?"}

    A_NO["DDD 不要\nCRUD / シンプル MVC で十分\n開発速度を優先する"]
    A_MAYBE["軽量 DDD を検討\n戦略的設計のみ適用し\n戦術パターンは最小限に"]
    A_YES["DDD を採用する\n戦略的設計 → 戦術的設計\nの順で進める"]
    A_RISK["高リスク\nDDD の恩恵が出ない可能性大\nチーム教育から始める"]

    Q1 -->|"CRUD中心\nビジネスルールほぼなし"| A_NO
    Q1 -->|"中程度\n一部複雑なルールあり"| Q2
    Q1 -->|"高い\n複数部署をまたぐ複雑な業務"| Q3
    Q2 -->|"1〜2年で廃棄予定"| A_NO
    Q2 -->|"3年以上運用"| Q3
    Q3 -->|"Yes"| Q4
    Q3 -->|"No"| A_MAYBE
    Q4 -->|"Yes"| A_YES
    Q4 -->|"No"| A_RISK
```

---

## フローチャート2: Entity か Value Object か

```mermaid
flowchart TD
    Q1{"このオブジェクトに\n'同一性'はあるか?\n(IDで区別する必要があるか)"}
    Q2{"時間とともに\n状態が変化するか?"}
    Q3{"同じ値を持つ2つは\n交換可能か?\n(どちらでも同じ意味か)"}
    Q4{"不変にできるか?\n(変更時は新しく作れるか)"}

    AE["Entity\n例: Customer, Order, Product"]
    AVO["Value Object\n例: Money, EmailAddress, Address"]
    AVO2["Value Object\n(強い確信)"]
    AE2["Entity\nただし設計を再検討\n本当に変化が必要か確認"]

    Q1 -->|"Yes: IDで区別する"| Q2
    Q1 -->|"No: 値だけで意味が決まる"| Q3
    Q2 -->|"Yes: 変化する"| AE
    Q2 -->|"No: 変化しない"| AE2
    Q3 -->|"Yes: 交換可能"| Q4
    Q3 -->|"No: どちらかが特定のもの"| AE
    Q4 -->|"Yes"| AVO2
    Q4 -->|"No: 参照が必要"| AE
```

---

## フローチャート3: どの Aggregate に含めるか

```mermaid
flowchart TD
    Q1{"このオブジェクトは\n別の Aggregate Root\nなしに存在できるか?"}
    Q2{"このオブジェクトの変更は\n常に別オブジェクトの\n変更と一緒に起きるか?"}
    Q3{"このオブジェクトは\n複数の Aggregate から\n参照されるか?"}

    A1["独立した Aggregate Root\n例: Order, Customer, Product"]
    A2["同じ Aggregate の内部 Entity\n例: OrderItem (Order なしに存在しない)"]
    A3["ID参照のみ\n別 Aggregate の ID だけを保持\nオブジェクト参照は禁止"]
    A4["Value Object として検討\nまたは独立 Aggregate"]

    Q1 -->|"No: 依存関係がある"| Q2
    Q1 -->|"Yes: 独立して存在できる"| A1
    Q2 -->|"Yes: 常にセットで変わる"| A2
    Q2 -->|"No: 独立して変わる"| Q3
    Q3 -->|"Yes: 複数から参照"| A3
    Q3 -->|"No: 1つから参照"| A4
```

---

## フローチャート4: ロジックをどこに書くか

```mermaid
flowchart TD
    Q1{"このロジックは\nビジネスルールか?"}
    Q2{"単一のEntity/VOの\n内部ルールか?"}
    Q3{"複数のAggregateを\nまたぐか?"}
    Q4{"DBや外部APIを\n呼ぶか?"}
    Q5{"ユースケースの\n手順を束ねるか?"}
    Q6{"データ変換・\nフォーマット変換か?"}

    AE["Entity / Value Object のメソッド\norder.Place() / money.Add()"]
    ADS["Domain Service\nOrderDomainService.CalculateDiscount()"]
    AIS["Infrastructure Service\nEmailService / PaymentGateway"]
    AAS["Application Service\nPlaceOrderHandler"]
    AUtil["ユーティリティ / 拡張メソッド\nStringExtensions等"]
    AQuery["Query Handler (CQRS)\nRead Model で直接 SQL"]

    Q1 -->|"No"| Q6
    Q1 -->|"Yes"| Q2
    Q2 -->|"Yes"| AE
    Q2 -->|"No"| Q3
    Q3 -->|"Yes"| Q4
    Q3 -->|"No"| Q5
    Q4 -->|"No: 純粋なビジネスロジック"| ADS
    Q4 -->|"Yes: 技術的処理が入る"| AIS
    Q5 -->|"Yes"| AAS
    Q5 -->|"No"| ADS
    Q6 -->|"表示用変換"| AQuery
    Q6 -->|"汎用変換"| AUtil
```

---

## フローチャート5: Bounded Context の境界をどこに引くか

```mermaid
flowchart TD
    Q1{"同じ言葉が\n異なる意味を持つ\n場所はあるか?"}
    Q2{"異なるチームが\n管理・変更する\n領域はあるか?"}
    Q3{"変更の頻度・理由が\n異なる部分はあるか?"}
    Q4{"整合性の要件が\n異なる部分はあるか?"}

    A1["ここに Bounded Context の境界\nUbiquitous Language が変わる場所"]
    A2["ここに Bounded Context の境界\nコンウェイの法則: チーム = コンテキスト"]
    A3["ここに Bounded Context の境界\n変更理由の違い = 責務の違い"]
    A4["ここに Bounded Context の境界\n結果整合性で繋ぐ"]
    A5["同一 Bounded Context で継続\nさらに探索が必要"]

    Q1 -->|"Yes"| A1
    Q1 -->|"No"| Q2
    Q2 -->|"Yes"| A2
    Q2 -->|"No"| Q3
    Q3 -->|"Yes"| A3
    Q3 -->|"No"| Q4
    Q4 -->|"Yes"| A4
    Q4 -->|"No"| A5
```

---

## フローチャート6: Context Map の統合パターン選択

```mermaid
flowchart TD
    Q1{"2つのチームの\n力関係は?"}
    Q2{"共有するモデルの\n量は?"}
    Q3{"下流が上流の\nモデルをそのまま使えるか?"}
    Q4{"外部/レガシーシステムとの\n統合か?"}

    AP["Partnership\n対等な協調\n同時リリースが必要"]
    ASK["Shared Kernel\n少量の共有モデル\n変更は双方の合意が必要"]
    ACS["Customer-Supplier\n上流が下流のニーズに応える"]
    AACL["Anti-Corruption Layer\n下流が上流のモデルを変換\nドメインを保護"]
    ACONF["Conformist\n下流が上流に完全に従う\n変換コストをかけない"]
    AOHS["Open-Host Service\nAPIを公開し多くの下流が使う"]
    ASW["Separate Ways\n統合コストが高すぎる\nあえて分離する"]

    Q1 -->|"対等"| AP
    Q1 -->|"上流が強い"| Q2
    Q1 -->|"下流が強い"| AOHS
    Q2 -->|"少量"| ASK
    Q2 -->|"多い"| Q3
    Q3 -->|"Yes: そのまま使える"| ACONF
    Q3 -->|"No: 変換が必要"| Q4
    Q4 -->|"Yes"| AACL
    Q4 -->|"No: 統合が難しい"| ASW
```

---

## 全パターン早見表（1枚まとめ）

| 判断 | 条件 | 答え |
|------|------|------|
| **DDD を使うか** | CRUD中心 | 不要 |
| | 複雑なドメイン + 長期運用 | 使う |
| **Entity vs VO** | ID で区別 + 状態変化あり | Entity |
| | 値で意味が決まる + 不変 | Value Object |
| **Aggregate の大きさ** | 常に一緒に変わる | 同一Aggregate |
| | 独立して変わる | 別Aggregate + ID参照 |
| **ロジックの配置** | 単体のルール | Entity/VO |
| | 複数Aggregate + 純粋ロジック | Domain Service |
| | 外部IO | Infrastructure Service |
| | ユースケースの手順 | Application Service |
| **境界の場所** | 同じ言葉が違う意味を持つ場所 | Bounded Context 境界 |
| **Context Map** | 対等な協調 | Partnership |
| | 上流強い + 少量共有 | Shared Kernel |
| | レガシー統合 | Anti-Corruption Layer |
