# TDD Protocol — Red-Green-Refactor
# .agents/skills/qa-pro-max/methodologies/tdd-protocol.md
#
# Used by: sdet
# This is the authoritative TDD execution protocol for the Quality Division.
# Extends and enriches the /tdd command definition.

---

## THE ABSOLUTE RULE

Tests MUST be written and MUST FAIL before any implementation code is written.

If you write a test and it passes before implementation: the test is wrong.
Either it's testing the wrong thing, or the implementation already exists.
Investigate — do not proceed.

---

## PHASE 0 — PRE-TDD PREPARATION (before writing any test)

```
Step 0a — Read boundary-analysis.md and produce a Scenario Inventory
  → Every test case in the red phase must appear in the inventory first
  → No ad-hoc test addition during green phase

Step 0b — Read error-taxonomy.md and complete the Error Coverage Matrix
  → Identify which error types apply to this feature
  → Add error scenarios to the inventory

Step 0c — Identify ALL side effects
  → DB writes, queue messages, emails, cache invalidation, audit log
  → Each side effect becomes an assertion in the corresponding test
  → No test asserts only a return value without checking side effects

Step 0d — Define acceptance criteria
  → Exact DB state after each operation
  → Exact response body shape for each scenario
  → Exact queue message payload for each async operation
```

---

## PHASE 1 — RED (Write Failing Tests)

```
Test naming convention:
  Format: "should [expected outcome] when [condition]"
  Examples:
    "should return 201 when user registers with valid email"
    "should return 400 when email exceeds 255 characters"
    "should return 429 when login attempted 6 times within 60 seconds"
    "should not create duplicate user when idempotency key is reused"

Test structure (AAA — Arrange, Act, Assert):
  ARRANGE:
    → Production-shaped test data (no {} or "test" placeholders)
    → Real data types, realistic lengths, real enum values
    → Database seeded to required precondition state
    → External dependencies mocked at their boundary (not deep inside)

  ACT:
    → Single operation being tested
    → One API call, one function call, one event trigger

  ASSERT:
    → Return value / HTTP response
    → AT LEAST ONE side effect (DB, queue, cache, audit log)
    → Exact values, not existence (toBe('confirmed'), not toBeTruthy())

Mock contracts:
  → Mock only external dependencies (email provider, payment gateway, third-party APIs)
  → NEVER mock the subject under test
  → NEVER mock the database in integration tests (use real DB with test transaction)
  → Mock responses must represent realistic error and success shapes

One scenario per test:
  → No multiple unrelated assertions in a single it() block
  → "should create user AND send email AND log audit" = 3 tests, not 1

No side effects between tests:
  → Each test is self-contained
  → beforeEach / afterEach cleanup database to baseline
  → No shared mutable state between tests
```

---

## PHASE 2 — RED PHASE VERIFICATION (mandatory before proceeding)

```
Run the full test suite.

ALL new tests must fail with meaningful assertion errors:
  ✅ Expected: "should return 201" → Got: "cannot read property of undefined" (implementation not written)
  ✅ Expected: DB row count = 1 → Got: 0 (service not implemented)
  ❌ Test passes before implementation → STOP. Test is wrong. Fix it.

Capture the failing output:
  → Include in Result Message to Quality Lead
  → Show: test name, failure reason, error output
  → DO NOT send Result Message without the failing test output

Specific failure patterns that indicate a bad test:
  → Test passes immediately → testing wrong thing or implementation exists
  → Test times out → async not handled correctly
  → Test fails with configuration error → setup issue (fix before proceeding)
  → Test fails with "function not defined" → correct (expected for missing implementation)
```

---

## PHASE 3 — GREEN (Implementation)

```
Engineering implements to make tests pass.
SDET's role during green phase:
  → DO NOT modify test assertions to make tests pass
  → DO report if Engineering modifies tests instead of implementing correctly
  → DO verify that the implementation matches the spec (not just the test)

Quality checks during green phase:
  → No .skip added to make suite "pass"
  → No /* c8 ignore */ added to inflate coverage
  → No test timeouts increased to mask performance issues
```

---

## PHASE 4 — REFACTOR VERIFICATION

```
After green phase:
  □ All tests still pass after refactor (no regression)
  □ No new tests added during refactor phase (only refactoring allowed)
  □ Coverage did not decrease on any modified file
  □ Suite runs consistently: 3 consecutive runs, all identical results
    → If any run differs: test is FLAKY — quarantine before proceeding

Coverage thresholds:
  □ Default modules: ≥ 80% line coverage
  □ Auth / security modules: ≥ 90% line coverage
  □ Coverage measured per-file: no file's coverage decreases from baseline

Flaky test protocol:
  → Quarantine immediately: mark with @flaky, run in isolation
  → Root cause must be identified before ship
  → Root causes: async timing, test order dependency, shared state, real clock
  → Fix: use proper async assertions, reset shared state, mock timers
```

---

## ASSERTION PATTERNS — REFERENCE

```javascript
// ✅ CORRECT: Assert exact HTTP status code AND body shape
expect(response.status).toBe(201)
expect(response.body).toMatchObject({
  id: expect.any(String),
  email: 'alice@example.com',
  role: 'member'
})

// ✅ CORRECT: Assert DB side effect
const user = await db.users.findUnique({ where: { email: 'alice@example.com' } })
expect(user).not.toBeNull()
expect(user.role).toBe('member')
expect(user.created_at).toBeBetween(now - 5000, now)

// ✅ CORRECT: Assert queue side effect
const jobs = await queue.getWaiting()
expect(jobs).toHaveLength(1)
expect(jobs[0].name).toBe('send-welcome-email')
expect(jobs[0].data.to).toBe('alice@example.com')

// ✅ CORRECT: Assert audit log side effect
const entry = await db.audit_log.findFirst({ where: { action: 'user.created' } })
expect(entry.actor_id).toBe(adminUser.id)
expect(entry.payload).toMatchObject({ email: 'alice@example.com' })

// ❌ WRONG: Asserting only existence
expect(user).not.toBeNull()  // Doesn't verify the data is correct

// ❌ WRONG: Asserting only HTTP status
expect(response.status).toBe(201)  // Doesn't verify DB state or side effects

// ❌ WRONG: Using toBeTruthy for exact values
expect(user.role).toBeTruthy()  // Passes if role = 'superadmin' — unintended
```
