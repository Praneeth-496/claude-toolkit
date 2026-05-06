# claude-toolkit

Portable Claude Code context, skills, and guard rails. Drop the [`claude-toolkit/`](claude-toolkit/) folder onto any machine, run [`install.sh`](claude-toolkit/install.sh) in a project, and that project gets the same disciplined setup: a tiny always-loaded `CLAUDE.md`, a lazy-loaded `CONTEXT.md`, sane permissions, and a curated set of user-scope skills.

**Current version:** see [`claude-toolkit/VERSION`](claude-toolkit/VERSION).

---

## Quick start (any project)

```bash
# 1. Clone the toolkit somewhere stable (one-time)
git clone <this-repo> ~/Documents/claude-toolkit

# 2. Bootstrap a project
cd /path/to/your/project
bash ~/Documents/claude-toolkit/claude-toolkit/install.sh
# Note: auto mode is enabled by default (requires Team/Enterprise/API plan).
# Disable: remove "defaultMode":"auto" from .claude/settings.local.json

# 3. Fill in the placeholders the installer flagged
grep -nE '<[A-Z_]+>' .claude/CLAUDE.md .claude/CONTEXT.md

# 4. (Optional) Let Claude bootstrap project memory by scanning the repo
#    Open Claude Code in the project and say: "run auto-memory"
```

That's it. Claude Code will pick up `.claude/CLAUDE.md` on the next session and the user-scope skills are now available in every project.

### Re-running the installer

```bash
bash ~/Documents/claude-toolkit/claude-toolkit/install.sh           # safe: skips files that already exist
bash ~/Documents/claude-toolkit/claude-toolkit/install.sh --update  # overwrite generic skills with newer toolkit copies (templates left alone)
bash ~/Documents/claude-toolkit/claude-toolkit/install.sh --force   # also overwrite project templates (DESTRUCTIVE — backs nothing up)
```

The default mode is idempotent: safe to re-run any time.

---

## Layout

