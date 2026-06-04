#!/usr/bin/env bash
# checkpoint.sh — snapshot the current Claude Code session state to a JSON file
# under <project>/.claude/checkpoints/. Used by watchdog.sh on threshold hit;
# can also be invoked directly when you want a manual save point.
#
# Usage:
#   bash checkpoint.sh <transcript.jsonl>
#
# Output:
#   .claude/checkpoints/<YYYYMMDDTHHMMSS>.json   the snapshot
#   .claude/checkpoints/latest.json              symlink to most recent

set -euo pipefail

TRANSCRIPT="${1:-}"
if [[ -z "$TRANSCRIPT" || ! -f "$TRANSCRIPT" ]]; then
  echo "usage: $0 <transcript.jsonl>" >&2
  exit 2
fi

PROJECT_DIR="${PROJECT_DIR:-$(pwd)}"
CHECKPOINT_DIR="$PROJECT_DIR/.claude/checkpoints"
mkdir -p "$CHECKPOINT_DIR"

ts=$(date +%Y%m%dT%H%M%S)
out="$CHECKPOINT_DIR/${ts}.json"

# Build the snapshot. Defensive defaults — fields are optional in older
# transcript schemas.
jq -s --arg saved_at "$(date -Iseconds)" --arg cwd "$PROJECT_DIR" '
  def text_of_msg:
    if (.message.content | type) == "string" then .message.content
    elif (.message.content | type) == "array" then
      (.message.content | map(.text? // "") | join("\n"))
    else "" end;

  {
    saved_at: $saved_at,
    cwd: $cwd,
    session_id: (.[0].sessionId // .[0].session_id // "unknown"),
    message_count: length,
    last_user_message:
      ([.[] | select(.type == "user") | text_of_msg] | last // ""),
    last_assistant_message:
      ([.[] | select(.type == "assistant") | text_of_msg] | last // ""),
    todos:
      ([.[]
        | select(((.toolName // .name // "") == "TodoWrite")
                 or ((.tool_use.name // "") == "TodoWrite"))
        | (.input.todos // .params.todos // .tool_use.input.todos // [])
       ] | last // []),
    last_usage:
      ([.[] | select(.message.usage) | .message.usage] | last // {}),
    transcript_path: input_filename
  }
' "$TRANSCRIPT" > "$out"

ln -sfn "$(basename "$out")" "$CHECKPOINT_DIR/latest.json"

echo "checkpoint written: $out"
echo "latest -> $(readlink "$CHECKPOINT_DIR/latest.json")"
