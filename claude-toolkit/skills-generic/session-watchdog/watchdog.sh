#!/usr/bin/env bash
# watchdog.sh — poll Claude Code's transcript JSONL files, sum token usage over
# the rolling rate-limit window, and fire a checkpoint + scheduled resume at
# THRESHOLD%.
#
# Usage:
#   bash watchdog.sh start    # spawn detached daemon
#   bash watchdog.sh stop     # SIGTERM the daemon, remove pidfile
#   bash watchdog.sh status   # running? what's the current % usage?
#   bash watchdog.sh run      # inner loop (do not call directly — `start` does)
#
# Configuration (env vars, override before invoking):
#   WATCHDOG_RATE_BUDGET   default 500000  total tokens allowed in the window
#   WATCHDOG_THRESHOLD     default 90      trigger percent (1..99)
#   WATCHDOG_WINDOW        default 18000   rolling-window seconds (5 h)
#   WATCHDOG_POLL          default 60      poll interval seconds
#   WATCHDOG_RESUME_PROMPT default see below
#
# State lives under <project>/.claude/checkpoints/.

set -euo pipefail

CMD="${1:-status}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(pwd)"
CWD_ENCODED=$(printf '%s' "$PROJECT_DIR" | sed 's/[^A-Za-z0-9]/-/g')
TRANSCRIPT_DIR="$HOME/.claude/projects/$CWD_ENCODED"
CHECKPOINT_DIR="$PROJECT_DIR/.claude/checkpoints"
PIDFILE="$CHECKPOINT_DIR/watchdog.pid"
LOGFILE="$CHECKPOINT_DIR/watchdog.log"
STATEFILE="$CHECKPOINT_DIR/watchdog.state"

RATE_BUDGET="${WATCHDOG_RATE_BUDGET:-500000}"
THRESHOLD="${WATCHDOG_THRESHOLD:-90}"
WINDOW="${WATCHDOG_WINDOW:-18000}"
POLL="${WATCHDOG_POLL:-60}"
RESUME_PROMPT="${WATCHDOG_RESUME_PROMPT:-Resume from checkpoint at .claude/checkpoints/latest.json. Read it, restore the todo list, and continue from the last user message.}"

mkdir -p "$CHECKPOINT_DIR"

log() { printf '[%s] %s\n' "$(date -Iseconds)" "$*" >> "$LOGFILE"; }