```
claude-toolkit/
├── README.md                         this file
├── claude-toolkit/
│   ├── VERSION                       toolkit version (stamped into ~/.claude/skills/.claude-toolkit-version on install)
│   ├── install.sh                    bootstrap script (idempotent; --update / --force)
│   ├── .claude-plugin/
│   │   ├── plugin.json               Claude Code plugin manifest (for /plugin install)
│   │   └── marketplace.json          marketplace entry pointing back at this repo
│   ├── agents/                       project-scope subagents installed to .claude/agents/
│   │   ├── code-reviewer.md          strict diff review (sonnet, read-only)
│   │   ├── security-auditor.md       OWASP-style security pass on diff (sonnet, read-only)
│   │   ├── test-runner.md            detects + runs project's test command (sonnet)
│   │   ├── simplifier.md             flags dead code, single-use abstractions (sonnet, read-only)
│   │   ├── adversary.md              steelman the opposite of the proposed change (opus)
│   │   ├── doc-writer.md             updates docs to match a code change (sonnet, docs-only)
│   │   ├── fact-checker.md           verifies individual claims (paths, symbols, numbers, signatures) against the repo (sonnet, read-only)
│   │   └── flow-auditor.md           verifies the *reasoning chain* between claims (catches unsupported leaps) (opus, read-only)
│   ├── templates/
│   │   ├── CLAUDE.md.template        always-loaded project onboarding (≤150 lines target)
│   │   ├── CONTEXT.md.template       lazy-loaded heavier background
│   │   ├── settings.local.json.template   permissions + deny list + hooks + statusline
│   │   ├── statusline.sh             toolkit statusline: branch | dirty | model | cost (ccusage)
│   │   ├── gitignore-snippet.txt     lines appended to a project .gitignore
│   │   ├── hooks/                    deterministic guardrails (29 events at code.claude.com/docs/en/hooks)
│   │   │   ├── block-dangerous-bash.sh    PreToolUse(Bash): block force-push, rm -rf /, fork bombs, etc.
│   │   │   ├── format-on-write.sh         PostToolUse(Edit|Write): run ruff/prettier/rustfmt etc.
│   │   │   ├── session-briefing.sh        SessionStart: inject git briefing
│   │   │   ├── pre-compact-briefing.sh    PreCompact: snapshot session state
│   │   │   └── post-compact-restore.sh    PostCompact: re-inject snapshot
│   │   ├── devcontainer/             sandboxed VS Code devcontainer for bypass-mode work
│   │   │   ├── devcontainer.json     Ubuntu 24.04 + Claude Code, no Docker socket / SSH mounts
│   │   │   └── post-create.sh        installs ruff/prettier/shfmt/ccusage
│   │   └── github-workflows/         drop into .github/workflows/
│   │       └── claude-pr-review.yml  anthropics/claude-code-action@v1 on PRs + @claude mentions
│   ├── skills-generic/               drop into ~/.claude/skills/ — project-agnostic
│   │   ├── auto-memory/              scan a fresh repo and seed project memory automatically
│   │   ├── council/                  convene 4 Claude personas on a high-stakes decision
│   │   ├── orchestrate/              operator pattern: decompose → dispatch specialists → synthesize
│   │   ├── pr-prep/                  stage + test + security + draft PR title/body (stops before push)
│   │   ├── verify-result-claim/      grep-based numeric-claim verifier
│   │   ├── refresh-memory/           re-derive project memory from current code state
│   │   ├── sync-rsync/               dry-run-first rsync to any remote
│   │   ├── submit-slurm/             pick freest SLURM partition; never auto-submits
│   │   ├── run-pipeline/             chained script orchestrator with --dependency=afterok
│   │   ├── memory-graph/             build/extend a JSONL knowledge graph (Graphiti-style) under memory/
│   │   └── query-graph/              cheap grep+jq lookup of the graph; returns 1-hop subgraph
│   ├── skills-examples/              reference implementations; copy + adapt
│   │   └── edit-doc-strict/          style-guard + numeric-verification editing pattern
│   └── docs/
│       ├── principles.md             token-saving habits, model routing, anti-patterns
│       └── 4-file-pattern.md         CLAUDE.md / CONTEXT.md / Memory / Skills mapping
```

---

## What the installer does

1. Copies `templates/CLAUDE.md.template` → `./.claude/CLAUDE.md` *(skip if exists, unless `--force`)*
2. Copies `templates/CONTEXT.md.template` → `./.claude/CONTEXT.md`
3. Copies `templates/settings.local.json.template` → `./.claude/settings.local.json`
4. Copies `templates/statusline.sh` → `./.claude/statusline.sh` (chmod +x)
5. Copies `templates/hooks/*.sh` → `./.claude/hooks/` (chmod +x; `--update` overwrites)
6. Copies `agents/*.md` → `./.claude/agents/` (project-scope subagents)
7. Appends `templates/gitignore-snippet.txt` to `./.gitignore` (skipped if already present)
8. Copies `skills-generic/*` → `~/.claude/skills/` (user scope; `--update` overwrites)
9. Stamps the toolkit version into `~/.claude/skills/.claude-toolkit-version`
10. Counts unfilled `<PLACEHOLDER>` markers and prints next-step hints

User-scope skills (`~/.claude/skills/`) are shared across every project. Project-scope agents and hooks live under `./.claude/` and travel with the repo.

### Optional add-ons (manual copy)

```bash
# Sandboxed devcontainer (recommended for bypass-mode / autonomous runs)
cp -r ~/Documents/claude-toolkit/claude-toolkit/templates/devcontainer .devcontainer

# GitHub Actions PR review
mkdir -p .github/workflows
cp ~/Documents/claude-toolkit/claude-toolkit/templates/github-workflows/claude-pr-review.yml .github/workflows/
gh secret set ANTHROPIC_API_KEY

# Cost data in the statusline
npm install -g ccusage
```

