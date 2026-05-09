# zenn-articles — Junya Sakakitani / CreaNest

[Zenn](https://zenn.dev) の GitHub 連携 repo。AI 駆動開発の記録を毎日 1 本公開する。

> **方針**: Claude Code (CLI) が draft → CEO が朝 5 分 approve → main merge で自動公開 + X 自動投稿。
> 量より「シリーズで 52 本繋がる」を狙う。**Anthropic API key は使わない (Max plan の `claude` CLI で完結)**。

## 目的

- 「AI でどんな開発ができるか」を技術記事の形でアピール
- 個人 / CreaNest の採用・営業・登壇への流入チャネル
- 自分自身の知見の体系化 (棚卸し → 公開 → fb で精度向上)

## 構造

```
zenn-articles/
├── articles/                       # Zenn 公開記事 (slug = filename)
├── books/                          # 連載 (使う場合のみ)
├── topic-queue.yaml                # 53 件 (INDEX + 52 章) 執筆 queue
├── voice.md                        # トーン辞書 (一人称・敬体・絵文字 etc.)
├── frontmatter-spec.md             # frontmatter 規約
├── .claude/commands/zenn-next.md   # /zenn-next slash command
├── scripts/
│   ├── generate-draft.sh           # claude -p "/zenn-next" を呼ぶ wrapper
│   └── publish-next.sh             # X 投稿 (Phase 2 stub)
├── com.creanest.zenn-daily-draft.plist  # launchctl agent (Mac local cron)
└── .github/workflows/
    └── post-publish-tweet.yml      # main merge → X 投稿 (claude CLI 不使用)
```

## 自動化フロー

> **設置: 自宅 iMac (always-on-host)**
> MacBook ではなく自宅 iMac の `~/Library/LaunchAgents/` に plist を load する。詳細: [`devops-hub/docs/runbooks/always-on-host-inventory.md`](../devops-hub/docs/runbooks/always-on-host-inventory.md) Phase D。

```
[iMac]
  05:00 JST  launchctl com.creanest.zenn-daily-draft
             → scripts/generate-draft.sh
             → claude -p "/zenn-next" (Max plan, API key 不要)
             → articles/<slug>.md を Write、topic-queue.yaml を更新

[CEO]  朝 5 分
  Zenn 記事を edit / approve、frontmatter published: true → main push
             → Zenn が自動公開 (GitHub 連携)
             → ✅ Zenn 記事のみ CEO approve 必須

[iMac]  12:00 / 18:00 / 21:00 JST  ★ CEO 承認なし、フル自動
  launchctl com.creanest.zenn-auto-post
             → scripts/auto-post.sh
             → draft-queue.jsonl から quality gate 通過分を 1 件選定:
                · category whitelist (numbers 除外)
                · score >= 0.6
                · NG regex (個人名/金額/顧客名)
                · dedup (cosine > 0.7 で skip)
                · rate limit (1 日 3 / 1 時間 1)
             → X API v2 (or vibium) で投稿
             → posted.jsonl に append、status=posted
```

## 初期セットアップ (CEO アクション)

```bash
# 1. リポ作成
gh repo create SakakitaniJunya/zenn-articles --public --source . --push

# 2. Zenn account に GitHub 連携
#    https://zenn.dev/dashboard/deploys から SakakitaniJunya/zenn-articles を選択

# 3. launchctl 登録 (Mac)
ln -s "$(pwd)/com.creanest.zenn-daily-draft.plist" \
      ~/Library/LaunchAgents/com.creanest.zenn-daily-draft.plist
launchctl load ~/Library/LaunchAgents/com.creanest.zenn-daily-draft.plist

# 4. (Phase 2) X API key を GitHub Secrets に投入
gh secret set X_API_KEY        --body "..."
gh secret set X_API_SECRET     --body "..."
gh secret set X_ACCESS_TOKEN   --body "..."
gh secret set X_ACCESS_SECRET  --body "..."

# 5. (任意) zenn-cli 動作確認
pnpm install && pnpm preview   # localhost:8000
```

## ローカル実行

```bash
# 手動 1 件 draft (queue から自動選定)
pnpm draft

# topic id 指定で draft
bash scripts/generate-draft.sh A-01

# 即時 launchctl trigger
launchctl start com.creanest.zenn-daily-draft

# Zenn local preview
pnpm preview
```

## なぜ Anthropic API ではなく Claude Code (CLI) か

- ✅ **Max plan で API 課金不要** — 既存サブスクで完結
- ✅ **API key 管理不要** — secret を repo / CI に置かない
- ✅ **skill / memory / context engine が自動で効く** — voice / frontmatter ルールを文脈に持ったまま draft 生成
- ✅ **Claude Code の Read / Write / Bash tool で他 repo (devops-hub / build-football 等) を context として読める**
- ⚠️ **GitHub Actions では実行できない** — `claude` CLI がインストールされていないため、daily draft は **Mac local launchctl** で動かす

### 非対話実行 (permission prompt 回避)

`claude -p` は default で permission prompt が出て止まる。`launchctl` の cron では応答できないため:

1. `.claude/settings.json` に **使う Bash / Read / Write を allowlist** 済 (Read 関連 repo / Write articles / Edit topic-queue.yaml / git status 系 / pnpm / zenn-cli / vibium)
2. `scripts/generate-draft.sh` は `--permission-mode acceptEdits` で起動 (編集系を auto-approve)
3. allowlist 外の Bash を `/zenn-next` が呼んだ場合は止まる → ログを見て `.claude/settings.json` を更新

deny list で `git push` / `gh pr merge` / `rm -rf` / 機密ディレクトリへの Write は明示的にブロック。

## 関連

- 戦略 SSOT: [devops-hub/docs/business/pr/zenn-strategy.md](../devops-hub/docs/business/pr/zenn-strategy.md)
- 元ネタ: [devops-hub/docs/business/hr/ai-development-portfolio.md](../devops-hub/docs/business/hr/ai-development-portfolio.md)
- Tweet capture (CEO 発言 → X 草案): `~/.claude/skills/tweet-capture/SKILL.md`
- emit script: `devops-hub/pipeline-kit/ops/emit-tweet-candidate.sh`
