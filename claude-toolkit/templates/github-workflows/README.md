# GitHub Actions templates

Drop-in workflows that wire `anthropics/claude-code-action@v1` into your repo.

## claude-pr-review.yml

On every PR open/sync and on `@claude` comments, runs a Claude review pass. Posts findings as PR comments.

### Setup

```bash
mkdir -p .github/workflows
cp ~/Documents/claude-toolkit/claude-toolkit/templates/github-workflows/claude-pr-review.yml .github/workflows/
```

Then add `ANTHROPIC_API_KEY` to your repo's secrets:
```bash
gh secret set ANTHROPIC_API_KEY
```

### Cost control

- The workflow is gated on PR events + `@claude` mentions only — it does NOT run on every push.
- `--max-turns 8` caps the agent's tool use per run.
- Add `paths:` to `on.pull_request` to scope to specific directories.

### Customisation

The `prompt:` block intentionally references the toolkit's `code-reviewer` agent style. To use a different agent (e.g. `security-auditor`), change the prompt body and add `claude_args: --agents-from .claude/agents/security-auditor.md` if you've checked the agent into the repo.

References:
- https://github.com/anthropics/claude-code-action
- https://code.claude.com/docs/en/github-actions
