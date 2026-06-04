---
description: Bootstrap the current project with claude-toolkit templates (CLAUDE.md, CONTEXT.md, settings.local.json, .gitignore) — idempotent, never overwrites without --force.
argument-hint: "[--force]"
allowed-tools: Bash(mkdir:*), Bash(cp:*), Bash(grep:*), Bash(cat:*), Bash(test:*), Read, Edit
---

Bootstrap the current working directory with the claude-toolkit project templates.

Templates live at `${CLAUDE_PLUGIN_ROOT}/templates/`. Arguments: `$ARGUMENTS` (pass `--force` to overwrite existing project files).

Do exactly this, in order:

1. `mkdir -p .claude`
2. For each of these, copy from the template **only if the destination does not already exist** (unless `--force` was passed, in which case overwrite):
   - `${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.md.template`          → `.claude/CLAUDE.md`
   - `${CLAUDE_PLUGIN_ROOT}/templates/CONTEXT.md.template`         → `.claude/CONTEXT.md`
   - `${CLAUDE_PLUGIN_ROOT}/templates/settings.local.json.template` → `.claude/settings.local.json`
   Report `copy`, `skip (exists)`, or `overwrite` for each.
3. Append `${CLAUDE_PLUGIN_ROOT}/templates/gitignore-snippet.txt` to `./.gitignore`, but only if the marker line `# claude-toolkit managed` is not already present. If `.gitignore` does not exist, create it.
4. Scan the new `.claude/CLAUDE.md` and `.claude/CONTEXT.md` for unfilled `<PLACEHOLDER>` markers (pattern `<[A-Z_][A-Z0-9_]*>`). List every placeholder with its file and line number so the user knows what to fill in. (The bundled `placeholder_scan` MCP tool does this if available; otherwise grep `-nE '<[A-Z_][A-Z0-9_]*>'`.)
5. Run the `env-bootstrap` skill to create the project's mandatory isolated environment (`.venv` via uv for Python, local `node_modules` for Node) so dependency versions never collide. This is required, not optional.
6. Print a short next-steps summary: fill placeholders, confirm the isolated env is active, then optionally run the `auto-memory` skill to seed project memory.

Never overwrite a file that already exists unless `--force` is in `$ARGUMENTS`. Never touch any file outside the current project. Do not commit anything.
