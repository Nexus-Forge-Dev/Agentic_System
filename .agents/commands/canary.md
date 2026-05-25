# Command: /canary
# .agents/commands/canary.md
# Owner: Incident Commander / DevOps Engineer
# Trigger: /canary — auto-runs after /land-and-deploy

## Purpose
Post-deploy health monitoring on critical production paths.
Runs at 5-minute intervals for a 30-minute window after deployment.
Catches issues that only appear under real production load.

## Monitoring Protocol
```
Duration: 30 minutes
Interval: Every 5 minutes (6 checks total)

Each check monitors:
  1. Service health endpoint → must return 200
  2. Error rate in Sentry → must not increase from baseline
  3. P95 latency → must not increase by more than 20% from pre-deploy
  4. Critical user flow → execute the primary user action end-to-end

PASS CRITERIA: All 6 checks pass → deployment declared healthy
FAIL CRITERIA: Any check fails → immediate rollback + /incident

Output after all checks:
  /canary — POST-DEPLOY MONITORING — <env>
  =========================================
  Check 1 (T+5m):   ✅ PASS — error rate: 0.01%, p95: 89ms
  Check 2 (T+10m):  ✅ PASS — error rate: 0.01%, p95: 91ms
  Check 3 (T+15m):  ✅ PASS — error rate: 0.02%, p95: 88ms
  Check 4 (T+20m):  ✅ PASS — error rate: 0.01%, p95: 87ms
  Check 5 (T+25m):  ✅ PASS — error rate: 0.01%, p95: 90ms
  Check 6 (T+30m):  ✅ PASS — error rate: 0.01%, p95: 89ms

  RESULT: ✅ DEPLOYMENT HEALTHY — monitoring complete
```
