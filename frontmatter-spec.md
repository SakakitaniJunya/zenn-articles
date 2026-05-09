# frontmatter 規約

Zenn の公式仕様 + 当 repo 独自フィールド。

## Zenn 公式 (必須)

```yaml
---
title: "AI 駆動開発を 1 年やって辿り着いた構成 (全体マップ)"
emoji: "🤖"        # 1 文字、絵文字
type: "tech"       # "tech" | "idea"
topics: ["claude", "anthropic", "agentsdk", "ai", "typescript"]
published: false   # true で公開
published_at: "2026-05-10 06:00"  # 予約投稿時のみ
---
```

## 当 repo 独自フィールド (frontmatter コメントで残す)

```yaml
---
# === Zenn 仕様 ===
title: "..."
emoji: "🤖"
type: "tech"
topics: [...]
published: false

# === 当 repo 独自 (Zenn 側は無視) ===
queue_id: "A-01"           # topic-queue.yaml の id
series: "ai-driven-dev"    # 同シリーズ判定 (1日3本以内)
draft_source: "human"      # "human" | "ai" | "ai+human"
related_decisions:         # decisions.jsonl の Decision-Id
  - "DEC-20260509-01"
related_repos:             # 元ネタ repo
  - "devops-hub"
review_status: "draft"     # draft | reviewing | approved | published
---
```

> Zenn は知らないフィールドを無視するので問題ない。

## slug (= filename)

- `articles/<slug>.md`
- slug は **半角英小文字 + 数字 + ハイフン、12-50 文字**
- 例: `ai-driven-dev-index-2026.md`、`creator-evaluator-pattern.md`
- **数値 prefix は使わない** (Zenn は文字列 sort なので意味がない)

## emoji 選定

| 記事カテゴリ | emoji 候補 |
|---|---|
| Claude / Agent SDK | 🤖 🛠️ 🧠 |
| Multi-LLM | 🔀 🌐 |
| RAG | 📚 🔍 |
| Vision | 👁️ 📷 |
| AI Ops | 🏢 🪜 |
| Failure / Postmortem | 💥 🔧 |
| 思想 / Essay | 💭 ✨ |

## topics の選び方

- **必ず Zenn 既存 topic を使う** (新造語は流入しない)
- 確実に拾える: `ai`, `claude`, `anthropic`, `openai`, `gemini`, `nextjs`, `typescript`, `firebase`, `nestjs`, `cloudrun`, `rag`, `agentsdk`, `llm`
- 5 個 max
- 1 つは「広い topic」(`ai`)、1 つは「狭い topic」(`agentsdk`) を必ず混ぜる

## published / published_at

- 通常: AI が draft → `published: false` → CEO approve → script が `published: true` に書き換え
- 予約: `published_at` を future の ISO で指定すれば Zenn 側で予約公開される (CI なくても OK)