### Plugin install (alternative to install.sh)

The toolkit ships a `.claude-plugin/plugin.json` manifest, so it can also be installed via Claude Code's native plugin system:

```
/plugin marketplace add github:Praneeth-496/claude-toolkit
/plugin install claude-toolkit
```

Plugin install gives namespaced skills (`/claude-toolkit:auto-memory`) and version-pinned updates; `install.sh` gives unprefixed skills and direct file ownership. Pick one — running both will fight for the same skill names.

---

## Skills bundled in `skills-generic/`

| Skill | Model | What it does |
|---|---|---|
| `auto-memory` | opus | First-run scan of the repo to seed `project_*` and `reference_*` memories. Run once on a fresh project, or after major refactors. |
| `council` | opus | Spawns 4 parallel Claude personas (architect, reviewer, simplifier, adversary) on one decision. Persists synthesis to `.claude/council/`. Use only for high-stakes one-shot calls. |
| `refresh-memory` | sonnet | Re-derives stale `project_*` memory snapshots from current code state. Finer-grained than `auto-memory`. |
| `verify-result-claim` | sonnet | Grep-checks a numeric claim against the project's declared results glob (JSON/CSV). Refuses unverified numbers. |
| `sync-rsync` | sonnet | Dry-run-first rsync to a remote (HPC / dev server). Excludes `settings.local.json` and large binaries. |
| `submit-slurm` | sonnet | Reads `sinfo`/`squeue`, picks the freest matching partition, prints the `sbatch` command. Never submits. |
| `run-pipeline` | opus | Chains shell scripts as `sbatch --dependency=afterok` jobs (or sequential bash locally). Awaits user approval. |
| `memory-graph` | opus | Builds / extends a Graphiti-style knowledge graph (`graph/nodes.jsonl` + `edges.jsonl`) under the project's memory dir. Modes: `build`, `add`, `rebuild`. Auto-triggers on phrases like "X depends on Y", "we superseded Z with W", or "remember the decision about …". |
| `query-graph` | haiku | Cheap keyword + `jq` lookup over the graph; returns a 1-hop subgraph as compact markdown. Token-light recall layer — auto-preferred over re-reading flat `project_*.md` snapshots whenever a graph exists. |
| `orchestrate` | opus | Operator/orchestrator pattern. Decomposes a task, dispatches specialists (`code-reviewer`, `security-auditor`, `test-runner`, `simplifier`, `doc-writer`, `adversary`) in parallel/sequence, synthesizes one consolidated result. |
| `pr-prep` | sonnet | End-to-end PR prep: snapshot diff, run tests via `test-runner`, security pass via `security-auditor`, match the project's house style by reading recent merged PRs, draft title + body. **Stops before push.** |

`skills-examples/edit-doc-strict/` is a reference pattern — not auto-installed. Copy and adapt it when a single document (thesis, spec, RFC, release notes) needs hard style/correctness rules.

## Project-scope agents (installed to `.claude/agents/`)

Six specialist subagents are checked into every project on install. Use them via `Task` tool (Claude routes by description) or invoke explicitly: "use the code-reviewer agent on this diff".

| Agent | Model | Tools | Purpose |
|---|---|---|---|
| `code-reviewer` | sonnet | read-only | Diff review with severity grouping (Blocker / Should-fix / Nit) |
| `security-auditor` | sonnet | read-only | OWASP-style audit on changed lines |
| `test-runner` | sonnet | bash + read | Detects test command (Make/npm/pytest/cargo/go), runs, summarizes failures |
| `simplifier` | sonnet | read-only | Flags dead code, single-use helpers, premature generalisation |
| `adversary` | opus | read-only | Steelmans the opposite of the proposed change |
| `doc-writer` | sonnet | edit (docs only) | Updates docstrings, README, CHANGELOG to match a code change |
| `fact-checker` | sonnet | read-only | Verifies individual factual claims (paths, symbols, line numbers, numbers, API signatures, commit hashes, citations) against the repo. Returns VERIFIED / UNVERIFIED / FALSE per claim. Verdict: ship / revise / reject. |
| `flow-auditor` | opus | read-only | Verifies the *reasoning chain* between claims: does each conclusion follow from the evidence cited? Catches OVERREACH, UNSUPPORTED leaps, and CONTRADICTED steps. Returns: accept / re-run-failing-steps / discard-chain. |

