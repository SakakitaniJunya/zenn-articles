#!/usr/bin/env bash
#
# generate-draft.sh — Claude Code (CLI) を呼んで Zenn 記事 draft を生成
#
# Usage:
#   scripts/generate-draft.sh           # topic-queue から自動選定
#   scripts/generate-draft.sh A-01      # queue_id を指定
#
# 前提:
#   - claude CLI (Claude Code) がインストール済 (Max plan で API key 不要)
#   - cwd は zenn-articles repo root
#
# launchctl から呼ばれる前提 (`com.creanest.zenn-daily-draft.plist`)。
#
# Permission mode:
#   --permission-mode bypassPermissions
#     headless worker は対話相手がいないため、許可ダイアログで停止すると永遠に待つ。
#     `acceptEdits` は Bash を bypass しないため Bash 含む slash command でハングする。
#     30 分 watchdog + cwd 制限 + .claude/settings.json の deny で security boundary を維持。
#     (devops-hub/pipeline-kit/ops/run-orchestrator.sh と同パターン)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
QUEUE_ID="${1:-}"
LOG_DIR="${REPO_ROOT}/.zenn-logs"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/$(date +%Y%m%d-%H%M%S).log"

cd "${REPO_ROOT}"

# claude CLI 存在チェック
if ! command -v claude >/dev/null 2>&1; then
  echo "[generate-draft] FATAL: claude CLI not found in PATH" | tee -a "${LOG_FILE}"
  exit 1
fi

# slash command を組み立て (stdin 経由で claude に渡す)
if [[ -n "${QUEUE_ID}" ]]; then
  PROMPT="/zenn-next ${QUEUE_ID}"
else
  PROMPT="/zenn-next"
fi

PROMPT_FILE="$(mktemp -t zenn-prompt.XXXXXX)"
echo "${PROMPT}" > "${PROMPT_FILE}"
trap 'rm -f "${PROMPT_FILE}"' EXIT

echo "[generate-draft] running: claude -p (prompt=${PROMPT}, cwd=${REPO_ROOT})" | tee -a "${LOG_FILE}"

# 30 分 watchdog (Mac 標準には timeout コマンドがないので自前)
CHILD_PID=""
start_watchdog() {
  local target_pid="$1"
  (
    sleep 1800
    if kill -0 "${target_pid}" 2>/dev/null; then
      echo "[generate-draft] WATCHDOG: 30min timeout — killing ${target_pid}" | tee -a "${LOG_FILE}"
      pkill -TERM -P "${target_pid}" 2>/dev/null || true
      kill -TERM "${target_pid}" 2>/dev/null || true
      sleep 5
      pkill -KILL -P "${target_pid}" 2>/dev/null || true
      kill -KILL "${target_pid}" 2>/dev/null || true
    fi
  ) &
  WATCHDOG_PID=$!
}

set +e
claude \
  -p \
  --verbose \
  --permission-mode bypassPermissions \
  --add-dir "${HOME}/project/devops-hub" \
  < "${PROMPT_FILE}" >> "${LOG_FILE}" 2>&1 &
CHILD_PID=$!
start_watchdog "${CHILD_PID}"

wait "${CHILD_PID}"
RC=$?
set -e

if [[ -n "${WATCHDOG_PID:-}" ]]; then
  kill "${WATCHDOG_PID}" 2>/dev/null || true
fi

echo "[generate-draft] claude exited with ${RC}" | tee -a "${LOG_FILE}"
exit "${RC}"
