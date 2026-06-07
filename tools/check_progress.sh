
#!/usr/bin/env bash
set -euo pipefail

# Enhanced progress checks for .claude/progress.md
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROGRESS_FILE="$ROOT_DIR/.claude/progress.md"

err() {
  echo "Error: $1" >&2
}

if [ ! -f "$PROGRESS_FILE" ]; then
  err "$PROGRESS_FILE not found. Please create the progress summary before running this script."
  exit 1
fi

# Check for 요약:
if ! grep -q -E "^[[:space:]-]*요약:" "$PROGRESS_FILE"; then
  err "Required section '요약:' not found in $PROGRESS_FILE"
  exit 1
fi

# Ensure 요약: has non-empty content on the following lines
summary_line=$(grep -n -E "^[[:space:]-]*요약:" "$PROGRESS_FILE" | cut -d: -f1 || true)
if [ -n "$summary_line" ]; then
  next_line=$((summary_line + 1))
  next_content=$(sed -n "${next_line}p" "$PROGRESS_FILE" || true)
  if [ -z "$(echo "$next_content" | sed 's/^[[:space:]-]*//')" ]; then
    err "The '요약:' section appears to be empty. Please provide a brief summary."
    exit 1
  fi
fi

# Check for 날짜:
if ! grep -q -E "^[[:space:]-]*날짜:" "$PROGRESS_FILE"; then
  err "Required field '날짜:' not found in $PROGRESS_FILE"
  exit 1
fi

date_value=$(grep -m1 -E '날짜:' "$PROGRESS_FILE" | sed 's/.*날짜: *//; s/ *$//')
today=$(date +%Y-%m-%d)
if [ "${SKIP_PROGRESS_DATE_CHECK:-0}" != "1" ] && [ "$date_value" != "$today" ]; then
  err "The '날짜:' value ($date_value) does not match today's date ($today)."
  err "Update $PROGRESS_FILE or set SKIP_PROGRESS_DATE_CHECK=1 to override."
  exit 1
fi

# Check for 변경된 파일:
if ! grep -q "변경된 파일:" "$PROGRESS_FILE"; then
  err "Required section '변경된 파일:' not found in $PROGRESS_FILE"
  exit 1
fi

# Ensure at least one listed file under 변경된 파일:
match_line=$(grep -n -m1 '변경된 파일:' "$PROGRESS_FILE" | cut -d: -f1 || true)
has_file=0
if [ -n "$match_line" ]; then
  for i in $(seq 1 8); do
    lnum=$((match_line + i))
    line=$(sed -n "${lnum}p" "$PROGRESS_FILE" || true)
    if [ -z "$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')" ]; then
      continue
    fi
    if echo "$line" | grep -q '[-*]'; then
      has_file=1
      break
    fi
    # also accept plain text filenames
    if echo "$line" | grep -qE '[[:alnum:]._/-]+'; then
      has_file=1
      break
    fi
  done
fi
if [ "$has_file" -ne 1 ]; then
  err "No files listed under '변경된 파일:' in $PROGRESS_FILE"
  exit 1
fi

# Check for 다음 작업
if ! grep -q '다음 작업' "$PROGRESS_FILE"; then
  err "Required section '다음 작업' not found in $PROGRESS_FILE"
  exit 1
fi

echo "> Progress check passed: $PROGRESS_FILE"
exit 0
