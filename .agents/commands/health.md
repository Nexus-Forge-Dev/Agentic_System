# Command: /health
# .agents/commands/health.md
# Owner: Quality Lead → SDET (test suite) + Platform Lead (infra checks)
# Trigger: /health

---

## Purpose
Full system health check. Runs all quality checks and infra status checks in parallel.
Produces a unified pass/fail dashboard. Used before major releases and for daily health monitoring.

---

## Workflow

```
PARALLEL GROUP 1 — Quality checks (SDET)
  Run: test suite                    → PASS/FAIL + coverage %
  Run: type-checker                  → PASS/FAIL + error count
  Run: linter                        → PASS/FAIL + warning count
  Run: dependency audit (npm audit)  → PASS / vulnerabilities found

PARALLEL GROUP 2 — Infrastructure checks (Platform Lead)
  Check: K8s pod status              → All pods RUNNING?
  Check: DB connectivity             → Can connect + respond to ping?
  Check: External service pings      → Third-party APIs responding?
  Check: Sentry error rate           → Within normal baseline?
  Check: Terraform drift             → terraform plan --detailed-exitcode

OUTPUT — Unified dashboard:

  HEALTH CHECK — <timestamp>
  ============================
  Tests:        ✅ PASS   (coverage: 87%)
  Type Check:   ✅ PASS
  Lint:         ⚠️  3 warnings (non-blocking)
  Dep Audit:    ⚠️  2 moderate, 0 critical

  K8s Pods:     ✅ All running (3/3)
  Database:     ✅ Responding (12ms)
  External APIs:✅ All responding
  Sentry:       ✅ Error rate normal (0.02%)
  Terraform:    ✅ No drift

  OVERALL: ✅ HEALTHY  (1 warning — see lint report)
```

---

## Output Artifacts
- Inline dashboard presented to user
- `.agents/reports/health-<ts>.md` — archived health check record

---

## Guardrails
- /health never modifies any files — it is read-only (Tier 1)
- Warnings are surfaced but do not block HEALTHY status
- Any FAIL → UNHEALTHY status → Orchestrator decides next action
