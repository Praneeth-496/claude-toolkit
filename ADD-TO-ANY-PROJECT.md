# Add claude-toolkit to any project

Two ways. **Use the plugin** (recommended — set up once, live in every project forever) or the **copy-installer** (per-project files, no plugin system). Pick one; don't run both for the same repo.

---

## Option A — Plugin (recommended, zero per-project setup)

Do this **once** on a machine, inside any Claude Code session:

```text
/plugin marketplace add github:Praneeth-496/claude-toolkit
/plugin install claude-toolkit
```

Restart the session. That's it. From now on, **every project you open** automatically has:

- 24 auto-routing skills (memory graph, council, verify-claim, slurm, sync, 10x, scout, ...)
- 8 review subagents (adversary, code-reviewer, fact-checker, ...)
- 3 safety hooks (block dangerous bash, format-on-write, git session briefing)
- 4 MCP tools (`verify_result_claim`, `query_graph`, `memory_graph_add`, `placeholder_scan`)

No `npm install`, no copying files. The MCP server is dependency-free (plain Node ≥18).

**Verify it loaded:**
```text
/plugin      → claude-toolkit shows as enabled
/mcp         → claude-toolkit server lists 4 tools
```

**Bootstrap a new repo's context files (optional, per project):**
```text
/toolkit-init
```
This drops `.claude/CLAUDE.md`, `.claude/CONTEXT.md`, and `.claude/settings.local.json`, then lists the `<PLACEHOLDER>` markers to fill in.

**Update later:**
```text
/plugin marketplace update claude-toolkit-marketplace
/plugin update claude-toolkit
```

---

## Option B — Copy-installer (no plugin system)

Clone once, then run `install.sh` inside each project:

```bash
# one-time
git clone https://github.com/Praneeth-496/claude-toolkit ~/Documents/claude-toolkit

# per project
cd /path/to/your/project
bash ~/Documents/claude-toolkit/claude-toolkit/install.sh
```

This copies:
- `templates/*` → `./.claude/` (CLAUDE.md, CONTEXT.md, settings.local.json, statusline.sh)
- `templates/hooks/*` → `./.claude/hooks/`
- `agents/*` → `./.claude/agents/`
- `skills-generic/*` → `~/.claude/skills/` (user scope, shared across projects)

Then fill placeholders:
```bash
grep -nE '<[A-Z_]+>' .claude/CLAUDE.md .claude/CONTEXT.md
```

Re-run modes: `install.sh --update` (refresh skills/hooks) · `install.sh --force` (overwrite templates too).

---

## Which should I use?

| | Plugin (A) | Installer (B) |
|---|---|---|
| Setup | once per machine | once per project |
| New project effort | zero (auto) | run `install.sh` |
| MCP tools | yes | no (skills only) |
| Files committed to your repo | none | `.claude/` (agents, hooks, context) |
| Best for | your own machines, many projects | sharing a repo's setup with a team, CI |

Most of the time: **Option A.** Use **B** when you want the setup committed into a specific repo so collaborators get it without installing the plugin.

Full details: [`claude-toolkit/docs/PLUGIN.md`](claude-toolkit/docs/PLUGIN.md).
