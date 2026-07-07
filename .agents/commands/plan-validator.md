# Command: /plan-validator
# .agents/commands/plan-validator.md
# Owner: Orchestrator
# Trigger: /plan-validator "<plan-file>"
# Source: .agents/scripts/plan-validator.ps1

---

## Purpose
Validate a plan JSON file against all 13 schema rules. Returns exit code 0 (PASS)
or 1 (FAIL) with specific rule violations listed.

---

## Usage
```
powershell .agents/scripts/plan-validator.ps1 -PlanFile "<path>"
```

---

## Parameters
| Param | Required | Description |
|-------|----------|-------------|
| PlanFile | Yes | Path to the plan JSON file |

## Validation Rules (13)
1. Schema must be `prompt-plan-v1`
2. All task IDs must be unique
3. No circular dependencies (Kahn's algorithm)
4. All dependency references must resolve to valid task IDs
5. Agent must be a valid agent role
6. Division must be a valid division name
7. Agent must belong to the assigned division
8. Risk must be LOW, MED, HIGH, or CRITICAL
9. Tasks with risk MED+ must have `brief_required: true`
10. Estimated files must be >= 1
11. Plan must have at least 1 task
12. `session_id` must be a valid ULID or `sess_` prefix
13. `prompt_id` must be a valid slug

---

## Source of Truth
All documentation lives in `.agents/scripts/plan-validator.ps1`.
Edit the script, then run `/sync-adapters` to regenerate this wrapper.
