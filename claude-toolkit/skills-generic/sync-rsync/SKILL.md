---
name: sync-rsync
description: Rsync the local project to a remote host (HPC cluster, dev server). Dry-run first, confirm before real push. Reads remote host/path from .claude/CLAUDE.md.
model: sonnet
---

## When to use
User asks to sync / push / rsync code to the remote workspace before submitting a job or running on the remote.

## Configuration

Read the **HPC / env** section of `.claude/CLAUDE.md` for:
- Remote host (e.g. `user@ssh.example.com`)
- Remote path (e.g. `/workspace/user/project/`)

If the section is absent or incomplete, ask the user once, then suggest they add it to CLAUDE.md for next time.

## Steps

1. **Always dry run first:**
   ```bash
   rsync -avn --delete \
     --exclude='.venv/' --exclude='venv/' --exclude='myenv/' \
     --exclude='__pycache__/' --exclude='*.pyc' --exclude='*.pyo' \
     --exclude='.git/' \
     --exclude='node_modules/' \
     --exclude='logs/' --exclude='*.log' \
     --exclude='.env*' --exclude='.credentials*' \
     --exclude='*.joblib' --exclude='*.pt' --exclude='*.h5' --exclude='*.ckpt' \
     --exclude='*.npz' --exclude='*.npy' \
     ./ <REMOTE_HOST>:<REMOTE_PATH>
   ```
   Show the user the list of files that would change.

2. Sync `.claude/` separately (usually gitignored but needed on remote for consistent context):
   ```bash
   rsync -avn ./.claude/ <REMOTE_HOST>:<REMOTE_PATH>/.claude/
   ```

3. **Wait for user confirmation.** Only then drop `-n` and run for real.

4. Verify after real sync:
   ```bash
   ssh <REMOTE_HOST> 'ls <REMOTE_PATH>/.claude/ && git -C <REMOTE_PATH> rev-parse HEAD 2>/dev/null'
   ```

## Anti-patterns
- Never `--delete` without a dry run the user has seen first.
- Never sync secrets (`.env*`, `.credentials*`, `id_rsa*`) — the exclude list guards but verify.
- Never sync large binary artefacts (`.joblib`, `.pt`, `.h5`, `.ckpt`, `.npz`, datasets) — they regenerate on the remote or are already there.
- Do not skip the dry run "because it's a small change" — `--delete` can still wipe remote state.
