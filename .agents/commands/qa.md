# Command: /qa
# .agents/commands/qa.md
# Owner: SDET / QA Automation Engineer
# Trigger: /qa — browser-driven QA with auto-fixes

## Purpose
Browser-driven quality check. Navigate the UI, interact with forms, check console errors.
Auto-fixes simple issues found. Returns a report for complex issues.

## Workflow
```
STEP 1 — Start dev server (if not running)
STEP 2 — Launch Playwright browser session
STEP 3 — Execute the primary user flow:
  Navigate → interact → assert → record issues

For each issue found:
  - Console error: locate source → attempt fix → re-run
  - Visual misalignment: apply CSS fix → screenshot to verify
  - Form validation: check client-side AND server-side validation works
  - Broken link / 404: file as GitHub issue

STEP 4 — Report
  Print: issues found, fixes applied, issues needing manual review
  Save: .agents/reports/qa-<ts>.md
```

---

# Command: /qa-only
# .agents/commands/qa-only.md
# Owner: SDET
# Trigger: /qa-only — read-only browser QA, no file modifications

## Purpose
Same as /qa but read-only. No files modified. Produces a QA report only.
Use when you want to audit without making automatic fixes.

## Output
- `.agents/reports/qa-<ts>.md` with full list of issues found, no auto-fixes applied
