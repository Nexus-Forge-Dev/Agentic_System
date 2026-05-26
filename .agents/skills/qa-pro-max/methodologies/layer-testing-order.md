# Layer Testing Execution Order
# .agents/skills/qa-pro-max/methodologies/layer-testing-order.md
#
# WHY ORDER MATTERS:
# Testing outside-in (E2E first) wastes time — you find the same bug in 5 places.
# Testing inside-out (unit first) misses integration failures.
# This prescribed order maximizes signal while minimizing wasted test runs.

---

## THE PRESCRIBED ORDER

```
LAYER 1 — DATABASE
  What: Schema constraints, RLS policies, transaction integrity, migration correctness
  Why first: Fastest feedback loop. If data model is wrong, everything above it is wrong.
  Checklist: checklists/database.md
  Tools: direct psql queries, migration test runner
  Estimated time: < 2 minutes

LAYER 2 — UNIT / SERVICE
  What: Pure business logic, no I/O, no external dependencies
  Why: Isolated, deterministic, fast. Catches logic errors cheaply.
  Checklist: methodologies/tdd-protocol.md → methodologies/boundary-analysis.md
  Tools: unit test runner (project-specific)
  Estimated time: < 5 minutes

LAYER 3 — INTEGRATION
  What: Service + Database + Cache together (real dependencies, no HTTP boundary)
  Why: Catches ORM misconfigurations, RLS violations, cache key collisions
  Checklist: relevant sections of checklists/backend.md + checklists/database.md
  Tools: integration test runner with real DB and Redis (not mocks)
  Estimated time: 5–15 minutes

LAYER 4 — API CONTRACT
  What: HTTP boundary — request schema, response schema, auth boundaries
  Why: Validates the public interface before E2E (cheaper than full journey tests)
  Checklist: checklists/backend.md + methodologies/contract-testing.md
  Tools: contract test runner, OpenAPI validator
  Estimated time: 5–10 minutes

LAYER 5 — WORKER / QUEUE
  What: Async job idempotency, retry behavior, DLQ routing, saturation
  Why: Async failures are invisible in E2E — must be tested at queue boundary
  Checklist: checklists/workers-queues.md
  Tools: queue test harness with real queue (not mock)
  Estimated time: 5–15 minutes

LAYER 6 — END-TO-END
  What: Full user journey through UI → API → DB → Queue → side effects
  Why: Validates the integrated whole. Most expensive — run last.
  Checklist: checklists/frontend.md + checklists/backend.md + DB state assertions
  Tools: browser automation (project-specific)
  Estimated time: 15–60 minutes

LAYER 7 — PERFORMANCE (dedicated pipeline — not on every PR)
  What: Load, spike, soak, saturation scenarios
  Why: Requires sustained execution time — cost-prohibitive on every PR
  Checklist: checklists/workers-queues.md + methodologies/load-testing.md
  Trigger: main branch merge, pre-production deploy, explicit /benchmark command
  Estimated time: 30–120 minutes

LAYER 8 — SECURITY (parallel with layers 1–6)
  What: SAST, dependency audit, OWASP checks
  Why: Parallelizable — does not depend on other layers
  Checklist: checklists/security.md
  Tools: SAST scanner, npm/pnpm audit, container scanner
  Estimated time: 5–15 minutes (parallel)
```

---

## EARLY TERMINATION RULE

```
IF Layer N fails → fix it BEFORE running Layer N+1.

Running E2E tests against broken business logic produces misleading results.
Running performance tests against broken integrations wastes time.

Exception: Layer 8 (security) runs in parallel and is never blocked by other layers.
```

---

## CONTEXT OPTIMIZATION RULE

```
Agents load only the checklist for the CURRENT layer being tested.
Do not load all checklists simultaneously.

Example for Layer 3 (Integration):
  ✅ Load: checklists/backend.md + checklists/database.md
  ❌ Do not load: checklists/frontend.md, checklists/workers-queues.md

This mirrors ui-ux-pro-max's pattern of loading only the matched industry row,
not all 161 industry rules.
```

---

## DECISION MATRIX — WHICH LAYERS TO RUN

```
PR on feature branch:       Layers 1–6 + Layer 8 (parallel)
PR on security fix:         Layers 1–4 + Layer 8 (focus on auth boundaries)
Merge to main:              All layers including Layer 7
Pre-production deploy:      All layers including Layer 7 + chaos scenarios
Hotfix:                     Layer 1 + Layer 4 + Layer 6 (expedited path)
Database migration only:    Layer 1 + Layer 3 (schema + integration)
Worker/queue change only:   Layer 5 + Layer 3
/dataaudit command:         Layer 1 only
/contract command:          Layer 4 only
```
