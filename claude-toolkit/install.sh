#!/usr/bin/env bash
# install.sh — bootstrap a project with claude-toolkit files
#
# Usage: run from the root of the target project.
#   cd /path/to/your/project
#   bash ~/Documents/claude-toolkit/install.sh
#
# Idempotent: skips files that already exist, appends .gitignore lines only if absent.

set -euo pipefail

TOOLKIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$(pwd)"

echo "Installing claude-toolkit into: $TARGET"
echo "Toolkit source: $TOOLKIT"
echo

# ── 1. Project-scope .claude/ files ─────────────────────────────────────────
mkdir -p "$TARGET/.claude"

copy_if_absent() {
  local src="$1" dst="$2"
  if [[ -e "$dst" ]]; then
    echo "  skip: $dst already exists"
  else
    cp "$src" "$dst"
    echo "  copy: $dst"
  fi
}

echo "[1/4] Project .claude/ templates"
copy_if_absent "$TOOLKIT/templates/CLAUDE.md.template"         "$TARGET/.claude/CLAUDE.md"
copy_if_absent "$TOOLKIT/templates/CONTEXT.md.template"        "$TARGET/.claude/CONTEXT.md"
copy_if_absent "$TOOLKIT/templates/settings.local.json.template" "$TARGET/.claude/settings.local.json"

# ── 2. .gitignore snippet ───────────────────────────────────────────────────
echo "[2/4] .gitignore"
SNIPPET_MARKER="# claude-toolkit managed"
if [[ -f "$TARGET/.gitignore" ]] && grep -qF "$SNIPPET_MARKER" "$TARGET/.gitignore"; then
  echo "  skip: snippet already present in .gitignore"
else
  {
    echo ""
    echo "$SNIPPET_MARKER"
    cat "$TOOLKIT/templates/gitignore-snippet.txt"
  } >> "$TARGET/.gitignore"
  echo "  append: added snippet to $TARGET/.gitignore"
fi

# ── 3. User-scope generic skills ────────────────────────────────────────────
echo "[3/4] User skills (~/.claude/skills/)"
mkdir -p "$HOME/.claude/skills"
for skill_dir in "$TOOLKIT/skills-generic"/*/; do
  name=$(basename "$skill_dir")
  dst="$HOME/.claude/skills/$name"
  if [[ -e "$dst" ]]; then
    echo "  skip: ~/.claude/skills/$name already exists"
  else
    cp -r "$skill_dir" "$dst"
    echo "  copy: ~/.claude/skills/$name"
  fi
done

# ── 4. Reminder to fill placeholders ────────────────────────────────────────
echo "[4/4] Next steps"
echo
if [[ -f "$TARGET/.claude/CLAUDE.md" ]]; then
  MISSING=$(grep -c '<[A-Z_][A-Z_]*>' "$TARGET/.claude/CLAUDE.md" "$TARGET/.claude/CONTEXT.md" 2>/dev/null | awk -F: '{s+=$2} END {print s}')
  if [[ "${MISSING:-0}" -gt 0 ]]; then
    echo "  ! $MISSING placeholder(s) still need to be filled in:"
    echo "      grep -n '<[A-Z_]*>' $TARGET/.claude/CLAUDE.md $TARGET/.claude/CONTEXT.md"
  else
    echo "  all placeholders already resolved."
  fi
fi
echo
echo "Done."
