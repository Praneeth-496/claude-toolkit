---
name: vote
description: Self-consistency wrapper for DISCRETE-answer questions. Samples the same question several times independently and returns the majority answer plus an agreement score (low agreement = low confidence). The cheapest reliability boost available, but only for questions with a small set of possible answers. TRIGGER on "which of these", classification, "pick one of A/B/C", "what's the most likely X".
model: sonnet
---

## When to use
Only when the answer is one of a SMALL, discrete set (a class label, a yes/no, "which of these 3 designs / partitions / fixes"). Self-consistency gives a robust, well-replicated accuracy gain for votable answers (Wang et al. 2022: +6 to +18% on reasoning benchmarks). For open-ended generation there is nothing to vote on — use `synthesizer`; for contested reasoning use `debate`.

## Steps
1. **Pin the answer space.** State the allowed answers explicitly. If the question isn't discrete, stop and route to `synthesizer`/`debate`.
2. **Sample k independent answers (k=5 default).** Each produced from scratch with brief reasoning, no memory of the others (parallel subagents or clean regenerations). Diversity in the *path* is the point.
3. **Tally.** Majority answer wins. Report the distribution.
4. **Confidence from agreement.** Unanimous = high; split (e.g. 3-2) = low — surface it rather than hiding the disagreement, and consider escalating a close call to `debate`.
5. **Ground if cheap.** If the answer is checkable (run a command, grep the repo), verify the leading answer instead of trusting the vote alone.

## Output
```
QUESTION: <one line>   ANSWER SPACE: {A, B, C}
SAMPLES (k=5): A, A, B, A, C
WINNER: A (3/5)   AGREEMENT: medium
NOTE: <"unanimous, high confidence" | "close — consider debate" | verification result>
```

## Anti-patterns
- Don't use on open-ended outputs (essays, designs, code) — averaging prose is meaningless.
- Don't re-ask in one context and call it voting; samples must be independent.
- Treat a narrow split as a signal to verify or debate, not as a clean answer.
