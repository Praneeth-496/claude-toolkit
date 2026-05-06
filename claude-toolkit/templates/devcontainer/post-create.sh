#!/usr/bin/env bash
# Runs once after the devcontainer is built. Safe to fail; postCreate failures don't kill the container.
set -uo pipefail

echo "→ post-create: installing optional formatters used by toolkit hooks..."

# Python formatters (best-effort)
pip install --user --quiet ruff black 2>/dev/null || true

# JS formatters (best-effort)
npm install -g --silent prettier 2>/dev/null || true

# Shell formatter
if ! command -v shfmt >/dev/null 2>&1; then
  go install mvdan.cc/sh/v3/cmd/shfmt@latest 2>/dev/null || true
fi

# ccusage for the statusline (optional)
npm install -g --silent ccusage 2>/dev/null || true

echo "→ post-create: done. Run 'bash claude-toolkit/install.sh' to bootstrap project files."
