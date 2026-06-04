# Add claude-toolkit to any project

Two ways. **Use the plugin** (recommended — set up once, live in every project forever) or the **copy-installer** (per-project files, no plugin system). Pick one; don't run both for the same repo.

---

## Option A — Plugin (recommended, zero per-project setup)

Use the **`claude plugin` CLI** in a normal terminal. This is the reliable method and works everywhere, including the VS Code / IDE extensions where the interactive `/plugin` slash command is **not** available.

> The `/plugin` slash command (`/plugin marketplace add …`) only works in the Claude Code **terminal TUI**, and not at all in your bash shell. If `/plugin` gave you `No such file or directory` (bash) or `/plugin isn't available in this environment` (VS Code), use the CLI below instead.

Run these **once** in a terminal (these ARE bash commands — note `claude plugin …`, and the source is `owner/repo`, not `github:owner/repo`):

```bash
claude plugin marketplace add Praneeth-496/claude-toolkit
claude plugin install claude-toolkit
```

That's it — it installs at **user scope and is enabled by default**. **Restart your Claude Code session** (close/reopen the IDE panel, or start a new chat) so it loads. From then on, **every project** automatically has:

- 30 auto-routing skills (memory graph, council, verify-claim, brainstorm, debate, refine-loop, env-bootstrap, 10x, scout, …)
- 14 subagents (review + verification/anti-hallucination: cove-verifier, citation-auditor; + ideation: ideator, synthesizer, premortem, …)
- 4 safety hooks (block dangerous bash, block global pip, format-on-write, git session briefing)
- 4 MCP tools (`verify_result_claim`, `query_graph`, `memory_graph_add`, `placeholder_scan`)

No `npm install`, no copying files. The MCP server is dependency-free (plain Node ≥18).

**Verify it loaded (in a terminal):**
```bash
claude plugin list                  # claude-toolkit -> Status: ✔ enabled
claude plugin details claude-toolkit  # full component inventory + token cost
```
And after restarting the session, inside the Claude Code chat: type `/claude-toolkit:` to see the 30 skills.

**Bootstrap a new repo's context files (optional, inside Claude Code chat):** type `/toolkit-init` — drops `.claude/CLAUDE.md`, `.claude/CONTEXT.md`, `.claude/settings.local.json` and lists the `<PLACEHOLDER>` markers.

**Update to a new version later (terminal):**
```bash
claude plugin marketplace update claude-toolkit-marketplace
```

> Do not paste `claude plugin disable claude-toolkit` from any reference — that turns the plugin OFF. To turn it back on: `claude plugin enable claude-toolkit`.

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
