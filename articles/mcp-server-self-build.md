---
title: "MCP Server を 1 ファイルで自作 — 採用判断と最小実装"
emoji: "🔌"
type: "tech"
topics: ["claudecode", "anthropic", "mcp", "ai", "agentsdk"]
published: false
queue_id: "A-08"
series: "ai-driven-dev"
draft_source: "ai+human"
related_repos: ["devops-hub"]
review_status: "draft"
---

> この記事は **52 本連載 (ai-driven-dev) の Day 29/52** です。第 1 回 [Slash と Skill と Hook を混ぜて爆発した話 — Claude Code 5 機構](./claude-code-as-company-5-mechanisms) で 5 機構の最後に置いた MCP を、1 本で深掘りします。
>
> ※ 本記事は著者個人の副業 (個人開発) における実践記録です。本業 (別会社所属) の業務・知見とは無関係で、特定法人の公式見解ではありません。コード片・設定例はすべて著者個人 repo の自著コードです。

## 結論

- MCP server を入れるべきラインは思ったより高いです。私は今、**公式 figma server を 1 個だけ繋いで、自作 MCP は 0 本** で運用しています。
- 自作の最小実装は **TypeScript で 50 行、`@modelcontextprotocol/sdk` 依存 1 個** で書けます。技術的には簡単です。
- 重いのは運用側です。**process 管理 / 認証情報の置き場 / context 圧迫 / version 衝突** の 4 つが foreground に出てきて、軽い気持ちで足すと毎回 1-2 時間溶けます。
- なので私は **採用判断 3 基準** を毎回当てています: ① 認証が複雑か ② バイナリ / リッチメタデータを扱うか ③ 単発でなく状態を持つか。3 つのうち 2 つ以上 yes なら MCP、それ以外は **Bash + `gh` / `curl` で十分**。

## なぜこの記事を書くか

Claude Code に外部 SaaS を繋ごうとすると、最初に手が伸びるのが MCP です。「公式の figma があるなら slack も notion も全部 MCP で繋ごう、無いものは自作しよう」と。私はその罠を踏みました。半日かけて自作 server を立て、context window が膨らんで Claude の応答が鈍り、結局 `gh issue list` を 1 行 Bash で呼ぶ運用に戻したことが何度かあります。

本記事はその試行錯誤を踏まえて、**MCP を採用すべきか / Bash で十分か** の判断軸と、判断後に「採用」になった場合の **1 ファイル 50 行** の最小実装を、実コード付きで書きます。

## まず脳内地図 — MCP server の構成

MCP (Model Context Protocol) は Anthropic が 2024 年末に公開した、**LLM クライアントと外部システムを繋ぐオープンプロトコル**です。Claude Desktop / Claude Code / Cursor などが client、figma / slack / 自作スクリプトが server。両者は **stdio または HTTP** で JSON-RPC 2.0 を流します。

server が公開できるのは大きく 3 種類です。

```mermaid
classDiagram
    class MCPServer {
        +name: string
        +version: string
        +listTools()
        +listResources()
        +listPrompts()
    }
    class Tool {
        +name: string
        +description: string
        +inputSchema: JSONSchema
        +call(args) Result
        <<副作用あり>>
    }
    class Resource {
        +uri: string
        +mimeType: string
        +read() bytes
        <<読み取り専用>>
    }
    class Prompt {
        +name: string
        +arguments: Arg[]
        +render() Message[]
        <<テンプレート>>
    }
    MCPServer "1" --> "*" Tool
    MCPServer "1" --> "*" Resource
    MCPServer "1" --> "*" Prompt
```

3 つの役割分担はシンプルです。

- **Tool** = 副作用ありの関数呼び出し (Slack に投稿する、DB に書く、Issue を立てる)
- **Resource** = 読み取り専用のデータ (ファイル、URL、DB のレコード)
- **Prompt** = 引数つきのメッセージテンプレート (「この文章を要約して」のような再利用形)

迷ったら **「LLM が読みたいだけ → Resource、LLM が叩いて何かしたい → Tool、LLM に決まった台詞を喋らせたい → Prompt」** で分けます。私が自作するときも、まず Tool / Resource / Prompt のどれに当てはまるかを最初の 30 秒で決めるようにしています。

server 全体のランタイム構成はこうなります。

