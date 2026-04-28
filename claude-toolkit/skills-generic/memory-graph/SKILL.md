---
name: memory-graph
description: Build or extend a Graphiti-style knowledge graph (nodes + edges as JSONL) under the project's memory directory. Captures files, modules, concepts, decisions, and their relationships so future sessions can recall a 1-hop subgraph instead of re-reading flat memory snapshots. Modes; build (first run), add (incremental), rebuild (destructive). Project-agnostic; works on any git repo. TRIGGER when user says "build memory graph", "graph this project", "graphiti memory", "memory graph", or states a durable relationship worth remembering ("X depends on Y", "we superseded Z with W", "remember that A owns B", "decision: ..."). Also auto-trigger after `auto-memory` finishes on a project with ≥30 source files where no `graph/` directory exists yet — propose it before suggesting more flat snapshots.
model: opus
---

## When to use

- User says "build the memory graph", "graph this project", "memory-graph", "graphiti memory".
- Project is large enough that flat `project_*.md` snapshots are starting to lose signal — typically ≥30 source files, or ≥10 commits with real decisions.
- After running `auto-memory` on a fresh project (graph layer is complementary, not a replacement).
- User states a relationship worth remembering — "X depends on Y", "we superseded Z with W", "module A owns concept B" — invoke with `add`.

This skill is **the only writer** for `graph/`. `query-graph` is read-only.

## Locating the memory directory

Same encoder as `auto-memory` and `refresh-memory`:

```bash
CWD_ENCODED=$(pwd | sed 's/[^A-Za-z0-9]/-/g')
MEM_DIR="$HOME/.claude/projects/$CWD_ENCODED/memory"
GRAPH_DIR="$MEM_DIR/graph"
mkdir -p "$MEM_DIR"
```

If `~/.claude/projects/` already has a directory whose basename matches the project's encoded basename but the full path differs (encoder changed), prefer that existing directory.

## Modes

The skill takes one positional arg. Default is `build`.

```
memory-graph [build|add|rebuild]
```

---

### Mode: `build` (first run)

Refuse if `$GRAPH_DIR/nodes.jsonl` already exists — point user at `add` for incremental updates or `rebuild` for a destructive reset.

```bash
if [[ -f "$GRAPH_DIR/nodes.jsonl" ]]; then
  echo "graph/ already exists. Use 'memory-graph add' or 'memory-graph rebuild'." >&2
  exit 1
fi
mkdir -p "$GRAPH_DIR"
TODAY=$(date +%Y-%m-%d)
```

Run **all inventory greps in parallel** (capture into shell vars, do not Read whole files):

#### 1. File nodes (cap 200)

Prefer entry points and files mentioned in `.claude/CLAUDE.md` first, then top-level source files, then everything else up to the cap.

```bash
git ls-files 2>/dev/null \
  | grep -E '\.(py|js|jsx|ts|tsx|go|rs|java|rb|md|tex)$' \
  | head -200 > /tmp/mg_files.$$
```

For each path, emit one node line:

```bash
while read -r f; do
  base=$(basename "$f")
  ext="${base##*.}"
  jq -cn --arg id "file:$f" --arg name "$base" --arg path "$f" \
         --arg type "file" --arg ext "$ext" --arg today "$TODAY" \
    '{id:$id, type:$type, name:$name, path:$path, tags:[$ext], created:$today, summary:""}'
done < /tmp/mg_files.$$ >> "$GRAPH_DIR/nodes.jsonl"
```

Leave `summary` empty on first build — it is filled in by `add` or by user dictation later. Never invent a summary.

#### 2. Import edges (language-agnostic patterns)

```bash
# Python: "from x.y import" or "import x"
grep -rEn '^(from |import )' --include='*.py' . 2>/dev/null \
  | head -500 > /tmp/mg_imports_py.$$

# JS/TS: import / require
grep -rEn "^(import |const .* = require\()" --include='*.js' --include='*.ts' \
        --include='*.jsx' --include='*.tsx' . 2>/dev/null \
  | head -500 > /tmp/mg_imports_js.$$
```

Parse each line into a `(from, to)` pair. The `from` is the file containing the import; the `to` is the imported module path resolved against `git ls-files` when possible (skip the edge if the target is a stdlib or external dep). Cap total import edges at 400.

```bash
jq -cn --arg from "file:$FROM" --arg to "file:$TO" \
       --arg rel "imports" --arg today "$TODAY" \
  '{from:$from, to:$to, rel:$rel, valid_from:$today}' >> "$GRAPH_DIR/edges.jsonl"
```

#### 3. Concept nodes (from README + CONTEXT.md)

```bash
for src in README.md .claude/CONTEXT.md docs/*.md; do
  [[ -f "$src" ]] || continue
  grep -E '^## ' "$src" 2>/dev/null \
    | sed -E 's/^## +//' \
    | head -20
done | sort -u | head -30 > /tmp/mg_concepts.$$
```

For each heading, emit one concept node with id `concept:<slug>` (slug = lowercase, non-alnum → `-`).

#### 4. Decision + person nodes (from git log, capped 20)

```bash
git log -50 --pretty=format:'%H|%an|%ad|%s' --date=short 2>/dev/null \
  | grep -iE '^[^|]+\|[^|]+\|[^|]+\|(feat|fix|refactor|remove|deprecate|decide)|decided|supersede|replac' \
  | head -20 > /tmp/mg_decisions.$$
```

For each row, emit:
- one `decision:<short-hash>` node with `summary` = commit subject
- a `decided_by` edge to a `person:<author>` node (deduplicated)

#### 5. Write `graph_index.md` (≤80 lines)

