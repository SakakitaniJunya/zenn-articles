---
title: "Claude Code を「会社」にする 5 機構"
emoji: "🛠️"
type: "tech"
topics: ["claude", "anthropic", "agentsdk", "ai", "llm"]
published: false
# === 当 repo 独自 ===
queue_id: "A-01"
series: "ai-driven-dev"
draft_source: "ai"
related_repos:
  - "devops-hub"
review_status: "draft"
---

> この記事は **52 本連載 (ai-driven-dev)** の第 2 回です。第 1 回 INDEX は [AI 駆動開発を 1 年やって辿り着いた構成](https://zenn.dev/junya_sakaki/articles/ai-driven-dev-index-2026)。

## 結論

- Claude Code の拡張機構は **Slash / Subagent / Hook / Skill / MCP** の 5 つに整理できます。
- 役割を分けて使うと、ただのエディタ補助だった Claude Code が「1 人会社の OS」に化けます。
- ただし 1 機構で全部やろうとすると破綻します。私は最初に Slash command へ全部詰めて爆発させました。

## なぜこの記事を書くか

Claude Code には Slash command / Subagent / Hook / Skill / MCP という、似ているようで役割の違う拡張ポイントが 5 つあります。これを混ぜて運用すると、Hook が暴発して保存のたびに数十秒待たされたり、Skill が「必要なときに発火しない」状態になったりします。

私はこの 1 年、Claude Code を「コードを書く道具」ではなく「会社の運営基盤」として使ってきました。本記事はその過程で固まった「どの機構を何に使うか」の現時点の整理です。

## 5 機構の役割分担

まず一行で並べます。

| 機構 | 一言で言うと | 起動条件 |
|---|---|---|
| Slash command | 人間が明示的に呼ぶ手順書 | `/<name>` を入力 |
| Subagent | 文脈を別腹で持たせたい仕事 | 親エージェントが `Agent` tool で呼ぶ |
| Hook | tool 呼び出しの前後で必ず走るロジック | PreToolUse / PostToolUse / Stop |
| Skill | 会話のシグナルから自動 fire する手続き知識 | description にマッチする発話 |
| MCP | 外部システムとの口 | tool として常時露出 |

以下、私の実運用例で順に見ていきます。

### 1. Slash command — 「人間が明示的に呼ぶ手順書」

`.claude/commands/<name>.md` に Markdown で置くだけで、`/<name>` で呼び出せるカスタムコマンドになります。中身は **手順を自然言語で書いた指示書** です。

私の `zenn-articles` repo では `/zenn-next` がこれに該当します。

```markdown
# /zenn-next — Zenn 記事 draft 生成

`topic-queue.yaml` から次の pending topic を 1 件 pop し、
`articles/<slug>.md` に draft を書き出す。

## 実行手順
### Step 1: 規約読込
以下を Read して必ず守る:
1. voice.md
2. frontmatter-spec.md
...
```

ポイントは **「人間がいつ呼ぶか決める」** ことです。毎朝 5 時の cron から `claude -p "/zenn-next"` で叩けば、launchctl のタイマーがそのまま slash command の発火条件になります。

devops-hub では同じ思想で `/orchestrate <issue>` (パイプライン全体実行)、`/spec`、`/implement`、`/review`、`/strategy` などを並べています。「人間 (または cron) が起点である」「再現可能な手順を持つ」仕事は全部 Slash command が向きます。

### 2. Subagent — 「文脈を別腹で持たせたい仕事」

Subagent は **親の context window を汚さずに別エージェントに調査や実装を任せる** 機構です。`Agent` tool 経由で呼びます。

組み込みでは `Explore` (ファイル検索専用)、`general-purpose` (汎用)、`Plan` (実装計画) などがあり、`~/.claude/agents/` や `<repo>/.claude/agents/` に Markdown で独自定義もできます。私が置いているのは `agent-improver.md` (エージェント定義そのものを改善する) と `skill-architect.md` (skill を新設するときの設計役) の 2 つです。

使い分けの目安はシンプルで、

- 結果が「短い要約」で済むなら Subagent に投げる (context 節約)
- 結果が「長い具体的な変更」になるなら親で直接やる (受け渡しのロスが大きい)

「3 本以上の grep が必要な探索」「並列で読むべきドキュメントが分散している」「PR が肥大化しそうな実装を 4 つに割って同時に投げる」あたりが Subagent の出番です。

### 3. Hook — 「ツール呼び出しの前後で必ず走るロジック」

Hook は `.claude/settings.json` で宣言する **シェルコマンドの自動実行ポイント** です。`PreToolUse` / `PostToolUse` / `Stop` などのイベントに紐づきます。

devops-hub の実例:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": "jq -r '.tool_input.file_path // empty' | { read -r f; [ -n \"$f\" ] && echo \"[$(date +%H:%M:%S)] modified: $f\" >> .claude/pipeline/agent.log 2>/dev/null; exit 0; } 2>/dev/null || true"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash .claude/skills/docs-mece-audit/scripts/run-on-stop.sh 2>/dev/null || true"
          }
        ]
      }
    ]
  }
}
```

Hook の特徴は **「Claude 本人が忘れても必ず走る」** ことです。私は最初これを軽視していました。Skill で「PR 作成前に MECE 監査をかけてね」と書けば守るだろう、と。守りませんでした。Claude も忘れます。Stop hook で強制実行に倒したら docs/ の重複が CI で機械的に落ちるようになりました。

### 4. Skill — 「自動 fire する手続き知識」

Skill は `~/.claude/skills/<name>/SKILL.md` に置く **「いつ発火させたいかを description に書く手続きの塊」** です。Hook と違って Claude 本人がトリガを判断する点が異なります。

私が今使っている skill (抜粋):

| Skill | 何をするか | トリガ |
|---|---|---|
| tweet-capture | 雑談から X 投稿候補を JSONL に積む | 「shipped」「ハマった」「正解だった」 |
| decision-genealogy | 重要判断に Decision-Id を発番して commit に埋める | 「これで行く」「ship it」 |
| deploy-verification | merge 後に Cloud Run / Vercel の revision を確認 | 「merge した」「deploy したか」 |
| pre-pr-checklist | PR 作成前に typecheck / build / test / docs を回す | 「PR 作る」「実装終わった」 |
| docs-mece-audit | docs/ の id 重複・孤立ファイルを検出 | docs/ への変更 |

ポイントは **description に発火条件を書ききる** ことです。「○○ のときは fire する」と曖昧に書くと、本当に必要なときだけ静かに発火しなくなります。私は `tweet-capture` で「Trigger on Japanese phrases: '通った', 'merge した', 'shipped'...」のようにシグナル語を列挙する方針に倒したら誤発火・取りこぼし両方が激減しました。

Skill と Hook の境界線は **「Claude が忘れても許せるか」** です。

- 忘れると致命的 (品質ゲート、ledger 記録) → **Hook**
- 忘れたら気づいたタイミングで補えれば良い (tweet 候補、文脈情報) → **Skill**

### 5. MCP — 「外部システムとの口」

Model Context Protocol (MCP) は **外部の SaaS や DB を tool として Claude に露出させる** プロトコルです。`figma`、`slack`、`github` などサーバ実装が増えています。

私の現状はかなり保守的で、公式 figma server を 1 つ繋いでいるだけです。理由は単純で、**ほとんどの外部連携は Bash + gh / curl で十分** だからです。MCP を入れるべきラインを自分の中ではこう引いています。

- 認証が複雑 (OAuth dance, refresh token 回し) → MCP が割に合う
- バイナリ / 画像 / リッチメタデータ を扱う → MCP が向く (figma の get_screenshot など)
- 単に REST を叩くだけ → Bash + gh / curl で良い (= 自作 MCP を書かない)

「自作 MCP server 1 ファイル」は技術的には簡単ですが、運用上の重さ (process 管理、認証情報の置き場、Claude 側の context 圧) を考えると後回しで良いと判断しています。

## 役割分担の判断フロー

ここまでをフロー化すると、**新しい運用ルールを Claude Code に教え込みたいとき** の判断はこうなります。

```
そのルールは「人間 (cron) が起点」？
  └ Yes → Slash command
  └ No  → 「忘れると致命的」？
            └ Yes → Hook
            └ No  → 「会話のシグナルで自動 fire したい」？
                      └ Yes → Skill
                      └ No  → 「親 context を汚したくない長い調査」？
                                └ Yes → Subagent
                                └ No  → 「外部 SaaS との常時接続」？
                                          └ Yes → MCP
                                          └ No  → そもそも自動化不要
