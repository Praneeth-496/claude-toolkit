---
name: update-thesis
description: "EXAMPLE — project-specific skill. Edit a LaTeX thesis file safely: enforces a no-em-dash rule and requires every numeric claim to be traceable to a results JSON/CSV. Copy this skill to ~/.claude/skills/ in any LaTeX thesis project and adapt the paths."
model: opus
---

> **This is a reference example of a project-specific skill.** It is not auto-installed by `claude-toolkit/install.sh`. Copy the folder to `~/.claude/skills/update-thesis/` (user scope) or `<project>/.claude/skills/update-thesis/` (project scope) and replace `<THESIS_PATH>` / `<RESULTS_GLOB>` with your own paths.

## When to use
User asks to add / update text, tables, or figures in the thesis LaTeX source at `<THESIS_PATH>`.

## Hard rules

1. **No em-dashes.** Before every Edit/Write, grep the candidate `new_string` for `—` (U+2014) and `–` (U+2013). If either matches, refuse and rewrite with `--`, commas, or parentheses.
   ```bash
   printf '%s' "$NEW_STRING" | grep -nE '—|–' && echo "BLOCKED: em/en-dash present" && exit 1
   ```

2. **Verify every number.** For every numeric value being inserted (metrics, counts, percentages), call the `verify-result-claim` skill. Refuse to insert unverified numbers — mark them as `\todo{verify}` instead.

3. **Do not edit generated outputs.** Table `.tex` files and PNGs produced by a build script are not editable here — edit the Python source and regenerate.

## Steps

1. Read the target section with `Read --offset --limit`. The thesis file is large; never read whole.
2. Draft the change.
3. Run the em-dash check.
4. For each number, call `verify-result-claim`. Record the source file:line.
5. If all checks pass, apply via `Edit` (not `Write` — keeps the diff small).
6. Report the source file:line for each verified number so the user can audit.

## Anti-patterns
- Do not "fix" a dash you are not sure about — flag to the user and let them pick.
- Do not paraphrase numbers ("about 80%" when the JSON says 80.8%). Use the exact JSON value.
- Do not add a figure without the naming convention used by the figure-generation script.

## Adapting to your project

Replace:
- `<THESIS_PATH>` → your main `.tex` file (e.g. `docs/report/main.tex`, `thesis/chapters/results.tex`)
- `<RESULTS_GLOB>` → where `verify-result-claim` will grep (e.g. `results/*.json`)
- The em-dash rule → whatever style rule matters for your document (LaTeX, Markdown, etc.)
