# Command: /e2e
# .agents/commands/e2e.md
# Owner: QA Automation Engineer
# Trigger: /e2e ["<feature>" | --all] — runs before /ship

---

## Purpose
Full black-box end-to-end validation. Tests the SYSTEM, not units.
Verifies DB state, API contracts, business rules, and all side effects.

---

## Workflow

```
STEP 1 — Seed test environment
  Run /seed with the required test scenario data
  Verify seed succeeded (check DB row counts match expectation)

STEP 2 — Execute E2E flows via Playwright
  For each user journey defined for this feature:

    HAPPY PATH:
      - Execute the full user journey (login → action → result)
      - Assert HTTP response codes at each step
      - Assert UI state changes where applicable

    AFTER EACH FLOW — DB State Assertions:
      - Query DB directly (using query_db primitive)
      - Assert exact row counts, field values, relationships
      - Assert no orphaned records created
      Examples:
        ✅ users.last_login updated within last 5 seconds
        ✅ orders.status = 'confirmed' for this order_id
        ✅ audit_log has entry for this action with correct userId
        ✅ inventory.quantity decreased by the correct amount

    SIDE EFFECT ASSERTIONS:
      - Events: check event queue / message broker for expected events
      - Emails: check email queue / mock SMTP for scheduled emails
      - Cache: verify cache was invalidated where expected
      - Audit: verify audit.jsonl (application-level) was written

    ERROR PATHS:
      - Test at least 2 error scenarios per feature
      - Verify error responses are correct (status code, message, no stack leak)
      - Verify DB was NOT modified on error paths (rollback verification)

STEP 3 — API Contract Tests (via /contract)
  Validate request schema against OpenAPI spec
  Validate response schema against OpenAPI spec
  Flag any drift between implementation and spec

STEP 4 — Generate report
  Write to: .agents/reports/e2e-<ts>.md
  Include:
    - Flows tested: X passed, Y failed
    - DB assertions: X passed, Y failed
    - Side effect assertions: X passed, Y failed
    - Contract violations: list
    - Overall verdict: PASS | FAIL

STEP 5 — Teardown
  Run /teardown to remove test data
  Verify DB is back to baseline state
```

---

## Output Artifacts
- `.agents/reports/e2e-<ts>.md` — full E2E report with pass/fail per assertion

---

## Guardrails
- Always run against a REAL environment — never mocked
- DB assertions are mandatory — HTTP codes alone are insufficient
- If teardown fails → BLOCKED, do not leave dirty test data in DB
- Any E2E failure → BLOCKED for /ship (cannot ship a broken system)
