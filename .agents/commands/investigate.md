# Command: /investigate
# .agents/commands/investigate.md
# Owner: Engineering Lead → Backend Architect (primary) / Frontend Developer / Database Engineer
# Trigger: /investigate "<bug description or Sentry link>"

---

## Purpose
Root-cause debugging. Iron law: NO FIX BEFORE HYPOTHESIS IS VERIFIED.
Every fix must be preceded by a proven hypothesis about why the bug exists.

---

## Workflow

```
INPUT: Bug description OR Sentry error URL OR reproduction steps

STEP 1 — Gather evidence
  If Sentry URL provided:
    - Fetch error trace, stack, context, frequency, affected users
  If description only:
    - Read relevant source files
    - Check git log for recent changes to affected area
    - Check audit.jsonl for recent agent actions in this area

STEP 2 — Form hypotheses
  Generate 2-3 distinct hypotheses for the root cause
  For each hypothesis:
    - State what must be true for this hypothesis to be correct
    - Identify a SPECIFIC test that would prove or disprove it
  Do NOT guess — every hypothesis needs a verification path

STEP 3 — Verify hypotheses (in order, stop at first confirmed)
  Run the specific test for hypothesis 1
  If CONFIRMED: proceed to Step 4
  If DISPROVED: run test for hypothesis 2
  If ALL disproved: form new hypotheses, repeat

STEP 4 — Write DEBUG_REPORT.md
  File: docs/DEBUG_REPORT-<bug-id>-<ts>.md
  Contents:
    - Bug: <description>
    - Root cause: <confirmed hypothesis>
    - Evidence: <what proved it>
    - Files involved: <list>
    - Proposed fix: <specific code change>
    - Test to verify fix: <how to confirm it's resolved>
    - Prevention: <how to avoid recurrence>

STEP 5 — Implement fix (only after report is written)
  Implement the minimum change that fixes the root cause
  Run the verification test from Step 4 → must pass
  Run full test suite → must not break anything

STEP 6 — Return Result Message to Engineering Lead
  { status: "SUCCESS", artifacts: ["docs/DEBUG_REPORT-...md", "src/..."], confidence: X% }
```

---

## Output Artifacts
- `docs/DEBUG_REPORT-<bug-id>-<ts>.md` — full investigation report
- Fix implementation files

---

## Guardrails
- NEVER implement a fix before hypothesis is verified (Rule: no guessing)
- If root cause cannot be determined in 2 hypothesis cycles → escalate to Orchestrator
- Performance bugs: always use benchmark before and after fix to prove improvement
- Security bugs: route immediately to Security Engineer before touching code
