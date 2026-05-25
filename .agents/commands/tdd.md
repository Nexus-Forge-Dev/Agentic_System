# Command: /tdd
# .agents/commands/tdd.md
# Owner: Quality Lead → SDET → Engineering Lead → Backend Architect / Frontend Developer
# Trigger: /tdd "<feature description>"

---

## Purpose
Full TDD cycle: write failing tests first, implement to make them pass,
verify coverage didn't drop, then pass to /review.

---

## Pre-Flight (8-step)
1. READ `.agents/MANIFEST.md`
2. READ `.agents/rules/global.md`
3. READ `.agents/rules/divisions/quality.md`
4. READ `.agents/PROJECT.md` — Test Framework section
5. READ `.agents/learned.jsonl` — filter: `["testing", "tdd"]`
6. CHECK `.agents/task.md` — create task entry if not exists
7. LOG brief to `audit.jsonl`: `{"type":"brief","skill":"/tdd","files_planned":["tests/..."]}`
8. LOG activation: `{"action_type":"skill_start","skill":"/tdd"}`

---

## Workflow

```
INPUT: Feature description

PHASE 1 — Quality Lead activates SDET
  SDET reads the feature description
  SDET identifies all test scenarios:
    - Happy path
    - Edge cases (empty, null, boundary values)
    - Error cases (invalid input, network failure, auth failure)
    - Side effect verification cases (DB state, events, emails)

PHASE 2 — SDET writes failing tests
  Write test file to tests/ or __tests__/
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
    - Coverage did not decrease on any modified file
    - No new flaky tests introduced
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
