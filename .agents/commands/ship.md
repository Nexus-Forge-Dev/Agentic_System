# Command: /ship
# .agents/commands/ship.md
# Owner: DevOps Engineer (delegated from Platform Lead)
# Trigger: /ship

---

## Purpose
Full pre-deploy pipeline: run all checks → /review gate → version bump →
commit → push → open GitHub PR. Zero shortcuts.

---

## Pre-Flight (8-step)
1. READ `.agents/MANIFEST.md`
2. READ `.agents/rules/global.md`
3. READ `.agents/rules/divisions/platform.md`
4. READ `.agents/PROJECT.md` — CI/CD and Branch Strategy
5. READ `.agents/learned.jsonl` — filter: `["deployment", "ship"]`
6. CHECK `.agents/task.md` — verify /review has completed for this session
7. LOG brief: `{"type":"brief","skill":"/ship","files_planned":["package.json","CHANGELOG.md"]}`
8. LOG activation to `audit.jsonl`

---

## Workflow

```
GATE CHECK: Has /review passed (score >= 8.0)? If NO → BLOCKED.

STEP 1 — Pre-ship quality check (parallel)
  Run: test suite
  Run: linter
  Run: type-checker
  If any fail → BLOCKED, return failures to Engineering Lead

STEP 2 — Security Engineer (parallel with Step 1)
  Security Engineer runs final OWASP check on the diff
  If any critical/high finding → BLOCKED

STEP 3 — QA Automation Engineer
  If /e2e hasn't run this session → run /smoke (fast) before shipping
  If /e2e has run and passed → proceed

STEP 4 — Version bump
  Read current version from package.json / pyproject.toml / go.mod
  Determine bump type (patch / minor / major) based on change type:
    - Bug fix / minor change → patch
    - New feature → minor
    - Breaking change → major (requires explicit user confirmation, Tier 2)
  Update version file

STEP 5 — Generate CHANGELOG entry
  Run /document-release to generate changelog from git log since last tag
  Append to CHANGELOG.md

STEP 6 — Git commit + tag (Tier 1 — auto-approved)
  git add -A
  git commit -m "release: v<version> — <summary of changes>"
  git tag v<version>

STEP 7 — Push (Tier 2 — requires approval)
  Present to user:
    "Ready to push v<version> to <branch> and open PR.
     Files changed: <list>. Approve? [y/n]"
  If approved:
    git push origin <branch>
    git push origin v<version>

STEP 8 — Open GitHub PR (via github MCP)
  Title: "release: v<version> — <feature summary>"
  Body: changelog entry + test results + review score
  Labels: ["release", risk-level-label]
  Assignee: none (human reviews)

STEP 9 — Report result
  Return Result Message: { status: "SUCCESS", pr_url: "...", version: "..." }
```

---

## Output Artifacts
- Updated `CHANGELOG.md`
- Updated version file (`package.json` etc.)
- GitHub PR (via MCP)

---

## Guardrails
- NEVER push directly to main/master/production — always a PR
- NEVER skip the /review gate
- Major version bumps always require explicit human confirmation (Tier 2)
- If any step fails, roll back the version bump and changelog changes