```mermaid
flowchart TB
    classDef client fill:#e3f2fd,stroke:#1565c0
    classDef proto  fill:#fff3e0,stroke:#e65100
    classDef server fill:#e8f5e9,stroke:#2e7d32
    classDef ext    fill:#fce4ec,stroke:#ad1457

    CC[Claude Code セッション]:::client
    CFG[~/.claude.json<br/>or .mcp.json]:::client

    JSONRPC[JSON-RPC 2.0<br/>over stdio / HTTP]:::proto

    SRV[MCP Server<br/>node my-server.ts]:::server
    H1[listTools handler]:::server
    H2[callTool handler]:::server
    H3[listResources handler]:::server

    API1[GitHub API]:::ext
    API2[Internal DB / file]:::ext

    CFG -.spawn.-> SRV
    CC <-->|stdin/stdout| JSONRPC
    JSONRPC <--> SRV
    SRV --> H1
    SRV --> H2
    SRV --> H3
    H2 --> API1
    H3 --> API2
```

Claude Code 起動時に `~/.claude.json` または repo の `.mcp.json` を読んで、設定された MCP server プロセスを **子プロセスとして spawn** します。client と server は親子関係の **stdin / stdout 経由** で JSON-RPC を流します (リモート接続なら HTTP)。これが MCP のすべてです。

## 採用判断 — MCP を入れるべき 3 つの基準

私が MCP server を採用するか / Bash で済ますかの判断ツリー。

```mermaid
flowchart TD
    Q1{① 認証が複雑か?<br/>OAuth / refresh token / SSO}
    Q2{② バイナリ or<br/>リッチメタデータを扱うか?<br/>画像 / PDF / 構造化文書}
    Q3{③ 状態を持つか?<br/>セッション / cursor / cache}

    Q1 -->|Yes| YES[MCP 推奨]
    Q1 -->|No| Q2
    Q2 -->|Yes| YES
    Q2 -->|No| Q3
    Q3 -->|Yes| YES
    Q3 -->|No| BASH[Bash + gh / curl で十分]

    YES --> O1{公式 server あり?}
    O1 -->|Yes| USE[公式を使う]
    O1 -->|No| Q4{事業価値 ありか?}
    Q4 -->|Yes| BUILD[自作 50 行]
    Q4 -->|No| WAIT[公式が出るまで待つ]

    classDef ans fill:#fff3e0,stroke:#e65100,font-weight:bold
    class USE,BUILD,BASH,WAIT ans
```

**3 基準のうち 2 つ以上 yes なら MCP**、1 個以下なら Bash で十分というのが私の現在のラインです。

| 基準 | yes の例 | no の例 (Bash で十分) |
|---|---|---|
| ① 認証が複雑 | Figma / Notion (OAuth dance) | GitHub (`gh` CLI が token 管理) |
| ② リッチメタデータ | Figma の design tree、PDF OCR | Issue title、Slack の text 投稿 |
| ③ 状態を持つ | DB session、ページ cursor、cache | 単発 REST 呼び出し |

私の現状を当てはめると:

- **figma** → ① yes (OAuth)、② yes (design tree / screenshot)、③ yes (session 維持) → **公式 MCP 採用** (3/3)
- **github** → ① no (`gh` CLI で OK)、② no (text)、③ no (単発) → **`gh` で十分** (0/3)
- **slack** → ① yes (OAuth + bot token)、② △ (添付ファイル扱う場合)、③ no → **公式 MCP かつ実需が出てから** (1.5/3)
- **notion** → ① yes、② yes (block tree)、③ yes → **公式 MCP 推奨だが私は未導入** (3/3 だが事業価値なし)

「3/3 なのに導入していない」のは **事業価値の判定** が後段にあるからです。Notion を MCP で繋いでも私の 1 人会社では検索できる量が増えるだけで、事業数値 (MRR / churn / 開発速度) は動きません。**MCP 採用判断 = 技術的妥当性 × 事業価値** の 2 段階です。

## Before / After (1) — Bash + gh vs 公式 MCP

GitHub Issue を取りに行く場面で、Bash と MCP のどちらが軽いかを実コードで比べます。

**Before** (Bash + `gh`、現役):

```bash
# devops-hub での Issue 一覧取得
gh issue list --repo SakakitaniJunya/Komyu \
  --state open --label active --limit 20 \
  --json number,title,labels,updatedAt
```

1 行で済みます。`gh` が token を `~/.config/gh/hosts.yml` で管理してくれるので Claude Code は何も気にせず実行できます。`PATH` に `gh` があれば Slash command でも Skill でも Hook でも呼べる。これが基準 ① ② ③ いずれも no の典型例です。

