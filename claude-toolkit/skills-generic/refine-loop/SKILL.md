---
name: refine-loop
description: Evaluator-optimizer loop gated on a REAL external signal. A generator produces a draft, an evaluator runs an actual check (tests, build, linter, a script, or a declared results source), writes a concrete critique, and the generator revises — repeating until the check passes or a cap is hit. Use for work that has an objective pass/fail. TRIGGER on "make this pass the tests", "iterate until it works", "refine until correct".
model: opus
---

## When to use
Only when there is an EXTERNAL signal of correctness. Reflexion/Self-Refine gains are real with a ground-truth signal and negative without one — pure "critique your own answer" loops degrade reasoning (Huang et al. 2023). So this skill refuses to run without a check.

## Find the external signal (project-agnostic)
Discover, in this order, what "correct" means for the task:
1. A test/build command — from `.claude/CLAUDE.md`, `package.json` scripts, a `Makefile`, `pyproject.toml`, CI config, or the obvious framework (`pytest`, `npm test`, `cargo test`, `go test`).
2. A declared results/spec source named in `.claude/CLAUDE.md` (e.g. a results glob) — use the `verify-result-claim` skill / `verify_result_claim` MCP tool to check numeric claims against it.
3. A runnable artifact (the script executes without error and produces expected output).

If none exists, STOP and say so — do not loop on self-judgement.

## Loop (max 3 iterations)
1. **Generate** the draft (code/answer/config).
2. **Evaluate** by RUNNING the signal — capture real output (test failures, error text, diff from expected). The evaluator must use the external signal, not its opinion.
3. **Critique** concretely from that output: what failed, where, why.
4. **Revise** addressing the critique. Re-run the signal.
5. **Stop** when the check passes, or after 3 iterations report the best attempt + remaining failures. Never claim success without showing the passing check.

## Roles
Run generator and evaluator as distinct passes (ideally distinct subagents) so the evaluator isn't anchored on the generator's reasoning. Keep the external command as the source of truth; the LLM interprets results, it does not replace them.

## Output
```
SIGNAL: <the test/build/verify command used>
iter 1: <draft summary> -> check: FAIL (<key output>)
iter 2: <change> -> check: FAIL (<output>)
iter 3: <change> -> check: PASS  ✓   (show the passing command output)
RESULT: passing | best-effort (remaining: <failures>)
```

## Anti-patterns
- No external signal -> do not run. "Looks right to me" is not a stop condition.
- Don't hide a failing check. Paste the real output.
