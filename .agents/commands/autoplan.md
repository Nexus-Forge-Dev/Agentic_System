# Command: /autoplan
# .agents/commands/autoplan.md
# Owner: Orchestrator
# Trigger: /autoplan "<goal>"

---

## Purpose
Full pre-build review sequence before ANY execution begins.
Chains: /office-hours → /plan → /brief (for all HIGH/CRITICAL tasks) → user approval.
Nothing executes until the user explicitly approves the full plan.

---

## Workflow

```
STEP 1 — /office-hours (UX Researcher)
  Challenge assumptions about the stated goal
  Define: problem, user, success metrics, MVP scope
  Output: docs/office-hours-brief.md

STEP 2 — /plan (Orchestrator)
  Decompose the refined goal into task DAG
  Risk-score all tasks
  Flag brief_required tasks

STEP 3 — /brief (for each HIGH/CRITICAL task)
  Route to assigned specialist for Implementation Brief
  Each brief documents:
    - Files to be modified (with locations)
    - Functions to be changed (with signatures)
    - Risk score on 4 dimensions
    - Rollback plan
    - Approval required? (YES for HIGH/CRITICAL)

STEP 4 — Present full plan to user
  Show: office-hours brief + task DAG + all implementation briefs
  Explicitly ask: "All briefs reviewed. Approve to begin execution? [y/n]"

STEP 5 — Execute ONLY after approval
  Proceed with task delegation in DAG order
```

---

## When to Use vs /plan
- `/plan` → quick planning when you're confident about the goal
- `/autoplan` → thorough planning when requirements are ambiguous or stakes are high
