#!/usr/bin/env bash
# PostToolUse(Edit|Write) — run the project's formatter on files Claude just modified.
#
# Best-effort: never fails the edit. Detects formatter from file extension + tool availability.
# Skips on large files (>1MB) and binary files.

set -uo pipefail

INPUT="$(cat)"
FILE="$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")"

[[ -z "$FILE" || ! -f "$FILE" ]] && exit 0

# Skip oversized files and binaries.
SIZE=$(stat -c%s "$FILE" 2>/dev/null || stat -f%z "$FILE" 2>/dev/null || echo 0)
[[ "$SIZE" -gt 1048576 ]] && exit 0
file "$FILE" 2>/dev/null | grep -qE 'binary|executable' && exit 0

format_with() {
  command -v "$1" >/dev/null 2>&1 && "$@" "$FILE" >/dev/null 2>&1 || true
}

case "$FILE" in
  *.py)
    format_with ruff format
    [[ $? -eq 0 ]] || format_with black -q
    ;;
  *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs|*.json|*.md|*.yaml|*.yml|*.css|*.html)
    format_with npx --no-install prettier --write
    ;;
  *.rs)
    format_with rustfmt
    ;;
  *.go)
    format_with gofmt -w
    ;;
  *.sh)
    format_with shfmt -w
    ;;
  *.tex)
    # LaTeX: do nothing (formatters often break custom commands).
    ;;
esac

exit 0
