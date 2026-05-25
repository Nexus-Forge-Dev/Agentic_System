# /qa-only — Read-Only QA Report Skill
# Runs quality analysis without modifying any files
# Owner: Quality Lead → SDET | Trigger: /qa-only
# Source: agents_and_skills_design.md §8.4

---

## Preamble

1. READ `.agents/MANIFEST.md`
2. READ `.agents/rules/global.md`
3. READ `.agents/PROJECT.md`
4. READ `.agents/learned.jsonl` — tag-filter: `["qa", "testing", "coverage"]`
5. CHECK `task.md` — verify task is scoped
6. VALIDATE permissions — ALL operations must be Tier 1 (read-only, no file writes to source)
7. LOG `{"action":"skill-activate","skill":"/qa-only","ts":"<ISO>"}` → `audit.jsonl`

---

## Purpose

**`/qa-only` is read-only. It NEVER modifies source files.**

The difference from `/qa`:
| | `/qa` | `/qa-only` |
|-|-------|------------|
| Runs tests | ✅ | ✅ |
| Reports failures | ✅ | ✅ |
| Fixes failures | ✅ | ❌ — reports only |
| Modifies source files | ✅ | ❌ |
| Output | Fixed code + qa-logs.json | qa-report.md only |

Use `/qa-only` to:
- Get a health snapshot before starting new work
- Verify nothing broke without risking any changes
- Run on a PR to generate a quality report for human review

---

## Skill Flow

```
User: /qa-only
  │
  ▼
Quality Lead → delegates to SDET

SDET:
  Phase 1 — Test Suite Execution
    → run_command("npm test" or project's test command from PROJECT.md)
    → run_command("npm run lint") or equivalent
    → Capture: test results, coverage report, lint errors

  Phase 2 — Coverage Analysis
    → Parse coverage report
    → Identify: files below coverage threshold (from PROJECT.md or 80% default)
    → List: which lines/branches are uncovered

  Phase 3 — Static Analysis
    → run_command("npx tsc --noEmit") or type-checker
    → Capture: type errors by file

  Phase 4 — Report Generation
    → Write: .agents/reports/qa-report-<timestamp>.md
    → Structure (see below)
    → NO source files are modified

  Phase 5 — Return Result Message to Quality Lead
    → status: SUCCESS (even if tests fail — the skill succeeded in reporting)
    → confidence: 95%
    → artifacts: [.agents/reports/qa-report-<timestamp>.md]
    → NEXT_ACTION_RECOMMENDATION: "Run /qa to auto-fix issues" or "All green!"
```

---

## QA Report Format

```markdown
# QA Report: <ISO-8601>

## Summary
- Tests:    <passed>/<total> passed
- Coverage: <N>% (threshold: <N>%)
- Lint:     <N> errors, <N> warnings
- Types:    <N> type errors

## Test Failures
| Test | File | Error |
|------|------|-------|
| <test name> | <path> | <error message> |

## Coverage Gaps
| File | Coverage | Missing Lines |
|------|----------|--------------|
| <path> | <N>% | L12, L45-L67 |

## Lint Errors
| File | Line | Rule | Message |
|------|------|------|---------|

## Type Errors
| File | Line | Error |
|------|------|-------|

## Recommendation
<What to fix first — prioritized by severity>
```

---

## Hard Rule

`/qa-only` MUST NOT write to any source file (`.ts`, `.tsx`, `.js`, `.py`, etc.).
If an agent attempts a source file write during `/qa-only`, it is BLOCKED immediately.
Write to `.agents/reports/` only.
