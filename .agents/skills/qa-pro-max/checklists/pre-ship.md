# Pre-Ship Quality Gate Checklist
# .agents/skills/qa-pro-max/checklists/pre-ship.md
#
# Used by: quality-lead, orchestrator
# Activated by: /ship (mandatory — /ship is BLOCKED until all items pass)
#
# This is the final gate before any code reaches a protected branch.
# Every item must be explicitly verified — not assumed.

---

## CODE QUALITY

```
□ All unit tests passing: 0 failures
□ All integration tests passing: 0 failures
□ All E2E tests passing: 0 failures (or documented known-failures with approved skip)
□ Zero linter errors (warnings: review count, apply project threshold)
□ Zero type-check errors
□ Test coverage:
    No modified file dropped below its prior coverage %
    Overall: ≥ 80% line coverage
    Auth / security modules: ≥ 90% line coverage
□ No .skip or .only left in test files (CI enforces this via lint rule)
□ No coverage ignore comments added without explicit Quality Lead approval
```

---

## API & CONTRACT

```
□ OpenAPI spec updated to match implementation (no drift)
□ Contract tests passed: request and response schema match spec exactly
□ No breaking changes introduced to any public API endpoint:
    Removed fields → version bump required
    Changed field types → version bump required
    Removed endpoints → deprecation header first
□ All new endpoints:
    Have at least one contract test
    Documented in OpenAPI spec
    Included in Postman collection (if project uses one)
□ Pagination, sorting, filtering: all tested for new endpoints
```

---

## DATABASE

```
□ All new migrations:
    Idempotent (running twice does not fail)
    Rollback script verified
    Created CONCURRENTLY for any new indexes
□ No raw SQL bypassing ORM in application code (migrations excepted):
    Exception requires explicit approval with justification
□ RLS policies: all new tables have RLS policies defined and tested
□ DB state assertions: E2E test suite verified DB side effects, not just HTTP responses
□ No test data left in shared environments
```

---

## SECURITY

```
□ Zero critical CVEs in production dependencies
□ SARIF static analysis scan completed — no blocking findings
□ No secrets detected in the diff (pre-commit + CI scan both passed)
□ Auth boundary tests: all passing for affected routes
□ No new stack traces visible in any error response
□ New inputs validated at API boundary (no raw user input reaching DB/shell)
```

---

## PERFORMANCE

```
□ p95 latency for affected endpoints:
    Internal service-to-service: ≤ 250ms
    External user-facing: ≤ 500ms
□ p99 latency for all affected endpoints: ≤ 1000ms
□ No memory leak detected:
    Benchmark run memory: stable (< 5% growth per 10 min window)
□ Worker queue:
    Dead-letter queue rate: < 1% of enqueued jobs
    Queue depth: drains under normal load (no unbounded growth)
□ Database:
    No new sequential scans on tables > 10k rows introduced
    EXPLAIN ANALYZE reviewed for any new or modified queries
```

---

## OBSERVABILITY

```
□ Every new feature has at minimum:
    One success metric (counter or gauge)
    One error metric (counter)
□ Structured logging: new log statements use structured JSON format
□ No plaintext log messages in critical paths (auth, payment, data writes)
□ Alerts defined for any new failure mode introduced by this change
□ Distributed trace spans: new service calls are instrumented
```

---

## FINAL VERDICT

```
ALL ITEMS CHECKED → PASS → /ship proceeds

ANY ITEM UNCHECKED → BLOCKED
  Quality Lead must resolve blocking item before /ship
  Orchestrator receives BLOCKED Result Message with specific item(s) failing
  No partial ships — entire changeset waits for resolution

EXCEPTIONS PROCESS:
  Documented exception requires: reason + risk assessment + Quality Lead sign-off
  Exception logged to .agents/audit.jsonl with approver and timestamp
```