**After** (もし MCP server で書いたら、過剰):

```typescript
// もし自作 MCP github-server.ts を作ったら (架空、現在は未導入)
import { Octokit } from "@octokit/rest";

server.tool(
  "list_issues",
  "List issues from a GitHub repo",
  { owner: z.string(), repo: z.string(), label: z.string().optional() },
  async ({ owner, repo, label }) => {
    const octokit = new Octokit({ auth: process.env.GH_TOKEN });
    const res = await octokit.rest.issues.listForRepo({ owner, repo, labels: label });
    return { content: [{ type: "text", text: JSON.stringify(res.data) }] };
  }
);
```

20 行近くなる + `GH_TOKEN` の置き場を考える必要が出る + Claude Code 起動時に常時 spawn される + listTools の返り値が context window を食う。**得るものはほぼゼロ** で、失うものだけ多い。私は最初これを書きかけて止めました。

## 1 ファイル 50 行で自作する最小実装

「3/3 + 公式無し + 事業価値あり」と判断した場合の自作の最小実装を、TypeScript SDK で書きます。題材は **「自社事業データ (Komyu の Cloud Run revision) を Claude Code に露出させる Tool」** という架空 (= 公式無し、事業価値あり、社内専用) のケース。

```typescript
// devops-hub/scripts/mcp-komyu-status.ts (架空、教育目的の最小実装)
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { execFile } from "node:child_process";
import { promisify } from "node:util";

const exec = promisify(execFile);

const server = new Server(
  { name: "komyu-status", version: "0.1.0" },
  { capabilities: { tools: {} } },
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "get_komyu_revision",
      description: "Komyu の Cloud Run 現行 revision を返す (asia-northeast1)",
      inputSchema: { type: "object", properties: {}, required: [] },
    },
  ],
}));

server.setRequestHandler(CallToolRequestSchema, async (req) => {
  if (req.params.name !== "get_komyu_revision") {
    throw new Error(`unknown tool: ${req.params.name}`);
  }
  const { stdout } = await exec("gcloud", [
    "run", "services", "describe", "komyu",
    "--region", "asia-northeast1",
    "--format", "value(status.latestReadyRevisionName)",
  ]);
  return { content: [{ type: "text", text: stdout.trim() }] };
});

await server.connect(new StdioServerTransport());
```

これで **本体 50 行未満** です (import 含めて 38 行)。`@modelcontextprotocol/sdk` 1 個に依存して `Server` + `StdioServerTransport` + 2 つの handler (list / call) を書くだけ。

## Claude Code への登録

書いた server を Claude Code から見えるようにするには `~/.claude.json` (global) または repo の `.mcp.json` (project) にエントリを足します。

```json
// ~/.claude.json (global、抜粋)
{
  "mcpServers": {
    "figma": {
      "command": "npx",
      "args": ["-y", "@figma/mcp-server"]
    },
    "komyu-status": {
      "command": "node",
      "args": ["/Users/sakaki/project/devops-hub/scripts/mcp-komyu-status.js"],
      "env": {
        "CLOUDSDK_CORE_PROJECT": "komyu-prod"
      }
    }
  }
}
```

Repo 単位で配布したい (チーム / CEO Agent 用) なら `.mcp.json` に同じ形式で書きます。

```json
// devops-hub/.mcp.json (project 配布用)
{
  "mcpServers": {
    "komyu-status": {
      "command": "node",
      "args": ["./scripts/mcp-komyu-status.js"]
    }
  }
}
```

`command` に書くのは **絶対パスまたは PATH 上のコマンド名**。私は global は絶対パス、repo 配布は相対パスで使い分けています (相対パスは Claude Code がサポートしている形)。

`tsc` でビルドして `.js` を指す場合は事前 build が必要です。**source `.ts` を直接 `tsx` で起動する手** もありますが、`tsx` は warm up コストがあり listTools の初回 timeout を踏みやすいので、私は素直に build 派です。

## Resource を公開する例

Tool だけでなく Resource (読み取り専用データ) を公開したい場合は、handler を 2 つ足すだけです。

