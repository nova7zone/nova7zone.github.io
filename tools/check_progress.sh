#!/usr/bin/env bash
set -euo pipefail

# Check that .claude/progress.md exists and contains required fields
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROGRESS_FILE="$ROOT_DIR/.claude/progress.md"

err() {
  echo "Error: $1" >&2
}

if [ ! -f "$PROGRESS_FILE" ]; then
  err "$PROGRESS_FILE not found. Please create the progress summary before running this script."
  exit 1
fi

if ! grep -q "요약:" "$PROGRESS_FILE"; then
  err "Required section '요약:' not found in $PROGRESS_FILE"
  exit 1
fi

if ! grep -q "날짜:" "$PROGRESS_FILE"; then
  err "Required field '날짜:' not found in $PROGRESS_FILE"
  exit 1
fi

echo "> Progress check passed: $PROGRESS_FILE"
exit 0
