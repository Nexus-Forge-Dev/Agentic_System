# Quality Division Rules
# .agents/rules/divisions/quality.md
# AUTHORITY: LAYER 3 — Division-level constraints.
# Read by: Quality Lead + all Quality specialists at session start.

---

## Hard Quality Rules (cannot be overridden by PROJECT.md)

### Test Coverage
- Coverage must NOT decrease on any modified file after a change — if it does, the change is rejected
- All new public-facing interfaces (API endpoints, exported functions, UI interactions) require at least one integration test
- Unit tests cover all business logic functions with edge cases (empty input, nulls, boundary values)

### Test Authoring
- Test names must describe the scenario precisely: `"should return 429 when rate limit exceeded"`
- Test selectors use stable `data-testid` attributes — never CSS class selectors or visible text strings
- Mocks must represent realistic data shapes — no empty objects `{}` or placeholder strings `"test"`
- Flaky tests are QUARANTINED and filed as GitHub issues — never silently retried

### TDD Protocol (when /tdd is invoked)
- Tests must be WRITTEN and must FAIL before any implementation code is written
- The failing test output must be shown in the Result Message before delegating to Engineering
- Implementation cannot begin until SDET's Result Message is received with `status: tests_written`

### E2E & System Validation
- E2E tests always run against a real environment — never mocked APIs
- DB state must be verified after every E2E flow (not just HTTP response codes)
- API contracts must be validated bidirectionally (request schema + response schema)
- Side effects must be verified: events queued, emails scheduled, cache invalidated, audit logs written

### Visual QA
- Visual regression baselines must be updated DELIBERATELY — never auto-updated by an agent
- Any visual delta > 2% pixel difference flags a review — agent does not auto-fix silently
- Screenshots saved to `.agents/screenshots/<commit-hash>-<component>-<ts>.png`

### Performance
- A performance benchmark must be run BEFORE and AFTER any change labeled as a performance fix
- No performance regression (> 10% latency increase on p95) ships to production without:
  1. A documented acceptance decision
  2. A follow-up issue filed in GitHub

---

## Quality Division Guardrails (Tier 2)

Enforced by Quality Lead before accepting specialist output:
- Coverage did not decrease (check coverage report before approving)
- No flaky tests silently swallowed
- All E2E flows verified DB state, not just HTTP codes
- Visual regression baselines only updated with explicit acknowledgment