```typescript
// scripts/mcp-komyu-status.ts に追記
import {
  ListResourcesRequestSchema,
  ReadResourceRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { readFile } from "node:fs/promises";

server.setRequestHandler(ListResourcesRequestSchema, async () => ({
  resources: [
    {
      uri: "komyu://decisions/latest",
      name: "Komyu 直近 Decision Genealogy",
      mimeType: "application/x-ndjson",
    },
  ],
}));

server.setRequestHandler(ReadResourceRequestSchema, async (req) => {
  if (req.params.uri !== "komyu://decisions/latest") {
    throw new Error(`unknown resource: ${req.params.uri}`);
  }
  const text = await readFile(
    "/Users/sakaki/project/devops-hub/.claude/decisions/decisions.jsonl",
    "utf-8",
  );
  return {
    contents: [
      { uri: req.params.uri, mimeType: "application/x-ndjson", text },
    ],
  };
});
```

これで Claude Code 側から `komyu://decisions/latest` が **読み取り専用 URI として参照可能** になります。MCP の URI スキームは自分で決められる (`komyu://`) ので、`scheme://path` の形で社内データに名前空間を切ると見通しが良いです。

## Before / After (2) — Heavy MCP vs 50 行 Light MCP

私が初期に書いて捨てた重い自作 MCP と、上の 50 行版を比較します。

**Before** (Heavy、廃止):

```typescript
// 約 350 行、全部入り
// - GitHub / GCS / Cloud Run / BigQuery を 1 server に詰めた
// - 各 API の認証を server 内で抱えた (.env 直書き)
// - 24 個の Tool を listTools で返した → context が 6KB 食われた
// - dependency: octokit, @google-cloud/storage, @google-cloud/run, @google-cloud/bigquery, ...
// - 起動時 cold start 約 4 秒
```

これを 1 ヶ月運用したら、Claude Code の listTools 応答が肥大して **会話 1 回ごとの token が無視できない量** に増え、なおかつ依存 update のたびに本体が壊れました。版 lock のせいで Komyu 側で `@google-cloud/run` を上げたら MCP server がコケる、という嫌な依存性が出ました。

**After** (Light、現行):

```typescript
// 1 server = 1 関心、50 行未満
// - komyu-status のみ。GitHub / GCS は別 server (= 必要になったら別 file)
// - 認証は `gcloud` CLI に任せる (server 内で credential を持たない)
// - Tool 1 個 / Resource 1 個 / Prompt 0 個
// - 依存: @modelcontextprotocol/sdk のみ
// - 起動 cold start 0.3 秒
```

**1 server 1 関心** に倒したら全部楽になりました。MCP server は **マイクロサービス的に細かく切る** のが正解。1 つの巨大 server に詰める誘惑に勝てるかが運用の分岐点です。

## 落とし穴 / 失敗談

### 失敗 1: process 管理を忘れて 7 個の zombie が残った

最初の自作 MCP は **`SIGTERM` を受けても綺麗に exit しなかった** ため、Claude Code を再起動するたびに古い node プロセスが残り、ある日 `ps aux | grep node` したら **同じ MCP server の zombie が 7 個** いました。子プロセスから孫プロセス (`gcloud`) を fork していたので、親が殺されても孫が走り続けるパターン。

**Before** (壊れた版):

```typescript
await server.connect(new StdioServerTransport());
// ↑ 終了処理なし、SIGTERM 受けても無視
```

**After** (現行):

```typescript
const transport = new StdioServerTransport();
await server.connect(transport);

const shutdown = async () => {
  await server.close();
  process.exit(0);
};
process.on("SIGTERM", shutdown);
process.on("SIGINT", shutdown);
```

**教訓: MCP server は子プロセスである以上、親 (Claude Code) の死に追従して exit する責務がある**。`SIGTERM` / `SIGINT` の handler は最低限必須。ついでに `gcloud` のような孫プロセスは `{ detached: false }` で fork する。

### 失敗 2: 認証情報を server 内 `.env` に直書きして PR で漏れかけた

初期実装では `process.env.GH_TOKEN` を `.env` に書いて `dotenv` で読み込んでいたところ、`.env` を `.gitignore` し忘れて GitHub に push しかけました (push 直前 `git status` で気づいた)。

**Before** (壊れた版):

```typescript
// scripts/.env
// GH_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
// GCP_SA_KEY={"type":"service_account",...}

import "dotenv/config";
const token = process.env.GH_TOKEN;
```

**After** (現行):

```typescript
// MCP server は credential を保持しない。OS の認証 store に任せる:
// - GitHub  → gh CLI の hosts.yml
// - GCP     → gcloud の application default credentials
// - Stripe  → keychain or 1Password CLI

// server 内では subprocess を呼ぶだけ:
const { stdout } = await exec("gh", ["api", "/user"]);
```

