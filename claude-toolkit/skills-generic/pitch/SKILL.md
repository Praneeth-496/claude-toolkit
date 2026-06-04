---
name: pitch
description: 30-second spoken pitch (~75 words). TRIGGER when user says "elevator pitch", "pitch this", "30 seconds", "summarize for my supervisor/committee/investor", "how would I introduce this in a defense", or asks for a quick spoken summary of the project/topic for a non-specialist audience.
---

# 30-second pitch

The user has invoked `/pitch`. Produce a spoken pitch of ~75 words (≈30 seconds at speaking pace) about the topic in the current conversation.

## Audience

Default to "smart but non-specialist" (investor, supervisor, panel chair). If the user names an audience ("/pitch to my thesis committee", "/pitch for a Series A VC"), tune to them.

## Structure (rough)

1. **Hook (one sentence)** — the problem in concrete, human terms. No jargon.
2. **What we built / what we found (one sentence)** — the solution or core result, with one number that matters.
3. **Why it's hard / why it's defensible (one sentence)** — the moat, the technical insight, or the surprising bit.
4. **Ask / next step (one sentence)** — what you want from the listener.

## Constraints

- ~75 words total. Count them.
- Spoken cadence: short sentences, no parentheticals, no semicolons.
- One number, max two. The number must be real (from the conversation or codebase) — never invent.
- No buzzwords ("synergy", "leverage", "best-in-class").
- No "I'm excited to share" preamble.

Output the pitch only. No surrounding explanation.
