# Database Integrity Testing Checklist
# .agents/skills/qa-pro-max/checklists/database.md
#
# Used by: sdet, database-engineer, qa-automation-engineer
# Activated by: /tdd, /e2e, /dataaudit

---

## TRANSACTION SAFETY

```
□ Multi-step writes are wrapped in a single transaction (atomic or nothing)
□ Simulate failure mid-transaction:
    → Full rollback verified (no partial write survives)
    → DB returned to exact prior state
□ Concurrent writes to same row:
    Optimistic lock: stale version rejected with 409
    Serializable isolation: deadlock handled gracefully (retry or 409)
□ Deadlock scenario:
    Two transactions acquiring locks in opposite order
    → Application handles gracefully (retry with backoff or surface 409)
    → No unhandled 500 on deadlock detection
□ Long-running transactions:
    No transaction held open across network I/O calls
    Connection returned to pool after each transaction completes
```

---

## ROW-LEVEL SECURITY (RLS)

```
□ Tenant A CANNOT SELECT rows belonging to Tenant B (verified at psql level)
□ Tenant A CANNOT UPDATE rows belonging to Tenant B (verified at psql level)
□ Tenant A CANNOT DELETE rows belonging to Tenant B (verified at psql level)
□ Admin bypass policy:
    Admin user CAN access cross-tenant rows when policy grants it
    Admin policy tested separately from tenant policy
□ RLS tested at DB level directly — not just through application HTTP layer:
    Connect as application DB user
    Run SELECT/UPDATE directly
    Assert RLS enforcement without app middleware
□ New table added: RLS policies written and verified before deployment
□ RLS performance: EXPLAIN ANALYZE confirms index used on tenant_id filter
```

---

## SOFT DELETES

```
□ Soft-delete sets deleted_at timestamp — row NOT physically removed
□ Standard queries exclude soft-deleted records:
    SELECT * FROM users → deleted rows NOT included
    All ORM default scopes filter deleted_at IS NULL
□ Soft-deleted records visible ONLY in:
    Admin/audit views (explicit permission required)
    Historical reports (via unscoped query)
□ Unique constraints account for soft deletes:
    email='test@test.com' can be re-used after soft delete
    UNIQUE index uses WHERE deleted_at IS NULL (partial index)
□ Cascade behavior on soft delete:
    Child records: also soft-deleted OR remain with parent_id referencing deleted parent — per spec
    Documented explicitly in migration comments
□ Hard delete audit:
    Any physical DELETE logged to audit_log before execution
```

---

## MIGRATION IDEMPOTENCY

```
□ Running the same migration twice does not fail or corrupt data
□ Rollback migration:
    Leaves schema in expected prior state
    Does not leave orphaned constraints or indexes
□ Migration user permissions:
    Migrations run as superuser (migration role)
    Application user has RLS-only access post-migration (not superuser)
□ New nullable column:
    Explicit DEFAULT value defined
    No silent nulls introduced in existing records
    Backfill script (if needed) included in migration
□ New NOT NULL column:
    Default value or backfill BEFORE constraint added
    Never adds NOT NULL constraint without default in single step
□ Index creation:
    Created CONCURRENTLY (no table lock in production migration)
    Verified index exists post-migration: \d tablename
□ Migration tested in CI on a real copy of the schema (not just SQLite mock)
```

---

## FOREIGN KEY & CONSTRAINT INTEGRITY

```
□ CASCADE rules tested:
    Parent deleted → child behavior matches defined rule (CASCADE/RESTRICT/SET NULL)
    SET NULL: child FK column set to null after parent delete
    RESTRICT: parent delete rejected when children exist → 409 at application layer
□ UNIQUE constraint:
    Duplicate insert → rejected at DB
    Application layer catches DB error → surfaces as 409 (not 500)
□ NOT NULL constraint:
    Inserting null to non-null column → rejected at DB
    Application layer catches → surfaces as 400 (not 500)
□ CHECK constraint:
    Value outside allowed range → rejected at DB
    Application layer catches → surfaces as 422 (not 500)
□ Circular references:
    If schema has self-referential FKs, defer constraint or use deferrable
```

---

## DB STATE ASSERTIONS (post every E2E flow — mandatory)

```
□ Assert exact row COUNT after writes (not just "no error")
    Example: expect(await db.query('SELECT count(*) FROM orders WHERE user_id=$1', [userId])).toBe(1)
□ Assert specific FIELD VALUES written (not just "row exists")
    Example: expect(order.status).toBe('confirmed')
    Example: expect(order.total_cents).toBe(4999)
□ Assert NO orphaned records:
    Line items exist only if parent order exists
    Profile exists only if user exists
□ Assert audit_log entry written for every state change:
    Action type matches expected
    Actor ID matches the authenticated user
    Payload contains relevant changed fields
    Timestamp within last 5 seconds
□ Assert soft delete fields correct:
    deleted_at IS NOT NULL after soft delete
    deleted_by set to correct actor ID
□ Assert created_at and updated_at timestamps are reasonable:
    created_at BETWEEN now() - interval '5 seconds' AND now()
□ Assert NO side-effect records on failed/rolled-back operations
```

---

## INDEX VALIDATION

```
□ Query plans verified for high-frequency queries:
    EXPLAIN ANALYZE used on queries run > 1000x/day
    No Seq Scan on tables with > 10k rows
    No Hash Join on critical hot paths (prefer Index Scan or Index Only Scan)
□ Pagination with large offsets:
    EXPLAIN ANALYZE on OFFSET 10000 LIMIT 20 queries
    Cursor-based pagination preferred over OFFSET for > 1000 rows
□ New query added: explain plan reviewed before merging
```

---

## ANTI-PATTERNS (HARD BLOCKS)

```
❌ Never test DB integrity via HTTP response alone — query DB directly with query_db
❌ Never run migration tests against a shared staging DB without a snapshot restore plan
❌ Never assume ORM protects against RLS bypass — test RLS at psql level
❌ Never leave test data in shared DB environments — teardown is mandatory
❌ Never add a NOT NULL column without a DEFAULT or backfill in the same migration
❌ Never create indexes without CONCURRENTLY in production migrations
❌ Never hardcode UUIDs or IDs in tests — generate them or use factory functions
```
