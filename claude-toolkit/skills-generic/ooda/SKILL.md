---
name: ooda
description: Structured Observe→Orient→Decide→Act for hard bugs and complex problems. TRIGGER when user says "I'm stuck", "this bug doesn't make sense", "I've tried everything", "weird behavior", "intermittent failure", "race condition", "the easy fix didn't work", or describes a problem where naive pattern-matching has already failed. Forces explicit observation before guessing.
---

# OODA loop

The user has invoked `/ooda` because the problem is non-trivial and the easy fix already failed (or is suspect). Work through the four phases explicitly. Don't skip ahead.

## 1. Observe (gather raw signal)

- What is the actual symptom? Quote the error, the failing assertion, the wrong output.
- What is the *current* state of the code, logs, or data — not what the user remembers?
- What changed recently? (`git log`, recent edits, dependency updates.)
- Use tools (Read, Bash, grep) before forming a hypothesis.

## 2. Orient (build a model)

- What system is this? Which components could plausibly be involved?
- Map the data/control flow from input to symptom. Where could it diverge?
- What invariants are claimed, and which one is being violated?
- List 2–4 *competing* hypotheses for what's wrong. Don't fixate on the first one.

## 3. Decide (pick the cheapest disambiguator)

- Which one experiment, log line, or test would distinguish the hypotheses fastest?
- Prefer cheap, reversible probes (a print, a unit test, a `--dry-run`) over speculative refactors.
- State the decision in one sentence: "I'll do X to distinguish Y from Z."

## 4. Act (execute and feed back)

- Run the probe. Read the actual result.
- If the result rules out hypotheses: loop back to Orient with the narrower model.
- If the result matches a hypothesis: propose the fix, with the *evidence chain* that supports it.
- If the result is surprising: that's the most informative outcome. Loop back to Observe.

## Output structure

Show the four phases as labeled sections. Keep each phase short — this is a thinking discipline, not a wall of prose. The user wants to *see* the reasoning, not skip to a guess.
