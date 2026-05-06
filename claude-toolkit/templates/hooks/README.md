# Hooks

Deterministic guardrails that fire on Claude Code lifecycle events. Hooks beat permission prompts: they enforce, they don't ask.

Hook events used here are documented at https://code.claude.com/docs/en/hooks (29 total events as of Claude Code v2.x). This toolkit ships five:

| Hook script | Event | Purpose |
|---|---|---|
| `block-dangerous-bash.sh` | `PreToolUse(Bash)` | Hard-block `git push --force`, `git reset --hard`, `rm -rf /`, `chmod 777`, etc. |
| `format-on-write.sh` | `PostToolUse(Edit\|Write)` | Run the project's formatter on files Claude just modified (best-effort, never fails the edit) |
| `session-briefing.sh` | `SessionStart` | Inject git branch + dirty-file count + last 3 commits as session context |
| `pre-compact-briefing.sh` | `PreCompact` | Write a "what we were doing" briefing to `.claude/_compact_briefing.md` so context survives auto-compact |
| `post-compact-restore.sh` | `PostCompact` | Echo the briefing back into the new context window |

## Wiring

The installer copies these into `.claude/hooks/` and the matching `hooks` block lives in `.claude/settings.local.json`. To disable any one of them, delete the matching block in `settings.local.json` (the script can stay on disk).

## Exit-code contract

- Exit `0` — normal, continue.
- Exit `2` — block the operation (PreToolUse) or send feedback to Claude.
- Any other non-zero — logged but does not block.

## Adding your own

1. Drop a script in `.claude/hooks/`.
2. Reference it from `settings.local.json` using `"$CLAUDE_PROJECT_DIR/.claude/hooks/yourscript.sh"`.
3. Pick the event from the [hooks reference](https://code.claude.com/docs/en/hooks).
4. Keep it under 200ms — hooks run synchronously.
