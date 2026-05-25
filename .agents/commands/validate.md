# Command: /validate
# .agents/commands/validate.md
# Owner: QA Automation Engineer
# Trigger: /validate "<feature>" "<acceptance criteria>"

## Purpose
Validates a specific feature end-to-end against stated acceptance criteria.
More targeted than /e2e (one feature) but deeper than /smoke (verifies acceptance criteria).

## Workflow
```
STEP 1 — Parse acceptance criteria
  Read the AC statements (user stories or bullet list)
  Convert each AC to a specific, verifiable assertion

STEP 2 — Seed test data (/seed)
  Seed the specific data needed for this feature validation

STEP 3 — Execute validation
  For each AC:
    - Execute the user flow that exercises it
    - Assert the expected outcome (HTTP, UI, DB, side effect)
    - Mark: PASS | FAIL with exact evidence

STEP 4 — Teardown (/teardown)

STEP 5 — Report
  .agents/reports/validate-<feature>-<ts>.md
  AC-by-AC pass/fail table
  Verdict: ALL PASS | PARTIAL (<N>/<M> passed) | FAIL
```
