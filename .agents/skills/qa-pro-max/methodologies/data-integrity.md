# Data Integrity Testing Methodology
# .agents/skills/qa-pro-max/methodologies/data-integrity.md
#
# Used by: sdet, database-engineer
# Activated by: /dataaudit, /e2e DB assertion phase

---

## WHY DATA INTEGRITY TESTING

HTTP tests tell you the application responded correctly.
Data integrity tests tell you the DATABASE is in the correct state.

These are different things. A 200 response can mask:
  → A transaction that committed only half its writes
  → An orphaned record (child exists without parent)
  → A constraint violation silently caught by ORM
  → An audit log entry that was never written
  → A soft-deleted record still being served in queries

Every critical user action must have a data integrity assertion.

---

## THE FIVE INTEGRITY PILLARS

### PILLAR 1 — Correctness

```
Every write must produce the exact expected DB state.

Assertion pattern:
  AFTER the operation:
  1. Query the affected table directly
  2. Assert the specific row exists
  3. Assert every written field has the expected value (not just existence)
  4. Assert count (no extra/missing rows)

Example:
  Action: POST /api/orders { items: [{product_id: 'abc', quantity: 2}], total_cents: 4998 }

  Assert:
    orders table: 1 new row
      status = 'pending'
      total_cents = 4998
      user_id = <authenticated user>
      created_at BETWEEN now() - 5s AND now()

    order_items table: 1 new row
      order_id = <new order's id>
      product_id = 'abc'
      quantity = 2
      unit_price_cents = 2499

    inventory table: 1 updated row
      product_id = 'abc'
      quantity decreased by 2
```

### PILLAR 2 — Atomicity

```
Operations that span multiple tables must succeed entirely or fail entirely.

Test pattern:
  1. Set up a scenario where the operation will fail mid-way
     (e.g., second INSERT violates a constraint)
  2. Execute the operation
  3. Expect an error response
  4. Assert ALL writes were rolled back:
     → First table: row NOT created
     → Second table: row NOT created (even though first write would have succeeded)

Anti-pattern:
  The "partial commit" — first write succeeds, second fails, first not rolled back.
  This leaves orphaned/inconsistent data.

How to simulate failure:
  → Trigger a DB constraint violation on the N-th write in a sequence
  → Use a mock that throws after N-th call
  → Use a test transaction that is rolled back to verify pre-state
```

### PILLAR 3 — Audit Completeness

```
Every state change must produce an audit_log entry.

State changes requiring audit:
  □ Create (user, order, resource)
  □ Update (any field change)
  □ Delete (soft or hard)
  □ Status transition (draft → published, pending → confirmed)
  □ Permission change (role assignment)
  □ Authentication event (login, logout, token refresh, failed login)
  □ Administrative action (impersonation, data export, config change)

Audit entry assertions:
  □ action: matches expected action type
  □ actor_id: matches authenticated user performing the action
  □ resource_type: correct (e.g., "user", "order")
  □ resource_id: matches the affected resource's ID
  □ before_state: previous field values (for updates)
  □ after_state: new field values (for updates)
  □ timestamp: within last 5 seconds
  □ ip_address: recorded (for user-facing actions)
  □ request_id: matches X-Request-ID header

No audit entry for a state change is a DATA INTEGRITY FAILURE.
```

### PILLAR 4 — Referential Integrity

```
No orphaned records allowed.

Assertions after every delete or create:
  → Parent deleted → children handled per cascade rule (deleted/nulled/blocked)
  → No record references a non-existent parent
  → No junction table rows referencing deleted entities
  → No soft-deleted entity referenced in active records (unless intentional — document it)

Regular /dataaudit checks:
  → Query for orphaned records across all defined FK relationships
  → Run on schedule (weekly) and before each major release
  → Orphan count: 0 is the expected baseline

Example orphan detection query:
  SELECT oi.id FROM order_items oi
  LEFT JOIN orders o ON oi.order_id = o.id
  WHERE o.id IS NULL;
  -- Expected: 0 rows
```

### PILLAR 5 — Consistency Under Concurrency

```
Race conditions produce data inconsistency.

Concurrent operation patterns to test:
  WRITE-WRITE conflict:
    Two requests simultaneously update the same row
    → One wins, one gets 409 (optimistic lock) or one is serialized
    → Final state: exactly one of the two writes (not a blend)

  READ-MODIFY-WRITE:
    Two requests simultaneously read quantity=10, both decrement by 1
    → Expected: quantity = 8 (two decrements)
    → Without serialization: quantity = 9 (lost update — one decrement ignored)
    → Test: run two requests concurrently, assert final value = 8

  DUPLICATE CREATE:
    Two requests simultaneously create a user with the same email
    → Expected: one succeeds (201), one fails (409)
    → Without unique constraint: two users with same email (data corruption)

How to test concurrency:
  → Run N requests simultaneously using concurrent test execution
  → Assert final DB state reflects ALL operations (not just last)
  → Assert no intermediate state was persisted (atomicity holds)
```

---

## DATA AUDIT PROCEDURE (/dataaudit command)

```
Step 1 — Orphan Detection
  Run orphan queries for every FK relationship in the schema
  Expected: 0 orphaned records
  If orphans found: log them, report to Quality Lead, do NOT delete without investigation

Step 2 — Constraint Verification
  Verify all unique constraints are still satisfied
  (Run: SELECT email, COUNT(*) FROM users GROUP BY email HAVING COUNT(*) > 1)
  Expected: 0 violations

Step 3 — Soft Delete Consistency
  Verify no soft-deleted records referenced in active data
  (Run: SELECT * FROM orders WHERE user_id IN (SELECT id FROM users WHERE deleted_at IS NOT NULL))
  If violations found: report — do not auto-fix

Step 4 — Audit Log Completeness
  For a time window (last 24h): compare action counts in audit_log vs actual writes
  (If 1000 orders created but only 990 audit entries → 10 entries missing)
  Expected: audit log count = actual write count

Step 5 — Sequence/Counter Integrity
  Verify any manually-managed sequences or counters are correct
  (Order number sequences, invoice number sequences)

Step 6 — Generate Report
  Write to: .agents/reports/dataaudit-<timestamp>.md
  Include: check name, expected, actual, pass/fail, orphan counts
```

---

## ANTI-PATTERNS (HARD BLOCKS)

```
❌ Never assert data integrity only via HTTP response — query DB directly
❌ Never skip audit log assertions on state-changing operations
❌ Never use SELECT * to detect orphans — write explicit FK-join queries
❌ Never auto-delete orphaned records without investigation (they indicate a bug)
❌ Never run /dataaudit in write mode against production — read-only assertions only
❌ Never assume ORM cascade rules are correct — test them at DB level
```
