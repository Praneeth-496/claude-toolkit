#!/usr/bin/env bash
# PostCompact — echo the pre-compact checkpoint back into the new (compacted) context window.
# Stdout is added to context per hooks docs.

set -uo pipefail

cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0

CHECKPOINT=".claude/_compact_briefing.md"
[[ -f "$CHECKPOINT" ]] || exit 0

echo "## Restored from pre-compact checkpoint"
echo ""
cat "$CHECKPOINT"
echo ""
echo "_(continue from where we left off; the full earlier history was compacted)_"

exit 0
