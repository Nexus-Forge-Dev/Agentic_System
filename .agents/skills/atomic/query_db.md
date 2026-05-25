# Atomic Skill: query_db
# .agents/skills/atomic/query_db.md
# Type: General-Purpose Primitive
# Available to: QA Automation Engineer, Database Engineer, Backend Architect
# Permission Tier: 1 for SELECT | 2 for INSERT/UPDATE/DELETE | 3 for DROP/TRUNCATE

---

## Purpose
Execute a SQL query against the project database. Default mode is read-only
(SELECT). All write operations require Tier 2 human approval. Used for:
validating data state in E2E tests, auditing integrity, checking migration results.

> **Rule**: Agents never construct queries with string interpolation.
> ALL values use parameterized placeholders — no exceptions.

---

## Inputs

| Field | Required | Description |
|-------|----------|-------------|
| `query` | ✅ | SQL query string — use `$1`, `$2` placeholders for values |
| `params` | Optional | Array of values for placeholders: `["value1", 42]` |
| `database` | Optional | Target: `local` \| `staging` \| `production`. Default: `local` |
| `timeout_ms` | Optional | Query timeout. Default: 5000 |
| `explain` | Optional | If true: run EXPLAIN ANALYZE first, return plan. Default: false |
| `purpose` | ✅ | One-sentence description of why this query is needed |

---

## Permission Gates by Operation

```
SELECT      → Tier 1 (auto-approved for local/staging)
             Tier 2 (require approval for production — always)

INSERT      → Tier 2 (require approval — all environments)
UPDATE      → Tier 2 (require approval — all environments)
DELETE      → Tier 2 (require approval) + must have WHERE clause
             Tier 3 if no WHERE clause (DELETE without WHERE = BLOCKED)

DROP        → Tier 3 (BLOCKED — always. Use migration pipeline)
TRUNCATE    → Tier 3 (BLOCKED — always. Use migration pipeline)
ALTER       → Tier 3 (BLOCKED — use migration pipeline)
```

---

## Approval Prompt for Tier 2

```
╔══════════════════════════════════════════════════════╗
║  DATABASE WRITE APPROVAL REQUIRED (Tier 2)           ║
╠══════════════════════════════════════════════════════╣
║  Database:  <local | staging | production>           ║
║  Operation: <INSERT | UPDATE | DELETE>               ║
║  Table:     <table name>                             ║
║  Query:     <full query with placeholder markers>    ║
║  Params:    <param values>                           ║
║  Purpose:   <purpose>                               ║
║  Estimated rows affected: <EXPLAIN result if known>  ║
╚══════════════════════════════════════════════════════╝
Approve? [y/n]
```

---

## Execution Protocol

```
PRE-FLIGHT:
  Classify query type (SELECT/INSERT/UPDATE/DELETE/DDL)
  Check permission tier for operation × database combination
  If Tier 2 → present approval prompt → wait for user
  If Tier 3 → BLOCKED immediately, log, return error
  Check: parameterized? (if literal values in WHERE → BLOCKED with message)

IF explain=true:
  Run EXPLAIN ANALYZE first
  Return plan + warn if: Seq Scan on large table, nested loops, high cost

EXECUTE:
  Run query with parameterized binding (never string interpolation)
  Record: rows returned/affected, query duration_ms

LOG to audit.jsonl:
  {
    "action_type": "db_query",
    "operation": "SELECT | INSERT | ...",
    "table": "<table>",
    "database": "<env>",
    "permission_tier": <N>,
    "approved_by": "auto | user",
    "rows_affected": <N>,
    "duration_ms": <N>,
    "purpose": "<purpose>"
  }

RETURN:
  {
    rows:          [{ ... }],    // for SELECT
    rows_affected: <N>,          // for writes
    duration_ms:   <N>,
    explain_plan:  "...",        // if explain=true
    query:         "<query>",
    params:        [...]
  }
```

---

## Usage Examples

```
# Check user exists after E2E signup flow
query_db(
  query="SELECT id, email, created_at FROM users WHERE email = $1",
  params=["test@example.com"],
  purpose="Verify test user was created by E2E signup test"
)

# Count records in a table after seed
query_db(
  query="SELECT COUNT(*) as total FROM products WHERE active = $1",
  params=[true],
  purpose="Confirm seed data loaded 100 products"
)

# Check migration applied (read-only schema inspect)
query_db(
  query="SELECT column_name, data_type FROM information_schema.columns WHERE table_name = $1",
  params=["users"],
  purpose="Verify new 'last_login_at' column was added by migration"
)

# Explain a slow query before optimizing
query_db(
  query="SELECT * FROM orders o JOIN users u ON o.user_id = u.id WHERE o.status = $1",
  params=["pending"],
  explain=true,
  purpose="Identify why orders list page is slow"
)
```
