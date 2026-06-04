---
name: compare
description: Side-by-side comparison table + verdict. TRIGGER when user says "X vs Y", "compare A and B", "which should I use", "should I pick X or Y", "what's better, A or B", or names two-or-more concrete alternatives (libraries, models, approaches, file structures, designs) and asks to choose.
---

# Compare

The user has invoked `/compare`. Produce a side-by-side comparison of the options in question.

## Inputs

- The options to compare (from the user's message or the conversation).
- If unclear, ask once: "Comparing X vs Y on what criteria?"

## How to structure

1. **Pick the dimensions that matter** for THIS decision — not a generic feature checklist. For a model choice: accuracy, latency, cost, license. For a refactor: blast radius, reversibility, test coverage, time. 4–7 dimensions, max.
2. **Markdown table**: rows = dimensions, columns = options. Cells are short — a number, a phrase, or a one-line verdict per cell.
3. **Bold the winner per row** when there is one. Use "tie" or "n/a" when honest.
4. **Below the table**: one paragraph (~3 sentences) summarizing the tradeoff in plain language.
5. **One-line verdict**: which option wins, and what would flip the decision.

## Rules

- Ground every cell in evidence — codebase, conversation, or named source. If you're guessing, mark it `(est.)`.
- No filler dimensions added just to fill the table.
- If the options aren't actually comparable on the same axes (e.g., "should I rewrite or refactor?"), say so and reframe.
