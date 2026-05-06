# Devcontainer template

A sandboxed VS Code devcontainer for running Claude Code with permissive flags (e.g. `--dangerously-skip-permissions`) without exposing the host machine.

## What's inside

- **Ubuntu 24.04** base
- **Claude Code** preinstalled via the official devcontainer feature
- **Node LTS, Python 3.12, gh CLI, git** preinstalled
- **No Docker socket mount** (the most common sandbox-escape vector)
- **No host SSH / AWS / GPG mounts** (no credential bleed)
- **Persistent volume** at `/home/vscode/.claude` so memory and skills survive container rebuilds

## Use

Copy `templates/devcontainer/` to `.devcontainer/` at your project root:

```bash
cp -r ~/Documents/claude-toolkit/claude-toolkit/templates/devcontainer .devcontainer
chmod +x .devcontainer/post-create.sh
```

Then in VS Code: **Reopen in Container** (or use GitHub Codespaces).

## Why use this?

Bypass mode (`claude --dangerously-skip-permissions`) is genuinely useful for long-running autonomous tasks but it's risky on the host. The container gives you:

1. Filesystem isolation — agent can't read `~/.ssh`, write to `/etc`, or scan your other repos.
2. Reproducible env — formatters, linters, ccusage, and Claude Code all preinstalled.
3. Network is allowed (so `npm install`, `pip install`, `gh` work) but nothing else.

## What this template deliberately does NOT do

- It does **not** mount your host Docker socket. If you need Docker inside, use docker-in-docker, never the host socket.
- It does **not** mount `~/.ssh`. Use a deploy key inside the container or a GitHub PAT in a Codespaces secret.
- It does **not** preinstall every language toolchain — add what you need via `features` in `devcontainer.json`.

References:
- https://code.claude.com/docs/en/devcontainer
- https://github.com/trailofbits/claude-code-devcontainer (a more hardened variant; consult for security audits / untrusted-code review work)
