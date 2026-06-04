#!/usr/bin/env bash
# resume.sh — fired by `at` (or a backgrounded `sleep`) after the rate-limit
# window rolls. Reattaches the saved Claude Code session in headless `--print`
# mode and feeds it a prompt that tells the agent to read the checkpoint and
# continue.
#
# Usage:
#   bash resume.sh <session-id> <project-dir>

set -euo pipefail

SESSION_ID="${1:-}"
PROJECT_DIR="${2:-$(pwd)}"

if [[ -z "$SESSION_ID" ]]; then
  echo "usage: $0 <session-id> <project-dir>" >&2
  exit 2
fi

cd "$PROJECT_DIR"
LOGFILE="$PROJECT_DIR/.claude/checkpoints/resume.log"
CHECKPOINT="$PROJECT_DIR/.claude/checkpoints/latest.json"
mkdir -p "$(dirname "$LOGFILE")"

log() { printf '[%s] %s\n' "$(date -Iseconds)" "$*" >> "$LOGFILE"; }

PROMPT="${WATCHDOG_RESUME_PROMPT:-Resume from checkpoint at .claude/checkpoints/latest.json. Read the file, restore the todo list, and continue from the last user message in the checkpoint. Do not redo completed todos.}"

if ! command -v claude >/dev/null 2>&1; then
  log "claude CLI not on PATH — cannot auto-resume. Manual: claude --resume $SESSION_ID"
  exit 1
fi

if [[ ! -f "$CHECKPOINT" ]]; then
  log "no checkpoint at $CHECKPOINT — proceeding anyway with bare resume prompt"
fi

log "resuming session=$SESSION_ID project=$PROJECT_DIR"
# --print runs Claude Code non-interactively, prints the response, and exits.
# We tee the response into the log so the user can audit what the resumed
# turn produced.
claude --resume "$SESSION_ID" --print "$PROMPT" 2>&1 | tee -a "$LOGFILE"
rc=${PIPESTATUS[0]}
log "resume exit=$rc"
exit "$rc"
