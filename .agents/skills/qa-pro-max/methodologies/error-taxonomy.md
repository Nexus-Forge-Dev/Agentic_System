# Error Taxonomy — Testing Every Error Type
# .agents/skills/qa-pro-max/methodologies/error-taxonomy.md
#
# Used by: All QA agents
# Read during: error path test design phase

---

## WHY AN ERROR TAXONOMY

Without a systematic taxonomy, agents test "the obvious errors" and skip the rest.
This taxonomy defines 8 error types. Every test suite must cover
each applicable type — not just the happy path and one error scenario.

---

## ERROR TYPE 1 — tool_failure

```
Definition: An infrastructure tool call fails (file I/O, shell command, external process)

Scenarios to test:
  → File read fails (permission denied, file not found)
  → Shell command exits non-zero
  → Binary execution times out

Expected behavior:
  → Error surfaced with type=tool_failure
  → Operation rolled back (no partial state)
  → Error NOT silently swallowed
  → Logged to audit.jsonl with context

Assertion:
  → Result message contains error type and specific tool that failed
  → DB unchanged from pre-operation state
  → Audit log entry present
```

---

## ERROR TYPE 2 — permission_denied

```
Definition: Action attempted beyond the agent's or user's permission tier

Scenarios to test:
  → Tier 2 action attempted without human approval
  → User with role=viewer attempts write operation
  → Cross-tenant resource access attempt
  → Admin action attempted by non-admin

Expected behavior:
  → Action blocked immediately
  → 403 returned (not 401, not 500)
  → Error logged to audit.jsonl
  → No partial execution occurred

Assertion:
  → HTTP 403 response
  → Response body does not reveal the existence of the resource (if hidden)
  → DB unchanged
  → Audit log records the denied attempt with actor and resource
```

---

## ERROR TYPE 3 — invalid_state

```
Definition: Required precondition not met; system is in wrong state for the operation

Scenarios to test:
  → Cancel an already-completed order
  → Publish a draft that is missing required fields
  → Confirm a payment that was already refunded
  → Delete a resource that has active dependencies

Expected behavior:
  → 409 Conflict or 422 Unprocessable Entity (per project convention)
  → Error message describes the invalid state transition
  → System remains in original state (no partial change)

Assertion:
  → Correct status code (409 or 422 — not 500)
  → Response body describes the constraint violated
  → DB row unchanged (status field not modified)
```

---

## ERROR TYPE 4 — external_api_error

```
Definition: Third-party or downstream service returns an error or is unavailable

Scenarios to test:
  → External API returns 500
  → External API returns 429 (rate limited)
  → External API times out (connection timeout)
  → External API returns malformed/unexpected response
  → External API unreachable (DNS failure, connection refused)

Expected behavior:
  → Retry with exponential backoff for transient errors (500, 429, timeout)
  → No retry for permanent errors (400, 401, 404 from external API)
  → Final failure surfaced as 502 Bad Gateway or 503 Service Unavailable (not 500)
  → Error logged with external API name, status code, and response

Assertion:
  → Client receives 502 or 503 (not the raw external error)
  → Retry count visible in logs (exponential backoff confirmed)
  → Circuit breaker state tracked (if circuit breaker is used)
  → No external API credentials exposed in error response
```

---

## ERROR TYPE 5 — context_overflow / timeout

```
Definition: Operation exceeds time or resource limits

Scenarios to test:
  → Request processing exceeds timeout threshold
  → Database query exceeds query timeout
  → Worker job exceeds max execution time
  → Large payload exceeds request size limit

Expected behavior:
  → 408 Request Timeout or 504 Gateway Timeout (not 500)
  → Worker job: moved to DLQ or retried (not silently abandoned)
  → DB query: statement_timeout triggered, transaction rolled back
  → Large payload: 413 Payload Too Large with size limit in response

Assertion:
  → Correct timeout status code
  → DB transaction rolled back (no partial write)
  → Operation logged with duration and timeout threshold
  → Memory and CPU released after timeout (no leak)
```

---

## ERROR TYPE 6 — logic_error / contradiction

```
Definition: Inputs or state are internally inconsistent or contradictory

Scenarios to test:
  → end_date before start_date
  → quantity = -5
  → discount_percent = 150
  → total != sum of line items

Expected behavior:
  → 422 Unprocessable Entity
  → Error message identifies the specific contradiction
  → No guessing or auto-correction (log the contradiction, reject the request)

Assertion:
  → 422 status
  → Response body names the contradicting fields
  → DB not modified
```

---

## ERROR TYPE 7 — ambiguous_instruction

```
Definition: Request is valid syntax but intent is unclear or contradictory

Scenarios to test (for agent commands):
  → Conflicting requirements in task spec
  → Underspecified requirement with multiple valid interpretations

Expected behavior:
  → Agent reports BLOCKED with specific ambiguity described
  → Agent does NOT pick one interpretation silently
  → Agent asks for clarification before proceeding

For API endpoints:
  → Request with mutually exclusive filter parameters
  → Expected behavior: 400 with description of conflict
```

---

## ERROR TYPE 8 — missing_dependency

```
Definition: Required environment, service, file, or configuration is absent

Scenarios to test:
  → Required environment variable not set
  → Required downstream service not reachable
  → Required file/config missing
  → Required DB table missing (migration not run)

Expected behavior:
  → Application fails with descriptive startup error (not cryptic null reference)
  → Error names the specific missing dependency
  → Application does NOT start partially (fail fast at startup)
  → For runtime discovery: return 503 with dependency name in response

Assertion:
  → Exit code non-zero on startup failure
  → Error message names the missing dependency
  → No silent fallback to incorrect behavior
```

---

## ERROR COVERAGE MATRIX

Use this matrix when reviewing test coverage for a feature:

```
Feature: _________________________

| Error Type           | Covered? | Test Name                           |
|----------------------|----------|-------------------------------------|
| tool_failure         | [ ]      |                                     |
| permission_denied    | [ ]      |                                     |
| invalid_state        | [ ]      |                                     |
| external_api_error   | [ ]      |                                     |
| context_overflow     | [ ]      |                                     |
| logic_error          | [ ]      |                                     |
| ambiguous_instruction| [ ]      | (agent context only)                |
| missing_dependency   | [ ]      |                                     |

Minimum requirement: every applicable error type has at least one test.
"N/A" is a valid entry only if the error type cannot physically occur for this feature.
```
