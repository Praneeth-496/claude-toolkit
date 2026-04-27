---
name: edit-doc-strict
description: "EXAMPLE — project-specific skill pattern. Edit a single authoritative document (thesis, spec, README, blog post) under strict rules: style guard runs before every write, and any numeric claim must trace to a results file. Copy this skill and adapt the rule list + paths to your project."
model: opus
---

> **This is a reference example, not auto-installed.** Copy the folder to `~/.claude/skills/<your-name>/` (user scope) or `<project>/.claude/skills/<your-name>/` (project scope). Edit the frontmatter `name`/`description`, then replace `<DOC_PATH>`, `<RESULTS_GLOB>`, and the rule list below.

## What pattern this shows

A document-editing skill that:
1. **Refuses edits that violate project style rules** (a static `grep` check on the candidate string).
2. **Refuses to insert numbers that aren't traceable** to an authoritative results file (delegates to `verify-result-claim`).
3. **Records sources** for every number written, so the user can audit.

Use it for: a thesis chapter, an RFC, a customer-facing spec, a paper, a release-notes file — anywhere a single doc has hard rules and load-bearing numbers.

## When to use
User asks to add or update text, tables, or figures in `<DOC_PATH>`.

## Hard rules (replace with your project's rules)

1. **Style guard.** Before every Edit/Write, grep the candidate `new_string` for forbidden patterns. Example for an academic doc that bans em/en-dashes:
   ```bash
   printf '%s' "$NEW_STRING" | grep -nE '—|–' && echo "BLOCKED: em/en-dash present" && exit 1
   ```
   Other examples to adapt: trailing whitespace, banned marketing words, TODO leftovers, tabs vs spaces.

2. **Verify every number.** For every numeric value being inserted (metrics, counts, percentages), call the `verify-result-claim` skill. If unverified, insert a placeholder (`\todo{verify}`, `<!-- TODO verify -->`, etc.) instead of the number.

3. **Do not edit generated outputs.** Files produced by a build script (rendered tables, exported figures) are not editable here — edit the source and regenerate.

## Steps

1. Read the target section with `Read --offset --limit`. The doc is usually large; never read it whole.
2. Draft the change.
3. Run the style guard.
4. For each number in the change, call `verify-result-claim`. Record `file:line` of the source.
5. If all checks pass, apply via `Edit` (not `Write` — keeps the diff reviewable).
6. Report the source `file:line` for each verified number so the user can audit.

## Anti-patterns
- Do not silently "fix" a style violation you're not sure about — flag to the user and let them pick.
- Do not paraphrase numbers (`"about 80%"` when the source says `80.8%`). Use the exact value.
- Do not add a figure without following the project's figure-naming convention.

## Adapting to your project

Replace in this file:
- `<DOC_PATH>` → main file you edit (e.g. `docs/report/main.tex`, `SPEC.md`, `RELEASE_NOTES.md`)
- `<RESULTS_GLOB>` → where `verify-result-claim` will grep (e.g. `results/*.json`, `benchmarks/*.csv`)
- The "Hard rules" list → whatever style/correctness rules actually matter for your document

Then update the `name:` and `description:` in the frontmatter so the skill matcher routes the right requests to it.
