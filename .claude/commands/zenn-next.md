---
description: topic-queue.yaml の次の pending topic から Zenn 記事 draft を生成
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# /zenn-next — Zenn 記事 draft 生成

`topic-queue.yaml` から次の pending topic を 1 件 pop し、`articles/<slug>.md` に draft を書き出す。

## 入力 (任意)

- `$1` = queue_id を指定 (例: `/zenn-next A-01`)。空ならスコア順で次を選ぶ。

## 実行手順

### Step 1: 規約読込

以下を Read して**必ず守る**:

1. `voice.md` — 一人称 / 敬体 / 絵文字禁止 / 失敗談必須 / 自慢禁止 等
2. `frontmatter-spec.md` — Zenn 公式 + 当 repo 独自フィールド
3. `README.md` — 構造概要
4. `topic-queue.yaml` — 全 topic queue
5. `../devops-hub/docs/business/hr/ai-development-portfolio.md` (元ネタ)
6. `../devops-hub/docs/business/pr/zenn-strategy.md` (戦略 SSOT)

### Step 2: topic 選定

`topic-queue.yaml` の `topics` 配列から 1 件選ぶ:

- `$1` で queue_id 指定があればそれを優先
- なければ `status=pending` から:
  - 直近 3 本の axis (articles/ の最新 3 ファイル frontmatter から取得) と**異なる axis** を優先
  - 同条件なら `priority` (1 が最強) 昇順
  - 同条件なら `id` 昇順

### Step 3: 元ネタ収集

該当 topic の `axis` に応じて、関連する実コード / docs を **Read** で参照:

| axis | 主な参照先 |
|---|---|
| claude-code | `~/.claude/skills/`, `~/.claude/agents/`, `devops-hub/.claude/` |
| multi-agent | `devops-hub/pipeline-kit/agents/prompts/`, `docs/architecture/coordination/` |
| eval | `devops-hub/docs/harness/eval-harness-spec.md` |
| multi-llm | `build-football/api/app/services/` (Soccer Note の AI Router) |
| rag | `build-football/api/app/services/`, `docs/explanation/` |
| devops | `devops-hub/pipeline-kit/.github/workflows/`, `docs/runbooks/` |
| vision | `keirai/src/` (Claude Vision 経理) |
| ai-ops | `devops-hub/docs/architecture/coordination/`, `docs/adr/` |
| prompt | `Komyu/`, `yomi-note/` の AI 呼び出し |
| integration | LIFF / Stripe / Cloud Run の各 PJ |

> ⚠️ **見つからない情報は捏造しない**。読めなければ「(準備中)」と書く。

### Step 4: draft 生成

`voice.md` の構造テンプレに従って書く:

1. 結論 (3 行以内) — まず何が言えるか
2. なぜこの記事を書くか (200 字)
3. 本論 (見出し 3-5 段)
4. **失敗談 / 落とし穴セクション (必須)**
5. 次の記事への誘導

文字数: **4,000 - 7,000 字** が目安 (Zenn の読了率最大ゾーン)。

#### frontmatter

`frontmatter-spec.md` に従う:

```yaml
---
title: "<topic title (32 字以内に縮める)>"
emoji: "<emoji>"
type: "tech"
topics: [<3-5 個、Zenn 既存 topic のみ>]
published: false
queue_id: "<id>"
series: "ai-driven-dev"
draft_source: "ai"
review_status: "draft"
---
```

#### slug (filename)

- kebab-case 半角英小文字 + 数字 + ハイフン、12-50 字
- 例: `creator-evaluator-pattern.md`、`multi-llm-router-4-quadrants.md`
- 数値 prefix は使わない

### Step 5: 書き出し + queue 更新

1. `articles/<slug>.md` に Write
2. `topic-queue.yaml` の該当 topic を `status: drafting` に Edit
3. 標準出力に summary を出す:

```
[zenn-next] queue_id=<id> slug=<slug> chars=<N> axis=<axis>
```

## Don't

- ❌ voice.md を無視 (絵文字 / 自慢調 / 「いかがでしたか」)
- ❌ 数字を捏造 (確証ない MRR / フォロワー / ユーザ数)
- ❌ 機密情報 (顧客名 / 契約金額 / Accenture 業務) を含める
- ❌ 同じ topic を重複生成 (status=drafting / published を pop する)
- ❌ コード断片で動かない擬似コード (`// ...` 過多)
- ❌ 1 度に複数 topic を生成 (1 回 1 件、queue から 1 pop のみ)
