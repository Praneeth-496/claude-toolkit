# Using claude-toolkit as a Claude Code plugin

As of v0.5.0 the toolkit installs as a **Claude Code plugin from GitHub** (it also still works as a copy-installer via `install.sh`). The plugin is the recommended path: enable it once at user scope and every project you open afterward has the skills, agents, hooks, and MCP tools automatically. No per-project install, and the bundled MCP server needs **no `npm install`** (it is dependency-free).

## What the plugin ships

| Component | Where | Loaded |
|---|---|---|
| 30 skills | `skills-generic/` | auto-discovered, auto-routed by `description:` |
| 14 subagents | `agents/` | available to the `Task` tool |
| 4 safety hooks | `hooks/hooks.json` → `templates/hooks/` | fire on Bash / Edit·Write / SessionStart |
| `/toolkit-init` command | `commands/` | bootstraps templates into a repo |
| Bundled MCP server | `mcp/index.mjs` + `.mcp.json` | 4 tools + 1 resource, over stdio, zero deps |
| Project templates | `templates/` | copied by `/toolkit-init` or `install.sh` |

### Skills (30)
- **Workflow (13):** auto-memory, council, memory-graph, query-graph, refresh-memory, run-pipeline, session-watchdog, submit-slurm, sync-rsync, verify-result-claim, orchestrate, pr-prep, env-bootstrap
- **Agentic loops (5):** consistency-checker (SelfCheckGPT triage), refine-loop (evaluator-optimizer, external-signal gated), debate (judged multi-round), vote (self-consistency), brainstorm (divergent->convergent pipeline)
- **Thinking/style (12):** 10x, brief, godmode, scout, critique, devil, compare, pitch, teacher, explainlikeim5, humanizer, ooda

### Subagents (14)
- **Review (8):** adversary, code-reviewer, fact-checker, flow-auditor, simplifier, doc-writer, test-runner, security-auditor.
- **Verification / anti-hallucination (2):** cove-verifier (Chain-of-Verification), citation-auditor (per-claim source grounding).
- **Ideation / critique (4):** ideator (diversity-forced divergent), synthesizer (convergent closer), premortem (prospective-hindsight risk), assumption-surfacer (Toulmin implicit-assumption finder).

### Hooks (4, plugin-active)
`hooks/hooks.json` wires these `templates/hooks/` scripts so they fire in **every** project the plugin is enabled in:
- **PreToolUse(Bash)** → `block-dangerous-bash.sh` (blocks `git push --force`, `rm -rf /`, fork bombs, `mkfs`, `dd of=/dev/...`, `curl | sh`).
- **PreToolUse(Bash)** → `block-global-pip.sh` (enforces env isolation: blocks global `pip install` outside a venv, `sudo pip`, and `npm install -g`).
- **PostToolUse(Edit|Write)** → `format-on-write.sh` (ruff/black, prettier, rustfmt, gofmt, shfmt).
- **SessionStart** → `session-briefing.sh` (branch, dirty count, recent commits).

> The same scripts also live under `templates/hooks/` so `install.sh` can drop **project-scoped** copies. If you use the plugin, you do not need the project-scoped copies; do not enable both for the same project or hooks fire twice.

### MCP server (Node, stdio, zero-dependency) — the "connector"
Registered via [`.mcp.json`](../.mcp.json) → `node ${CLAUDE_PLUGIN_ROOT}/mcp/index.mjs`. It implements the MCP stdio protocol by hand (no SDK), so it runs on plain Node with nothing installed. Tools take a project path, so they work against any repo and in any MCP client (Claude Code, Cursor, Windsurf).

| Tool | Purpose |
|---|---|
| `verify_result_claim` | Confirm a number appears in a project's results files (JSON/CSV/TXT). Refuses if absent. |
| `query_graph` | 1-hop subgraph lookup over a `nodes.jsonl` + `edges.jsonl` memory graph. |
| `memory_graph_add` | Append a node or edge (`depends_on`, `supersedes`, `decided_by`, ...) to the graph. |
| `placeholder_scan` | Find unfilled `<PLACEHOLDER>` markers in CLAUDE.md / CONTEXT.md. |
| resource `toolkit://principles` | Serves `docs/principles.md` to any client. |

A few techniques exist in **both** forms on purpose: the *skill* is the auto-routing in-chat UX; the *MCP tool* is the callable-from-anywhere primitive with structured I/O. Self-test the server with `node mcp/smoke-test.mjs`.

## Install (one-time, then live everywhere)

Use the **`claude plugin` CLI** in a terminal. It works everywhere, including IDE/VS Code extensions where the interactive `/plugin` slash command is unavailable. The source is `owner/repo` (not `github:owner/repo`):

```bash
claude plugin marketplace add Praneeth-496/claude-toolkit
claude plugin install claude-toolkit
```

It installs at **user scope, enabled by default**. **Restart the Claude Code session** so it loads; it is then live in **every** project. Verify in a terminal with `claude plugin list` (→ `claude-toolkit` enabled) and `claude plugin details claude-toolkit` (full inventory + token cost). After restart, inside the chat: `/mcp` shows the `claude-toolkit` server with 4 tools, and `/claude-toolkit:` lists the 30 skills. No `npm install`, no per-project setup.

> The `/plugin marketplace add …` slash command is an alternative that only works in the Claude Code terminal TUI. In bash it errors `No such file or directory`; in the VS Code extension it errors `/plugin isn't available in this environment`. Use the CLI above.

## Per new project (optional)

Inside the Claude Code chat, type `/toolkit-init` to drop `CLAUDE.md` / `CONTEXT.md` / `settings.local.json` templates, then fill placeholders.

## Updating

```bash
claude plugin marketplace update claude-toolkit-marketplace
```

To turn the plugin off/on in a terminal: `claude plugin disable claude-toolkit` / `claude plugin enable claude-toolkit`. (Don't paste the `disable` line by accident — it switches the plugin OFF.)

## Recommended companions (NOT bundled — install separately)

Independent plugins/MCP servers the toolkit deliberately does not vendor:
`claude-mem` (persistent memory), `cc10x` (workflow router), `octocode` (code research MCP), `context7` (live docs MCP), and for academic work `zotero` / `academic-mcp` / `paper-search`.

## Fallback: copy-installer (no plugin system)

`bash install.sh` still copies `skills-generic/*` into `~/.claude/skills/`, `agents/*` and `templates/hooks/*` into `./.claude/`, and the templates into `./.claude/`. Use the plugin **or** the installer, not both.
