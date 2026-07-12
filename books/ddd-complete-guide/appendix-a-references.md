---
title: "付録A: 参考文献・推薦図書"
---

# 付録 A: 参考文献・推薦図書

本書の執筆にあたり参照した文献、および DDD をより深く学ぶための推薦図書を記載します。

---

## 一次文献（必読）

### 書籍

| # | 書誌情報 | 推薦理由 |
|----|---------|---------|
| [1] | Evans, Eric. *Domain-Driven Design: Tackling Complexity in the Heart of Software*. Addison-Wesley, 2003. ISBN 978-0321125217 | DDD の原典。通称「Blue Book」。戦略的設計・戦術的設計の全体像を定義した。本書の思想的土台。 |
| [2] | Vernon, Vaughn. *Implementing Domain-Driven Design*. Addison-Wesley, 2013. ISBN 978-0321834577 | Evans の Blue Book を実装レベルまで掘り下げた実践書。通称「Red Book」。Aggregate 設計 4 原則、Domain Event の詳述はここが出典。 |
| [3] | Vernon, Vaughn. *Domain-Driven Design Distilled*. Addison-Wesley, 2016. ISBN 978-0134434421 | Blue Book の要約版。入門として最適。200 ページで戦略的設計の核心を掴める。 |
| [4] | Brandolini, Alberto. *Introducing EventStorming*. Leanpub, 2021. | Event Storming の考案者による公式解説。Leanpub で継続的に更新されているため最新版を参照のこと。 |
| [5] | Millett, Scott & Tune, Nick. *Patterns, Principles, and Practices of Domain-Driven Design*. Wrox, 2015. ISBN 978-1118714706 | Blue Book の実践補完。C# での実装例が豊富。本書の C# コード設計の参考にした。 |

---

## 二次文献（深化）

### アーキテクチャ・パターン

| # | 書誌情報 | 関連章 |
|----|---------|-------|
| [6] | Fowler, Martin. *Patterns of Enterprise Application Architecture*. Addison-Wesley, 2002. ISBN 978-0321127426 | Repository パターン、Service Layer の原典。第11章参照。 |
| [7] | Cockburn, Alistair. "Hexagonal Architecture." *Alistair Cockburn's Website*, 2005. https://alistair.cockburn.us/hexagonal-architecture/ | Ports & Adapters (ヘキサゴナルアーキテクチャ) の原論文。第14章参照。 |
| [8] | Martin, Robert C. *Clean Architecture: A Craftsman's Guide to Software Structure and Design*. Prentice Hall, 2017. ISBN 978-0134494166 | 依存逆転の原則と Clean Architecture の詳述。第14章参照。 |

### マイクロサービス・分散システム

| # | 書誌情報 | 関連章 |
|----|---------|-------|
| [9] | Richardson, Chris. *Microservices Patterns*. Manning, 2018. ISBN 978-1617294549 | Saga パターン (Choreography / Orchestration) の詳細な解説と実装例。第22章参照。 |
| [10] | Newman, Sam. *Building Microservices*, 2nd ed. O'Reilly, 2021. ISBN 978-1492034025 | Bounded Context とマイクロサービスの境界の関係を論じた実践書。第19章参照。 |

### チーム・組織設計

| # | 書誌情報 | 関連章 |
|----|---------|-------|
| [11] | Skelton, Matthew & Pais, Manuel. *Team Topologies*. IT Revolution, 2019. ISBN 978-1942788812 | コンウェイの法則と Bounded Context の関係。チーム境界 = ドメイン境界の思想を詳述。第19章参照。 |
| [12] | Tune, Nick. *Architecture Modernization*. Manning, 2023. ISBN 978-1633438309 | 戦略的 DDD の現代的実践。Team Topologies と Domain-Driven Design の融合。 |

### リファクタリング

| # | 書誌情報 | 関連章 |
|----|---------|-------|
| [13] | Fowler, Martin. *Refactoring: Improving the Design of Existing Code*, 2nd ed. Addison-Wesley, 2018. ISBN 978-0134757599 | 既存コードを段階的に改善する手法。第18章のリファクタリング手順の基盤。 |

---

## オンラインリソース

| # | リソース | 内容 |
|----|---------|------|
| [14] | Fowler, Martin. "AnemicDomainModel." *Martin Fowler's Bliki*. https://martinfowler.com/bliki/AnemicDomainModel.html (2003) | 貧血ドメインモデルをアンチパターンと命名した元記事。第20章参照。 |
| [15] | Fowler, Martin. "BoundedContext." *Martin Fowler's Bliki*. https://martinfowler.com/bliki/BoundedContext.html (2014) | Bounded Context の平易な解説。Evans の原典と合わせて読む。 |
| [16] | Young, Greg. "CQRS Documents." *Greg Young's Blog*. https://cqrs.files.wordpress.com/2010/11/cqrs_documents.pdf (2010) | CQRS / Event Sourcing の原典ドキュメント。第15・16章の理論的基盤。 |
| [17] | Vernon, Vaughn. "Effective Aggregate Design." *Vaughn Vernon's Blog*. https://vaughnvernon.co/?p=838 (2011) | Aggregate 設計 4 原則の原論文（3部作）。第9章参照。 |
| [18] | DDD Community. https://dddcommunity.org | DDD の公式コミュニティ。Evans ほか発起人たちの議論アーカイブ。 |

---

## 日本語文献

| # | 書誌情報 | 推薦理由 |
|----|---------|---------|
| [19] | 松岡幸一郎 (訳). *エリック・エヴァンスのドメイン駆動設計*. 翔泳社, 2011. ISBN 978-4798121963 | Evans [1] の公式日本語訳。用語の日本語対応はこの訳語を基準にした。 |
| [20] | 成瀬允宣. *ドメイン駆動設計入門 ボトムアップでわかる！ドメイン駆動設計の基本*. 翔泳社, 2020. ISBN 978-4798150727 | 日本語で読める最も実践的な DDD 入門書。C# での実装例が充実。本書の姉妹書として推薦。 |
| [21] | 増田亨. *現場で役立つシステム設計の原則 〜変更を楽で安全にするオブジェクト指向の実践技法*. 技術評論社, 2017. ISBN 978-4774189062 | DDD の戦術パターンを現場視点で解説。Value Object・Entity の実装判断の参考に。 |
| [22] | 中村充志. *ドメイン駆動設計 モデリング/実装ガイド*. BOOTH, 2019. | Kotlin + Spring での DDD 実装例が豊富。DDD の実装アプローチを複数言語で確認したい場合に。 |

---

## 本書での引用ポリシー

本書で登場する「参考文献と著者の解釈」セクションは、上記文献の内容を著者（筆者）が解釈・要約したものです。直接引用の場合は `（著者, 出版年, p.XX）` の形式で出典を明記しています。

いずれの著者も本書を個人的にレビュー・推薦したわけではありません。各著者の思想を正確に伝えるよう努めましたが、解釈の誤りは筆者の責任です。原典の参照を強く推奨します。