```markdown
---
name: graph_index
description: Knowledge graph index for <project> — schema, counts, top entities. Refreshed <YYYY-MM-DD>.
type: project
---

## Knowledge graph (refreshed <YYYY-MM-DD>)

**Storage:** `graph/nodes.jsonl` (one JSON/line), `graph/edges.jsonl` (one JSON/line). Append-only by default.

**Counts:**
- nodes: <N> (file: <a>, concept: <b>, decision: <c>, person: <d>, dep: <e>)
- edges: <M> (imports: <i>, depends_on: <j>, supersedes: <k>, decided_by: <l>, ...)

**Top 10 most-connected nodes:**
1. <id> — <summary> (<degree> edges)
...

**How to query:** `query-graph <keyword>` returns matching nodes + 1-hop edges.

**How to extend:** `memory-graph add` after stating a new fact.
```

Compute counts and top-connected nodes with `jq`:

```bash
TOTAL_N=$(wc -l < "$GRAPH_DIR/nodes.jsonl")
TOTAL_E=$(wc -l < "$GRAPH_DIR/edges.jsonl")
# top 10 by degree (in + out)
{ jq -r '.from' "$GRAPH_DIR/edges.jsonl"; jq -r '.to' "$GRAPH_DIR/edges.jsonl"; } \
  | sort | uniq -c | sort -rn | head -10
```

#### 6. Optional graphviz export

If `dot` is on PATH, render a pruned `graph.dot` containing only nodes with degree ≥ 2:

```bash
command -v dot >/dev/null && {
  # write graph.dot then `dot -Tpng graph.dot -o graph.png` (skipped on headless)
  :
}
```

Skip silently if `dot` is missing.

#### 7. Update `MEMORY.md`

Append exactly one line, after checking it is not already there:

```bash
LINE="- [graph_index](graph/graph_index.md) — knowledge graph: $TOTAL_N nodes, $TOTAL_E edges"
grep -qF "graph/graph_index.md" "$MEM_DIR/MEMORY.md" 2>/dev/null \
  || echo "$LINE" >> "$MEM_DIR/MEMORY.md"
```

#### 8. Report

```
Built graph at <GRAPH_DIR>:
  nodes.jsonl: <N> entries
  edges.jsonl: <M> entries
  graph_index.md: <L> lines
MEMORY.md: appended index line.

Skipped: <reasons — e.g. "no git history", "no README", "dot not installed">
```

---

### Mode: `add` (incremental)

Triggered when the user states a new fact worth a node or edge. The skill expects context from the conversation — never invent a relationship.

1. Determine whether the fact is a **node**, an **edge**, or both.
2. Check `nodes.jsonl` for an existing matching id (`grep -F "\"id\":\"<candidate>\""`); if present, do not duplicate — only update `summary` via `jq` rewrite.
3. Append new lines through `jq -c .`:
   ```bash
   jq -cn --arg id "$ID" --arg type "$TYPE" --arg name "$NAME" \
          --arg summary "$SUM" --arg today "$(date +%Y-%m-%d)" \
     '{id:$id, type:$type, name:$name, summary:$summary, created:$today}' \
     >> "$GRAPH_DIR/nodes.jsonl"
   ```
4. If the new edge has `rel: "supersedes"`, also patch the target node's `superseded_by` field — this is the **only** sanctioned in-place rewrite of `nodes.jsonl`:
   ```bash
   tmp=$(mktemp)
   jq -c --arg target "$TARGET_ID" --arg by "$NEW_ID" \
     'if .id == $target then . + {superseded_by: $by} else . end' \
     "$GRAPH_DIR/nodes.jsonl" > "$tmp" && mv "$tmp" "$GRAPH_DIR/nodes.jsonl"
   ```
5. Re-derive the top-10 list in `graph_index.md` (only that block — leave the rest).
6. Print a one-line confirmation: `Added <kind>: <id>` (or `Added edge: <from> --[<rel>]--> <to>`).

---

### Mode: `rebuild` (destructive)

1. **Ask the user to confirm** — this is destructive. Do not proceed on a single instruction; require explicit "yes, rebuild".
2. Move existing `graph/` to `graph.bak-$(date +%Y%m%d-%H%M%S)/`.
3. Run the `build` flow from scratch.
4. Report which backup was created and the new counts.

---

## Hard rules

- **Never invent edges or summaries.** Every node and edge must trace to a `grep` / `git log` result, an existing memory file, or an explicit user statement in the current conversation.
- **Append-only by default.** `edges.jsonl` is never rewritten. `nodes.jsonl` is rewritten only by the `supersedes` patch in `add` and by `rebuild`.
- **One JSON per line.** Always pipe through `jq -c .` before appending — multi-line JSON breaks `query-graph`'s grep step.
- **Caps on `build`:** ≤200 file nodes, ≤30 concept nodes, ≤20 decision nodes, ≤500 import edges. If the project is bigger, prefer concept nodes over file nodes.
- **Date stamps.** Every node has `created`, every edge has `valid_from`. Use today's date; never back-date.
- **Skip user/feedback memory.** Like `auto-memory`, this skill writes only `project`/`reference`-shaped facts. User and feedback memories come from real conversations.
- **Cross-project safety.** Do not write outside `$MEM_DIR`. Do not delete anything outside `$GRAPH_DIR`.

## Anti-patterns

- Do not `Read` `nodes.jsonl` or `edges.jsonl` whole — they are designed for `grep` + `jq`. Reading them defeats the token-saving point.
- Do not run `build` silently as part of another skill's flow. It writes durable state; the user must invoke it.
- Do not back-fill summaries by guessing what a file does. Empty `summary` is fine — leave it for `add` or for the user to dictate.
- Do not create edges to external libraries (stdlib, npm packages) unless the user explicitly asks. The graph is for *project* relationships.
- Do not duplicate nodes already present in `nodes.jsonl`. Always grep for the id first.
