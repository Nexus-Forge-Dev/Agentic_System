# Chaos Engineering Methodology
# .agents/skills/qa-pro-max/methodologies/chaos-engineering.md
#
# Used by: performance-tester, platform-lead
# Activated by: /health (post-deploy), explicit chaos scenarios

---

## PHILOSOPHY

Chaos engineering doesn't test IF your system fails.
It verifies HOW it fails — and whether that failure is predictable, observable, and recoverable.

Every production system WILL experience:
  → Network timeouts
  → Database connection drops
  → Memory pressure
  → Downstream service failures
  → Worker process crashes

Chaos tests ensure these events produce known, graceful outcomes
— not unknown cascading failures.

---

## CRITICAL RULE

```
NEVER run chaos scenarios in production without:
  1. Explicit human approval (Tier 3 operation)
  2. A defined rollback procedure
  3. An active incident-response person monitoring

All chaos scenarios in CI/CD run against a production-identical staging environment only.
```

---

## STEADY STATE HYPOTHESIS

Before injecting any failure, define what "normal" looks like:

```
For each affected endpoint/service:
  □ p95 latency baseline (measured in the 5 minutes before chaos)
  □ Expected error rate: 0% (or project-defined acceptable rate)
  □ Queue depth baseline: steady (not growing)
  □ Memory baseline: stable RSS reading

For each scenario:
  □ Define the METRIC that signals recovery
  □ Define the MAXIMUM time to recovery acceptable
  □ Define what "cascading failure" looks like (so you can HALT if it occurs)
```

---

## FAILURE SCENARIOS

### SCENARIO 1 — Database Unavailability (10 seconds)

```
Inject: Drop all PostgreSQL connections for 10 seconds
Method: Block port 5432 at network level OR kill all DB connections

Assert during failure window:
  □ API returns 503 (not 500)
  □ 503 includes Retry-After header
  □ No stack traces in 503 response body
  □ Queue jobs stop processing (wait for DB) — do NOT retry infinitely
  □ No new data written (consistent state — no partial writes)

Assert on recovery:
  □ System reconnects automatically within 30 seconds (no manual restart)
  □ Queue resumes processing without job duplication
  □ p95 latency returns to baseline within 60 seconds of DB restoration
  □ Connection pool size recovers to normal (no pool exhaustion after reconnect)

HALT condition:
  → If any write operation commits to DB while connection should be down → STOP (data integrity violation)
```

### SCENARIO 2 — Cache (Redis) Unavailability (30 seconds)

```
Inject: Make Redis unreachable for 30 seconds
Method: Block port 6379 at network level

Assert during failure window:
  □ Application falls back to DB for data that would have been cached
  □ p95 latency increases (expected) but does not breach p99 threshold
  □ Error rate remains 0% (degraded, not broken)
  □ No 5xx responses due to cache failure alone

Assert on recovery:
  □ Application reconnects to Redis automatically (no restart)
  □ Cache begins repopulating on subsequent reads
  □ p95 latency returns to baseline within 60 seconds
  □ No stale data served from Redis after recovery (correct invalidation)

HALT condition:
  → If application returns 5xx on cache failure (cache is not a required dependency)
```

### SCENARIO 3 — Worker Process Crash (mid-job)

```
Inject: Kill the worker process while a job is in-progress
Method: SIGKILL the worker process at a random point during job execution

Assert:
  □ Job returns to queue (not lost) — verifiable by checking queue state
  □ Job does not execute twice (idempotency key prevents double-write)
  □ New worker instance picks up the job and completes it
  □ Job completion side effects occur exactly once (one email, one DB row, etc.)
  □ DLQ does not receive the job (unless max retries exceeded by crash count)

Assert — new worker startup:
  □ Starts without manual intervention
  □ Picks up the in-progress job within its stall timeout window

HALT condition:
  → If job executes twice (duplicate email, duplicate DB record) → STOP (idempotency failure)
```

### SCENARIO 4 — Memory Pressure

```
Inject: Consume 80% of available system memory via external process
Method: Stress testing tool allocating memory without releasing

Assert:
  □ Application does not crash (OOM kill)
  □ Graceful degradation: new requests may be rejected (503) but app continues
  □ Existing in-flight requests complete without corruption
  □ Metrics observable and alertable during pressure
  □ Memory pressure metric emitted to monitoring

Assert on pressure removal:
  □ Application returns to normal behavior within 30 seconds
  □ No memory fragmentation persists

HALT condition:
  → If application OOM-kills → stop (review memory limits and footprint before re-running)
```

### SCENARIO 5 — Network Latency Injection (500ms on DB connection)

```
Inject: Add 500ms artificial latency to all PostgreSQL connections
Method: Traffic shaping (tc netem) or proxy latency injection

Assert:
  □ API p95 latency increases to reflect injected delay (observable)
  □ Circuit breaker trips at configured threshold (if configured)
  □ Downstream consumers receive graceful degraded response (not timeout cascade)
  □ Statement timeouts fire correctly (queries do not hang indefinitely)
  □ Connection pool does not exhaust (waiting connections are bounded)

Assert on removal:
  □ p95 returns to baseline within 60 seconds
  □ No permanently stalled connections remain

HALT condition:
  → If circuit breaker does not trip after 3x threshold violations → STOP (circuit breaker not working)
```

### SCENARIO 6 — Third-Party API Unavailability

```
Inject: Mock all responses from a third-party dependency to return 500

Assert:
  □ Application degrades gracefully (feature disabled, not full outage)
  □ Correct fallback behavior (cached result, default value, disabled feature)
  □ Error surfaced correctly: 502 or 503 with Retry-After header
  □ No secrets or internal details exposed in error response
  □ Retry logic fires with exponential backoff

Assert on recovery (mock returns 200 again):
  □ Application resumes using third-party service automatically
  □ Cached fallback values are replaced with fresh data
```

---

## HALT CONDITIONS (Global)

```
STOP immediately if any scenario causes:
  → Data loss (records missing that should exist)
  → Data duplication (records exist twice)
  → Data corruption (wrong values written)
  → Cascading failures that cannot auto-recover within 5 minutes
  → Security boundary violation (cross-tenant data exposure during failure)

On HALT:
  → Stop the chaos scenario
  → Execute rollback procedure
  → Report to Orchestrator as BLOCKED with full details
  → Human Intervention Checkpoint required before re-running
```

---

## CHAOS READINESS ASSESSMENT

Before any chaos scenario is run, verify:

```
□ Rollback procedure defined and tested
□ Monitoring is active (can observe metrics in real-time)
□ Alert channels are functional (will receive notifications during chaos)
□ DLQ monitoring is active (can observe queue state)
□ Database backup is current (taken within 24 hours)
□ Human operator is available and monitoring throughout

If any item above is not checked → DO NOT run chaos scenarios.
```
