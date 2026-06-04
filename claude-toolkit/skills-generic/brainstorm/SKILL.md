---
name: brainstorm
description: End-to-end divergent->convergent ideation pipeline. Reframes the problem, generates diverse options, stress-tests them, and converges to a recommended shortlist — wiring the ideator, premortem, assumption-surfacer, and synthesizer agents into one disciplined pass. Use for "help me brainstorm", "explore options for X", "what are our approaches and which is best". Project-agnostic.
model: opus
---

## What it does
Enforces the rule that idea generation and judgement must be separate phases (Guilford), and that LLM ideation must be diversity-forced or it homogenizes (Anderson et al. 2024). It orchestrates the toolkit's ideation/critique agents so you get spread AND a decision, not just a list.

## Pipeline
1. **Reframe.** Turn the request into 1-3 sharp "How might we ___?" questions. Confirm the framing with the user if the problem is ambiguous (a wrong frame wastes the whole pipeline).
2. **Diverge** — run the `ideator` agent. Over-generate diverse options using ordinary-persona sampling and axis variation. Do not judge yet.
3. **Expand (optional).** For an existing artifact, also run `scamper`-style transformation; for a stuck space, force lateral/analogy ideas. Skip if the diverge step already spans the space.
4. **Stress-test.** Run `premortem` (how does the leading direction fail?) and `assumption-surfacer` (what must be true for it to work?) on the strongest 2-3 candidates. Kill or revise options whose load-bearing assumptions fail.
5. **Converge** — run the `synthesizer` agent. Cluster, score against explicit criteria, recommend a shortlist with the "fails if…" condition for the winner.

## Orchestration notes
- This skill runs in the MAIN thread, so it can spawn the agent subtasks; the agents themselves cannot. Dispatch ideator/premortem/assumption-surfacer/synthesizer as subagents and synthesize their returns.
- Keep generation and judgement strictly ordered — never let the ideator see the scoring criteria, never let the synthesizer add new ideas.
- Scale to the task: a quick "name this" needs steps 1-2 + a light converge; a "which architecture" needs the full pipeline.

## Output
```
FRAMED: How might we <…>?
DIVERGED: <N ideas across K axes>  (from ideator)
STRESS-TESTED: <which survived; what assumption killed the rest>
SHORTLIST: <2-3 ranked options with criteria>
RECOMMENDATION: <winner> — fails if <assumption>.
```

## Anti-patterns
- Don't collapse to convergence too early — let the diverge step over-generate first.
- Don't skip the stress-test on high-stakes decisions; the cheapest time to kill a bad idea is before building it.
- For a single contested yes/no, this is overkill — use `debate`.
