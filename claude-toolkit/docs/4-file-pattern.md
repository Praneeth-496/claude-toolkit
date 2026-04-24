# The 4-File Pattern (and How It Maps to Claude Code)

Inspired by a video (https://youtube.com/shorts/ovLAIhbk3ek) describing a 4-file context system:

1. **Agents.md** — onboarding / voice / work style
2. **Context.md** — heavier nuanced background
3. **Memory.md** — auto-updating preferences
4. **Skills.md** — reusable workflows packaged from one-time walkthroughs

Claude Code already has native equivalents for all four. The toolkit does **not** create files literally named `Agents.md`/`Context.md`/`Memory.md`/`Skills.md` — it maps each role onto Claude Code's real primitives so the system actually loads them automatically.

## Mapping

| Video file | Claude Code primitive | Where the toolkit puts it |
|---|---|---|
| **Agents.md** | `CLAUDE.md` (project) — always loaded into context | `<project>/.claude/CLAUDE.md` |
| **Context.md** | `CONTEXT.md` (project) — lazy-loaded, referenced from CLAUDE.md | `<project>/.claude/CONTEXT.md` |
| **Memory.md** | auto-memory system — `MEMORY.md` index + per-topic `.md` files | `~/.claude/projects/<encoded-path>/memory/` |
| **Skills.md** | per-skill folders — each with a `SKILL.md` frontmatter file | `~/.claude/skills/<name>/SKILL.md` (user scope) or `<project>/.claude/skills/<name>/SKILL.md` (project scope) |

## Why this mapping

- **CLAUDE.md is auto-loaded every turn.** The video's "Agents.md" describes exactly this role, so we reuse the existing file rather than create a second always-loaded file.
- **CONTEXT.md is opened only when relevant.** Claude Code does not have a built-in "lazy background" file, but CLAUDE.md can link to one with a pointer ("heavier background: `.claude/CONTEXT.md`"), and Claude will open it on demand. This preserves the video's Context.md role without bloating the always-on surface.
- **Memory is auto-managed by Claude Code.** The harness writes to `~/.claude/projects/<path>/memory/` without explicit prompting when you tell it to "remember" things or when the conversation surfaces a lasting preference. `MEMORY.md` is an index (≤200 lines) and individual `.md` files hold the body. This is a richer implementation of the video's single Memory.md.
- **Skills are per-folder, not per-file.** Claude Code's skill system expects one folder per skill, with a `SKILL.md` that declares a `description:` (matcher text) and optional `model:` (routing). The video's monolithic Skills.md becomes one folder per reusable workflow — the benefit is each skill can be invoked independently by name or by the description matcher.

## Where the toolkit files go

### Project scope (bootstrap with `install.sh`)
```
<your-project>/
├── .claude/
│   ├── CLAUDE.md            ← from templates/CLAUDE.md.template
│   ├── CONTEXT.md           ← from templates/CONTEXT.md.template
│   └── settings.local.json  ← from templates/settings.local.json.template
└── .gitignore               ← appended with `.claude/` rule
```

### User scope (shared across all projects; copied by install.sh)
```
~/.claude/skills/
├── verify-result-claim/SKILL.md
├── refresh-memory/SKILL.md
├── sync-rsync/SKILL.md
├── submit-slurm/SKILL.md
└── run-pipeline/SKILL.md
```

### User scope (auto-managed by Claude itself, not by install.sh)
```
~/.claude/projects/<encoded-path>/memory/
├── MEMORY.md                ← index, auto-updated
├── project_<topic>.md       ← auto-updated
├── user_<topic>.md          ← auto-updated
└── feedback_<topic>.md      ← auto-updated
```

## When to add a new skill vs. edit CLAUDE.md

- **New skill** — a chore you do repeatedly with a concrete command sequence (rsync, submit, verify, regenerate). One-time walk Claude through it, then save as a SKILL.md for next time.
- **Edit CLAUDE.md** — a preference or rule that applies to every turn (response style, branch rule, don't-commit-without-asking). Short, stable, no sequence of commands.
- **Edit CONTEXT.md** — background needed only for some questions (dataset provenance, hardware quirks, calibration story). Heavy, referenced on demand.
- **Let memory handle it** — a fact that changes over time and that you've told Claude to remember ("I'm using Python 3.11 on this project", "the lab is switching to a new sniffer in May"). Let the auto-memory capture it; don't manually curate.
