---
name: debate
description: Judged multi-round debate for contested-correctness questions where a single pass over-commits to its first answer. 2-3 independent agents answer, read each other's reasoning, and revise over a capped number of rounds; a separate judge declares consensus or the best-supported position. Use for hard yes/no or "is this correct?" questions. TRIGGER on "is this actually safe/correct?", "settle this", "stress-test this conclusion".
model: opus
---

## When to use
For questions with a defensible right answer that a single model tends to lock onto prematurely ("is this concurrency-safe?", "is this proof valid?", "will this migration lose data?"). Debate counters Degeneration-of-Thought — first-answer fixation (Liang et al. 2023). For OPEN-ENDED generation or discrete-votable answers, do not use this; use `synthesizer` or `vote` respectively (they're cheaper).

## Cost discipline (read first)
Multi-agent debate often only matches plain majority voting and can lose to it at equal cost (Huang et al. 2023). So: cap at **2-3 rounds with 2-3 agents** (Du et al.'s own cost-driven default), and if the answer is discrete, prefer the `vote` skill instead. Only spend debate on genuinely contested correctness where the reasoning, not just the answer, matters.

## Protocol
1. **Independent round (R0).** Spawn 2-3 subagents; each answers the question from scratch with its reasoning and a confidence. They do NOT see each other yet.
2. **Debate rounds (R1, optional R2).** Show each agent the others' answers+reasoning. Each must either defend (with new evidence) or revise. Encourage genuine disagreement — penalize lazy convergence.
3. **Judge.** A separate judge subagent reads the full transcript and rules: consensus reached (state it) or, if not, the best-evidenced position and why — and what evidence would settle the remainder. The judge weighs evidence, not vote count or verbosity.
4. **Ground where possible.** If the question is checkable (code, tests, a source), have at least one agent or the judge verify with `Read`/`Grep`/`Bash`/web rather than argue from priors.

## Output
```
QUESTION: <one line>
R0: A=<pos/conf>  B=<pos/conf>  C=<pos/conf>
R1: <who moved and why>
JUDGE: <ruling> — because <evidence>.  Unresolved: <what would settle it, or "none">.
```

## Anti-patterns
- Don't exceed 3 rounds (diminishing returns, rising cost).
- Don't let the judge tally votes — it weighs evidence. Never let an agent judge the round it debated in.
- Discrete answer? Use `vote`. Open-ended? Use `synthesizer`/`council`.
