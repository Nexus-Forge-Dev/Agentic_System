# Command: /pipeline-generate
# .agents/commands/pipeline-generate.md
# Owner: DevOps Engineer
# Trigger: /pipeline-generate ["<service-name>"]

---

## Purpose
Generate a production-ready CI/CD pipeline YAML for a service from scratch.
Reads PROJECT.md stack, selects stages, pins all step SHAs, and produces
a pipeline-manifest explaining every decision.

---

## Workflow

```
INPUT: Optional service name (defaults to project name from PROJECT.md)

STEP 1 — Read project stack
  Read .agents/PROJECT.md:
    - Runtime (Node.js / Python / Go)
    - Test framework
    - Build tool
    - Cloud deployment target
    - Container registry (if applicable)

STEP 2 — Determine required stages
  MANDATORY (all 5 required, no exceptions):
    Stage 1: Lint & Type Check
    Stage 2: Test Suite
    Stage 3: Build
    Stage 4: CVE Scan (Trivy or Snyk)
    Stage 5: Deploy (environment-specific)

  OPTIONAL (add if stack requires):
    - Database migration check (if ORM/migrations detected)
    - E2E smoke test (if playwright configured)
    - Performance benchmark (if benchmark script exists)

STEP 3 — Fetch pinned SHA versions for each step
  For GitHub Actions, look up current SHA for each action used:
    actions/checkout, actions/setup-node, actions/cache, etc.
  Pin all steps to exact SHA — never use @latest or @v3

STEP 4 — Generate pipeline YAML
  Write to: .github/workflows/<service-name>.yml
  Include:
    - Correct trigger (push to non-main branches + PR)
    - Job dependency graph (lint → test → build → scan → deploy)
    - Caching for package manager (npm, pip, go modules)
    - Timeout on every job (no unbounded jobs)
    - Permissions: read-all default, write only where explicitly needed
    - Secret references by name only (never hardcoded values)
    - Deployment only on main branch or explicit tag

STEP 5 — Generate pipeline manifest
  Write to: .agents/reports/pipeline-manifest-<service>-<ts>.md
  Contents:
    - Why each stage exists
    - What each tool version was pinned to (and when to update it)
    - What secrets are required (names only)
    - How to extend the pipeline for new stages

STEP 6 — Validation
  Run: actionlint (if available) or validate YAML syntax
  Confirm no secrets in YAML (scan for patterns)
```

---

## Output Artifacts
- `.github/workflows/<service>.yml` — the generated pipeline
- `.agents/reports/pipeline-manifest-<service>-<ts>.md` — decision documentation

---

## Hard Rules
- Generated pipeline MUST have all 5 mandatory stages — less is BLOCKED
- All step versions must be pinned to exact SHA — no @latest
- No secrets or credentials in YAML — references to env/secrets only
- Deploy stage only triggers on main branch push or explicit tag — never on feature branches
