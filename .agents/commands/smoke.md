# Command: /smoke
# .agents/commands/smoke.md
# Owner: QA Automation Engineer
# Trigger: /smoke — runs automatically after every /deploy

## Purpose
Fast post-deploy verification. Critical paths only. Must complete in < 5 minutes.
If smoke fails → automatic rollback (no manual decision required).

## Smoke Test Scenarios (run in order, stop on first failure)
1. Service health endpoint: GET /health → HTTP 200 + JSON { status: "ok" }
2. Authentication: POST /api/auth/login with valid credentials → HTTP 200 + token
3. Core feature (most critical user action for this service): execute it → HTTP 2xx
4. Database connectivity: verify service can read from DB (one simple read query)
5. External dependency ping: verify primary third-party service is reachable

## Output
```
/smoke — <timestamp> — <environment>
=====================================
Health endpoint:    ✅ 200 OK (23ms)
Authentication:     ✅ Token issued (140ms)
Core action:        ✅ Success (89ms)
DB connectivity:    ✅ Connected (12ms)
External deps:      ✅ Stripe API reachable (200ms)

RESULT: ✅ PASS — Deploy is live and healthy
```

## On Failure
```
Authentication:     ❌ FAILED — 500 Internal Server Error
RESULT: ❌ FAIL — Triggering automatic rollback
```

Immediately trigger Platform Lead → rollback sequence.
File GitHub issue: "smoke test failed after deploy to <env> at <ts>"
