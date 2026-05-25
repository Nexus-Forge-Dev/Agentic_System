# Command: /land-and-deploy
# .agents/commands/land-and-deploy.md
# Owner: DevOps Engineer
# Trigger: /land-and-deploy "<pr-url>"

## Purpose
Merge an approved PR, monitor CI, then run health checks on the live URL.
Bridges the gap between PR approval and verified live deployment.

## Workflow
```
STEP 1 — Verify PR is approved
  Via GitHub MCP: check PR approval status
  If not approved: BLOCKED — "PR requires human approval before landing"

STEP 2 — Merge PR (Tier 2 — requires confirmation)
  Confirm with user: "Merging <PR title> to <branch>. Proceed? [y/n]"
  Merge: squash and merge (default) or rebase (per PROJECT.md)

STEP 3 — Monitor CI
  Poll CI status every 30 seconds (max 15 minutes)
  If CI fails: surface failure immediately, do NOT deploy

STEP 4 — Trigger /deploy
  If CI passes: trigger /deploy for the appropriate environment

STEP 5 — Run /canary
  Monitor critical production paths for 30 minutes post-deploy
```
