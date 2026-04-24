---
name: run-pipeline
description: Orchestrate a sequence of shell scripts as chained SLURM jobs with --dependency=afterok, or sequentially as bash locally. Uses submit-slurm for partition selection on each step.
model: opus
---

## When to use
User asks to run a full training / evaluation pipeline that involves 2+ scripts in order, where later steps depend on the artefacts of earlier ones.

## Configuration

Read `.claude/CLAUDE.md` **File conventions** for the project's pipeline script naming (often `run_*.sh` at repo root or under `<pipeline_dir>/`).

Confirm with the user which scripts, in which order. Do not infer the order from filenames alone — ask if unclear.

## Steps (HPC path, chained sbatch)

1. For each script, call the `submit-slurm` skill to pick the best partition. Collect the recommended `sbatch` command per step.

2. Build the dependency chain:
   ```bash
   JOB1=$(sbatch --parsable <sbatch_args_1> <script_1>)
   JOB2=$(sbatch --parsable --dependency=afterok:$JOB1 <sbatch_args_2> <script_2>)
   JOB3=$(sbatch --parsable --dependency=afterok:$JOB2 <sbatch_args_3> <script_3>)
   # ...
   echo "Submitted: $JOB1 $JOB2 $JOB3"
   ```

3. Present as a single block for user approval. **Do not submit autonomously.**

4. After approval, the user runs the block. Dependency chain auto-cancels downstream jobs if any fails.

5. Suggest monitoring with:
   ```bash
   watch -n 30 squeue -u <user>
   ```
   Do not busy-poll from within Claude.

## Steps (local path, sequential bash)

If the user wants a local run:
```bash
set -e
bash <script_1> && bash <script_2> && bash <script_3>
```
`set -e` stops on first failure. Still present for approval, don't run autonomously.

## On failure

If a step fails on HPC, the dependency chain auto-cancels downstream jobs. Tail the failing log:
```bash
ssh <cluster> 'tail -50 logs/slurm_<jobid>.err'
```

## Anti-patterns
- Do not run all steps as `bash` locally if they are designed for HPC (check for `#SBATCH --gres=gpu`).
- Do not skip earlier steps "to save time" if later steps read artefacts they produce.
- Do not parallelise steps that depend on each other's outputs.
