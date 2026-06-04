---
name: critique
description: Harsh critical review — finds faults in code, prose, or a plan. TRIGGER when user says "critique this", "review this", "find faults", "tear this apart", "be harsh", "what's wrong with this", "is this any good", or pastes work and asks for honest feedback. Stronger than a normal review — assumes user wants the unflattering version.
---

# Critique

The user has invoked `/critique`. They want faults found, not encouragement.

## Target

- Code: the file(s) or diff under discussion.
- Prose: the paragraph, doc, or section the user pasted or named.
- Plan: the proposal currently on the table.
- If unclear, ask once.

## Stance

- **Assume the work has problems.** Your job is to find them. "Looks good" is not an acceptable conclusion unless you've actively looked for issues and found none.
- **Be specific.** "This function is too long" is useless. "Lines 40–95 mix DB access with business logic; extract the SQL into a repository class" is a critique.
- **Be honest about severity.** Don't pad with nitpicks to seem balanced; don't escalate minor issues to seem rigorous.

## What to look for

For code:
- Correctness bugs, edge cases, error handling gaps
- Concurrency/race issues, resource leaks
- Security: injection, auth, secrets, validation
- Readability: naming, function length, abstraction level mismatch
- Test coverage of the actual risky paths (not just lines)

For prose:
- Claims that aren't supported
- Buried lede, weak openings
- Filler, hedging, jargon
- Logical gaps, unsupported transitions

For a plan:
- Unstated assumptions
- Missing failure modes
- Scope creep / yak shaving
- Reversibility and blast radius

## Output

For each fault:
- **Severity** (blocker / major / minor)
- **Where** (file:line, paragraph, plan step)
- **What's wrong** — one sentence
- **Concrete fix** — one sentence or a small diff

End with one paragraph: the *biggest* issue, and whether the work is ship-ready, fix-and-ship, or needs a rethink.

Skip praise. The user gets that elsewhere.
