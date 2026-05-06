#!/usr/bin/env bash
# statusline.sh — toolkit-shipped Claude Code statusline.
# Reads JSON session info on stdin (per https://code.claude.com/docs/en/statusline).
# Prints: branch | dirty | model | session-cost (if ccusage available)
#
# Required: jq. Optional: ccusage (npm i -g ccusage), or `bunx ccusage`.

set -uo pipefail

INPUT="$(cat 2>/dev/null || true)"
MODEL="$(echo "$INPUT" | jq -r '.model.display_name // .model.id // "claude"' 2>/dev/null)"
WORKDIR="$(echo "$INPUT" | jq -r '.workspace.current_dir // .cwd // empty' 2>/dev/null)"
[[ -n "$WORKDIR" ]] && cd "$WORKDIR" 2>/dev/null

# Branch + dirty count.
if git rev-parse --git-dir >/dev/null 2>&1; then
  BRANCH="$(git branch --show-current 2>/dev/null || echo 'detached')"
  DIRTY="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
  GIT_PART="${BRANCH}"
  [[ "$DIRTY" -gt 0 ]] && GIT_PART="${BRANCH}*${DIRTY}"
else
  GIT_PART="(no git)"
fi

# Optional ccusage cost block.
COST_PART=""
if command -v ccusage >/dev/null 2>&1; then
  COST_PART=" | $(echo "$INPUT" | ccusage statusline 2>/dev/null | tail -1 || echo '')"
elif command -v bunx >/dev/null 2>&1; then
  COST_PART=" | $(echo "$INPUT" | bunx ccusage statusline 2>/dev/null | tail -1 || echo '')"
fi

printf '%s | %s%s\n' "$GIT_PART" "$MODEL" "$COST_PART"
