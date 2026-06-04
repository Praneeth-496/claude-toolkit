---
name: session-watchdog
description: Background bash daemon that polls Claude Code's transcript JSONL files, sums token usage over the rolling rate-limit window, and at 90% triggers (a) a checkpoint of current task state to .claude/checkpoints/ and (b) a scheduled `claude --resume` for after the window rolls. Project-agnostic; pure bash + jq, optional `at`. TRIGGER when user says "watchdog", "auto-resume", "session timeout", "rate-limit handling", "checkpoint and resume", "monitor token usage", or starts a long autonomous task that may exceed a single 5-hour window.
model: haiku
---

## What this skill is — and what it isn't

**Is:** a thin wrapper around four bash scripts that the agent installs alongside this `SKILL.md`. The scripts run **outside** the agent's process, in the user's shell, as a background daemon.

**Is not:** in-turn token monitoring. The agent itself cannot read its own token counter mid-response — there is no API for that. The watchdog works only because Claude Code persistently logs every assistant message (with `message.usage`) to `~/.claude/projects/<encoded>/<session-id>.jsonl`. The daemon polls that file, not the agent.

The pieces:

| File | Role |
|---|---|
| `watchdog.sh start\|stop\|status\|run` | Long-running daemon — polls every 60 s, checks token usage, fires checkpoint + resume at 90%. |
| `checkpoint.sh <transcript>` | Writes a JSON snapshot (session id, last user message, last assistant message, todo state) to `.claude/checkpoints/<timestamp>.json` and updates `latest.json` symlink. |
| `resume.sh <session-id> <project-dir>` | What `at`/sleep fires after the window rolls. Runs `claude --resume <id> --print "Resume from checkpoint .claude/checkpoints/latest.json"`. |
| `SKILL.md` | This file. |

All four live in `~/.claude/skills/session-watchdog/` after install. The daemon writes its state to **the project's** `.claude/checkpoints/` (per-project, not global).

## When the agent should invoke this

- User starts a multi-hour autonomous task (`/loop`, big refactor, long benchmark sweep) → `bash ~/.claude/skills/session-watchdog/watchdog.sh start`.
- User says "I'll be afk, keep going" → start the watchdog so a rate-limit doesn't strand the work.
- After installing the toolkit on a new machine, the user wants to verify it's wired up → `... watchdog.sh status`.

The agent **never starts the daemon silently**. Always confirm with the user once before the first start, then it's stateful (subsequent starts in the same project are idempotent).

## Configuration (env vars, sane defaults)

| Var | Default | Meaning |
|---|---|---|
| `WATCHDOG_RATE_BUDGET` | `500000` | Token budget for the rolling window. Adjust to your plan's actual 5-hour cap. |
| `WATCHDOG_THRESHOLD` | `90` | Trigger percentage (1–99). |
| `WATCHDOG_WINDOW` | `18000` | Rolling-window seconds (5 h). |
| `WATCHDOG_POLL` | `60` | Daemon poll interval in seconds. |
| `WATCHDOG_RESUME_PROMPT` | (built-in) | What to feed `claude --resume --print` on wake-up. |

Set them in `.claude/settings.local.json` `env` block, or export inline:

```bash
WATCHDOG_RATE_BUDGET=800000 bash ~/.claude/skills/session-watchdog/watchdog.sh start
```

## Operations

### Start

```bash
bash ~/.claude/skills/session-watchdog/watchdog.sh start
```

Spawns a detached `nohup` daemon. Writes pid to `.claude/checkpoints/watchdog.pid` and tail-friendly log to `.claude/checkpoints/watchdog.log`.

### Status

```bash
bash ~/.claude/skills/session-watchdog/watchdog.sh status
```

Prints `running (pid …)` or `stopped`, plus the last polled token count and percentage from `watchdog.state`.

### Stop

```bash
bash ~/.claude/skills/session-watchdog/watchdog.sh stop
```

Sends `SIGTERM`, removes the pid file. Any pending `at` job for resume is left alone (intentional — if you stop the daemon mid-window, the scheduled resume still fires).

### Manual checkpoint

```bash
bash ~/.claude/skills/session-watchdog/checkpoint.sh ~/.claude/projects/<encoded>/<session>.jsonl
```

For when the agent (or user) wants a snapshot without waiting for the threshold.

## How auto-resume actually works

1. Daemon polls every 60 s, sums `message.usage` tokens from the latest transcript JSONL where `timestamp` falls within the last `WATCHDOG_WINDOW` seconds.
2. When `used / RATE_BUDGET >= THRESHOLD/100`:
   - `checkpoint.sh` writes `<timestamp>.json` and updates the `latest.json` symlink.
   - The daemon computes `reset_epoch = oldest_message_in_window_ts + WATCHDOG_WINDOW + 60s_buffer`.
   - If `at` is on PATH: `echo "bash resume.sh <session> <project>" | at <reset>`.
   - Otherwise: `(sleep <delta> && bash resume.sh ...) &` — survives the daemon being killed only if `disown`'d; with `at` it's robust.
3. After the window rolls, the scheduled job runs `claude --resume <session-id> --print "<resume prompt>"`. This starts a new headless Claude Code turn that sees the checkpoint, restores todos, and continues.
4. The daemon backs off for half the window after triggering, so it doesn't fire the same resume twice.

## Limitations the agent must surface to the user

- **Plan-dependent budget.** The default `WATCHDOG_RATE_BUDGET=500000` is a guess. The user should set it to their actual plan's 5-hour token cap.
- **Transcript schema.** Assumes `message.usage.{input_tokens, output_tokens, cache_read_input_tokens, cache_creation_input_tokens}`. If a Claude Code update changes the schema, the jq filter in `watchdog.sh` needs an update.
- **Resume fidelity.** `claude --resume --print` reattaches the session, but the agent in the resumed turn must read `.claude/checkpoints/latest.json` itself to restore todos / context. The default resume prompt instructs it to do so — but if the agent ignores the prompt, state is lost.
- **One project at a time.** The daemon's pid/state lives under the project's `.claude/checkpoints/`. Run separate daemons per project; they don't conflict.
- **`at` may need installing.** Debian/Ubuntu: `sudo apt install at && sudo systemctl enable --now atd`. Without `at`, the fallback uses a backgrounded `sleep` which dies if the user logs out — start the daemon under `tmux`/`screen` if you log out a lot.

## Hard rules

- **Never run the daemon from inside an agent turn without confirmation.** It writes to the project and schedules future processes — that's a stateful side-effect and warrants one explicit user yes.
- **Never inflate the budget to "make threshold disappear".** If you're hitting 90% on real work, schedule resume — don't paper over it.
- **Never delete checkpoints automatically.** They're cheap; let the user clean `.claude/checkpoints/` themselves.
- **Idempotent start.** `start` while already running is a no-op with a clear "already running (pid X)" message — never spawn duplicates.

## Anti-patterns

- Do not poll the transcript at sub-10 s intervals. The transcript only updates per assistant turn; faster polls just burn CPU.
- Do not embed token-counting heuristics ("estimate from message length") in `watchdog.sh`. Read `message.usage` from the transcript or fail loud — guesses are worse than nothing.
- Do not chain to other skills automatically on threshold hit. The only side effect is checkpoint + scheduled resume. Anything else (notifying the user, opening a PR with partial work, etc.) is a separate explicit step.
- Do not assume `claude` is on PATH on the resume-host. `resume.sh` checks and writes a clear error to the log instead of failing silently.
