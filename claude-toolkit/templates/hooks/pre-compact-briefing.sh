#!/usr/bin/env bash
# PreCompact — write a checkpoint of "what we were doing" to disk so context survives compaction.
#
# Hook input (stdin) carries session metadata. We persist a snapshot of:
#   - timestamp, branch, dirty files
#   - last 5 commits
#   - currently-staged diff stats
# The PostCompact hook reads this back into the new context window.

set -uo pipefail

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
mkdir -p .claude

OUT=".claude/_compact_briefing.md"

{
  echo "# Pre-compact checkpoint"
  echo ""
  echo "Saved at: $(date -Iseconds 2>/dev/null || date)"
  echo ""
  if git rev-parse --git-dir >/dev/null 2>&1; then
    echo "**Branch:** $(git branch --show-current 2>/dev/null || echo 'detached')"
    echo ""
    echo "**Dirty files (top 20):**"
    echo '```'
    git status --short 2>/dev/null | head -20
    echo '```'
    echo ""
    echo "**Last 5 commits:**"
    echo '```'
    git log --oneline -5 2>/dev/null
    echo '```'
    echo ""
    echo "**Staged diff stats:**"
    echo '```'
    git diff --cached --stat 2>/dev/null | tail -20
    echo '```'
  fi
} > "$OUT"

exit 0
