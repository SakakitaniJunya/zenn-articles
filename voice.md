# Voice / トーン辞書

draft 生成時に必ず参照する。**逸脱した draft は reroll**。

## 一人称

- `私` を default。「筆者」「自分」は使わない。
- カジュアルさが必要な締めは `自分` 可。

## 敬体

- 全文 **敬体 (です・ます調)**。
- ただし箇条書き内は体言止め可 (見出し含む)。

## 絵文字

- **本文中の絵文字は禁止**。
- frontmatter `emoji` のみ Zenn 仕様で使用。
- 例外: 章末 `---` 区切りの後の「次の記事」誘導の矢印 `→` は OK。

## コード断片

- 動かない擬似コードは禁止。`// ...` での省略は最小。
- 言語は明示 (`typescript`, `bash`, `yaml`)。
- TypeScript は **strict + any 禁止** で書く (CLAUDE.md C-005/C-006 と一致)。

## 専門用語の前置き

- Anthropic / Claude / Agent SDK / RAG / LLM-as-Judge は前置き不要。
- ただし「13 部署 director」「Decision Genealogy」「Context Engine」「Event Bus」など**社内造語**は初回登場時に 1 行で説明。

## 構造 (aicon_kato 型・100 いいね 候補のテンプレ)

```
1. ファーストビュー = 1 行で結論 + 数字埋込
   例: 「2 ヶ月で 21 体の AI エージェントを構築した。Issue に書いて寝れば朝に PR が上がる」
   → 「3 行以内」ではなく「1 行 + データ続き」が刺さる
2. 問題 (我々の課題、Before の状況) — 200-400 字
3. 解法 (やったこと一覧、各 h3 で深掘り、コード/図/スクショ豊富)
4. 残課題 (まだできていないこと、今後やること) — 誠実性で信頼を得る
5. 理論根拠 / 振り返り — 「なぜこれで上手くいったか」を OpenAI / Anthropic 公式の原則と接続
6. CTA — イベント / Discussion / 連載カウンタ Day N/52 / フォロー導線
```

**4 段階構成「問題 → 解法 → 残課題 → 理論根拠」** が Zenn 上位記事の標準。「失敗談」は解法セクションの中に Before/After で混ぜる。

## 数字の出し方 — 「テーブル」より「本文埋込」

❌ 弱い (テーブル):
```
| 項目 | 値 |
|---|---|
| TS ファイル | 170 |
| skill | 11 |
```

✅ 強い (本文埋込):
> 2 ヶ月で 21 体の AI エージェントを構築した。半月単位で 681 件の PR をマージし、57 万行のモノレポを 1 人で回している。

数字を**動詞と組合せて 1 文** にすると説得力が桁違い。テーブルは補助。

## 品質バー (Mandatory — 100 いいね 候補なら全項目クリア)

> ⚠️ 「言っているだけで具体性が無い」記事は AI 量産の薄っぺらい記事として認識される。以下を**最低ライン**として必ず満たすこと。

| 要素 | 最低数 | 100 いいね目安 | 例 |
|---|---:|---:|---|
| **Mermaid 図** | **1+** | **3-5** | flowchart / sequenceDiagram / stateDiagram。ASCII 図禁止、必ず ` ```mermaid ` ブロック |
| **実コード断片** | **2+** | **5-10** | TypeScript / YAML / Python / Bash / JSON 各 10-30 行、実 repo から引用 |
| **file:line 引用** | **3+** | **5+** | `pipeline-kit/ops/run-orchestrator.sh:415` で根拠 |
| **実測の数字** | **3+** | **5+ (本文埋込)** | "21 体のエージェント / 681 件/半月 / 57 万行モノレポ" |
| **Before / After 比較** | **1+** | **2-3** | 失敗談で「壊れたコード」→「直したコード」 |
| **スクリーンショット** | 0 | **3-4** | 実運用画面 (Issue / PR / Dashboard / Graph) — 撮れる場合 |
| **冒頭 1 行結論** | 必須 | 必須 | 数字 + 動詞、aicon_kato 型 |
| **CTA 多層** | 必須 | 必須 | フォロー + 連載カウンタ + (イベント / Discussion / GitHub 編集提案) |

### Mermaid 推奨パターン

| 記事タイプ | 推奨図 |
|---|---|
| アーキテクチャ概観 | `flowchart TB` (Layer 図) |
| 1 日 / 1 リクエストのフロー | `sequenceDiagram` |
| Agent の状態遷移 | `stateDiagram-v2` |
| 部署 / 機構の関係 | `flowchart LR` (左→右の DAG) |
| 時系列 (Phase 移行) | `gantt` |

例:

```mermaid
flowchart TB
    A[trigger] --> B{condition}
    B -->|yes| C[Action 1]
    B -->|no| D[Action 2]
```

### 引用の書き方

実コードを貼る場合は **必ず file:line を冒頭で示す**:

```typescript
// pipeline-kit/agents/prompts/_shared/project-namespace-protocol.md:42-58
export type Project = {
  id: string;
  stage: "ideation" | "mvp" | "pmf" | "frozen";
  ...
};
```

「私はこう書いている」だけでは不十分。**「どこに置いてあるか」を示すと読者は repo を覗きに来る** = 連載全体の流入になる。

### 数字の出典

数字を出す場合、出典 / 確認方法を 1 行で添える:

```
TS/TSX ファイル数: 884 (`find App/ -name "*.ts*" | wc -l` 実測)
Komyu Cloud Run revision: 64 (`gcloud run revisions list` で確認)
```

捏造は禁則。確証ない数字は出さない。

## 禁則

- ❌ 「いかがでしたか?」「以上です」「最後までお読みいただきありがとうございました」 — Zenn では即離脱
- ❌ 自慢 / マウント — 「私が作った最強の」「他社にはない」
- ❌ 数字の捏造 — 確証ない数値は出さない (フォロワー / MRR / ユーザ数)
- ❌ 無料 SaaS / OSS の dis — トーン悪化
- ❌ 「個人開発で〜」を冒頭で繰り返す — 1 記事 1 回まで

## 推奨

- ✅ **失敗談を最初に出す** — pnpm v10 force-legacy-deploy 罠 / Worktree isolation バグ等
- ✅ **数字は実測のみ** — 「Komyu の Cloud Run revision 64」「TS/TSX 884 ファイル」
- ✅ **コードの「捨てた版」も載せる** — Before / After で説得力
- ✅ **ADR / Decision-Id で根拠を示す** — 「DEC-20260505-06」のように

## SEO 最低限

- title: 32 字以内 (Zenn の OGP 切れ防止)
- topics: 3-5 個 (`ai`, `claude`, `anthropic`, `nextjs`, `typescript`, `agentsdk` 等)
- 1 記事 4,000-7,000 字目安 (Zenn の読了率最大ゾーン)

## トピック × ハッシュタグ (X)

| 記事カテゴリ | X ハッシュタグ |
|---|---|
| Claude Code 拡張 | `#ClaudeCode` `#AnthropicAPI` |
| Multi-Agent | `#AIエージェント` `#LLM` |
| RAG | `#RAG` `#LLM` |
| Vision | `#ClaudeVision` `#OCR` |
| AI Ops | `#AI駆動開発` `#1人会社` |

複数該当時は **2 つまで**。多すぎると逆効果。