The `orchestrate` skill knows about these and dispatches them as a team. The `pr-prep` skill chains `test-runner` + `security-auditor`. Use them individually for narrow tasks, or via `orchestrate` for cross-cutting reviews.

## Hooks (installed to `.claude/hooks/`)

Five hooks ship enabled by default — deterministic guardrails that beat permission prompts. Disable any by deleting its block in `settings.local.json`; the script can stay on disk.

| Hook | Event | What it does |
|---|---|---|
| `block-dangerous-bash.sh` | `PreToolUse(Bash)` | Hard-blocks `git push --force`, `rm -rf /`, `chmod 777`, fork bombs, `dd of=/dev/sd*`, `curl … \| sh` patterns |
| `format-on-write.sh` | `PostToolUse(Edit\|Write)` | Best-effort formatter run (ruff/black/prettier/rustfmt/gofmt/shfmt) on modified files |
| `session-briefing.sh` | `SessionStart` | Injects branch + dirty-file count + last 5 commits as session context |
| `pre-compact-briefing.sh` | `PreCompact` | Snapshots state to `.claude/_compact_briefing.md` before auto-compact |
| `post-compact-restore.sh` | `PostCompact` | Re-injects the snapshot into the new (compacted) context window |

Full list of available hook events (29 total): https://code.claude.com/docs/en/hooks

---

## Philosophy (short)

