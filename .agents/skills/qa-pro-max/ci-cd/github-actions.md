# GitHub Actions Standards
# .agents/skills/qa-pro-max/ci-cd/github-actions.md
#
# Standards for how quality checks integrate with GitHub Actions.

---

## REQUIRED STATUS CHECKS (all must pass to merge to protected branches)

```
test:unit          → All unit tests pass, exit 0
test:integration   → All integration tests pass, exit 0
test:e2e           → All E2E flows pass including DB assertions, exit 0
test:contract      → OpenAPI spec matches implementation, exit 0
lint               → Zero linter errors, exit 0
type-check         → Zero type errors, exit 0
coverage           → All coverage thresholds met, exit 0
security:sarif     → Zero Critical/High SAST findings, exit 0
security:audit     → Zero Critical/High dependency CVEs, exit 0
```

---

## RECOMMENDED JOB STRUCTURE

```yaml
# Jobs run in this order for maximum efficiency

# Stage 1 — Fast feedback (parallel, < 5 minutes total)
jobs:
  lint:          # linter — fastest possible feedback
  type-check:    # type checking — fast
  security:      # SAST + dep audit — parallelizable with tests

# Stage 2 — Test pyramid (sequential within layer, parallel across)
  unit-tests:
    needs: [lint, type-check]

  integration-tests:
    needs: [unit-tests]          # runs after unit (inside-out order)

  contract-tests:
    needs: [integration-tests]

  coverage:
    needs: [unit-tests, integration-tests]

# Stage 3 — E2E (most expensive — runs last on feature PRs)
  e2e-tests:
    needs: [contract-tests]
    # Only on: PRs to main, direct main merges

# Stage 4 — Performance (dedicated — not on every PR)
  benchmark:
    needs: [e2e-tests]
    # Only on: main branch merges, explicit /benchmark trigger

# Artifact upload — always runs regardless of test outcome
  upload-artifacts:
    needs: [e2e-tests]
    if: always()
```

---

## PR ANNOTATIONS

```
All failing checks must annotate the PR diff inline:

JUnit XML → Failed test names shown on the file where the test lives
  Example: "❌ should return 401 when token is expired" on auth.service.ts:42

SARIF → Security findings annotated on the exact line
  Example: "⚠️ SQL injection risk — use parameterized query" on user.repo.ts:87

Linter → Error lines annotated on the changed files
  Example: "❌ ESLint: no-unused-vars — 'userId' is defined but never used" on user.controller.ts:12

Coverage → Files below threshold highlighted
  Example: "⚠️ Coverage dropped from 85% to 72% on this file"
```

---

## ARTIFACT UPLOAD CONFIGURATION

```yaml
# Upload ALL artifacts even on test failure
- name: Upload test artifacts
  uses: actions/upload-artifact@v4
  if: always()                    # ← critical: must be always(), not on success
  with:
    name: test-artifacts-${{ github.run_id }}
    path: ./artifacts/
    retention-days: ${{ github.ref == 'refs/heads/main' && 90 || 7 }}

# Playwright-specific: upload traces only on failure (large files)
- name: Upload Playwright traces
  uses: actions/upload-artifact@v4
  if: failure()
  with:
    name: playwright-traces-${{ github.run_id }}
    path: ./artifacts/tests/playwright-report/
    retention-days: 7

# SARIF upload for GitHub Code Scanning
- name: Upload SARIF results
  uses: github/codeql-action/upload-sarif@v3
  if: always()
  with:
    sarif_file: ./artifacts/security/
```

---

## PERFORMANCE REGRESSION CHECK

```yaml
# Only runs on main branch merges and explicit /benchmark trigger
benchmark:
  if: github.ref == 'refs/heads/main' || contains(github.event.comment.body, '/benchmark')
  steps:
    - name: Download baseline
      uses: actions/download-artifact@v4
      with:
        name: performance-baseline
        path: ./artifacts/load/

    - name: Run load tests
      run: pnpm run benchmark        # exits 1 if any threshold exceeded

    - name: Compare against baseline
      run: node scripts/compare-baseline.js
        # exits 1 if p95 regressed > 10% from baseline

    - name: Update baseline on success
      if: success() && github.ref == 'refs/heads/main'
      run: cp ./artifacts/load/${{ github.run_id }}/summary.json ./artifacts/load/baseline.json
```

---

## CONCURRENCY & CANCELLATION

```yaml
# Cancel in-progress runs for same PR when new commit is pushed
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

# Exception: never cancel production deploy pipelines
# production-deploy job should NOT use cancel-in-progress: true
```

---

## ENVIRONMENT VARIABLES IN CI

```
Required secrets (stored in GitHub Actions secrets):
  DATABASE_URL        → Test database connection string
  REDIS_URL           → Test Redis connection string
  JWT_SECRET          → Test JWT signing key (NOT production key)

Rules:
  → Never use production secrets in CI (separate test environment credentials)
  → Never echo secrets in CI logs (Actions masks them by default — do not bypass)
  → Never hardcode credentials in workflow YAML files
  → Rotate CI secrets on any suspected exposure (treat as production breach)
```

---

## BRANCH PROTECTION RULES

```
Protected branches: main, develop (project-specific)

Required before merge:
  → All required status checks must pass
  → Branch must be up to date with base branch
  → At least 1 approving review from code owner

Bypassing protection:
  → Requires repository admin override
  → All bypasses logged to .agents/audit.jsonl automatically
  → No agent can bypass branch protection — human only
```
