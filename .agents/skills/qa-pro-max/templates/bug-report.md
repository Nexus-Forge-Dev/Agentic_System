# Bug Report Template
# .agents/skills/qa-pro-max/templates/bug-report.md
#
# Use this template for every bug found during testing.
# A bug report without a state diff and replication steps is incomplete.

---

# Bug Report: [Short Description — e.g., "Order total not updated on item removal"]

**Filed by:** [agent-role]  
**Task / Session:** [task-id] / [session-id]  
**Date:** [YYYY-MM-DD]  
**Severity:** [ ] Critical  [ ] High  [ ] Medium  [ ] Low  
**Layer:** [ ] Frontend  [ ] Backend API  [ ] Database  [ ] Worker/Queue  [ ] Cache  [ ] Security

---

## Severity Definition (choose one)

```
Critical: Data loss, security breach, or complete feature unavailable in production
High:     Key user flow broken, incorrect data persisted, auth bypass possible
Medium:   Feature partially broken, workaround exists, no data loss
Low:      Minor UI issue, cosmetic, no user impact
```

---

## Replication Steps

Prerequisite state:
- [Database state or user state required before replication]
- Example: "User with id=abc exists with role=member"

Steps:
1. [Exact step — method, endpoint, payload, or UI action]
2. [Exact step]
3. [Observe result]

Example:
1. `POST /api/v1/orders { "items": [{"product_id": "xyz", "quantity": 2}] }`
2. `DELETE /api/v1/orders/{order_id}/items/{item_id}`
3. `GET /api/v1/orders/{order_id}`

---

## Expected Behavior

[What should happen — be specific about field values, status codes, DB state]

Example:
- HTTP 200 response
- `order.total_cents` = 2499 (original 4998 minus one item at 2499)
- `orders.total_cents` column in DB = 2499
- `order_items` table: 1 remaining row for order_id

---

## Actual Behavior

[What actually happened — be specific]

Example:
- HTTP 200 response
- `order.total_cents` = 4998 (NOT updated — stale total returned)
- `orders.total_cents` column in DB = 4998 (NOT updated — service layer bug)
- `order_items` table: 1 remaining row (item correctly deleted)

---

## State Diff

| Dimension | Expected | Actual |
|---|---|---|
| HTTP Status | 200 | 200 |
| Response: order.total_cents | 2499 | 4998 |
| DB: orders.total_cents | 2499 | 4998 |
| DB: order_items count | 1 | 1 |
| Queue: recalculation job | enqueued | NOT enqueued |
| Audit log | action=order.item_removed | action=order.item_removed (present) |

---

## Evidence

**Error logs** (relevant lines only — no stack traces with secrets):
```
[paste relevant log lines]
```

**HTTP Request:**
```
DELETE /api/v1/orders/order-123/items/item-456
Authorization: Bearer <redacted>
```

**HTTP Response:**
```json
{
  "id": "order-123",
  "total_cents": 4998,
  "items": [...]
}
```

**Screenshot / Recording:**  
[Path if UI issue: /artifacts/screenshots/<filename>.png]

**Database query result:**
```sql
SELECT id, total_cents FROM orders WHERE id = 'order-123';
-- Result: { id: 'order-123', total_cents: 4998 }
```

---

## Root Cause Hypothesis

[Agent's best hypothesis of where the bug originates]

Example:
"The `removeOrderItem` service function deletes the order_item row but does not recalculate and update `orders.total_cents`. The total recalculation is only triggered in `createOrder` and `addOrderItem` but was not implemented in the remove path."

---

## Regression Test

A regression test must be added before this bug is considered resolved.

**Test name:** `"should recalculate order total when an item is removed"`  
**Test file:** `[where it should live]`  
**Assertion:**
```javascript
// After removing item:
const order = await db.orders.findUnique({ where: { id: orderId } })
expect(order.total_cents).toBe(2499)  // Not 4998
```

**Acceptance criterion:**
This regression test must pass before the issue is closed.
The test must fail on the current (buggy) code to confirm it catches the regression.

---

## Rollback / Mitigation

**Immediate mitigation (if critical/high):**  
[What can be done right now to reduce impact — e.g., "Revert commit abc1234"]

**Data fix required:**  
[ ] Yes — affected records: [description of data that needs fixing]  
[ ] No — bug was caught before reaching production

**Data fix script:**  
[If yes: SQL or script to correct affected data — reviewed by human before execution]