- **Tiny always-on surface.** `CLAUDE.md` stays ≤150 lines. Heavier context lives in `CONTEXT.md`, read on demand.
- **Skills do deterministic work with Bash.** `grep` beats re-reading. A skill's LLM pass should be a thin wrapper around `grep` / `rsync` / `sbatch`, not a free-form reasoning dump.
- **Model routing.** Opus for judgement and council synthesis, Sonnet for mechanical work, Haiku 4.5 for trivial deterministic glue. Set `model:` in each `SKILL.md` frontmatter.
- **Verification before insertion.** Numbers going into docs/memory must trace to a source file — `verify-result-claim` is the gate.
- **Memory is short and indexed.** `MEMORY.md` has one line per entry; bodies live in separate files. Truncation hits at line 200, so keep the index lean.
- **Graph memory for larger projects.** Past a few thousand lines, prefer `memory-graph` + `query-graph` over flat snapshots. Edges (`depends_on`, `imports`, `supersedes`, `decided_by`) make recall ≥10× cheaper than re-reading `project_*.md` files, and `supersedes` makes stale facts auto-flag instead of silently overwrite.
- **Skills auto-route, no slash needed.** The agent reads each skill's `description:` / TRIGGER phrases and invokes proactively when the user's intent matches — `/memory-graph add` is a fallback, not the primary path. See [`skill auto-routing`](claude-toolkit/docs/principles.md#skill-auto-routing-dont-wait-for-slash-commands).
- **No static output-token cap.** `CLAUDE_CODE_MAX_OUTPUT_TOKENS` is intentionally unset — long edits and reviews use the model's full per-response budget. The agent already runs across as many responses as the task needs.
- **Confirm before destructive actions.** `git commit`, `git push`, `git reset --hard`, recursive `rm`, and `sudo` are all in the deny list.
- **Auto mode on by default (Sonnet + Opus).** `settings.local.json` sets `"defaultMode": "auto"` so every bootstrapped project runs autonomously without permission prompts for every tool call. Requires Claude Code v2.1.83+ and a Team/Enterprise/API plan. Disable by removing the key or pressing `Shift+Tab` mid-session.

See [`claude-toolkit/docs/principles.md`](claude-toolkit/docs/principles.md) for the full list and [`claude-toolkit/docs/4-file-pattern.md`](claude-toolkit/docs/4-file-pattern.md) for the layout rationale.

---

## Customising for a new project

The templates use `<ALL_CAPS_PLACEHOLDERS>`. Common ones:

- `<PROJECT_NAME>`, `<ONE_PARAGRAPH_PROJECT_DESCRIPTION>`
- `<ROLE_AND_AFFILIATION>`, `<DOMAIN_FOCUS>`
- `<HPC_HOST>`, `<REMOTE_PATH>` *(delete the HPC section if not applicable)*
- `<RESULTS_GLOB>` (e.g. `results/*.json`, `experiments/*/metrics.csv`)
- `<MAIN_BRANCH>` (usually `main` or `master`)
- `<TOOLKIT_PATH>` (e.g. `~/Documents/claude-toolkit/claude-toolkit`)
- `<AUTO_MEMORY_DIR>` — the encoded project path under `~/.claude/projects/` (run `pwd | sed 's/[^A-Za-z0-9]/-/g'` to compute it)

Find every remaining placeholder after copying:

```bash
grep -nE '<[A-Z_]+>' .claude/CLAUDE.md .claude/CONTEXT.md
```

---

## Council vs. external multi-agent tools

The bundled `council` skill is **Claude-only** (4 personas, varied prompts and models, ~30–60s, zero extra deps). It is the right tool for most "stop and think" decisions inside this toolkit.

If you genuinely need *cross-vendor* model diversity (e.g. you're choosing between AI providers themselves), the third-party [`agent-council`](https://github.com/yogirk/agent-council) shells out to Codex CLI and Gemini CLI. It needs those CLIs installed and authenticated, takes longer, and overlaps with Claude Code's first-party `/ultrareview` for PR-style reviews.

Rule of thumb: bundled `council` for design questions, `/ultrareview` for branch reviews, external `agent-council` only when the decision is specifically about non-Claude models.

---

## What changed in 0.4.1

Two new agents that close the integrity gap. Together they make orchestrate runs trustworthy at scale.

- **New agent: `fact-checker`** (sonnet, read-only). Verifies every concrete factual claim in another agent's output: file paths, function/symbol names, line citations, numeric results, API signatures, library presence, commit hashes, citations. Three buckets per claim — VERIFIED / UNVERIFIED / FALSE — with verbatim quotes and exact evidence (`grep`, `git show`, `jq` over JSON). Verdict: ship / revise / reject. A single FALSE on a load-bearing claim is enough to reject.
- **New agent: `flow-auditor`** (opus, read-only). Audits the *reasoning chain* — what `fact-checker` doesn't see. Numbers each step in a chain, identifies the load-bearing path, classifies dependencies as GROUNDED / OVERREACH / UNSUPPORTED / CONTRADICTED. Catches the case where every individual claim is true but the conclusion doesn't follow. Verdict: accept / re-run-failing-steps / discard-chain.
- **`orchestrate` skill updated** to make `fact-checker` + `flow-auditor` the verification pair after any flow with ≥3 specialist outputs. Persists to `.claude/orchestrate/last-run.md` so both checkers can re-read it. If either returns a reject verdict, the orchestrate result is marked BLOCKED.
- **Plugin manifest version bumped** to 0.4.1 in `.claude-plugin/plugin.json`.
- Complements `verify-result-claim` (the gate for numeric claims going into docs). `fact-checker` is the broader gate; `flow-auditor` is the cross-cutting one.

---

## What changed in 0.4.0

Verified against the official Claude Code docs ([hooks](https://code.claude.com/docs/en/hooks), [plugins](https://code.claude.com/docs/en/plugins), [sub-agents](https://code.claude.com/docs/en/sub-agents), [agent-teams](https://code.claude.com/docs/en/agent-teams)) before shipping.

- **Hooks layer.** Five hook scripts under `templates/hooks/` wired into the `settings.local.json` template: `PreToolUse(Bash)` blocks dangerous commands; `PostToolUse(Edit|Write)` runs the project's formatter; `SessionStart` injects a git briefing; `PreCompact` / `PostCompact` make session state survive auto-compaction.
- **Plugin manifest.** `.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json`. The toolkit now installs via `/plugin install claude-toolkit` in addition to `install.sh`.
- **Six project-scope agents.** `agents/{code-reviewer,security-auditor,test-runner,simplifier,adversary,doc-writer}.md`. Installed to `.claude/agents/` and dispatched by the new `orchestrate` skill.
- **New skill: `orchestrate`.** Operator pattern. Decomposes a task, dispatches the right specialist agents in parallel/sequence, synthesizes one consolidated result. Replaces ad-hoc "run reviewer then run tests then update docs" sequences.
- **New skill: `pr-prep`.** Stage → test → security → match house style → draft PR title/body. Stops before push.
- **Statusline.** `templates/statusline.sh` — branch, dirty count, model, optional ccusage cost block. Wired into the settings template.
- **Devcontainer template.** `templates/devcontainer/` — sandboxed VS Code container for `--dangerously-skip-permissions` work. No Docker socket, no SSH/AWS mounts, persistent volume for `~/.claude`.
- **GitHub Actions template.** `templates/github-workflows/claude-pr-review.yml` using `anthropics/claude-code-action@v1`. Runs on PR open and `@claude` comments.
- **Permissions widened.** Added `git worktree*` to allow list (for the new worktree-aware patterns); added `docs.claude.com` and `code.claude.com` to allowed `WebFetch` domains.

---

## What changed in 0.3.0

- **New skill: `memory-graph`** — builds and extends a Graphiti-style JSONL knowledge graph (`graph/nodes.jsonl` + `graph/edges.jsonl`) inside the per-project memory directory. Captures files, modules, concepts, decisions, and people, plus typed relationships (`imports`, `depends_on`, `supersedes`, `decided_by`, `references`). Project-agnostic — works on any git repo.
- **New skill: `query-graph`** — cheap `grep` + `jq` lookup that returns matching nodes plus their 1-hop edges as a ≤40-line markdown subgraph. Replaces re-reading flat `project_*.md` snapshots for entity-scoped recall questions.
- **Skill auto-routing documented.** New section in `docs/principles.md` and the `CLAUDE.md.template` instruct the agent to scan available skills' `description:` / TRIGGER phrases on every non-trivial turn and invoke proactively, instead of waiting for the user to type `/skillname`.
- **`auto-memory`** cross-links to `memory-graph` so larger projects get the relationship graph after the flat snapshot.
- **No `install.sh` change required.** The install loop already iterates every directory in `skills-generic/`; the two new skill folders are picked up automatically.

---

## What changed in 0.2.0

- **New skill: `auto-memory`** — scans a fresh repo and seeds project memory without user input.
- **New skill: `council`** — 4-persona Claude council for high-stakes decisions, persists to `.claude/council/`.
- **`install.sh`** — added `--update` and `--force` flags, fixed placeholder counter, added VERSION stamp.
- **`refresh-memory`** — fixed path-encoding bug (was `sed 's|/|-|g'`, missed dots/underscores).
- **`settings.local.json`** — removed static `CLAUDE_CODE_MAX_OUTPUT_TOKENS=8000` cap; widened `rm` deny patterns; moved `git commit` from allow → deny to match the documented rule.
- **`sync-rsync`** — excludes `settings.local.json` from remote sync (machine-specific).
- **`skills-examples/edit-doc-strict/`** — renamed from `update-thesis`; rewritten as a domain-agnostic style-guard + numeric-verification pattern.
- **Haiku rule relaxed.** Haiku 4.5 (Jan 2026) is now allowed for trivial deterministic skills; still avoided for anything needing judgement.

---

## License

Personal toolkit, no formal licence. Use freely.
