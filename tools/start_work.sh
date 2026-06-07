#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROGRESS_FILE="$ROOT_DIR/.claude/progress.md"

if [ ! -f "$PROGRESS_FILE" ]; then
  echo "Error: $PROGRESS_FILE not found."
  echo "Please create the progress summary before starting work."
  exit 1
fi

echo "=== 이전 작업 요약 (.claude/progress.md) ==="
cat "$PROGRESS_FILE"

echo
if command -v git >/dev/null 2>&1; then
  echo "=== Git 상태 ==="
  git -C "$ROOT_DIR" status --short
  echo
  echo "=== 최신 커밋 ==="
  git -C "$ROOT_DIR" log -1 --oneline
else
  echo "Git is not available in PATH."
fi
