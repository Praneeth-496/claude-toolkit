---
name: scout
description: Find risks, blind spots, failure modes — prioritized by severity. TRIGGER when user says "what could go wrong", "find blind spots", "risks of this approach", "what am I missing", "stress-test this plan", "is this safe to ship", "what could break", before merging a PR, or before an irreversible decision.
---

# Scout

The user has invoked `/scout`. Hunt for what could go wrong with the current plan, design, or code.

## What to scan

- The proposal, plan, or code in the current conversation.
- If multiple candidates exist (Claude proposed a plan, user countered with another), scout BOTH.
- If unclear what to scout, ask once.

## What to look for

- **Failure modes**: what breaks under load, on edge inputs, on first-run, on retry, on rollback?
- **Hidden coupling**: what else in the system depends on this assumption?
- **Reversibility**: can we undo this if it goes wrong? How fast?
- **Operational risk**: what does monitoring miss? Who gets paged? What's the worst Friday-5pm scenario?
- **Threat model**: who/what is the adversary? (User input, race conditions, malicious data, dependency drift.)
- **Cognitive blind spots**: what is the user assuming because it was true *last* time?
- **What's NOT being tested**: which behaviors have no coverage?

## Output

A prioritized list. For each risk:

- **Severity** (high / med / low) — by impact × likelihood
- **Risk** — one sentence
- **Why it's plausible** — one sentence (specific, not generic)
- **Cheapest mitigation** — one sentence

5–10 risks. Skip generic boilerplate ("you should write tests"). Every item must be specific to this plan.

End with a one-line verdict: ship-as-is, ship-with-mitigations, or rethink.
