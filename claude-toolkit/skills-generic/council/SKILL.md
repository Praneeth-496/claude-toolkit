---
name: council
description: Convene a panel of 4 Claude subagents (architect, reviewer, simplifier, adversary) on a single hard decision — architecture choice, security review, "should we?" questions. Each gives an independent ≤300-word opinion in parallel; main thread synthesizes consensus and dissent. Result is written to .claude/council/ for later audit. Use only for high-stakes one-shot decisions, not daily code edits.
model: opus
---

## When to use

A "stop and think" tool. Invoke for:
- Architecture choices ("Postgres vs SQLite for this service?", "monorepo vs polyrepo?")
- Security/risk reviews ("is this auth flow safe?", "should we expose this endpoint?")
- Reversibility-sensitive decisions ("should we rewrite the X module?", "drop support for Y?")
- Pre-PR sanity check on a non-trivial design

**Do not invoke for:** daily code edits, single-file refactors, "fix this bug", or anything where the answer is obvious. The council costs ~30–60s and 4× the tokens of a normal turn — only worth it when a wrong call is expensive.

## Inputs the user must provide

1. **The question** — a one-paragraph framing of the decision and the leading proposal.
2. *(Optional)* Pointers to relevant files/docs the panellists should ground their opinions in.

If the question is vague ("what should I do about X?"), ask for the leading proposal first. The council critiques a concrete option better than it generates one from scratch.

## Steps

### 1. Build the shared brief (≤500 words)

Compose a single brief that every panellist receives identically. Include:
- The exact question and leading proposal.
- Relevant excerpts from `.claude/CLAUDE.md` (≤30 lines) for project context.
- Any file paths the user pointed at.
- Constraints the user mentioned (deadline, team size, budget, etc.).

Do **not** include your own opinion in the brief — that biases the panel.

### 2. Spawn 4 panellists in parallel

Send a single message with **four `Agent` tool calls in one block** so they run concurrently. Each gets the same brief plus a different persona prompt:

| Persona | subagent_type | model | Persona prompt (added to brief) |
|---|---|---|---|
| **Architect** | general-purpose | opus | "Prioritise long-term maintainability and clean boundaries. What design holds up at 10× the current scale? Recommend the choice that future maintainers will thank us for." |
| **Reviewer** | general-purpose | sonnet | "Find what could break, get exploited, or fail silently. Assume adversarial users and partial outages. What's the worst plausible failure mode of the leading proposal?" |
| **Simplifier** | general-purpose | sonnet | "Argue for the smallest possible solution. What's the boring option? What can we *not* build and still meet the requirement? Push back on any complexity that isn't load-bearing." |
| **Adversary** | general-purpose | opus | "Argue against the leading proposal. Steelman the opposite choice. If the user is wrong here, why? What are they not seeing?" |

Each panellist's prompt ends with:
> Reply in ≤300 words with exactly: **Recommendation:** (one sentence). **Top risk:** (one sentence). **Confidence:** (1–5). **Reasoning:** (≤6 bullets).

### 3. Synthesize in main context (do not delegate this)

Once all four return, write the synthesis yourself in the main conversation:

```markdown
# Council on: <one-line question>  (<YYYY-MM-DD>)

## Panel
- Architect (opus): <recommendation> — confidence <n>/5
- Reviewer (sonnet): <recommendation> — confidence <n>/5
- Simplifier (sonnet): <recommendation> — confidence <n>/5
- Adversary (opus): <recommendation> — confidence <n>/5

## Points of agreement
- <bullet>
- <bullet>

## Points of dissent
- <issue>: <who said what, briefly>

## Top risks raised
1. <risk> (raised by <persona>)
2. ...

## Chairman's recommendation
<your synthesis: which proposal, what to mitigate, what to defer. Cite which panellist's reasoning swung the call.>

## Open questions for the user
- <thing the panel could not resolve without more info>
```

### 4. Persist the result

Write the synthesis to `./.claude/council/<YYYY-MM-DD>_<slug>.md` (create the directory if missing). Slug = first 40 chars of the question, lowercased, non-alphanumerics → `-`.

This makes past councils greppable later — useful when a similar question comes up.

### 5. Report to the user

Print the chairman's recommendation + the file path of the persisted council. Do **not** dump all four panellist replies into the main conversation — they're long and the synthesis already captured what matters. The user can open the persisted file if they want the raw transcripts (include those in the persisted file, after the synthesis).

## Hard rules

- **Spawn all four panellists in a single message.** Sequential spawning quadruples latency for no benefit.
- **The synthesis is yours, not a 5th agent.** Delegating synthesis loses the user's intent and the conversation context the panel didn't see.
- **No leaking your opinion into the brief.** The panel is worth nothing if you've already steered it.
- **300-word cap is real.** If a panellist runs long, ask them to compress — the synthesis can't hold four 1000-word essays.
- **Always persist.** A council whose output isn't saved becomes hearsay in 10 turns.

## Anti-patterns

- Do not invoke the council for "what's the best way to write this function?" — overkill.
- Do not include the panellist replies in the main reply to the user — only the synthesis.
- Do not let the Adversary persona devolve into nitpicking — its job is steelman, not bikeshed.
- Do not run councils in a loop. If the first one is inconclusive, the answer is "go gather more data," not "ask 4 more agents."

## Comparison with external tools

The third-party `agent-council` (yogirk/agent-council) does the same shape but spawns *cross-vendor* CLIs (Codex, Gemini) for true model diversity. This skill trades vendor diversity for zero setup — all four panellists are Claude. Use the external tool when the decision genuinely benefits from non-Claude perspectives (e.g. choosing between AI providers themselves); use this skill for everything else.
