# Command: /plan-scaffold
# .agents/commands/plan-scaffold.md
# Owner: Orchestrator
# Trigger: /plan-scaffold "<plan-file>"
# Source: .agents/scripts/plan-scaffold.ps1

---

## Purpose
Create the queue directory structure from a validated plan JSON file.
Creates one directory per task under `.agents/queue/<prompt_id>/<task_id>/`
with a `status.json` initialized to `pending`, and updates the v2 index.

---

## Usage
```
powershell .agents/scripts/plan-scaffold.ps1 -PlanFile "<path>" -QueueDir "path/to/queue"
```

---

## Parameters
| Param | Required | Description |
|-------|----------|-------------|
| PlanFile | Yes | Path to the plan JSON file |
| QueueDir | No | Queue directory path (default: .agents/queue) |
| Force | No | Overwrite existing queue directories |

---

## Source of Truth
All documentation lives in `.agents/scripts/plan-scaffold.ps1`.
Edit the script, then run `/sync-adapters` to regenerate this wrapper.