```

完璧な分類ではありませんが、迷ったらまずこのツリーを上から降りています。

## 落とし穴 / 失敗談

### 1. Slash command に Hook の仕事を詰めて爆発させた

最初に作った `/check-pr` は「PR 作成前に typecheck / build / test / lint / docs / git status を全部回す」slash command でした。動きはするのですが、**人間が呼ばないと走らない** ので、急ぎのときほど忘れます。週 3 回くらい「このファイル lint 通ってないですよ」と CI に怒られた末、`pre-pr-checklist` skill に書き直しました。Skill にしたことで「PR 作る」「ready for review」「実装終わった」あたりの発話で勝手に走るようになり、抜けが消えました。

教訓: **「人間が呼び忘れる」ものは Slash にしてはいけない**。

### 2. Hook に重い処理を入れて編集が止まった

PostToolUse の Write/Edit にフルの type-check を仕込んだら、1 ファイル編集するたびに 30 秒止まる地獄になりました。今は **Hook には append-only な軽い記録 (agent.log への append、ledger への JSON 1 行追記) しか書かない** ルールにしています。重い検証は Stop hook (= 一連の作業が終わった時点) に集約し、PostToolUse は計測とログだけ、と分けています。

教訓: **Hook の所要時間 = 編集体験の遅延**。重い処理は Stop hook に寄せる。

### 3. Skill の description が曖昧で発火しなかった

初期の `tweet-capture` の description は「CEO の発言で tweet になりそうなものを拾う」だけでした。これだと Claude は「自分で判断していいのか?」と引いてしまい、ほぼ発火しません。シグナル語を「'shipped' / 'merge した' / 'ハマった' / 'moat'」のように具体的に列挙したら、適切な頻度で発火するようになりました。

教訓: **Skill description は「曖昧な状況説明」ではなく「具体的なシグナル語の列挙」で書く**。

### 4. Subagent に context を渡し忘れて二度手間

`Explore` agent に「この feature を grep して」とだけ投げて、ファイルパスや前提を渡さなかった結果、汎用の grep 結果しか返ってこず、結局自分で grep し直す羽目になりました。Subagent は **「親の会話を見ていない別人」** なので、必要な前提・除外条件・期待する出力形式を毎回明示する必要があります。

教訓: **Subagent への prompt は「この会話を見ていない同僚への依頼書」として書く**。

## まとめ

5 機構を 1 行で覚えるならこうです。

- Slash = 人間が呼ぶ手順書
- Subagent = 別腹の context
- Hook = 忘れても走る品質ゲート
- Skill = 会話シグナルで fire する知識
- MCP = 外部システムとの口

役割を分けるだけで、Claude Code は「コードエディタ」から「会社の OS」に近づきます。

---

→ 次回は **Skill Architecture 入門 — 自動 fire する手続き的知識を Markdown + frontmatter で定義する** (queue id: A-02) を書きます。Skill description の書き方をもう一段細かく掘ります。

→ Hook の組み方 (PostToolUse / Stop で品質ゲートを作る具体) は A-03 で扱います。