**教訓: MCP server に認証情報を持たせない**。`gh` / `gcloud` / `aws` のような **CLI が既に解決している認証は CLI に丸投げ** する。`.env` の書き間違えで credential を漏らすリスクを 0 にできる。私はこれ以降、自作 server に直接 token を渡すパターンを禁止しています。

### 失敗 3: listTools の返り値で context window を圧迫した

24 個の Tool を 1 server に詰めて全部 description を 200 字書いたら、Claude Code セッション開始直後に **context が 6KB ほど食われた**ことがありました。1 セッション で会話 50 turn 回せば 300KB 相当 (= 数 % の context window)。これは MCP の常時露出という性質ゆえの罠です。

**Before** (壊れた版):

```typescript
server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    { name: "tool_1", description: /* 200 字 */, inputSchema: { /* 大 */ } },
    { name: "tool_2", description: /* 200 字 */, inputSchema: { /* 大 */ } },
    // ... 24 個続く
  ],
}));
```

**After** (現行):

```typescript
// 1 server 1 Tool が原則。description は 1 行 (60-80 字) に絞る。
server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "get_komyu_revision",
      description: "Komyu の Cloud Run 現行 revision を返す (asia-northeast1)",
      inputSchema: { type: "object", properties: {}, required: [] },
    },
  ],
}));
```

**教訓: MCP の Tool は「常時露出」する性質上、context window コストが永久に乗る**。Slash command や Skill と違い、呼ばれなくても description は client に流れているので、不要な Tool は載せない。description は **「1 行で機能と引数の要点」** に圧縮する。

### 失敗 4: SDK の version 衝突で Claude Code 起動が失敗した

`@modelcontextprotocol/sdk` を repo 内で使い、別 repo の MCP server も同じ SDK を別 version で使っていたら、`~/.claude.json` から `npx -y` で起動する server と、repo の `.mcp.json` から起動する server で **SDK version の major mismatch** が発生し、`unknown method` エラーが出る事態になりました。

**Before** (壊れた版):

```json
// repo A の package.json: "@modelcontextprotocol/sdk": "^0.4.0"
// repo B の package.json: "@modelcontextprotocol/sdk": "^0.6.0"
// → 同時に Claude Code から呼ぶと、handler の signature が変わって死ぬ
```

**After** (現行):

```json
// すべての自作 server を 1 repo (devops-hub/scripts/mcp/) に集約。
// SDK は repo root の package.json で 1 version 固定。
// 各 server は `node ./scripts/mcp/<name>.js` で起動。
{
  "dependencies": {
    "@modelcontextprotocol/sdk": "0.6.1"
  }
}
```

**教訓: MCP server は単一 repo で SDK version を 1 個に固定する**。複数 repo に散らすと version drift が即時死を招く。`scripts/mcp/<server-name>.ts` の monorepo 配置で揃える、または `bunx` のような version pinning が効く起動方法を使う。

## 残課題 — まだできていないこと

正直に並べます。

1. **HTTP transport の本番運用は未経験** — 私の自作 server はすべて stdio ローカル起動。リモート MCP (HTTP / SSE) は team 配布する将来必要だが、認証 / mTLS / rate-limit の設計が手付かず。
2. **Tool 設計の粒度ガイド不足** — 「1 server 1 関心」までは固まったが、その内部で Tool を何個に分けるかは経験則。`get_x` `update_x` を分けるか統合するかは毎回迷う。
3. **OAuth client を持つ server の認証フロー** — 公式 figma は OAuth dance を裏でやってくれているが、自作で OAuth を持つと dance を server 内に実装する必要がある。SDK の helper があるはずだが調査未着手。
4. **MCP Prompt の使いどころが見えていない** — Tool / Resource は明確だが、Prompt は Slash command との境界が曖昧。私は今のところ Prompt を 0 個も実装していない。
5. **採用判断 3 基準の定量化** — 「① 認証が複雑」「② リッチメタデータ」「③ 状態を持つ」を主観で判定しているが、チームに広めるなら yes/no を切る客観基準が要る。

## 理論根拠 — なぜ「採用ライン高め」が正解なのか

最後に、判断軸の根拠を 3 つ。

### 根拠 1: MCP は「常時露出」の機構 — context cost が永久に乗る

