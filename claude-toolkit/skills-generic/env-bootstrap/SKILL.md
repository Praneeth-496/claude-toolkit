---
name: env-bootstrap
description: Create a mandatory isolated environment for a project so package/module versions never collide with the system or other projects. uv-first for Python (falls back to python -m venv), local node_modules for Node. Idempotent; never installs anything globally. TRIGGER when starting work in a new repo, when the user says "set up the environment", "create a venv", "isolate dependencies", or before any package install.
model: sonnet
---

## When to use
Run once per project before installing any dependency. Also run when `block-global-pip` blocks a global `pip install` — it means no isolated env is active yet.

## Rule (mandatory)
Never install packages globally. Every project gets its own isolated environment. For Python that means a project-local `.venv`; for Node the local `node_modules` (never `npm -g`).

## Steps

1. **Detect the language** from files in the project root:
   - Python: `pyproject.toml`, `requirements.txt`, `setup.py`, `setup.cfg`, `Pipfile`, or any `*.py`.
   - Node: `package.json`.
   - Both can be true — handle each.

2. **Python — create `.venv` (idempotent):**
   ```bash
   if [ -d .venv ]; then echo ".venv exists"; else
     if command -v uv >/dev/null 2>&1; then
       uv venv                         # fast; creates .venv
     else
       python3 -m venv .venv           # stdlib fallback
     fi
   fi
   ```
   Then install deps **into the venv only**, preferring uv:
   ```bash
   # with uv (no activation needed):
   [ -f pyproject.toml ]    && uv sync 2>/dev/null || true
   [ -f requirements.txt ]  && uv pip install -r requirements.txt
   # without uv: activate first, then pip
   #   source .venv/bin/activate && pip install -r requirements.txt
   ```
   Tell the user how to activate: `source .venv/bin/activate` (or just prefix commands with `uv run`).

3. **Node — keep installs local (never global):**
   ```bash
   [ -f package-lock.json ] && npm ci || npm install   # writes ./node_modules
   ```
   Never `npm install -g`. Global Node tools belong in the user's own shell, not a project setup.

4. **Add to `.gitignore`** if missing: `.venv/`, `node_modules/`.

5. **Confirm isolation:** print the interpreter path (`.venv/bin/python` or `which python` after activation) so the user can see they are inside the env, not the system Python.

## Anti-patterns
- Do not `pip install` without an active venv or `uv` — that pollutes the system Python and causes the exact version conflicts this skill prevents. (The `block-global-pip` hook enforces this.)
- Do not use `sudo pip`, `pip install --user`, or `conda install` into `base`.
- Do not recreate `.venv` if it already exists unless the user asks (it is expensive and discards installed deps).
- Do not commit `.venv/` or `node_modules/`.
