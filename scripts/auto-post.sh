#!/usr/bin/env bash
#
# auto-post.sh — draft-queue.jsonl から quality gate 通過分を X に自動投稿
#
# 設置: 自宅 iMac (always-on-host-inventory.md `com.creanest.zenn-auto-post`)
# 頻度: 12:00 / 18:00 / 21:00 JST (1 日 3 回)
# CEO 承認なし: 日常ツイートはフル自動 (CEO 明示要請 2026-05-09)
#
# Quality gates:
#   1. Category whitelist: dev-progress / tech-learning / ai-ops-mindset / industry-watch
#      (numbers は除外 — MRR / 売上 / 顧客名 を public に晒すリスク)
#   2. Score: >= 0.6
#   3. NG word regex: 個人名 (.{1,4}(さん|氏|様)) / 金額 (¥\d+|\d+万円) / 顧客名リスト
#   4. Dedup: 直近 7 日 posted.jsonl と cosine sim > 0.7 → skip
#   5. Rate limit: 1 日 3 投稿 / 1 時間 1 投稿 / 連続同 category 回避
#
# 緊急停止: launchctl unload ~/Library/LaunchAgents/com.creanest.zenn-auto-post.plist

set -euo pipefail

DEVOPS_HUB_ROOT="${HOME}/project/devops-hub"
QUEUE_FILE="${DEVOPS_HUB_ROOT}/.claude/tweets/draft-queue.jsonl"
POSTED_FILE="${DEVOPS_HUB_ROOT}/.claude/tweets/posted.jsonl"
FORBIDDEN_CUSTOMERS_FILE="${DEVOPS_HUB_ROOT}/.claude/tweets/forbidden-customers.txt"
LOG_DIR="${DEVOPS_HUB_ROOT}/.claude/tweets/logs"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/auto-post-$(date +%Y%m%d).log"

# X API key (1Password CLI 等で展開、~/.config/zenn-articles/x.env から読む想定)
X_ENV="${HOME}/.config/zenn-articles/x.env"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"; }

log "=== auto-post.sh start ==="

# ---- Phase 2 stub: 実装は後で ----
# 以下の python オブジェクトで全 gate を回す予定:
#
# import json, re, math, os, time
# from collections import Counter
#
# CATEGORY_WHITELIST = {"dev-progress", "tech-learning", "ai-ops-mindset", "industry-watch"}
# SCORE_THRESHOLD = 0.6
# DAILY_MAX = 3
# HOURLY_MAX = 1
# DEDUP_THRESHOLD = 0.7
# DEDUP_WINDOW_DAYS = 7
#
# NG_REGEXES = [
#     r"(.{1,4})(さん|氏|様)",     # 個人名 (緩い検出、誤爆あり)
#     r"¥\d+|\d+万円|\d+万",        # 金額
#     r"MRR|売上|月商|フォロワー数 \d+",
# ]
# # 顧客名リスト
# if os.path.exists(FORBIDDEN_CUSTOMERS_FILE):
#     with open(FORBIDDEN_CUSTOMERS_FILE) as f:
#         NG_REGEXES.extend([re.escape(line.strip()) for line in f if line.strip()])
#
# def cosine(a: str, b: str) -> float:
#     # 文字 bigram cosine (簡易)
#     def bigrams(s): return Counter(s[i:i+2] for i in range(len(s)-1))
#     ba, bb = bigrams(a), bigrams(b)
#     dot = sum(ba[k]*bb[k] for k in ba.keys() & bb.keys())
#     na = math.sqrt(sum(v*v for v in ba.values()))
#     nb = math.sqrt(sum(v*v for v in bb.values()))
#     return dot / (na*nb) if na*nb else 0
#
# # 1. queue 読込
# with open(QUEUE_FILE) as f:
#     queue = [json.loads(l) for l in f if l.strip()]
#
# pending = [r for r in queue if r["status"] == "pending"]
#
# # 2. category gate
# pending = [r for r in pending if r["category"] in CATEGORY_WHITELIST]
#
# # 3. score gate
# pending = [r for r in pending if r["score"] >= SCORE_THRESHOLD]
#
# # 4. NG word
# def has_ng(t): return any(re.search(p, t) for p in NG_REGEXES)
# pending = [r for r in pending if not has_ng(r["draft_tweet"])]
#
# # 5. dedup vs posted
# posted_recent = []
# if os.path.exists(POSTED_FILE):
#     with open(POSTED_FILE) as f:
#         posted_recent = [json.loads(l) for l in f if l.strip()][-50:]
# def is_dup(t):
#     return any(cosine(t, p["draft_tweet"]) > DEDUP_THRESHOLD for p in posted_recent)
# pending = [r for r in pending if not is_dup(r["draft_tweet"])]
#
# # 6. rate limit
# now = time.time()
# today = [p for p in posted_recent if p["posted_at"][:10] == time.strftime("%Y-%m-%d")]
# if len(today) >= DAILY_MAX:
#     print("daily cap reached"); exit(0)
# last_hour = [p for p in posted_recent if now - parse_iso(p["posted_at"]) < 3600]
# if len(last_hour) >= HOURLY_MAX:
#     print("hourly cap reached"); exit(0)
#
# # 7. category 連続避け
# if today and pending:
#     last_cat = today[-1]["category"]
#     diff_cat = [r for r in pending if r["category"] != last_cat]
#     if diff_cat: pending = diff_cat
#
# # 8. score 上位 1 件選択
# if not pending:
#     print("no candidate after gates"); exit(0)
# pick = max(pending, key=lambda r: r["score"])
#
# # 9. X v2 API で POST /2/tweets
# # ... (OAuth1.0a + curl or python requests-oauthlib)
#
# # 10. status=posted に更新 + posted.jsonl に append
#
# ----------------------------------------------------------------

if [[ ! -f "${X_ENV}" ]]; then
  log "X env not found at ${X_ENV} — Phase 2 未着手なので skip"
  exit 0
fi

log "Phase 2 stub — gate logic not yet implemented, skipping"
exit 0
