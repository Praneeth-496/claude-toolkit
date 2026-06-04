#!/usr/bin/env node
// Generate a self-contained dashboard.html for claude-toolkit.
// Zero dependencies. Scans skills-generic/, agents/, commands/, hooks/, VERSION and
// renders a single static HTML file (cards pre-rendered; a small JS adds live search).
//
//   node dashboard/build.mjs       # writes dashboard/dashboard.html
//
// Re-run after adding skills/agents/hooks to refresh the dashboard.

import { readFileSync, readdirSync, existsSync, writeFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, "..");

const THINKING = new Set(["10x", "brief", "godmode", "scout", "critique", "devil", "compare", "pitch", "teacher", "explainlikeim5", "humanizer", "ooda"]);

function frontmatter(text) {
  const m = text.match(/^---\n([\s\S]*?)\n---/);
  const out = {};
  if (!m) return out;
  // crude YAML: key: value (one line) — enough for name/description/model
  for (const line of m[1].split("\n")) {
    const kv = line.match(/^([a-zA-Z_]+):\s*(.*)$/);
    if (kv) out[kv[1]] = kv[2].trim();
  }
  return out;
}

const readDirs = (p) => (existsSync(p) ? readdirSync(p, { withFileTypes: true }) : []);

// ---- collect ---------------------------------------------------------------

const version = existsSync(join(ROOT, "VERSION")) ? readFileSync(join(ROOT, "VERSION"), "utf8").trim() : "?";

const skills = [];
for (const d of readDirs(join(ROOT, "skills-generic"))) {
  if (!d.isDirectory()) continue;
  const f = join(ROOT, "skills-generic", d.name, "SKILL.md");
  if (!existsSync(f)) continue;
  const fm = frontmatter(readFileSync(f, "utf8"));
  skills.push({ name: fm.name || d.name, description: fm.description || "", model: fm.model || "", group: THINKING.has(d.name) ? "thinking" : "workflow" });
}
skills.sort((a, b) => (a.group === b.group ? a.name.localeCompare(b.name) : a.group === "workflow" ? -1 : 1));

const agents = [];
for (const d of readDirs(join(ROOT, "agents"))) {
  if (!d.isFile() || !d.name.endsWith(".md")) continue;
  const fm = frontmatter(readFileSync(join(ROOT, "agents", d.name), "utf8"));
  agents.push({ name: fm.name || d.name.replace(/\.md$/, ""), description: fm.description || "", model: fm.model || "" });
}
agents.sort((a, b) => a.name.localeCompare(b.name));

const commands = [];
for (const d of readDirs(join(ROOT, "commands"))) {
  if (!d.isFile() || !d.name.endsWith(".md")) continue;
  const fm = frontmatter(readFileSync(join(ROOT, "commands", d.name), "utf8"));
  commands.push({ name: "/" + d.name.replace(/\.md$/, ""), description: fm.description || "" });
}

const mcpTools = [
  { name: "verify_result_claim", description: "Confirm a number appears in a project's results files (JSON/CSV/TXT). Refuses if absent." },
  { name: "query_graph", description: "1-hop subgraph lookup over a nodes.jsonl + edges.jsonl memory graph." },
  { name: "memory_graph_add", description: "Append a node or edge (depends_on, supersedes, decided_by, ...) to the graph." },
  { name: "placeholder_scan", description: "Find unfilled <PLACEHOLDER> markers in CLAUDE.md / CONTEXT.md." },
];

const hooks = [];
const hj = join(ROOT, "hooks", "hooks.json");
if (existsSync(hj)) {
  const data = JSON.parse(readFileSync(hj, "utf8"));
  for (const [event, arr] of Object.entries(data.hooks || {})) {
    for (const entry of arr) {
      for (const h of entry.hooks || []) {
        const script = (h.command.match(/([\w-]+\.sh)/) || [])[1] || h.command;
        hooks.push({ event, matcher: entry.matcher || "*", script, note: h.statusMessage || "" });
      }
    }
  }
}

// ---- render ----------------------------------------------------------------

const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
const clip = (s, n = 200) => (s.length > n ? esc(s.slice(0, n - 1)) + "&hellip;" : esc(s));

const card = (title, sub, body, tag) => `
  <article class="card" data-search="${esc((title + " " + body).toLowerCase())}">
    <div class="card-head"><h3>${esc(title)}</h3>${tag ? `<span class="pill ${tag.cls}">${esc(tag.text)}</span>` : ""}</div>
    ${sub ? `<div class="sub">${esc(sub)}</div>` : ""}
    <p>${clip(body)}</p>
  </article>`;

