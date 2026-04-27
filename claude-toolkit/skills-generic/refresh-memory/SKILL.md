---
name: refresh-memory
description: Re-derive the project's auto-memory snapshot from the current repo state. Use when the memory file contradicts the code, or when asked to "refresh memory" / "update memory".
model: sonnet
---

## When to use
- User says "update memory", "refresh memory", or "memory is stale".
- A conversation reveals a memory file contradicts the code (e.g. outdated feature dim, old best-model number).

## Locating the memory

The auto-memory for the current project lives at:
```
~/.claude/projects/<ENCODED_PROJECT_PATH>/memory/
```
Where `<ENCODED_PROJECT_PATH>` is the current working directory with **every non-alphanumeric character** (slashes, dots, underscores, hyphens between letters all count) replaced by `-`. The leading `/` becomes a leading `-`.

Examples:
- `/home/user/Documents/foo`     → `-home-user-Documents-foo`
- `/home/user/proj.v2`           → `-home-user-proj-v2`
- `/home/user/my_app`            → `-home-user-my-app`

## Steps

1. Find the memory directory (handles dots, underscores, etc.):
   ```bash
   CWD_ENCODED=$(pwd | sed 's/[^A-Za-z0-9]/-/g')
   MEM_DIR="$HOME/.claude/projects/$CWD_ENCODED/memory"
   if [[ ! -d "$MEM_DIR" ]]; then
     # Fall back to fuzzy match in case the encoder ever changes.
     candidate=$(ls "$HOME/.claude/projects/" 2>/dev/null \
                 | grep -F "$(basename "$(pwd)" | sed 's/[^A-Za-z0-9]/-/g')" \
                 | head -1)
     [[ -n "$candidate" ]] && MEM_DIR="$HOME/.claude/projects/$candidate/memory"
   fi
   ls "$MEM_DIR"
   ```

2. Identify which memory file needs refreshing. Typical candidates:
   - `project_<something>.md` — project status snapshots
   - Skip `user_*.md` and `feedback_*.md` — those are user/behaviour memories, not code-derived.

3. Derive canonical numbers/facts directly from the repo. Sources to grep (in priority order):
   - Declared results glob from `.claude/CLAUDE.md` (Architecture section) — JSON/CSV result files
   - `README.md` — but only numbers that themselves cite a source
   - Main preprocessor / config module — for feature dims, class counts, split sizes

4. Write a fresh memory file with frontmatter:
   ```markdown
   ---
   name: <memory_name>
   description: <one-line updated description> (refreshed <YYYY-MM-DD>)
   type: project
   ---
   ## Current state (<YYYY-MM-DD>)
   ...
   ```

5. Ensure `MEMORY.md` index still points at the file. If missing, add:
   ```markdown
   - [<file>](<file>) — <one-line hook>
   ```

6. Cap body ≤80 lines. If growing larger, split off a secondary file and index both.

## Anti-patterns
- Do not invent results. Every number must come from a grep in step 3.
- Do not delete and leave MEMORY.md dangling — overwrite in place.
- Do not refresh `user_*` or `feedback_*` memories from this skill — this is for project snapshots only.
- Do not add ephemeral task state to memory (in-progress work, current conversation topic).
