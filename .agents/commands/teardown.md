# Command: /teardown
# .agents/commands/teardown.md
# Owner: QA Automation Engineer
# Trigger: /teardown — always runs after /e2e and /validate

## Purpose
Remove test data created during a test run. Leave DB in a clean, baseline state.
Uses the audit.jsonl seed manifest — never deletes blindly.

## Workflow
```
STEP 1 — Read seed manifest from audit.jsonl
  Find the most recent /seed entry for this session
  Read: which records were created (tables + IDs)

STEP 2 — Delete test records (in reverse FK order)
  Delete child records first, then parent records
  Use parameterized DELETE with explicit WHERE id IN (<test-ids>)
  Never DELETE without WHERE clause

STEP 3 — Verify clean state
  Count remaining rows in each seeded table
  Verify no test records remain (by checking the seed IDs)

STEP 4 — Report
  { tables_cleaned: { users: 3, orders: 5 }, db_state: "CLEAN" }
  If any records remain → BLOCKED, surface to QA Lead
```

## Guardrails
- Only deletes records listed in the seed manifest — never bulk deletes
- Verifies clean state after deletion — does not assume DELETE succeeded
- If teardown fails → BLOCKED, do not declare test run complete
