# claude-toolkit

Portable Claude Code context files and skills. Copy this folder onto any machine and run `install.sh` to bootstrap a new project (work or personal) with the same 4-file pattern: **CLAUDE.md (Agents)**, **CONTEXT.md**, **Memory**, **Skills**.

## Layout

```
claude-toolkit/
├── README.md                      this file
├── install.sh                     copies templates + skills into a project / user scope
├── templates/
│   ├── CLAUDE.md.template         always-loaded project onboarding (≤150 lines target)
│   ├── CONTEXT.md.template        lazy-loaded heavier background
│   ├── settings.local.json.template  sane default permissions + deny list
│   └── gitignore-snippet.txt      lines to append to a project .gitignore
├── skills-generic/                drop into ~/.claude/skills/  — project-agnostic
│   ├── verify-result-claim/       grep-based numeric-claim verifier
│   ├── refresh-memory/            re-derive project memory from code state
│   ├── sync-rsync/                dry-run-first rsync to any remote
│   ├── submit-slurm/              pick freest partition; never auto-submits
│   └── run-pipeline/              chained script orchestrator with --dependency
├── skills-examples/               reference implementations; copy + adapt
│   └── update-thesis/             LaTeX em-dash guard + numeric verification
└── docs/
    ├── principles.md              token-saving habits, model routing, anti-patterns
    └── 4-file-pattern.md          mapping of video pattern → Claude Code primitives
```

## Quick start in a new project

```bash
cd /path/to/your/new/project
bash ~/Documents/claude-toolkit/install.sh
# Then edit .claude/CLAUDE.md and replace the <PLACEHOLDER> markers.
```

The installer:
1. Copies `templates/CLAUDE.md.template` → `./.claude/CLAUDE.md`
2. Copies `templates/CONTEXT.md.template` → `./.claude/CONTEXT.md`
3. Copies `templates/settings.local.json.template` → `./.claude/settings.local.json` (only if absent)
4. Appends `templates/gitignore-snippet.txt` to `./.gitignore` (skips if already present)
5. Copies `skills-generic/*` → `~/.claude/skills/` (user scope, not per-project)

User-scope skills are shared across all your projects. Project-specific skills can sit under `./.claude/skills/` and are copied manually from `skills-examples/`.

## Philosophy (short)

- **Tiny always-on surface.** CLAUDE.md stays ≤150 lines. Everything heavier is in CONTEXT.md, read on demand.
- **Skills do deterministic work with Bash.** Grep beats re-reading. A skill's LLM pass should be a thin wrapper around a pipeline of `grep`/`rsync`/`sbatch`, not a free-form reasoning dump.
- **Model routing: Opus for judgement, Sonnet for mechanical. Never Haiku.** Set `model:` in each SKILL.md frontmatter.
- **Verification before insertion.** Any number going into docs/thesis/memory must trace to a source file — `verify-result-claim` is the gate.
- **Memory is short and indexed.** `MEMORY.md` has one line per entry; bodies live in separate files. Truncation hits at line 200.

See [docs/principles.md](docs/principles.md) for the full list.

## Customising for a new project

The templates use `<ALL_CAPS_PLACEHOLDERS>` that you fill in after copying:
- `<PROJECT_NAME>`, `<ONE_LINE_PROJECT_DESCRIPTION>`
- `<WHAT_YOU_DO>`, `<DOMAIN>`
- `<HPC_HOST>` / `<REMOTE_PATH>` (delete the HPC section if not applicable)
- `<RESULTS_GLOB>` (e.g. `results/*.json`, `experiments/*/metrics.csv`)
- `<MAIN_BRANCH>` (usually `main` or `master`)

Grep the file after copying to find every remaining placeholder:
```bash
grep -n '<[A-Z_]*>' .claude/CLAUDE.md .claude/CONTEXT.md
```

## License

Personal toolkit, no formal licence. Use freely.
