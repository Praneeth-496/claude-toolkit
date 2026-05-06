#!/usr/bin/env bash
# install.sh — bootstrap a project with claude-toolkit files
#
# Usage:
#   cd /path/to/your/project
#   bash ~/Documents/claude-toolkit/install.sh           # fresh install (skips existing files)
#   bash ~/Documents/claude-toolkit/install.sh --update  # overwrite generic skills with newer toolkit copies
#   bash ~/Documents/claude-toolkit/install.sh --force   # overwrite project templates too (DESTRUCTIVE)
#
# Idempotent by default: skips files that already exist, appends .gitignore lines only if absent.

set -euo pipefail

MODE="install"
for arg in "$@"; do
  case "$arg" in
    --update) MODE="update" ;;
    --force)  MODE="force"  ;;
    -h|--help)
      sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown flag: $arg" >&2; exit 2 ;;
  esac
done

TOOLKIT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$(pwd)"

echo "Installing claude-toolkit into: $TARGET   (mode: $MODE)"
echo "Toolkit source: $TOOLKIT"
echo

# ── helpers ────────────────────────────────────────────────────────────────
copy_file() {
  # copy_file SRC DST [overwrite]
  local src="$1" dst="$2" overwrite="${3:-no}"
  if [[ -e "$dst" && "$overwrite" != "yes" ]]; then
    echo "  skip: $dst already exists"
    return
  fi
  cp "$src" "$dst"
  echo "  copy: $dst"
}

copy_dir() {
  # copy_dir SRC_DIR DST_DIR [overwrite]
  local src="$1" dst="$2" overwrite="${3:-no}"
  if [[ -e "$dst" && "$overwrite" != "yes" ]]; then
    echo "  skip: $dst already exists"
    return
  fi
  mkdir -p "$(dirname "$dst")"
  cp -r "$src" "$dst"
  echo "  copy: $dst"
}

# ── 1. Project-scope .claude/ files ─────────────────────────────────────────
mkdir -p "$TARGET/.claude" "$TARGET/.claude/hooks" "$TARGET/.claude/agents"

echo "[1/7] Project .claude/ templates"
TEMPLATE_OVERWRITE=no
[[ "$MODE" == "force" ]] && TEMPLATE_OVERWRITE=yes
copy_file "$TOOLKIT/templates/CLAUDE.md.template"           "$TARGET/.claude/CLAUDE.md"           "$TEMPLATE_OVERWRITE"
copy_file "$TOOLKIT/templates/CONTEXT.md.template"          "$TARGET/.claude/CONTEXT.md"          "$TEMPLATE_OVERWRITE"
copy_file "$TOOLKIT/templates/settings.local.json.template" "$TARGET/.claude/settings.local.json" "$TEMPLATE_OVERWRITE"
copy_file "$TOOLKIT/templates/statusline.sh"                "$TARGET/.claude/statusline.sh"       "$TEMPLATE_OVERWRITE"
chmod +x "$TARGET/.claude/statusline.sh" 2>/dev/null || true

# ── 2. Hooks (project-scope) ───────────────────────────────────────────────
echo "[2/7] Project hooks (.claude/hooks/)"
HOOK_OVERWRITE=no
[[ "$MODE" == "force" || "$MODE" == "update" ]] && HOOK_OVERWRITE=yes
for hook_src in "$TOOLKIT/templates/hooks"/*.sh; do
  [[ -f "$hook_src" ]] || continue
  hook_name="$(basename "$hook_src")"
  hook_dst="$TARGET/.claude/hooks/$hook_name"
  if [[ -e "$hook_dst" && "$HOOK_OVERWRITE" != "yes" ]]; then
    echo "  skip: $hook_dst already exists"
  else
    cp "$hook_src" "$hook_dst"
    chmod +x "$hook_dst"
    echo "  copy: $hook_dst"
  fi
done
copy_file "$TOOLKIT/templates/hooks/README.md" "$TARGET/.claude/hooks/README.md" "$HOOK_OVERWRITE"

# ── 3. Agents (project-scope, lazy: copy if not present) ───────────────────
echo "[3/7] Project agents (.claude/agents/)"
for agent_src in "$TOOLKIT/agents"/*.md; do
  [[ -f "$agent_src" ]] || continue
  agent_name="$(basename "$agent_src")"
  agent_dst="$TARGET/.claude/agents/$agent_name"
  if [[ -e "$agent_dst" && "$MODE" == "install" ]]; then
    echo "  skip: $agent_dst already exists (use --update to overwrite)"
    continue
  fi
  cp "$agent_src" "$agent_dst"
  echo "  copy: $agent_dst"
done

# ── 4. .gitignore snippet ──────────────────────────────────────────────────
echo "[4/7] .gitignore"
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

# ── 5. User-scope generic skills ────────────────────────────────────────────
echo "[5/7] User skills (~/.claude/skills/)"
mkdir -p "$HOME/.claude/skills"
for skill_dir in "$TOOLKIT/skills-generic"/*/; do
  name=$(basename "$skill_dir")
  dst="$HOME/.claude/skills/$name"
  if [[ -e "$dst" && "$MODE" == "install" ]]; then
    echo "  skip: ~/.claude/skills/$name already exists (use --update to overwrite)"
    continue
  fi
  if [[ -e "$dst" ]]; then
    rm -rf "$dst"
    cp -r "$skill_dir" "$dst"
    echo "  update: ~/.claude/skills/$name"
  else
    cp -r "$skill_dir" "$dst"
    echo "  copy: ~/.claude/skills/$name"
  fi
done

# ── 6. Version stamp ───────────────────────────────────────────────────────
echo "[6/7] Version stamp"
VERSION_FILE="$TOOLKIT/VERSION"
if [[ -f "$VERSION_FILE" ]]; then
  cp "$VERSION_FILE" "$HOME/.claude/skills/.claude-toolkit-version"
  echo "  recorded version: $(cat "$VERSION_FILE")"
else
  echo "  skip: no VERSION file in toolkit"
fi

# ── 7. Reminder to fill placeholders ────────────────────────────────────────
echo "[7/7] Next steps"
echo
PLACEHOLDER_RE='<[A-Z_][A-Z_]*>'
MISSING=0
for f in "$TARGET/.claude/CLAUDE.md" "$TARGET/.claude/CONTEXT.md"; do
  [[ -f "$f" ]] || continue
  n=$(grep -oE "$PLACEHOLDER_RE" "$f" | wc -l | tr -d ' ')
  MISSING=$((MISSING + n))
done
if [[ "$MISSING" -gt 0 ]]; then
  echo "  ! $MISSING placeholder(s) still need to be filled in:"
  echo "      grep -nE '$PLACEHOLDER_RE' $TARGET/.claude/CLAUDE.md $TARGET/.claude/CONTEXT.md"
else
  echo "  all placeholders already resolved."
fi
echo
echo "  Optional next steps:"
echo "    - copy templates/devcontainer/ to .devcontainer/ for a sandboxed workflow"
echo "    - copy templates/github-workflows/claude-pr-review.yml to .github/workflows/"
echo "    - install ccusage (npm i -g ccusage) for cost data in the statusline"
echo
echo "Done."
