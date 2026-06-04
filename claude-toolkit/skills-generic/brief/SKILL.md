---
name: brief
description: One-sentence-or-paragraph answer, zero preamble. TRIGGER when user says "in one line", "one sentence", "TL;DR", "short answer", "quick", "just the answer", "don't explain", or the question is a factual lookup that doesn't need elaboration. Style change — apply for one turn.
---

# Brief

The user has invoked `/brief`. Give the shortest answer that is still correct and complete.

## Rules

- **One sentence** if the answer fits in one. **One paragraph** if it doesn't. Never more.
- **No preamble**: no "Sure", "Great question", "Let me explain", "It's worth noting".
- **No closing**: no "Hope this helps", "Let me know if you need more", "Happy to elaborate".
- **No caveats** unless the caveat changes the answer. ("It depends on X" — only if X actually flips the answer.)
- **No headers, no lists** unless the answer is genuinely a list of items the user asked for.
- **Numbers and names, not adjectives.** "47ms" beats "fast". "PostgreSQL 14+" beats "modern Postgres".
- **Code blocks** are allowed and don't count toward the length cap — but only the minimum lines needed.

If the question genuinely cannot be answered briefly (it's actually three questions, or requires a table to be useful), say so in one sentence and ask which part to answer first. Don't pad.
