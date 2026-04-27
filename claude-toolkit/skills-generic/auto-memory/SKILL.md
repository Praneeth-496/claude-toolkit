---
name: auto-memory
description: Bootstrap or refresh the project memory directory automatically by scanning the current repo. Derives a project snapshot, a code-style snapshot, and a reference-paths snapshot from what's actually on disk — no user input required. Run on a fresh project to seed memory; re-run any time to rebuild from current state.
model: opus
---

## When to use
- First time a project is opened with this toolkit installed and `~/.claude/projects/<encoded>/memory/` is empty or missing.
- User says "build memory", "init memory", "auto memory", "scan the project for memory".
- After major refactors when the existing memory clearly disagrees with the code (a `refresh-memory` is finer-grained; this is the from-scratch rebuild).

This skill never invents facts about the *user* or *feedback* — those memory types come from real conversations. It only writes `project` and `reference` memories that can be derived from the repo itself.

## Locating the memory directory

```bash
CWD_ENCODED=$(pwd | sed 's/[^A-Za-z0-9]/-/g')
MEM_DIR="$HOME/.claude/projects/$CWD_ENCODED/memory"
mkdir -p "$MEM_DIR"
```

If a directory matching the project basename already exists under `~/.claude/projects/` but the encoded name differs, prefer the existing one (the harness encoder may have changed).

## Steps

### 1. Inventory the project (cheap greps, no full reads)

Run these in parallel and capture the output. If anything errors, skip that line — the skill must not fail because the project lacks a feature.

```bash
# Identity
basename "$(pwd)"
git -C . remote get-url origin 2>/dev/null
git -C . rev-parse --abbrev-ref HEAD 2>/dev/null

# Tech stack signals (presence-only)
ls package.json pyproject.toml requirements.txt Cargo.toml go.mod \
   pom.xml build.gradle Gemfile composer.json 2>/dev/null
ls Dockerfile docker-compose.yml .github/workflows/ 2>/dev/null

# Entry points
ls *.py main.* index.* app.* server.* 2>/dev/null | head -20
find . -maxdepth 2 -name 'README*' -o -name 'CLAUDE.md' 2>/dev/null

# Test layout
find . -maxdepth 3 -type d \( -name tests -o -name test -o -name __tests__ \) 2>/dev/null

# Existing toolkit context (read these, they're small)
[[ -f .claude/CLAUDE.md ]]  && head -80 .claude/CLAUDE.md
[[ -f .claude/CONTEXT.md ]] && head -40 .claude/CONTEXT.md

# Recent activity for the "what's hot" snapshot
git -C . log --oneline -20 2>/dev/null
git -C . diff --stat HEAD~10..HEAD 2>/dev/null | tail -5
```

### 2. Decide which memory files to write

For a typical project, write **at most three**:

| File | Type | Source of facts |
|---|---|---|
| `project_snapshot.md` | project | basename, remote URL, branch, tech stack, entry points, test layout |
| `project_recent_activity.md` | project | last ~10 commits + churn summary (frozen-in-time, marked with date) |
| `reference_paths.md` | reference | declared results glob, HPC host, important external dashboards (only what's actually in CLAUDE.md/CONTEXT.md — do not invent) |

If a category has no signal (e.g. no git remote, no HPC config), **skip the file** rather than writing placeholders.

### 3. Write each file with proper frontmatter

```markdown
---
name: project_snapshot
description: One-line description specific to this project (e.g. "<repo>: Python ML pipeline, FastAPI serving layer, pytest suite under tests/")
type: project
---

## Snapshot (<YYYY-MM-DD>)

**What:** <one-paragraph description derived from README/CLAUDE.md, NOT invented>

**Stack:** <list of detected tech>

**Entry points:**
- <path>:<line if known> — <role>

**Tests:** <test framework + location>, run with `<command>` if discoverable

## Why this matters
<How a future conversation should use this — e.g. "When suggesting changes, check whether they need accompanying tests under tests/. The project uses pytest with fixtures in conftest.py.">
```

`recent_activity` and `reference_paths` follow the same shape — see the `<types>` section in the parent prompt for the canonical structure.

### 4. Update `MEMORY.md` index

```markdown
- [project_snapshot](project_snapshot.md) — <one-line hook>
- [project_recent_activity](project_recent_activity.md) — last ~10 commits, frozen <YYYY-MM-DD>
- [reference_paths](reference_paths.md) — declared results glob and external dashboards
```

Cap `MEMORY.md` at ~50 lines on first write — leave room for user/feedback memories that accumulate over time.

### 5. Report

After writing, print:
```
Wrote N memory files to <MEM_DIR>:
  - project_snapshot.md (<X> lines)
  - project_recent_activity.md (<X> lines)
  - reference_paths.md (<X> lines)
Index: MEMORY.md (<Y> entries)

Skipped: <list of files skipped and why>
```

## Hard rules

- **Never invent.** Every fact in a memory file must trace to a `grep` / `find` / `git log` / file-read result captured in step 1.
- **Date-stamp project memories.** The `## Snapshot (YYYY-MM-DD)` header lets future-you spot stale entries.
- **Skip user/feedback types.** Those are conversation-derived. Writing them from a code scan is dishonest.
- **Don't overwrite without backup.** If `project_snapshot.md` already exists, write to `project_snapshot.md.new` and ask the user to diff/merge.
- **Cap each file ≤80 lines.** If a snapshot grows larger, split off the heaviest section into a sibling file and index both.

## Anti-patterns
- Do not `Read` every source file in the project to "understand it better" — the inventory greps are enough. The user can ask follow-up questions later.
- Do not write a `project_*` file for something you can already see in `CLAUDE.md` — that just duplicates what's loaded every turn.
- Do not write speculation ("the project probably uses X for Y") — write only what `grep` / `git log` confirmed.
- Do not run this skill silently as part of another skill's flow. It writes durable state; the user must invoke it.
