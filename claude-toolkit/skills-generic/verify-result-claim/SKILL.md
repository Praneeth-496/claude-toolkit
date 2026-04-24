---
name: verify-result-claim
description: Given a numeric claim (e.g. "82.1% accuracy", "0.559 MAE"), confirm it matches a value in this project's authoritative results files (JSON/CSV). Refuses if no match. Reads the project's results glob from .claude/CLAUDE.md (Architecture section) or from an explicit user hint.
model: sonnet
---

## When to use
Before inserting any number into docs, README, thesis, memory, or a commit message. Also: whenever the user pastes a result and asks "is this right?"

## How to find the authoritative sources

1. Read `.claude/CLAUDE.md` — look for paths mentioned in the **Architecture** or project-specific sections (e.g. `results/*.json`, `experiments/*/metrics.csv`, `saved_models/*.json`, `evaluation/*/summary.csv`).
2. If the user provided a hint ("check the benchmark CSVs"), use that path.
3. If neither is available, grep the whole repo for the value — but warn the user that this is less reliable than a declared results glob.

## Steps

1. Normalise the claim: strip units, keep 3–4 significant digits (e.g. "0.559 m" → `0.559`).

2. Grep the authoritative sources (do NOT Read them in full):
   ```bash
   grep -rn "<value>" <RESULTS_GLOB_1> <RESULTS_GLOB_2> 2>/dev/null
   ```

3. Also try ±1 in the last significant digit for rounding differences:
   ```bash
   # e.g. for "0.559", also grep "0.558" and "0.560"
   ```

4. Output:
   - **≥1 hit:** `VERIFIED: <value> found at <file>:<line>` for each hit.
   - **0 hits:** `UNVERIFIED: <value> not found. Nearby values in the source: <list>` and refuse.

## Anti-patterns
- Do not open the entire JSON/CSV with Read — grep only. A single short CSV can be Read if grep is ambiguous, but never large data files.
- Do not accept a claim that only matches the README — the README usually cites the JSONs/CSVs, not vice versa. The authoritative source is the machine-generated artefact.
- Do not fudge "close enough". If the value is not in the declared source, it is unverified.
