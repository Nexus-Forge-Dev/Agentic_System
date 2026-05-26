# Command: /tdd
# .agents/commands/tdd.md
# Owner: Quality Lead → SDET → Engineering Lead → Backend Architect / Frontend Developer
# Trigger: /tdd "<feature description>"

---

## Purpose
Full TDD cycle: write failing tests first, implement to make them pass,
verify coverage didn't drop, then pass to /review.

---

## Pre-Flight (9-step)
1. READ `.agents/MANIFEST.md`
2. READ `.agents/rules/global.md`
3. READ `.agents/rules/divisions/quality.md`
4. READ `.agents/skills/qa-pro-max/SKILL_REGISTRY.md` ← **qa-pro-max orientation**
5. READ `.agents/skills/qa-pro-max/methodologies/layer-testing-order.md` ← determine layers
6. READ `.agents/PROJECT.md` — Test Framework section
7. READ `.agents/learned.jsonl` — filter: `["testing", "tdd"]`
8. CHECK `.agents/task.md` — create task entry if not exists
9. LOG brief to `audit.jsonl`: `{"type":"brief","skill":"/tdd","files_planned":["tests/..."]}`

---

## Workflow

```
INPUT: Feature description

PHASE 0 — Boundary Analysis (SDET, before writing any test)
  READ `.agents/skills/qa-pro-max/methodologies/boundary-analysis.md`
  Produce Scenario Inventory:
    Category A: Happy path scenarios (minimum, maximum, all-optional)
    Category B: Boundary value scenarios (min-1, min, max, max+1 per field)
    Category C: Error cases (missing fields, wrong types, auth failures)
    Category D: Side effect verifications (DB, queue, email, cache, audit)
  READ `.agents/skills/qa-pro-max/methodologies/error-taxonomy.md`
  Complete Error Coverage Matrix — identify all applicable error types
  Return Scenario Inventory to Quality Lead before writing any test

PHASE 1 — Quality Lead activates SDET
  SDET reads the feature description
  SDET has Scenario Inventory from Phase 0
  SDET identifies test file locations and patterns from PROJECT.md

PHASE 2 — SDET writes failing tests
  Write test file to tests/ or __tests__/
  READ `.agents/skills/qa-pro-max/methodologies/tdd-protocol.md` — follow assertion patterns
  Run tests → ALL must FAIL (if any pass, the test is testing the wrong thing)
  Return Result Message to Quality Lead:
    { status: "tests_written", confidence: X%, artifacts: ["tests/..."] }
    Include: the failing test output as proof

PHASE 3 — Quality Lead reports to Orchestrator
  Orchestrator delegates to Engineering Lead

PHASE 4 — Engineering Lead activates appropriate specialist
  Backend Architect (API/service) or Frontend Developer (UI/component)
  Specialist reads failing tests — these are the specification
  Specialist implements the minimum code to make all tests pass
  Specialist runs test suite → ALL must pass
  Specialist returns Result Message:
    { status: "success", confidence: X%, artifacts: ["src/..."] }

PHASE 5 — Post-implementation quality check
  Quality Lead activates SDET to verify:
    - All tests pass
    - Coverage did not decrease on any modified file (READ ci-cd/gates.md for thresholds)
    - No new flaky tests introduced
    - Suite passes 3 consecutive runs (flaky detection)
  If coverage drops → BLOCKED, Engineering must add more tests

PHASE 6 — Orchestrator runs /review
  /review runs with Security Engineer in parallel
  Must score >= 8.0/10 to proceed to /ship
```

---

## Output Artifacts
- `tests/<feature>.test.<ext>` — the failing-then-passing test file
- `src/<service|component>/<feature>.<ext>` — the implementation
- Coverage report (terminal output, not a file)

---

## Guardrails
- Tests MUST fail before implementation begins — never skip Phase 2 verification
- No mocking of the thing being tested (mock external deps, not the subject)
- Coverage threshold: configured in PROJECT.md test framework settings
