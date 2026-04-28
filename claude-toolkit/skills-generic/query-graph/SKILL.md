---
name: query-graph
description: Cheap keyword + jq lookup over the project's knowledge graph (`graph/nodes.jsonl` + `graph/edges.jsonl`); returns matching nodes plus their 1-hop edges as a compact markdown subgraph. Token-light recall layer — use this instead of re-reading flat memory snapshots whenever the question is about a specific file/concept/decision and a graph already exists for the project. TRIGGER when user asks "what depends on X", "what uses X", "who decided X", "what was superseded", "show me the X subgraph", "graph lookup", or any recall question that names a single entity. Auto-prefer this skill over reading project_*.md files when `graph/nodes.jsonl` exists in the project memory directory.
model: haiku
---

## When to use

- Any recall question scoped to one entity: "what depends on `auth.py`?", "what was the JWT decision?", "show me everything tagged `auth`".
- Before reading flat `project_*.md` snapshots — graph traversal is cheaper.
- As a precondition to other skills (`memory-graph add`, `refresh-memory`) so they know what already exists.

If `graph/nodes.jsonl` does not exist for this project, this skill prints a one-liner suggesting `memory-graph build` and exits — it never falls back to other memory layers.

## Locating the graph

```bash
CWD_ENCODED=$(pwd | sed 's/[^A-Za-z0-9]/-/g')
GRAPH_DIR="$HOME/.claude/projects/$CWD_ENCODED/memory/graph"
NODES="$GRAPH_DIR/nodes.jsonl"
EDGES="$GRAPH_DIR/edges.jsonl"

if [[ ! -f "$NODES" ]]; then
  echo "No graph at $GRAPH_DIR. Run 'memory-graph build' first." >&2
  exit 0
fi
```

## Query forms

The skill accepts one positional arg. Three forms:

| Form | Example | Behaviour |
|---|---|---|
| Plain keyword | `query-graph auth` | Case-insensitive grep over `name`, `summary`, `tags` of every node. |
| Typed filter | `query-graph type:decision jwt` | First filter by `type`, then grep remaining keywords. |
| Tag filter | `query-graph tag:auth` | Match exact tag in the node's `tags` array. |

## Steps

### 1. Find matching nodes (grep, never Read)

```bash
case "$QUERY" in
  type:*)
    T="${QUERY#type:}"; T="${T%% *}"; KW="${QUERY#* }"
    matches=$(grep -F "\"type\":\"$T\"" "$NODES" | grep -i "$KW")
    ;;
  tag:*)
    T="${QUERY#tag:}"
    matches=$(grep -F "\"$T\"" "$NODES")
    ;;
  *)
    matches=$(grep -i "$QUERY" "$NODES")
    ;;
esac
```

Cap matches at 20 — if more, ask the user to narrow the query rather than dumping a wall of text.

### 2. Pull 1-hop edges for matched node ids

```bash
ids=$(echo "$matches" | jq -r '.id')
edges=$(echo "$ids" | while read -r id; do
  [[ -z "$id" ]] && continue
  grep -F "\"$id\"" "$EDGES"
done | sort -u)
```

Cap edges at 30. If a node has more, prefer `supersedes`, `decided_by`, and `depends_on` over `imports`.

### 3. Format output (≤40 lines)

```markdown
## Subgraph for "<query>"

### Nodes (<N>)
- <id> — <summary> [<tags>]
  ...

### Edges (<M>)
- <from> --[<rel>]--> <to>  (<note if present>)
  ...

### Suggested next queries
- query-graph <related-tag-1>
- query-graph type:decision <related-keyword>
```

Sort nodes by type (decision, concept, file, person, dep) then alphabetically by id. Sort edges by `rel` (supersedes first, then decided_by, depends_on, imports last).

### 4. No-match path

If `matches` is empty:

```bash
# Surface closest nodes by tag overlap so the user can refine
all_tags=$(jq -r '.tags // [] | .[]' "$NODES" | sort -u)
echo "$all_tags" | grep -i "$QUERY" | head -5
```

Print: `No nodes match "<query>". Closest tags: a, b, c. Try: query-graph tag:<one>`.

## Hard rules

- **Read-only.** This skill never writes to `nodes.jsonl` or `edges.jsonl`. Mutations go through `memory-graph add`.
- **Grep / jq only.** Never `Read` the JSONL files whole — that defeats the entire token-saving purpose. If a question genuinely needs the full graph, point the user at `cat graph_index.md` and stop.
- **Cap output ≤40 lines.** If a subgraph is larger, list the top 20 nodes/edges by degree and tell the user to narrow with `type:` / `tag:`.
- **Sub-second.** All operations here are line-oriented `grep` + `jq`. If the call takes more than ~1 s, the graph has grown past its caps — recommend `memory-graph rebuild`.

## Anti-patterns

- Do not invoke this skill when the user is asking a broad "tell me about the project" question — that is `auto-memory`'s territory. Graph queries are for *specific entity* questions.
- Do not chain into `memory-graph add` automatically. Reading and writing are separate; the user should approve writes.
- Do not include nodes that only appear as the target of a single `imports` edge with no other relationships — they add noise.
- Do not reformat the JSONL — leave it as the authoritative store.
