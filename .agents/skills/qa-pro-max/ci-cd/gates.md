# Quality Gate Definitions
# .agents/skills/qa-pro-max/ci-cd/gates.md
#
# These are the hard thresholds that block merges and deploys.
# All gates are enforced via CI required status checks.

---

## COVERAGE GATES

```
Default modules:
  Threshold: ≥ 80% line coverage per file
  Measurement: per-file (not aggregate — aggregate can hide badly-uncovered files)
  Gate action: exit 1 if any modified file drops below its prior coverage %

Auth / security modules:
  Threshold: ≥ 90% line coverage per file (hard minimum)
  Modules in scope: files matching patterns:
    */auth/*
    */security/*
    */middleware/auth*
    */guards/*
    */permissions/*
  No exceptions without explicit Quality Lead sign-off AND Research Council review

Contract / schema validation:
  Threshold: 100% of exported schemas must have at least 1 test
  Measurement: check that every exported Zod schema, TypeScript interface,
               or OpenAPI schema has a corresponding contract test

Gate failure behavior:
  → exit 1 from coverage check
  → PR annotated with specific file(s) below threshold
  → Merge blocked
```

---

## PERFORMANCE GATES

```
API Latency (measured at p95 and p99):
  Internal service-to-service endpoints:
    p95: < 250ms  ← CI fails if any endpoint exceeds this
    p99: < 1000ms ← CI fails if any endpoint exceeds this

  External user-facing endpoints:
    p95: < 500ms  ← CI fails if any endpoint exceeds this
    p99: < 1000ms ← CI fails if any endpoint exceeds this

Memory stability (soak test):
  Growth limit: < 5% RSS growth per 10-minute window
  Gate: CI fails if growth exceeds limit at any 10-minute interval

Worker queue health:
  Dead-letter queue rate: < 1% of total enqueued jobs
  Gate: CI fails if DLQ rate exceeds 1% under load test

Database connection pool:
  Peak utilization: < 90% of max_connections
  Gate: CI fails if pool exhausted (100% utilization) at any point during load test

Baseline regression:
  p95 regression threshold: > 10% increase from baseline → CI fails
  Memory regression threshold: > 20% increase from baseline → CI fails
  Gate: Only applies when baseline.json exists; first run always passes

When to run performance gates:
  → Main branch merge (always)
  → Pre-production deploy (always)
  → Explicit /benchmark command (always)
  → PR builds: NOT by default (too expensive) — only if performance-sensitive files changed
```

---

## SECURITY GATES

```
Dependency Audit (npm/pnpm audit):
  Critical CVEs:  0 allowed → CI fails if any found
  High CVEs:      0 allowed → CI fails if any found
  Moderate CVEs:  tracked, non-blocking (warning only)
  Low CVEs:       tracked, non-blocking (informational)

SAST (Static Application Security Testing):
  SARIF upload:   mandatory for every pipeline run (even if no findings)
  Critical level: 0 allowed on protected branches → CI fails
  High level:     0 allowed on protected branches → CI fails
  Medium level:   non-blocking (warning annotation on PR)
  Low level:      non-blocking (informational)

Secrets Detection:
  Any secret detected in diff:
    Pre-commit hook: blocks commit
    CI scan: blocks merge
    Zero tolerance: no exceptions (rotate immediately if detected)

Container Image Scan (if applicable):
  Critical CVEs in base image: 0 allowed → CI fails
  Running as root in container: → CI fails
  Secrets embedded in image layers: → CI fails

Gate failure behavior:
  → exit 1 from security scan
  → SARIF result uploaded as GitHub Code Scanning finding
  → PR annotated with finding location and severity
  → Merge blocked until resolved or formally excepted (with audit log entry)
```

---

## EXCEPTIONS PROCESS

```
When a gate failure cannot be immediately resolved:

Step 1: Document the exception
  Required fields:
    → Gate name and specific check that failed
    → Root cause (why it cannot be fixed now)
    → Risk assessment (what could go wrong if exception granted)
    → Time-bound resolution plan (by what date will it be fixed)
    → Owner (who is responsible for the fix)

Step 2: Approval
  Coverage exception: Quality Lead sign-off
  Performance exception: Quality Lead + Platform Lead sign-off
  Security exception: Quality Lead + Security Engineer sign-off (REQUIRED)

Step 3: Log to audit
  Entry logged to .agents/audit.jsonl:
    {
      "type": "gate_exception",
      "gate": "<gate name>",
      "approved_by": ["<name>", "<name>"],
      "reason": "<reason>",
      "resolution_date": "<date>",
      "ts": "<ISO timestamp>"
    }

Step 4: Track
  Exception added to .agents/reports/open-exceptions.md
  Reviewed in every /health run
  Auto-expired: any exception unresolved past resolution_date is escalated
```

---

## GATE STATUS DASHBOARD

Format used in /health output:

```
QUALITY GATES — <timestamp>
═══════════════════════════════════════════════════════
Coverage:
  Auth/security modules:  ✅ 94% (threshold: 90%)
  Default modules:        ✅ 83% (threshold: 80%)

Performance (last benchmark):
  p95 internal APIs:      ✅ 187ms (threshold: 250ms)
  p95 external APIs:      ✅ 423ms (threshold: 500ms)
  p99 all APIs:           ✅ 812ms (threshold: 1000ms)
  Memory (soak):          ✅ +1.9% growth (threshold: +5%)
  DLQ rate:               ✅ 0.3% (threshold: 1%)

Security:
  Dependency audit:       ✅ 0 critical, 0 high
  SARIF scan:             ✅ 0 blocking findings
  Secrets detection:      ✅ Clean

Open Exceptions:          ⚠️  1 (see .agents/reports/open-exceptions.md)

OVERALL: ✅ ALL GATES PASSING
```
