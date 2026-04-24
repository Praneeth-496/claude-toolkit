# Principles — Token Budget, Model Routing, Anti-Patterns

Core rules the toolkit is designed around. Read once, internalise, apply in every project.

---

## Token & cost budget

You pay per token. The 4-file layout is designed around **what loads every turn vs. what loads on demand**. Core principle: keep the always-loaded surface tiny, push bulk content behind lazy loads, let skills/subagents do expensive work in isolated contexts that return a short summary.

### Rules the setup enforces

1. **CLAUDE.md stays under ~150 lines.** It ships on every turn. Anything longer moves to `CONTEXT.md` (lazy read).
2. **`CONTEXT.md` is read only when relevant.** Claude opens it only when a question actually needs heavier background. No turn pays for it unprompted.
3. **`MEMORY.md` index lines ≤150 chars, body ≤~30 lines per entry.** The harness truncates `MEMORY.md` after line 200; short entries = more entries fit.
4. **Skills bodies short and imperative.** Each `SKILL.md` has a one-sentence `description:` in frontmatter (the matcher reads only this), then ≤ 50 lines of concrete steps.
5. **Skills run Bash, not LLM reasoning, when possible.** Grep beats "reason about which value matches". `rsync -avn` beats "decide what to sync".

### Rules to keep in CLAUDE.md

- "Short answers, no padding" — terse replies ≈ 3–5× fewer output tokens.
- "No preamble, no 'I'll now…' narration" — cuts repetitive turn-openers.
- "Don't summarize what you just did" — `git diff` is free; a summary costs output tokens every turn.
- "Minimal inline comments" — fewer tokens written per edit.
- "Use `/compact` when context > 80%" — forces a summary pass before the window fills with stale tool output.

### Concrete habits

| Habit | Saves tokens by |
|---|---|
| `Read` with `offset`/`limit` on large files | avoids loading 1000+ line modules when only a function is needed |
| `grep` / `rg` before `Read` | narrows to the exact span you need |
| `Edit` over `Write` for existing files | only the diff is sent |
| Delegate codebase surveys to **Explore** subagent | tool output stays in subagent's context, only a summary returns |
| Delegate large plans to **Plan** subagent | same isolation benefit |
| Never re-`Read` a file just edited | Edit errors loudly on failure; re-reading is wasted |
| Batch independent tool calls in one message | parallelism cuts latency and per-turn model overhead |
| Bound `CLAUDE_CODE_MAX_OUTPUT_TOKENS` (default 8000) | hard ceiling on runaway replies |

---

## Model routing

| Model | When to use | Skill frontmatter |
|---|---|---|
| **Opus 4.7** | Intelligent multi-file reasoning — thesis rewrites, pipeline orchestration, architectural decisions, judgement calls | `model: opus` |
| **Sonnet (latest)** | Small/mechanical skills — claim verification, rsync, single-file edits, partition picking | `model: sonnet` |
| **Haiku** | Never used — quality ceiling too low for serious work; saves pennies but costs re-work | — |

Opus pays for itself only when the task actually needs its reasoning depth. Sonnet handles 80%+ of skill invocations cleanly.

---

## Anti-patterns

- ❌ Do **not** inline large data (dataset contents, full JSON artefacts, notebook outputs) into any of the 4 files. Reference the path, let skills fetch on demand.
- ❌ Do **not** create both `Agents.md` and `CLAUDE.md` — that doubles the always-loaded surface. CLAUDE.md **is** Agents.md.
- ❌ Do **not** let `MEMORY.md` grow past ~100 index lines — consolidate stale entries into a `historical.md` instead of accumulating.
- ❌ Do **not** ask Claude to "summarise the repo" as a warm-up — that is ~50K tokens for information already in CLAUDE.md.
- ❌ Do **not** put project-specific facts in user-scope skills — generic skills read from `.claude/CLAUDE.md`, they don't bake in project paths.
- ❌ Do **not** auto-submit jobs, auto-push commits, or auto-sync destructively — every irreversible action waits for user confirmation.

---

## Rough cost intuition

- Turn with just CLAUDE.md loaded: ~2K input tokens.
- Turn with CLAUDE.md + CONTEXT.md forced open: ~8–10K input tokens → only pay when the heavier context is actually needed.
- Subagent call: ~3–10K tokens amortised, but replaces 10–50 main-context tool calls that would have cost more and forced a `/compact` sooner.
- Skill running a pure Bash grep: near-zero model tokens; only the user/assistant framing counts.

A typical productive day with these defaults: a few edits + one HPC submission + several verifications sits comfortably under a couple dollars of Opus-equivalent spend. Most turns run on Sonnet.