is_running() {
  [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null
}

# ── usage_tokens: prints total tokens in the window across newest transcript ──
usage_tokens() {
  if [[ ! -d "$TRANSCRIPT_DIR" ]]; then
    echo 0; return
  fi
  local latest
  latest=$(ls -1t "$TRANSCRIPT_DIR"/*.jsonl 2>/dev/null | head -1)
  [[ -z "$latest" ]] && { echo 0; return; }
  local cutoff
  cutoff=$(date -d "-${WINDOW} seconds" -Iseconds 2>/dev/null \
           || gdate -d "-${WINDOW} seconds" -Iseconds 2>/dev/null \
           || echo "1970-01-01T00:00:00")
  jq -s --arg cutoff "$cutoff" '
    def tnum: if . == null then 0 else . end;
    map(
      select((.timestamp // "9999") > $cutoff)
      | (.message.usage // {})
      | (.input_tokens|tnum) + (.output_tokens|tnum)
        + (.cache_read_input_tokens|tnum) + (.cache_creation_input_tokens|tnum)
    ) | add // 0
  ' "$latest" 2>/dev/null || echo 0
}

oldest_ts_in_window() {
  local latest
  latest=$(ls -1t "$TRANSCRIPT_DIR"/*.jsonl 2>/dev/null | head -1)
  [[ -z "$latest" ]] && { echo ""; return; }
  local cutoff
  cutoff=$(date -d "-${WINDOW} seconds" -Iseconds 2>/dev/null \
           || gdate -d "-${WINDOW} seconds" -Iseconds 2>/dev/null \
           || echo "1970-01-01T00:00:00")
  jq -rs --arg cutoff "$cutoff" '
    map(select((.timestamp // "") > $cutoff) | .timestamp)
    | sort | .[0] // ""
  ' "$latest" 2>/dev/null || echo ""
}

latest_session_id() {
  local f
  f=$(ls -1t "$TRANSCRIPT_DIR"/*.jsonl 2>/dev/null | head -1)
  [[ -z "$f" ]] && { echo ""; return; }
  basename "$f" .jsonl
}

schedule_resume() {
  local session_id="$1" reset_epoch="$2"
  local now=$(date +%s)
  local delta=$(( reset_epoch - now ))
  (( delta < 60 )) && delta=60

  if command -v at >/dev/null 2>&1; then
    local at_time
    at_time=$(date -d "@$reset_epoch" '+%H:%M %m/%d/%Y' 2>/dev/null \
              || date -r "$reset_epoch" '+%H:%M %m/%d/%Y' 2>/dev/null)
    echo "bash '$SCRIPT_DIR/resume.sh' '$session_id' '$PROJECT_DIR'" \
      | at "$at_time" 2>>"$LOGFILE" || {
        log "at submission failed; falling back to sleep"
        ( sleep "$delta" && bash "$SCRIPT_DIR/resume.sh" "$session_id" "$PROJECT_DIR" ) \
          >> "$LOGFILE" 2>&1 &
        disown 2>/dev/null || true
      }
    log "scheduled resume via 'at' for $(date -d "@$reset_epoch" 2>/dev/null || date -r "$reset_epoch")"
  else
    ( sleep "$delta" && bash "$SCRIPT_DIR/resume.sh" "$session_id" "$PROJECT_DIR" ) \
      >> "$LOGFILE" 2>&1 &
    disown 2>/dev/null || true
    log "scheduled resume via sleep ($delta s)"
  fi
}

case "$CMD" in
  start)
    if is_running; then
      echo "watchdog already running (pid $(cat "$PIDFILE"))"
      exit 0
    fi
    nohup "$0" run </dev/null > "$LOGFILE" 2>&1 &
    echo $! > "$PIDFILE"
    sleep 0.3
    echo "watchdog started (pid $(cat "$PIDFILE"))"
    echo "  log:        $LOGFILE"
    echo "  state:      $STATEFILE"
    echo "  budget:     $RATE_BUDGET tokens / ${WINDOW}s window"
    echo "  threshold:  ${THRESHOLD}%"
    ;;

  stop)
    if [[ ! -f "$PIDFILE" ]]; then
      echo "no pidfile at $PIDFILE — daemon not running here"
      exit 0
    fi
    pid=$(cat "$PIDFILE")
    if kill "$pid" 2>/dev/null; then
      echo "stopped pid $pid"
    else
      echo "pid $pid not alive; cleaning pidfile"
    fi
    rm -f "$PIDFILE"
    ;;

  status)
    if is_running; then
      echo "running (pid $(cat "$PIDFILE"))"
    else
      echo "stopped"
    fi
    [[ -f "$STATEFILE" ]] && { echo "---"; cat "$STATEFILE"; }
    [[ -f "$LOGFILE" ]] && { echo "---"; tail -5 "$LOGFILE"; }
    ;;

  run)
    # Inner loop. Only reachable through `start`.
    echo $$ > "$PIDFILE"
    log "watchdog daemon up (pid $$, budget=$RATE_BUDGET, window=${WINDOW}s, threshold=${THRESHOLD}%)"
    trap 'log "received signal, exiting"; rm -f "$PIDFILE"; exit 0' INT TERM
    cooldown_until=0
    while true; do
      now=$(date +%s)
      used=$(usage_tokens)
      pct=$(( used * 100 / (RATE_BUDGET == 0 ? 1 : RATE_BUDGET) ))
      printf 'updated_at=%s  used=%s  budget=%s  pct=%s%%\n' \
        "$(date -Iseconds)" "$used" "$RATE_BUDGET" "$pct" > "$STATEFILE"

      if (( pct >= THRESHOLD )) && (( now >= cooldown_until )); then
        log "THRESHOLD HIT used=$used pct=${pct}%% — checkpointing"
        latest=$(ls -1t "$TRANSCRIPT_DIR"/*.jsonl 2>/dev/null | head -1)
        if [[ -n "$latest" ]]; then
          bash "$SCRIPT_DIR/checkpoint.sh" "$latest" >> "$LOGFILE" 2>&1 || \
            log "checkpoint.sh failed"
          oldest_iso=$(oldest_ts_in_window)
          if [[ -n "$oldest_iso" ]]; then
            oldest_epoch=$(date -d "$oldest_iso" +%s 2>/dev/null || echo "$now")
          else
            oldest_epoch=$now
          fi
          reset_epoch=$(( oldest_epoch + WINDOW + 60 ))
          session_id=$(latest_session_id)
          if [[ -n "$session_id" ]]; then
            WATCHDOG_RESUME_PROMPT="$RESUME_PROMPT" \
              schedule_resume "$session_id" "$reset_epoch"
          else
            log "no session id resolved; resume not scheduled"
          fi
          # cool down for half the window so we don't re-trigger every poll
          cooldown_until=$(( now + WINDOW / 2 ))
        else
          log "threshold hit but no transcript file found at $TRANSCRIPT_DIR"
        fi
      fi
      sleep "$POLL"
    done
    ;;

  *)
    echo "usage: $0 {start|stop|status|run}" >&2
    exit 2
    ;;
esac
