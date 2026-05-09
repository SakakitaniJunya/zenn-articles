#!/usr/bin/env bash
#
# publish-next.sh — published: true に切り替わった記事を検出し、X に告知 tweet
#
# 前提: post-merge / cron いずれかで起動。X API key は ~/.config/zenn-articles/x.env から読む。
# 現状は Phase 2 stub。実装は後で。

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${REPO_ROOT}"

X_ENV="${HOME}/.config/zenn-articles/x.env"
if [[ ! -f "${X_ENV}" ]]; then
  echo "[publish-next] X env not found at ${X_ENV} — skip tweet (Phase 2 未着手)"
  exit 0
fi

# shellcheck disable=SC1090
source "${X_ENV}"

for var in X_API_KEY X_API_SECRET X_ACCESS_TOKEN X_ACCESS_SECRET; do
  if [[ -z "${!var:-}" ]]; then
    echo "[publish-next] missing ${var} — skip"
    exit 0
  fi
done

echo "[publish-next] Phase 2 stub — X API call not yet implemented"
# TODO: git diff HEAD~1 HEAD -- articles/ で published: false→true 検出
# TODO: title / topics / slug を抽出
# TODO: tweet 文 = title + 一行要約 + Zenn URL + hashtag 2 つ
# TODO: curl で POST /2/tweets (OAuth1.0a)
# TODO: devops-hub/.claude/tweets/posted.jsonl に append

exit 0
