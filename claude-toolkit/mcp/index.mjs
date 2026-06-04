#!/usr/bin/env node
// claude-toolkit MCP server (stdio) — ZERO dependencies.
//
// Implements the MCP stdio transport (newline-delimited JSON-RPC 2.0) by hand so the
// plugin runs with nothing but Node installed — no `npm install` in the plugin cache,
// which matters because this plugin is installed from GitHub via /plugin install.
//
// Exposes the toolkit's deterministic techniques as callable tools (usable from Claude
// Code OR any MCP client, against any project by passing a path). The same logic also
// ships as auto-routing skills; these tools are the callable-anywhere primitives.
//
// Tools:    verify_result_claim, query_graph, memory_graph_add, placeholder_scan
// Resource: toolkit://principles  (serves docs/principles.md)

import {
  readFileSync, readdirSync, existsSync, mkdirSync, appendFileSync,
} from "node:fs";
import { join, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const PLUGIN_ROOT = resolve(HERE, "..");
const SERVER = { name: "claude-toolkit", version: "0.5.0" };
const PROTOCOL_VERSION = "2025-06-18";

const SKIP_DIRS = new Set([
  "node_modules", ".git", "dist", "build", ".next", ".venv", "venv",
  "__pycache__", ".cache", "coverage", ".pytest_cache", ".mypy_cache", "site-packages",
]);

// ---- shared helpers --------------------------------------------------------

function walkFiles(root, { exts, maxFiles = 4000, maxDepth = 12 } = {}) {
  const out = [];
  const extSet = exts ? new Set(exts.map((e) => e.replace(/^\./, "").toLowerCase())) : null;
  const stack = [[root, 0]];
  while (stack.length && out.length < maxFiles) {
    const [dir, depth] = stack.pop();
    let entries;
    try { entries = readdirSync(dir, { withFileTypes: true }); } catch { continue; }
    for (const ent of entries) {
      if (out.length >= maxFiles) break;
      const full = join(dir, ent.name);
      if (ent.isDirectory()) {
        if (SKIP_DIRS.has(ent.name) || ent.name.startsWith(".")) continue;
        if (depth < maxDepth) stack.push([full, depth + 1]);
      } else if (ent.isFile()) {
        if (!extSet) { out.push(full); }
        else {
          const dot = ent.name.lastIndexOf(".");
          const ext = dot >= 0 ? ent.name.slice(dot + 1).toLowerCase() : "";
          if (extSet.has(ext)) out.push(full);
        }
      }
    }
  }
  return out;
}

function numericNeighbours(value) {
  const m = String(value).trim().match(/^(-?\d+)(\.(\d+))?$/);
  if (!m) return [];
  const hasFrac = m[3] !== undefined;
  const digits = hasFrac ? m[3].length : 0;
  const num = parseFloat(value);
  if (Number.isNaN(num)) return [];
  const step = hasFrac ? Math.pow(10, -digits) : 1;
  const fmt = (n) => (hasFrac ? n.toFixed(digits) : String(Math.round(n)));
  return [fmt(num + step), fmt(num - step)].filter((v) => v !== String(value).trim());
}

const textResult = (obj) => ({ content: [{ type: "text", text: JSON.stringify(obj, null, 2) }] });
const errResult = (msg) => ({ content: [{ type: "text", text: JSON.stringify({ error: msg }, null, 2) }], isError: true });

// ---- tool definitions + handlers ------------------------------------------

const TOOLS = [
  {
    name: "verify_result_claim",
    description:
      "Confirm a numeric claim (e.g. '0.559', '80.8') actually appears in a project's results files (JSON/CSV/TXT). Refuses (found=false) if no match. Use before inserting any number into docs, a thesis, a README, or a commit message.",
    inputSchema: {
      type: "object",
      properties: {
        value: { type: "string", description: "The value to verify, e.g. '0.559' or '80.8'. Units / percent signs are ignored." },
        project_dir: { type: "string", description: "Absolute path to the project root to search." },
        extensions: { type: "array", items: { type: "string" }, description: "File extensions to search. Default: json, csv, txt." },
        subpath: { type: "string", description: "Restrict the search to this sub-directory of project_dir (e.g. 'results')." },
      },
      required: ["value", "project_dir"],
    },
    handler({ value, project_dir, extensions, subpath }) {
      const root = subpath ? join(project_dir, subpath) : project_dir;
      if (!existsSync(root)) return errResult(`path does not exist: ${root}`);
      const needle = String(value).trim().replace(/[%\s]|m$/g, "");
      if (!needle) return errResult("empty value after normalisation");
      const neighbours = numericNeighbours(needle);
      const targets = [needle, ...neighbours];
      const exts = extensions && extensions.length ? extensions : ["json", "csv", "txt"];
      const files = walkFiles(root, { exts });
      const matches = [];
      for (const f of files) {
        let text;
        try { text = readFileSync(f, "utf8"); } catch { continue; }
        const lines = text.split(/\r?\n/);
        for (let i = 0; i < lines.length; i++) {
          for (const t of targets) {
            if (lines[i].includes(t)) {
              matches.push({ file: f, line: i + 1, matched_value: t, exact: t === needle, text: lines[i].trim().slice(0, 200) });
              break;
            }
          }
          if (matches.length >= 100) break;
        }
        if (matches.length >= 100) break;
      }
      const exact = matches.filter((m) => m.exact);
      return textResult({
        claim: value, normalised: needle, neighbours_tried: neighbours,
        found: exact.length > 0, exact_matches: exact.length,
        approximate_matches: matches.length - exact.length, files_scanned: files.length,
        matches: matches.slice(0, 50),
        verdict: exact.length > 0 ? "VERIFIED" : "UNVERIFIED — value not found in results files",
      });
    },
  },
  {
    name: "query_graph",
    description:
      "Cheap 1-hop subgraph lookup over a Graphiti-style JSONL knowledge graph (nodes.jsonl + edges.jsonl). Returns nodes whose id/label/summary matches a keyword, plus every edge touching them. Token-light recall layer; prefer over re-reading flat memory snapshots.",
    inputSchema: {
      type: "object",
      properties: {
        keyword: { type: "string", description: "Case-insensitive substring to match against node id/label/name/summary." },
        graph_dir: { type: "string", description: "Directory containing nodes.jsonl and edges.jsonl (usually <project>/memory/graph)." },
      },
      required: ["keyword", "graph_dir"],
    },
    handler({ keyword, graph_dir }) {
      const nodesPath = join(graph_dir, "nodes.jsonl");
      const edgesPath = join(graph_dir, "edges.jsonl");
      if (!existsSync(nodesPath)) return errResult(`no nodes.jsonl in ${graph_dir}`);
      const kw = keyword.toLowerCase();
      const parseJsonl = (p) => existsSync(p)
        ? readFileSync(p, "utf8").split(/\r?\n/).filter((l) => l.trim())
            .map((l) => { try { return JSON.parse(l); } catch { return null; } }).filter(Boolean)
        : [];
      const allNodes = parseJsonl(nodesPath);
      const allEdges = parseJsonl(edgesPath);
      const hay = (n) => [n.id, n.name, n.label, n.title, n.summary, n.type].filter(Boolean).join(" ").toLowerCase();
      const matched = allNodes.filter((n) => hay(n).includes(kw));
      const ids = new Set(matched.map((n) => n.id ?? n.name).filter(Boolean));
      const edgeIds = (e) => [e.src, e.source, e.from, e.dst, e.target, e.to];
      const edges = allEdges.filter((e) => edgeIds(e).some((x) => ids.has(x)));
      const neighbourIds = new Set();
      for (const e of edges) for (const x of edgeIds(e)) if (x && !ids.has(x)) neighbourIds.add(x);
      const neighbours = allNodes.filter((n) => neighbourIds.has(n.id ?? n.name));
      return textResult({
        keyword, matched_nodes: matched.slice(0, 40), one_hop_neighbours: neighbours.slice(0, 60),
        edges: edges.slice(0, 80), totals: { nodes: allNodes.length, edges: allEdges.length, matched: matched.length },
      });
    },
  },
  {
    name: "memory_graph_add",
    description:
      "Append a node or an edge to a Graphiti-style JSONL knowledge graph. Deterministic write; creates the directory and files if missing. Use to capture durable facts ('X depends on Y', 'Z supersedes W', 'decided: ...') as graph edges instead of new flat memory files.",
    inputSchema: {
      type: "object",
      properties: {
        graph_dir: { type: "string", description: "Directory for nodes.jsonl / edges.jsonl (created if missing)." },
        kind: { type: "string", enum: ["node", "edge"], description: "Whether to append a node or an edge." },
        node: { type: "object", description: "Node payload when kind='node'. Must include an id (string)." },
        edge: { type: "object", description: "Edge payload when kind='edge', e.g. {src, rel, dst}. rel e.g. depends_on, imports, supersedes, decided_by." },
      },
      required: ["graph_dir", "kind"],
    },
    handler({ graph_dir, kind, node, edge }) {
      if (kind === "node" && (!node || !node.id)) return errResult("kind=node requires a node payload with an id");
      if (kind === "edge" && !edge) return errResult("kind=edge requires an edge payload");
      try { mkdirSync(graph_dir, { recursive: true }); } catch (e) { return errResult(`cannot create ${graph_dir}: ${e.message}`); }
      const file = kind === "node" ? join(graph_dir, "nodes.jsonl") : join(graph_dir, "edges.jsonl");
      const payload = kind === "node" ? node : edge;
      try { appendFileSync(file, JSON.stringify(payload) + "\n"); } catch (e) { return errResult(`write failed: ${e.message}`); }
      return textResult({ written_to: file, kind, payload });
    },
  },
  {
    name: "placeholder_scan",
    description:
      "Find unfilled <PLACEHOLDER> markers (matching <[A-Z_][A-Z0-9_]*>) in a project's .claude/CLAUDE.md and .claude/CONTEXT.md, or in an explicit list of files. Use after bootstrapping a new project with /toolkit-init.",
    inputSchema: {
      type: "object",
      properties: {
        project_dir: { type: "string", description: "Project root; scans .claude/CLAUDE.md and .claude/CONTEXT.md." },
        files: { type: "array", items: { type: "string" }, description: "Explicit file paths to scan instead of project_dir." },
      },
    },
    handler({ project_dir, files }) {
      let targets = files && files.length ? files : [];
      if (!targets.length) {
        if (!project_dir) return errResult("provide project_dir or files");
        targets = [join(project_dir, ".claude", "CLAUDE.md"), join(project_dir, ".claude", "CONTEXT.md")];
      }
      const re = /<[A-Z_][A-Z0-9_]*>/g;
      const report = [];
      let total = 0;
      for (const f of targets) {
        if (!existsSync(f)) { report.push({ file: f, exists: false, placeholders: [] }); continue; }
        const lines = readFileSync(f, "utf8").split(/\r?\n/);
        const hits = [];
        lines.forEach((ln, i) => {
          const found = ln.match(re);
          if (found) hits.push({ line: i + 1, markers: [...new Set(found)] });
        });
        total += hits.reduce((a, h) => a + h.markers.length, 0);
        report.push({ file: f, exists: true, count: hits.length, placeholders: hits });
      }
      return textResult({ total_unfilled: total, clean: total === 0, report });
    },
  },
];
const TOOL_BY_NAME = new Map(TOOLS.map((t) => [t.name, t]));

const RESOURCES = [
  {
    uri: "toolkit://principles",
    name: "principles",
    description: "Token-budget habits, model-routing table, and anti-patterns the toolkit is built around.",
    mimeType: "text/markdown",
    read() {
      const p = join(PLUGIN_ROOT, "docs", "principles.md");
      return existsSync(p) ? readFileSync(p, "utf8") : "principles.md not found next to the MCP server.";
    },
  },
];
const RESOURCE_BY_URI = new Map(RESOURCES.map((r) => [r.uri, r]));

// ---- JSON-RPC dispatch -----------------------------------------------------

function handle(method, params) {
  switch (method) {
    case "initialize":
      return {
        protocolVersion: params?.protocolVersion ?? PROTOCOL_VERSION,
        capabilities: { tools: {}, resources: {} },
        serverInfo: SERVER,
      };
    case "ping":
      return {};
    case "tools/list":
      return { tools: TOOLS.map(({ name, description, inputSchema }) => ({ name, description, inputSchema })) };
    case "tools/call": {
      const tool = TOOL_BY_NAME.get(params?.name);
      if (!tool) throw { code: -32602, message: `unknown tool: ${params?.name}` };
      try { return tool.handler(params.arguments ?? {}); }
      catch (e) { return errResult(`tool threw: ${e?.message ?? String(e)}`); }
    }
    case "resources/list":
      return { resources: RESOURCES.map(({ uri, name, description, mimeType }) => ({ uri, name, description, mimeType })) };
    case "resources/read": {
      const res = RESOURCE_BY_URI.get(params?.uri);
      if (!res) throw { code: -32602, message: `unknown resource: ${params?.uri}` };
      return { contents: [{ uri: res.uri, mimeType: res.mimeType, text: res.read() }] };
    }
    default:
      throw { code: -32601, message: `method not found: ${method}` };
  }
}

// ---- stdio transport (newline-delimited JSON-RPC) --------------------------

function send(obj) { process.stdout.write(JSON.stringify(obj) + "\n"); }

let buf = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  buf += chunk;
  let nl;
  while ((nl = buf.indexOf("\n")) >= 0) {
    const line = buf.slice(0, nl).trim();
    buf = buf.slice(nl + 1);
    if (!line) continue;
    let msg;
    try { msg = JSON.parse(line); } catch { continue; }
    const isRequest = msg.id !== undefined && msg.id !== null;
    try {
      const result = handle(msg.method, msg.params);
      if (isRequest) send({ jsonrpc: "2.0", id: msg.id, result });
    } catch (err) {
      if (isRequest) send({ jsonrpc: "2.0", id: msg.id, error: { code: err.code ?? -32603, message: err.message ?? "internal error" } });
    }
  }
});
process.stdin.on("end", () => process.exit(0));
console.error("claude-toolkit MCP server (zero-dep) running on stdio");
