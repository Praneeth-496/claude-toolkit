#!/usr/bin/env node
// Minimal stdio MCP client that boots index.mjs, lists tools, and calls one.
// Exits non-zero on any failure. Run: node smoke-test.mjs

import { spawn } from "node:child_process";
import { writeFileSync, mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const child = spawn("node", [join(HERE, "index.mjs")], { stdio: ["pipe", "pipe", "inherit"] });

let buf = "";
const pending = new Map();
child.stdout.on("data", (d) => {
  buf += d.toString();
  let nl;
  while ((nl = buf.indexOf("\n")) >= 0) {
    const line = buf.slice(0, nl).trim();
    buf = buf.slice(nl + 1);
    if (!line) continue;
    let msg;
    try {
      msg = JSON.parse(line);
    } catch {
      continue;
    }
    if (msg.id && pending.has(msg.id)) {
      pending.get(msg.id)(msg);
      pending.delete(msg.id);
    }
  }
});

let idc = 0;
function rpc(method, params) {
  const id = ++idc;
  return new Promise((res, rej) => {
    pending.set(id, res);
    child.stdin.write(JSON.stringify({ jsonrpc: "2.0", id, method, params }) + "\n");
    setTimeout(() => rej(new Error(`timeout on ${method}`)), 5000);
  });
}
function notify(method, params) {
  child.stdin.write(JSON.stringify({ jsonrpc: "2.0", method, params }) + "\n");
}

function die(msg) {
  console.error("SMOKE FAIL:", msg);
  child.kill();
  process.exit(1);
}

try {
  const init = await rpc("initialize", {
    protocolVersion: "2025-06-18",
    capabilities: {},
    clientInfo: { name: "smoke", version: "0" },
  });
  if (!init.result?.serverInfo?.name) die("no serverInfo in initialize result");
  notify("notifications/initialized");

  const tools = await rpc("tools/list", {});
  const names = (tools.result?.tools ?? []).map((t) => t.name).sort();
  const expected = ["memory_graph_add", "placeholder_scan", "query_graph", "verify_result_claim"];
  if (JSON.stringify(names) !== JSON.stringify(expected)) {
    die(`tools mismatch. got ${JSON.stringify(names)} want ${JSON.stringify(expected)}`);
  }

  // exercise placeholder_scan on a temp file with a known placeholder
  const dir = mkdtempSync(join(tmpdir(), "toolkit-smoke-"));
  const f = join(dir, "CLAUDE.md");
  writeFileSync(f, "# <PROJECT_NAME>\nsome text\nbranch: <MAIN_BRANCH>\n");
  const call = await rpc("tools/call", { name: "placeholder_scan", arguments: { files: [f] } });
  const payload = JSON.parse(call.result.content[0].text);
  if (payload.total_unfilled !== 2) die(`placeholder_scan expected 2, got ${payload.total_unfilled}`);

  console.error("SMOKE OK: initialize + tools/list (4 tools) + placeholder_scan(2) all passed");
  child.kill();
  process.exit(0);
} catch (e) {
  die(e.message);
}
