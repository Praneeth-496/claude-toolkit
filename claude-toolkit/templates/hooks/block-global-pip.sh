#!/usr/bin/env bash
# PreToolUse(Bash) — enforce mandatory env isolation.
#
# Blocks package installs that would pollute the system / global environment instead
# of a project-local isolated env. Forces Python installs through uv or an activated
# .venv, and forbids global Node installs. Exit 2 = block, exit 0 = allow.
#
# Reads tool input from stdin: { "tool_input": { "command": "..." } }
# Pairs with the env-bootstrap skill, which creates the .venv this hook expects.

set -uo pipefail

INPUT="$(cat)"
CMD="$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || echo "")"
[[ -z "$CMD" ]] && exit 0

block() {
  echo "BLOCKED by toolkit (env isolation): $1" >&2
  echo "Command was: $CMD" >&2
  echo "" >&2
  echo "$2" >&2
  exit 2
}

# Markers that prove the install is going into an isolated env (Python).
ISOLATED_RE='uv (pip|run|sync|add)|\.venv/bin/|source[[:space:]]+[^[:space:]]*\.venv/bin/activate|VIRTUAL_ENV='

# --- Python: global pip install ---------------------------------------------
if echo "$CMD" | grep -qE '(^|[;&|[:space:]])(python3?[[:space:]]+-m[[:space:]]+)?pip3?[[:space:]]+install'; then
  if [[ -n "${VIRTUAL_ENV:-}" ]] || echo "$CMD" | grep -qE "$ISOLATED_RE"; then
    : # isolated — allow
  else
    block "global 'pip install' with no active virtualenv" \
"Create/activate an isolated env first (run the env-bootstrap skill), then either:
  uv pip install <pkg>                         # preferred
  source .venv/bin/activate && pip install ... # or activate the venv
Never install into the system Python."
  fi
fi

# --- Python: sudo pip / conda base ------------------------------------------
echo "$CMD" | grep -qE 'sudo[[:space:]]+(-H[[:space:]]+)?pip3?[[:space:]]+install' && \
  block "'sudo pip install' modifies the system Python" "Use a project .venv (run env-bootstrap) and install there instead."

# --- Node: global install ---------------------------------------------------
if echo "$CMD" | grep -qE '(npm[[:space:]]+(install|i|add)[[:space:]]+(-g|--global)|pnpm[[:space:]]+add[[:space:]]+(-g|--global)|yarn[[:space:]]+global[[:space:]]+add)'; then
  block "global Node install" \
"Install into the project's local node_modules instead (npm install <pkg>, no -g).
Global CLI tools belong in your own shell setup, not a project's dependency install."
fi

exit 0
