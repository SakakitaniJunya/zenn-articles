---
title: "AI 駆動開発を 1 年やって辿り着いた構成 — 8 SaaS と自作 Eval Harness の全体マップ"
emoji: "🤖"
type: "tech"
topics: ["claude", "anthropic", "agentsdk", "ai", "typescript"]
published: false
# === 当 repo 独自 ===
queue_id: "INDEX"
series: "ai-driven-dev"
draft_source: "human"
review_status: "draft"
---

> この記事は **52 本連載の入口 (INDEX)** です。各章のリンクは公開順に追記していきます。

## 結論

- 個人で AI 駆動開発を 1 年回したら、コードを書く仕事より **「AI に何をどう任せるかを設計する仕事」** の比重が圧倒的に増えました。
- 今は **8 つの SaaS** を 1 人で並列に運用しています。回せている理由は「AI に渡す Context」「収束を強制する設計」「Eval で品質を測る習慣」の 3 点に尽きます。
- 本記事はその全体像を 1 枚の地図にしたものです。各章は別記事に切り出します。

## なぜこの記事を書くか

「AI 駆動開発」と言っても、Cursor や Copilot を使う話と、Agent SDK で自律的にコードを書かせる話と、自社運用を全部 AI に置き換える話は別物です。流派ごとに語彙も道具立ても違うので、**「どこまでやれているか」のスナップショット** がないと話が噛み合いません。

この INDEX は、自分が現時点で何を作って何を作っていないかを正直に並べる場として書きます。

## 全体像 (1 枚地図)

```
┌──────────────────────────────────────────────────────────────┐
│ Layer 0: ハーネス基盤                                         │
│   Claude Code + Hooks + Skills + Subagents + MCP             │
│   ~/.claude/agents で 13 部署 director を宣言                 │
├──────────────────────────────────────────────────────────────┤
│ Layer 1: Multi-Agent パターン                                 │
│   Creator ≠ Evaluator / 収束ガード / Escalation              │
│   7 エージェント協調 CI/CD (PMA → DocsA → DevA → ...)        │
├──────────────────────────────────────────────────────────────┤
│ Layer 2: Multi-LLM Router                                     │
│   Claude / GPT-4o / Gemini をタスク特性で振り分け            │
│   Fallback Chain / Prompt Caching / Tool Use                 │
├──────────────────────────────────────────────────────────────┤
│ Layer 3: 知識注入 (RAG / Context Engine)                      │
│   ドメイン辞書 × Markdown チャンクで pgvector なし RAG       │
│   .claude/context/ 5 層構造を全 repo に展開                  │
├──────────────────────────────────────────────────────────────┤
│ Layer 4: Eval / 品質保証                                      │
│   LLM-as-Judge 13 Evaluator                                  │
│   decisions.jsonl に Decision-Id を貫通させる Genealogy      │
├──────────────────────────────────────────────────────────────┤
│ Layer 5: 運用                                                 │
│   GitHub Issue → Claude Code → PR → Cloud Run               │
│   Cross-Department Event Bus / Handoff Playbook              │
└──────────────────────────────────────────────────────────────┘
```

各 Layer に対応する記事を 52 本に分解しました。書き次第ここからリンクを貼っていきます。

## 動いているプロダクト

| プロダクト | 役割 | AI 実装の主軸 |
|---|---|---|
| nailsalon-reserve | 確定収益 (MRR ¥20k) | LIFF + Firebase + Cloud Scheduler |
| keirai | 経理 SaaS | Claude Vision OCR + 仕訳分類 |
| Komyu | コミュニティ運営 | Gemini 2.0 Flash + 4 層 (Creator/Validator/RateLimiter/Fallback) |
| Soccer Note | 練習ノート × AI 振り返り | Claude / GPT-4o / Gemini Router + RAG |
| yomi-note | 教材感想文 + AI fb | Gemini 2.5 Flash + Cloud Run |
| vivivi-beauty | 美容サロン (ideation) | NestJS + Stripe + マルチロール予約 |
| Colason Markdown | OSS Reader (検証中) | C++ + TypeScript |
| DevOps Hub | 自社 AI ハーネス | Claude Agent SDK + 13 部署 director |

## Layer 別: 何ができるようになるのか

### Layer 0 — ハーネス基盤

Claude Code を「IDE 拡張」ではなく **「会社」として運用するための層** です。

- `~/.claude/skills/` に手続き的知識を YAML で置けば、文脈に応じて自動 fire する
- `Hooks` の PostToolUse / Stop で品質ゲート (重複 docs / strict TS 違反) を CI なしで止められる
- `~/.claude/agents/` に 13 部署 director を宣言すれば、`/sales komyu` で「komyu 担当の営業部」が動く

詳細記事:
- (準備中) Claude Code を「会社」にする — Slash / Subagent / Hook / Skill / MCP 役割分担
- (準備中) Skill Architecture 入門
- (準備中) Hooks PostToolUse / Stop で品質ゲート

