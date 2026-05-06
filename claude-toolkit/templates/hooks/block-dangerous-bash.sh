#!/usr/bin/env bash
# PreToolUse(Bash) — hard-block destructive commands the model shouldn't run unattended.
#
# Reads the tool input from stdin as JSON: { "tool_input": { "command": "...", ... } }
# Exit 2 to block. Exit 0 to allow.
#
# These match the spirit of the deny list in settings.local.json but with regex granularity.

set -euo pipefail

INPUT="$(cat)"
CMD="$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")"

if [[ -z "$CMD" ]]; then
  exit 0
fi

# Patterns we never want to run unattended.
BLOCKED_PATTERNS=(
  'git\s+push\s+(-f|--force)'
  'git\s+push\s+.*--force-with-lease'
  'git\s+reset\s+--hard\s+(origin|upstream)'
  'git\s+clean\s+-[fdx]+'
  'git\s+filter-branch'
  'rm\s+-[rRf]+\s+/'
  'rm\s+-[rRf]+\s+\$HOME'
  'rm\s+-[rRf]+\s+~'
  'chmod\s+-R?\s*777'
  ':\(\)\{\s*:\|:&'  # fork bomb
  '>\s*/dev/sd[a-z]'
  'mkfs\.'
  'dd\s+.*of=/dev/'
  'curl\s+.*\|\s*(sudo\s+)?(bash|sh)'
  'wget\s+.*\|\s*(sudo\s+)?(bash|sh)'
)

for pat in "${BLOCKED_PATTERNS[@]}"; do
  if echo "$CMD" | grep -qE "$pat"; then
    echo "BLOCKED by toolkit hook: command matches dangerous pattern: $pat" >&2
    echo "Command was: $CMD" >&2
    echo "If you really intended this, run it yourself in a terminal." >&2
    exit 2
  fi
done

exit 0
