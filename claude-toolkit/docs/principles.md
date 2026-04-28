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

> **On `CLAUDE_CODE_MAX_OUTPUT_TOKENS`:** the toolkit no longer sets this. A static per-response cap truncates long edits and code reviews mid-stream, forcing re-work that costs *more* tokens than it saves. The agent already runs across as many responses as the task needs — let each response use the model's full budget. Only set the cap if you want to ceiling a chatty skill.

---

## Model routing

| Model | When to use | Skill frontmatter |
|---|---|---|
| **Opus 4.7** | Intelligent multi-file reasoning — doc rewrites, pipeline orchestration, architectural decisions, council synthesis | `model: opus` |
| **Sonnet (latest)** | Small/mechanical skills — claim verification, rsync, single-file edits, partition picking | `model: sonnet` |
| **Haiku 4.5** | Cheap deterministic glue — path lookups, presence-only greps, frontmatter parsing. Acceptable when the skill body is < 5 logical lines and there's no judgement call. | `model: haiku` |

Opus pays for itself only when the task actually needs its reasoning depth. Sonnet handles 80%+ of skill invocations cleanly. Haiku 4.5 (Jan 2026) closed enough of the quality gap that it's no longer auto-banned — just don't reach for it on anything that requires reasoning across files.

## Skill auto-routing (don't wait for slash commands)

Skills are not just `/command` shortcuts — they are first-class context the agent should consult on every non-trivial turn. The harness lists available skills at the top of each conversation; the matcher reads the `description:` frontmatter to decide relevance. **The agent's job is to scan that list, match the user's intent against the descriptions, and invoke proactively.** A user typing `/skillname` is the fallback path, not the primary one.

Concrete rules:

- **Recall before re-reading.** If a knowledge graph exists for the project (`memory/graph/nodes.jsonl`), reach for `query-graph <keyword>` before re-reading `project_*.md` snapshots. The 1-hop subgraph is typically 5–10× cheaper.
- **Capture durable facts as graph edges, not new memory files.** When the user states a relationship ("X depends on Y", "we superseded Z"), invoke `memory-graph add` instead of writing a fresh `project_*.md`.
- **Style/voice skills (`brief`, `godmode`, `10x`, `ghost`, `teacher`, `critique`, `devil`, `scout`, `compare`, `pitch`, `ooda`, `explainlikeim5`) match on natural-language phrases**, not just `/name`. The triggers are listed in each skill's `description:` — apply them silently, do not announce.
- **Never ask "should I use skill X?".** If the description matches the request, invoke. If it doesn't, don't. The middle path of asking permission turns every skill into a slash command and defeats the auto-routing point.
- **Description fields are the contract.** When writing a new skill, front-load the `description:` with the natural-language phrases that should trigger it ("TRIGGER when user says ..."). The matcher only reads that field.

## When to reach beyond this toolkit

- **Multi-perspective decisions:** the bundled `council` skill convenes 4 Claude personas in parallel for high-stakes one-shot questions. For *cross-vendor* diversity (Codex + Gemini), the third-party [`agent-council`](https://github.com/yogirk/agent-council) is the relevant tool.
- **Multi-reviewer PR sweep:** Claude Code's own `/ultrareview` runs a cloud-side multi-agent review on a branch or PR. Useful before a non-trivial merge.
- **Cross-project memory search:** `grep -r 'pattern' ~/.claude/projects/*/memory/` is faster than any vector store at this scale; reach for embeddings only when you have a true external corpus.

---

## Anti-patterns

- ❌ Do **not** inline large data (dataset contents, full JSON artefacts, notebook outputs) into any of the 4 files. Reference the path, let skills fetch on demand.
- ❌ Do **not** create both `Agents.md` and `CLAUDE.md` — that doubles the always-loaded surface. CLAUDE.md **is** Agents.md.
- ❌ Do **not** let `MEMORY.md` grow past ~100 index lines — consolidate stale entries into a `historical.md` instead of accumulating.
- ❌ Do **not** ask Claude to "summarise the repo" as a warm-up — that is ~50K tokens for information already in CLAUDE.md.
- ❌ Do **not** put project-specific facts in user-scope skills — generic skills read from `.claude/CLAUDE.md`, they don't bake in project paths.
- ❌ Do **not** auto-submit jobs, auto-push commits, or auto-sync destructively — every irreversible action waits for user confirmation.
- ❌ Do **not** convene the `council` skill on routine questions — it costs 4× the tokens of a normal turn. Reserve it for decisions where a wrong call is expensive.

---

## Rough cost intuition

- Turn with just CLAUDE.md loaded: ~2K input tokens.
- Turn with CLAUDE.md + CONTEXT.md forced open: ~8–10K input tokens → only pay when the heavier context is actually needed.
- Subagent call: ~3–10K tokens amortised, but replaces 10–50 main-context tool calls that would have cost more and forced a `/compact` sooner.
- Skill running a pure Bash grep: near-zero model tokens; only the user/assistant framing counts.

A typical productive day with these defaults: a few edits + one HPC submission + several verifications sits comfortably under a couple dollars of Opus-equivalent spend. Most turns run on Sonnet.
