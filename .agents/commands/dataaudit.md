# Command: /dataaudit
# .agents/commands/dataaudit.md
# Owner: QA Automation Engineer
# Trigger: /dataaudit — standalone or as part of /e2e post-teardown

## Purpose
Scan database for data integrity violations. Finds problems that unit tests
cannot catch: orphaned records, broken constraints, null required fields, stale states.

## Checks Run
```
ORPHANED RECORDS:
  - order_items with no matching order_id in orders
  - session tokens for non-existent users
  - files/attachments with no owning record

CONSTRAINT VIOLATIONS:
  - Rows where FK constraint points to deleted parent (if using soft-delete)
  - Duplicate entries in unique-constrained columns
  - NULL in columns that require values per business rules (not DB constraints)

STATE INCONSISTENCIES:
  - Orders in status 'shipped' with no shipping_date
  - Users with email_verified=true but no verified_at timestamp
  - Payments in 'completed' state without a transaction_id

STALE RECORDS:
  - Sessions older than max TTL that are still 'active'
  - Password reset tokens past expiry that are still 'valid'
  - Draft records older than 30 days with no activity

OUTPUT:
  .agents/reports/dataaudit-<ts>.md
  Table: check name | count of violations | sample IDs | severity
  Verdict: CLEAN | VIOLATIONS_FOUND (with severity: LOW | MED | HIGH | CRITICAL)
```

## Guardrails
- Read-only queries ONLY (SELECT only — never UPDATE/DELETE during audit)
- Does not fix violations — surfaces them for human decision
