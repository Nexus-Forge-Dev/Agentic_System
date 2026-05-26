# Command: /contract
# .agents/commands/contract.md
# Owner: QA Automation Engineer
# Trigger: /contract — runs as part of /e2e or standalone

## Purpose
Bidirectional API contract test. Validates that implementation matches OpenAPI spec
in BOTH directions: request schema and response schema.

---

## Pre-Flight Skill Loading

Before starting, load:
  1. `.agents/skills/qa-pro-max/SKILL_REGISTRY.md`
  2. `.agents/skills/qa-pro-max/methodologies/contract-testing.md` ← full contract methodology
  3. `.agents/skills/qa-pro-max/checklists/backend.md` ← API contract compliance section
  4. `.agents/skills/qa-pro-max/ci-cd/gates.md` ← contract test gate definitions

## Workflow
```
STEP 1 — Load OpenAPI spec
  Read: openapi.yaml or openapi.json from project root or docs/

STEP 2 — For each endpoint in the spec

  REQUEST validation:
    - Send request with valid body (per spec)           → expect 2xx
    - Send request with missing required field          → expect 400
    - Send request with wrong type                      → expect 400
    - Send request with extra unknown field             → verify handled

  RESPONSE validation:
    - Verify response schema matches spec exactly
    - Check all required fields are present in response
    - Check no extra undocumented fields in response (strict mode)
    - Verify error responses match error schema

STEP 3 — Report
  .agents/reports/contract-<ts>.md
  List: endpoints tested, violations found (field, expected, actual)
  Verdict: PASS | VIOLATIONS_FOUND

STEP 4 — File GitHub issues for violations
  Label: ["api-contract", "quality"]
```