5 機構の中で MCP だけが **「呼ばれていなくても存在コストがある」** という特殊な性質を持ちます (詳細は [A-01 5 機構](./claude-code-as-company-5-mechanisms))。Slash / Subagent / Skill は呼ばれた瞬間にだけ context を食う。Hook は tool 呼び出しに紐づいて瞬発的に走る。MCP の Tool は **listTools で client に description が常時露出される**ため、何もしなくても context window を食い続けます。

会話 1 turn ごとに **数百〜数 KB の Tool description が context に流れる** = 100 turn 続けば 100 倍。**1 turn の token cost は雑音だが、累積は本質**。だから MCP は気軽に増やせない。「Bash で済むなら Bash」を default にすべき強い理由です。

### 根拠 2: 公式 server がある領域は車輪の再発明をしない

Anthropic の公式 MCP server registry には figma / slack / github / postgres など主要 SaaS が並んでいて、メンテナーが Anthropic 自身か SaaS ベンダーです。**自作 = ゼロから OAuth / rate-limit / error handling を書き直す** ことになり、メンテ責任が個人にきます。

副業の 1 人会社で OSS の保守タスクを抱える余裕は無いので、**「公式があれば公式、無ければ事業価値が高い場合のみ自作」** が正しい。これは [A-02 Skill Architecture](./skill-architecture-introduction) で論じた「自作の動機が弱いものは公開しない / 自作しない」と同じ原則です。

### 根拠 3: 1 server 1 関心 = マイクロサービス原則の小型版

「1 server 1 関心」は突き詰めると古典的なマイクロサービス原則 (Single Responsibility / Bounded Context) の小型版です。Tool を詰め込んだ巨大 server は、依存関係 / version 衝突 / context cost のすべてで損をする。**小さい単位に切る** ことで、

- 失敗 1 (zombie) → 該当 server だけ kill すれば良い
- 失敗 2 (credential) → CLI 任せにできるので server に持たない
- 失敗 3 (context) → 1 server あたり Tool 数が減る
- 失敗 4 (version) → repo を分散させない

の 4 つすべてが緩和される。**1 server 1 関心は MCP の運用上の universal な答え** です。

## まとめ

- MCP server は **公式があれば公式、無ければ採用ラインを高く** が default。
- 自作するなら **TypeScript SDK + stdio + 1 ファイル 50 行** が最小実装。
- 「1 server 1 関心」を守る。Tool を詰め込まない。
- 認証は CLI (`gh` / `gcloud`) に丸投げ、server 内に credential を持たない。
- description は 1 行に圧縮。listTools の常時露出 cost を意識する。
- `SIGTERM` / `SIGINT` の handler を必ず書いて zombie を残さない。

私は今のところ自作 MCP は 0 本ですが、Komyu の Decision Genealogy を Claude Code に直接読ませたい局面が来たら、上の 50 行から始めるつもりです。

## 次の記事へ + 連載をフォロー

これは **52 本連載 (ai-driven-dev) の Day 29/52** です。

関連:

→ **A-01 [Slash と Skill と Hook を混ぜて爆発した話 — Claude Code 5 機構](./claude-code-as-company-5-mechanisms)** (Day 2/52) — MCP を含む 5 機構の使い分け

→ **A-02 [Skill Architecture 入門 — description で発火する手続き知識](./skill-architecture-introduction)** (Day 3/52) — Skill の自作と発火条件

→ **A-03 [Hooks で品質ゲートを作る — PostToolUse / Stop の使い分け](./hooks-quality-gates)** (Day 4/52) — Hook と MCP の境界

これから書く予定:

→ **A-09** Status Line を KPI ダッシュボードにする
→ **A-10** Claude Code Memory 4 種の使い分け

### 連載を見逃さない方法

- **Zenn でこの著者をフォロー** — 公開通知が届きます
- **X で告知 tweet をフォロー** (準備中) — 朝 6:00 に投稿
- **repo を watch**: [SakakitaniJunya/zenn-articles](https://github.com/SakakitaniJunya/zenn-articles) — 全 draft が見えます

### Discussion / フィードバック歓迎

- 「採用 3 基準、自分はこの 4 つ目を入れている」 → GitHub Issue で議論しましょう
- 「自作 MCP server で別の運用罠を踏んだ」 → Before/After で寄稿歓迎
- 「公式 server で認証 dance がうまく動かない」 → 反例も歓迎

連載 52 本を書き切る間に、MCP 採用判断は更新し続けます。本記事も将来書き直します。誤りや「ここをもっと深く」のリクエストは GitHub Issue でお気軽に。