### Layer 1 — Multi-Agent パターン

「LLM に何かを生成させて、別の LLM がそれをレビューする」を**収束させる**には、設計で押さえるべき制約があります。

- **Creator ≠ Evaluator**: 生成した側に評価させない (自己肯定 bias)
- **最大ラウンド制限**: 3 ラウンド超えたら人間にエスカレーション
- **Sub-Agent 4 層**: Creator / Validator / RateLimiter / Fallback を必ず分離

これを守らないと「永遠に修正案を出し続ける AI」が出来上がります。

### Layer 2 — Multi-LLM Router

私は Anthropic / OpenAI / Google の **3 社を同一サービス内で併用** しています。判断軸は 4 象限:

| 軸 | 強い provider |
|---|---|
| 高品質な日本語 | GPT-4o |
| 深い推論 / コード生成 | Claude Sonnet / Opus |
| 軽量・高速・低コスト | Gemini Flash |
| 大規模コンテキスト | Gemini Pro / Claude 1M |

これに **Fallback Chain** (OpenAI → Anthropic → Google) と **Prompt Caching** (Anthropic) を被せれば、コストと可用性を両立できます。

### Layer 3 — 知識注入 (RAG / Context Engine)

「ベクトル DB を立てない RAG」を運用しています。Soccer Note では:

- **ドメイン辞書** (TECHNICAL / TACTICAL / PHYSICAL / MENTAL) でキーワードスコアリング
- **Markdown チャンク** から該当ノートを抽出
- **ポジション別 / 年齢別** にプロンプト動的生成 (U6〜U18, 13 ポジション)

これで pgvector も Pinecone も使わずに、十分な精度を出しています。**RAG は最後の手段** であり、その前にプロンプト構造化で勝てる範囲を広げる、が今の感触です。

### Layer 4 — Eval / 品質保証

AI の出力を「なんとなく良さそう」で運用すると 1 ヶ月で破綻します。

- **LLM-as-Judge** で 13 観点の Evaluator を並列実行
- 各 Evaluator のスコアを `decisions.jsonl` に追記
- すべての commit / ADR / CEO 承認に **Decision-Id** を貫通させ、後から「なぜそう決めたか」を辿れるようにする

これを `Decision Genealogy` と呼んでいます。**moat 候補** として磨いている領域です。

### Layer 5 — 運用

最終的に、

- GitHub Issue を立てる →
- `/orchestrate` で Claude Code がパイプラインを起動 →
- 7 エージェントが順に動いて PR まで作る →
- Cloud Run に自動 deploy →
- Discord で通知

までを 1 人で回しています。**「マージ済 ≠ 本番反映済」** を口酸っぱく自分に言い続け、`deploy-verification` skill で revision まで確認する運用です。

## 失敗談 (これが結構大きい)

### 1. 設計を引き直しすぎる病

最初の半年は「もっと良い設計があるはず」で延々と議論ループを回していました。

学び: **1 セッションで 3 回棄却された設計案は、その日のうちに実装ゼロにする** ルールを skill 化しました (`feedback_design_loop_circuit_breaker`)。Excel と Slack で粘ることが最善のときもあります。

### 2. Worktree 並列のコミット先事故

`isolation: "worktree"` で並列エージェントを動かすと、**たまに main tree に commit してくる** バグに遭遇しました。

学び: dispatch 後は必ず `git worktree list` + `git log` で何が main に乗ったか verify する。force-push を拒否するなら旧 PR を close + 新 PR の B option を取る。

### 3. AI Ops を商品化しようとした

「これだけ使い込んだなら外販できる」と思い込み、4 並列でアーキテクチャレビューを走らせたら全員から **「commodity, weak moat」** という判定を食らいました。

学び: AI Ops 自体は商品化しない / OSS 化しない。**SI 受託 + 自社 Portfolio + AI Ops (multiplier)** の三脚で食う、と方針を確定。

## これから書く 52 章

ざっくりカテゴリ別:

- A. Claude Code 拡張・運用 (10 章)
- B. Multi-Agent 設計 (7 章)
- C. LLM-as-Judge / Eval (4 章)
- D. Multi-LLM / AI Router (7 章)
- E. RAG / 知識注入 (4 章)
- F. AI 駆動 CI/CD / DevOps (4 章)
- G. Vision / マルチモーダル (3 章)
- H. AI Ops 独自路線 (5 章)
- I. プロンプト工学・堅牢化 (4 章)
- J. 統合・経済圏 (4 章)

公開ペース: **1 日 1 本、52 日連続** を目標にします。AI が draft を書いて私が朝 5 分で approve する半自動運用です。

## 次の記事へ

→ (準備中) **Creator ≠ Evaluator パターン — AI 生成物を「収束」させる 3 ラウンド設計**

書き進めながらこの INDEX は更新します。誤りや「ここをもっと深く」というリクエストは X (準備中) でお気軽に。
