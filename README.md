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
│   ├── templates/
│   │   ├── CLAUDE.md.template        always-loaded project onboarding (≤150 lines target)
│   │   ├── CONTEXT.md.template       lazy-loaded heavier background
│   │   ├── settings.local.json.template   permissions + deny list (no static token cap)
│   │   └── gitignore-snippet.txt     lines appended to a project .gitignore
│   ├── skills-generic/               drop into ~/.claude/skills/ — project-agnostic
│   │   ├── auto-memory/              scan a fresh repo and seed project memory automatically
│   │   ├── council/                  convene 4 Claude personas on a high-stakes decision
│   │   ├── verify-result-claim/      grep-based numeric-claim verifier
│   │   ├── refresh-memory/           re-derive project memory from current code state
│   │   ├── sync-rsync/               dry-run-first rsync to any remote
│   │   ├── submit-slurm/             pick freest SLURM partition; never auto-submits
│   │   └── run-pipeline/             chained script orchestrator with --dependency=afterok
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
4. Appends `templates/gitignore-snippet.txt` to `./.gitignore` (skipped if already present, marker-detected)
5. Copies `skills-generic/*` → `~/.claude/skills/` (user scope; `--update` overwrites)
6. Stamps the toolkit version into `~/.claude/skills/.claude-toolkit-version`
7. Counts unfilled `<PLACEHOLDER>` markers in your new `CLAUDE.md` / `CONTEXT.md` and prints the grep command to find them

User-scope skills (`~/.claude/skills/`) are shared across every project. Project-specific skills can sit under `./.claude/skills/` — copy them manually from `skills-examples/`.

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

`skills-examples/edit-doc-strict/` is a reference pattern — not auto-installed. Copy and adapt it when a single document (thesis, spec, RFC, release notes) needs hard style/correctness rules.

---

## Philosophy (short)

- **Tiny always-on surface.** `CLAUDE.md` stays ≤150 lines. Heavier context lives in `CONTEXT.md`, read on demand.
- **Skills do deterministic work with Bash.** `grep` beats re-reading. A skill's LLM pass should be a thin wrapper around `grep` / `rsync` / `sbatch`, not a free-form reasoning dump.
- **Model routing.** Opus for judgement and council synthesis, Sonnet for mechanical work, Haiku 4.5 for trivial deterministic glue. Set `model:` in each `SKILL.md` frontmatter.
- **Verification before insertion.** Numbers going into docs/memory must trace to a source file — `verify-result-claim` is the gate.
- **Memory is short and indexed.** `MEMORY.md` has one line per entry; bodies live in separate files. Truncation hits at line 200, so keep the index lean.
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
