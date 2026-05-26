# Boundary Analysis Methodology
# .agents/skills/qa-pro-max/methodologies/boundary-analysis.md
#
# Used by: sdet
# Read BEFORE writing any test file — determines the complete scenario set

---

## WHY BOUNDARY ANALYSIS FIRST

Most bugs live at boundaries: the edge between valid and invalid, zero and one,
empty and non-empty, min and max. Without systematic boundary analysis,
the agent picks "obvious" test cases and misses the failures that reach production.

This methodology is read before writing a single test. It produces the scenario
inventory that drives the TDD red-phase.

---

## CATEGORY A — HAPPY PATH

```
Minimum valid input
  → The smallest/simplest input that satisfies all constraints
  → Example: name = "A" (1-character minimum)

Maximum valid input
  → The largest/most complex input within all constraints
  → Example: name = "A" × 255 (255-character maximum)

Typical/median input
  → Representative of what real users submit
  → Example: name = "Alice Johnson"

All optional fields populated
  → Verify the system handles fully-specified input

No optional fields provided
  → Verify the system handles minimal valid input
```

---

## CATEGORY B — BOUNDARY VALUES

For every numeric, string, array, date, or paginated field:

```
Numeric fields:
  → min - 1  (one below minimum) → expect rejection
  → min      (exactly minimum)   → expect acceptance
  → min + 1  (one above minimum) → expect acceptance
  → max - 1  (one below maximum) → expect acceptance
  → max      (exactly maximum)   → expect acceptance
  → max + 1  (one above maximum) → expect rejection
  → 0        (zero — often special-cased)
  → -1       (negative — if type is unsigned, expect rejection)
  → MAX_INT  (integer overflow boundary)

String fields:
  → 0 characters (empty string) → expect rejection or acceptance per spec
  → 1 character
  → max - 1 characters
  → max characters
  → max + 1 characters → expect rejection
  → Unicode: emoji, RTL text, combined characters
  → Whitespace-only string: "   " → per spec (trim or reject)

Array / collection fields:
  → Empty array []          → per spec (accept or reject)
  → Single item [x]         → accept
  → N items (at limit)      → accept
  → N+1 items (over limit)  → reject
  → Duplicate items         → per spec (deduplicate or reject)

Pagination:
  → page=1, limit=1
  → page=1, limit=max_per_page
  → page=1, limit=max_per_page+1 → reject or cap
  → page=last_page           → returns partial or empty results (not error)
  → page=last_page+1         → empty array (not 404)
  → page=0                   → per spec
  → page=-1                  → reject

Dates / timestamps:
  → Minimum allowed date
  → Maximum allowed date
  → Today's date
  → Past date (yesterday)
  → Future date (tomorrow)
  → Invalid format → 400
  → Timezone edge cases (midnight UTC, DST boundaries)
  → Leap day (February 29)
```

---

## CATEGORY C — ERROR CASES

```
Missing required fields:
  → For EACH required field: submit without it → 400 with field named in error

Wrong type:
  → String where integer expected
  → Integer where string expected
  → Array where object expected
  → Object where array expected

Null inputs:
  → null for required field → 400
  → null for optional field → per spec

Invalid enum values:
  → For every enum field: submit a value not in the enum → 400

Auth failures:
  → No token → 401
  → Expired token → 401
  → Tampered token → 401
  → Wrong role → 403
  → Wrong tenant → 403

Referenced resource not found:
  → Submit ID of non-existent resource → 404 or 422 per spec

State conflicts:
  → Submit operation that's invalid in current state (e.g., cancel completed order) → 409 or 422
```

---

## CATEGORY D — SIDE EFFECT VERIFICATION

For every write operation, identify ALL side effects that must be asserted:

```
DB writes:
  → Which table and column is written
  → What value is expected
  → What count is expected

Events / queue messages:
  → Which queue receives a message
  → What the message payload contains

Emails / notifications:
  → Which email template is sent
  → To which recipient
  → With which content

Cache invalidation:
  → Which cache key is invalidated
  → Subsequent read should be a cache miss

Audit log:
  → What action is logged
  → Who the actor is
  → What the payload contains

Cascade operations:
  → What child records are created / updated / deleted
  → What foreign key relationships are set
```

---

## SCENARIO INVENTORY OUTPUT FORMAT

After completing this analysis, produce a scenario inventory:

```
Feature: [Name]

Happy Path (3 scenarios):
  HP-1: Minimum valid input — expect 201, 1 DB row, 1 email queued
  HP-2: Maximum valid input — expect 201, 1 DB row
  HP-3: All optional fields — expect 201, all fields written to DB

Boundary Values (N scenarios):
  BV-1: name at max (255 chars) — expect 201
  BV-2: name at max+1 (256 chars) — expect 400
  BV-3: age = 0 — expect 400
  BV-4: age = 1 — expect 201
  ...

Error Cases (N scenarios):
  EC-1: Missing name — expect 400, message includes "name"
  EC-2: No auth token — expect 401
  EC-3: Wrong role (viewer) — expect 403
  ...

Side Effects (verified in HP-1 and HP-3):
  SE-1: DB users row created with correct email and role
  SE-2: welcome email queued (assert mock SMTP)
  SE-3: audit_log entry written with action=user.created
```

Use this inventory as the source of truth for the TDD red phase.
Every scenario in the inventory → exactly one test case.
