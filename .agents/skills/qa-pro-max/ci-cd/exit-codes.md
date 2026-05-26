# Exit Code Contracts
# .agents/skills/qa-pro-max/ci-cd/exit-codes.md
#
# ALL CI steps must comply with these contracts.

---

## UNIVERSAL RULE

```
Exit 0  = success (all checks passed, all thresholds met)
Non-zero = failure (pipeline must stop and report)
```

---

## HARD BLOCKS (these patterns are banned in all CI scripts)

```bash
# ❌ These suppress failures and are explicitly forbidden

command || true
command || echo "OK"
command; exit 0
command && echo "done" || echo "failed but continuing"

# Why: They convert real failures into false greens.
# If any of these appear in CI scripts, they are a P1 security/quality issue.
```

---

## PER-CATEGORY EXIT CODE CONTRACTS

```
UNIT & INTEGRATION TESTS
  0 = all tests pass
  1 = one or more tests failed
  2 = configuration error (runner could not start, missing env var)

E2E TESTS
  0 = all flows pass, all DB assertions pass
  1 = one or more test flows failed
  2 = environment setup failed (seed failed, service not ready)

LINTER
  0 = no errors (warnings alone do not trigger exit 1)
  1 = one or more errors (not warnings)
  2 = configuration error

TYPE CHECKER
  0 = no type errors
  1 = one or more type errors
  2 = tsconfig not found or invalid

COVERAGE
  0 = all coverage thresholds met
  1 = one or more files below threshold
  Note: Coverage failures do NOT suppress test failures — if tests fail,
        coverage is not measured (test failure exit code takes priority)

SECURITY SCAN (SAST / SCA)
  0 = no blocking findings (Critical / High)
  1 = one or more Critical or High severity findings
  2 = scanner configuration error
  Note: Medium/Low findings produce warnings, not exit 1

LOAD / PERFORMANCE TEST
  0 = all p95/p99 thresholds met, memory stable
  1 = one or more threshold exceeded
  2 = load test environment setup failed

CONTRACT TEST
  0 = implementation matches OpenAPI spec exactly
  1 = schema drift detected (missing field, wrong type, status code mismatch)
  2 = OpenAPI spec file not found

DATA AUDIT
  0 = zero orphaned records, zero constraint violations, audit log complete
  1 = integrity issues detected
  Note: /dataaudit never writes — read-only, always safe to run

MIGRATION
  0 = migration applied successfully, idempotency verified
  1 = migration failed or produced unexpected schema state
```

---

## PIPELINE FAILURE BEHAVIOR

```
On any non-zero exit code:
  → Current job fails immediately
  → Subsequent jobs in the same stage do NOT run
  → PR cannot be merged (protected branch check fails)
  → Artifact upload: ALWAYS runs (even on failure)
    (Allows debugging failed test screenshots, traces, logs)

On concurrent job failure (e.g., security runs in parallel with tests):
  → If security fails: pipeline fails even if all tests pass
  → Both must pass for pipeline to succeed

On infrastructure failure (exit code 2 — configuration error):
  → Do NOT treat as a test failure
  → Escalate to Platform Lead immediately
  → Do NOT auto-retry more than 1 time (masks real infra issues)
```
