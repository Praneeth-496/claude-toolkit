#!/usr/bin/env bash
# SessionStart — inject a short git briefing into the new session's context.
# Stdout is fed to Claude as additional context (per hooks docs).

set -uo pipefail

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  exit 0
fi

echo "## Session briefing"
echo ""
echo "**Branch:** $(git branch --show-current 2>/dev/null || echo 'detached')"
DIRTY=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
echo "**Uncommitted files:** $DIRTY"
if [[ "$DIRTY" -gt 0 ]]; then
  echo ""
  echo "Top of \`git status\`:"
  echo '```'
  git status --short 2>/dev/null | head -10
  echo '```'
fi
echo ""
echo "**Recent commits:**"
echo '```'
git log --oneline -5 2>/dev/null
echo '```'

# Optionally surface a stale-cache warning if claude-toolkit version drifted.
TOOLKIT_VERSION_FILE="$HOME/.claude/skills/.claude-toolkit-version"
if [[ -f "$TOOLKIT_VERSION_FILE" ]]; then
  echo ""
  echo "_Toolkit version: $(cat "$TOOLKIT_VERSION_FILE")_"
fi

exit 0
