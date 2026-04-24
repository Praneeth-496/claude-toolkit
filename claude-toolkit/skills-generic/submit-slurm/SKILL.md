---
name: submit-slurm
description: Submit an sbatch job to any SLURM cluster. Picks the freest partition whose GPU/CPU/time limits match the script's #SBATCH directives. Never auto-submits — prints the chosen partition and the sbatch command for user confirmation.
model: sonnet
---

## When to use
User asks to submit any `.sh` script containing `#SBATCH` directives to a SLURM cluster.

## Configuration

Read the **HPC / env** section of `.claude/CLAUDE.md` for:
- Cluster SSH alias or host
- Known partitions and their rough roles

If the section is absent, ask the user for the cluster host.

## Steps

1. Read the script's first 30 lines. Extract existing `#SBATCH --partition=`, `--gres=`, `--time=`, `--mem=`, `--cpus-per-task=` directives.

2. Over SSH to the cluster, run:
   ```bash
   sinfo -o "%P %a %l %D %t %C %G" | column -t
   squeue -h -o "%P %T" | sort | uniq -c
   ```
   Parse: for each partition listed in CLAUDE.md, compute `idle_nodes` and `queue_depth`.

3. Filter to partitions that:
   - Match GRES (if script requests `gpu:1` → only GPU partitions).
   - Have `time_limit >= script --time`.
   - Have at least one node in `idle` state, OR the shortest queue.

4. Rank by (idle nodes desc, queue depth asc, time limit closest fit). Pick the top one.

5. If the picked partition differs from the script's `#SBATCH --partition=`:
   ```
   Script says: <original>
   Recommend:   <picked>  (idle=<n>, queue=<m>)
   Override:    sbatch --partition=<picked> <script>
   ```
   Do NOT modify the script file.

6. If they match, just print `sbatch <script>`.

7. **Stop. Wait for user to confirm before running sbatch.** Never submit autonomously.

## Anti-patterns
- Do not default to any specific partition just because existing scripts use it — check availability fresh each time.
- Do not edit the script's `#SBATCH` lines; suggest `--partition=` override on the sbatch command line.
- Do not Read the script in full — first 30 lines for directives is enough.
- Do not silently skip the SSH check if the cluster is unreachable; tell the user and pick the script's declared partition as a fallback.