const section = (id, title, count, cards) => `
  <section id="${id}">
    <h2>${esc(title)} <span class="count">${count}</span></h2>
    <div class="grid">${cards.join("")}</div>
  </section>`;

const workflowSkills = skills.filter((s) => s.group === "workflow");
const thinkingSkills = skills.filter((s) => s.group === "thinking");

const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>claude-toolkit · dashboard</title>
<style>
  :root{
    --bg:#0b0e14; --panel:#121723; --panel2:#171d2b; --line:#222a3a;
    --ink:#e6edf3; --dim:#8b97a8; --accent:#7c9cff; --accent2:#5ce6c0;
    --warn:#ffb454; --pink:#ff7eb6;
  }
  *{box-sizing:border-box}
  body{margin:0;font:15px/1.5 ui-sans-serif,system-ui,-apple-system,Segoe UI,Roboto,Inter,sans-serif;
    background:radial-gradient(1200px 600px at 80% -10%,#1a2236 0,var(--bg) 55%) fixed;color:var(--ink)}
  a{color:var(--accent);text-decoration:none}
  header.hero{padding:54px 24px 30px;max-width:1180px;margin:0 auto}
  .logo{display:flex;align-items:center;gap:14px}
  .logo .mark{width:46px;height:46px;border-radius:13px;background:linear-gradient(135deg,var(--accent),var(--accent2));
    display:grid;place-items:center;font-weight:800;color:#0b0e14;font-size:22px;box-shadow:0 8px 30px rgba(124,156,255,.35)}
  h1{font-size:30px;margin:0;letter-spacing:-.5px}
  .ver{font:600 12px ui-monospace,SFMono-Regular,Menlo,monospace;color:var(--accent2);
    border:1px solid var(--line);padding:3px 9px;border-radius:999px;background:var(--panel)}
  .tag{color:var(--dim);margin:10px 0 0;max-width:680px}
  .stats{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:14px;margin:26px 0 6px}
  .stat{background:linear-gradient(180deg,var(--panel2),var(--panel));border:1px solid var(--line);
    border-radius:16px;padding:18px 18px}
  .stat b{display:block;font-size:30px;letter-spacing:-1px}
  .stat span{color:var(--dim);font-size:13px}
  .stat.s1 b{color:var(--accent)} .stat.s2 b{color:var(--accent2)}
  .stat.s3 b{color:var(--warn)} .stat.s4 b{color:var(--pink)}
  .toolbar{position:sticky;top:0;z-index:5;backdrop-filter:blur(8px);
    background:rgba(11,14,20,.7);border-bottom:1px solid var(--line)}
  .toolbar .inner{max-width:1180px;margin:0 auto;padding:12px 24px;display:flex;gap:12px;align-items:center;flex-wrap:wrap}
  #q{flex:1;min-width:220px;background:var(--panel);border:1px solid var(--line);color:var(--ink);
    padding:11px 14px;border-radius:12px;font-size:14px;outline:none}
  #q:focus{border-color:var(--accent)}
  .nav{display:flex;gap:8px;flex-wrap:wrap}
  .nav a{font-size:13px;color:var(--dim);border:1px solid var(--line);padding:7px 11px;border-radius:10px;background:var(--panel)}
  .nav a:hover{color:var(--ink);border-color:var(--accent)}
  main{max-width:1180px;margin:0 auto;padding:8px 24px 70px}
  section{margin:34px 0}
  h2{font-size:18px;display:flex;align-items:center;gap:10px;margin:0 0 14px}
  .count{font:600 12px ui-monospace,monospace;color:var(--dim);border:1px solid var(--line);
    padding:2px 8px;border-radius:999px}
  .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:14px}
  .card{background:var(--panel);border:1px solid var(--line);border-radius:14px;padding:15px 16px;
    transition:transform .12s,border-color .12s,box-shadow .12s}
  .card:hover{transform:translateY(-3px);border-color:var(--accent);box-shadow:0 10px 34px rgba(0,0,0,.35)}
  .card-head{display:flex;align-items:center;justify-content:space-between;gap:8px}
  .card h3{margin:0;font:600 15px ui-monospace,SFMono-Regular,Menlo,monospace;color:var(--ink)}
  .card .sub{color:var(--dim);font-size:12px;margin-top:2px}
  .card p{margin:9px 0 0;color:#c6d0de;font-size:13.5px}
  .pill{font:600 10px ui-monospace,monospace;padding:2px 7px;border-radius:999px;border:1px solid var(--line);color:var(--dim)}
  .pill.opus{color:var(--pink);border-color:#3a2433} .pill.sonnet{color:var(--accent);border-color:#23304d}
  .pill.haiku{color:var(--accent2);border-color:#1d3b35}
  .empty{display:none;color:var(--dim);padding:30px 0;text-align:center}
  footer{max-width:1180px;margin:0 auto;padding:0 24px 60px;color:var(--dim);font-size:13px}
  code{background:var(--panel2);border:1px solid var(--line);padding:2px 7px;border-radius:7px;
    font:13px ui-monospace,monospace;color:var(--accent2)}
  .no-match section{display:none}
</style>
</head>
<body>
<header class="hero">
  <div class="logo">
    <div class="mark">ct</div>
    <div>
      <h1>claude-toolkit <span class="ver">v${esc(version)}</span></h1>
    </div>
  </div>
  <p class="tag">Portable Claude Code workflow toolkit — skills, review agents, safety hooks, and a bundled zero-dependency MCP server. Install once, live in every project.</p>
  <div class="stats">
    <div class="stat s1"><b>${skills.length}</b><span>skills</span></div>
    <div class="stat s2"><b>${agents.length}</b><span>review agents</span></div>
    <div class="stat s3"><b>${hooks.length}</b><span>active hooks</span></div>
    <div class="stat s4"><b>${mcpTools.length}</b><span>MCP tools</span></div>
  </div>
</header>

<div class="toolbar"><div class="inner">
  <input id="q" type="search" placeholder="Filter everything…  (try: memory, slurm, review, pip)" autofocus>
  <nav class="nav">
    <a href="#skills">Skills</a><a href="#agents">Agents</a><a href="#mcp">MCP</a>
    <a href="#hooks">Hooks</a><a href="#commands">Commands</a>
  </nav>
</div></div>

<main>
  ${section("skills", "Workflow skills", workflowSkills.length,
    workflowSkills.map((s) => card(s.name, "", s.description, s.model ? { text: s.model, cls: s.model } : null)))}
  ${section("thinking", "Thinking / style skills", thinkingSkills.length,
    thinkingSkills.map((s) => card(s.name, "", s.description, s.model ? { text: s.model, cls: s.model } : null)))}
  ${section("agents", "Review subagents", agents.length,
    agents.map((a) => card(a.name, "", a.description, a.model ? { text: a.model, cls: a.model } : null)))}
  ${section("mcp", "MCP tools (bundled server)", mcpTools.length,
    mcpTools.map((t) => card(t.name, "callable via /mcp", t.description, { text: "tool", cls: "sonnet" })))}
  ${section("hooks", "Active hooks", hooks.length,
    hooks.map((h) => card(h.script, h.event + "  ·  " + h.matcher, h.note, { text: "hook", cls: "haiku" })))}
  ${section("commands", "Commands", commands.length,
    commands.map((c) => card(c.name, "", c.description, { text: "cmd", cls: "opus" })))}
  <div class="empty" id="empty">No matches.</div>
</main>

<footer>
  Install: <code>/plugin marketplace add github:Praneeth-496/claude-toolkit</code> then <code>/plugin install claude-toolkit</code>.
  Regenerate this page with <code>node dashboard/build.mjs</code>.
</footer>

<script>
  const q = document.getElementById('q'), cards = [...document.querySelectorAll('.card')],
        empty = document.getElementById('empty'), main = document.querySelector('main');
  q.addEventListener('input', () => {
    const t = q.value.trim().toLowerCase(); let shown = 0;
    for (const c of cards){ const hit = !t || c.dataset.search.includes(t); c.style.display = hit ? '' : 'none'; if(hit) shown++; }
    for (const s of document.querySelectorAll('section')){
      const any = [...s.querySelectorAll('.card')].some(c => c.style.display !== 'none');
      s.style.display = any ? '' : 'none';
    }
    empty.style.display = shown ? 'none' : 'block';
  });
</script>
</body>
</html>
`;

const outDir = join(HERE);
writeFileSync(join(outDir, "dashboard.html"), html);
console.log(`dashboard.html written — ${skills.length} skills, ${agents.length} agents, ${hooks.length} hooks, ${mcpTools.length} MCP tools, ${commands.length} commands (v${version})`);
