# Command: /review
# .agents/commands/review.md
# Owner: Orchestrator (Security Engineer runs in parallel)
# Trigger: /review (runs automatically before /ship; can also be run standalone)

---

## Purpose
Score staged changes on 6 quality axes. Minimum 8.0/10 weighted average
to proceed. Security Engineer runs in parallel — always, no exceptions.

---

## Workflow

```
STEP 1 — Get the diff
  Run: git diff HEAD (or git diff <base>..<head> for a specific range)
  If no changes staged → return BLOCKED "Nothing to review"

STEP 2 — Security Engineer (parallel, mandatory)
  Activate Security Engineer with the diff
  Security Engineer runs OWASP Top 10 checklist
  Security Engineer returns: { findings: [...], severity: CLEAR|LOW|MEDIUM|HIGH|CRITICAL }
  If CRITICAL finding → immediately return FAILED, do not score other axes

STEP 3 — Score all 6 axes (0-10 each)
  CORRECTNESS (25%):
    - Does the code logically do what the task description requires?
    - Are all edge cases handled?
    - Does it match the failing test specs?

  SECURITY (20%):
    - Security Engineer's report (integrate findings here)
    - No secrets/credentials in code or comments
    - Input validation at boundaries
    - No OWASP Top 10 violations

  PERFORMANCE (15%):
    - No N+1 query patterns
    - No unbounded loops over large datasets
    - No synchronous blocking operations in async contexts
    - No unnecessary re-renders (for frontend)

  CODE STYLE (15%):
    - Follows PROJECT.md naming conventions
    - No dead code, commented-out blocks, or debug statements
    - Functions/methods are focused (< 50 lines rule of thumb)
    - Consistent with surrounding codebase patterns

  TEST COVERAGE (15%):
    - Coverage did not decrease on any modified file
    - New features have corresponding tests
    - Tests are meaningful (not testing mocks)

  DOCUMENTATION (10%):
    - New public functions/methods have JSDoc/docstrings
    - New API endpoints have OpenAPI spec entries
    - README updated if public interface changed
    - Complex logic has inline comments explaining WHY

STEP 4 — Compute weighted score
  score = (correctness * 0.25) + (security * 0.20) + (performance * 0.15)
        + (style * 0.15) + (coverage * 0.15) + (docs * 0.10)

STEP 5 — Decision
  IF score >= 8.0 AND security = CLEAR or LOW:
    → APPROVED: GitHub MCP creates PR with score in description
  ELSE:
    → REMEDIATION REQUIRED: return specific items per failing axis
    → List exact files + line numbers where issues are found
    → Do NOT create the PR
    → Route remediation items back to Engineering Lead
```

---

## Output Format

```
/review RESULT
==============
Score: 8.7/10  ✅ APPROVED

Correctness:   9/10  (25%) — All edge cases handled
Security:      9/10  (20%) — OWASP CLEAR, no secrets found
Performance:   8/10  (15%) — No N+1, acceptable complexity
Code Style:    9/10  (15%) — Consistent with codebase
Test Coverage: 8/10  (15%) — Coverage maintained, tests meaningful
Documentation: 8/10  (10%) — JSDoc added, minor: missing @throws doc

Security Report: CLEAR (0 findings)
```

---

## Guardrails
- Security Engineer is NEVER skipped — parallel always
- Any CRITICAL security finding → immediate FAILED, no score computed
- Score is NEVER rounded up to meet the 8.0 threshold
- All axis scores and reasoning stored in `.agents/reports/review-<ts>.md`
