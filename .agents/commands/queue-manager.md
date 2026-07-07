# Command: /queue-manager
# .agents/commands/queue-manager.md
# Owner: Orchestrator
# Trigger: /queue-manager -Action <action>
# Source: .agents/scripts/queue-manager.ps1

---

## Purpose
Manage the task queue — create queue items, update status, write output, archive,
and query the queue index. Supports 9 actions for full queue lifecycle management.

---

## Usage
```
powershell .agents/scripts/queue-manager.ps1 -Action <action> [-TaskId "task_001"] [-Status "in_progress"]
```

---

## Actions
| Action | Description | Key Params |
|--------|-------------|------------|
| New-QueueItem | Create a new queue entry from a brief | BriefPath, Actor |
| Set-QueueStatus | Update task status (validates transitions) | TaskId, Status |
| Get-QueueItem | Read a queue entry's status.json | TaskId |
| Write-QueueOutput | Write output to a task's output file | OutputPath, |
| Get-QueueOutput | Read a task's output | TaskId |
| Remove-QueueItem | Delete a queue entry | TaskId |
| Get-QueueIndex | Display the full queue index | - |
| Archive-QueueItem | Archive completed/failed tasks | TaskId |
| Get-PendingItems | List all pending tasks | - |

---

## Valid Status Transitions
- pending → in_progress, blocked, cancelled
- in_progress → completed, failed, blocked
- blocked → in_progress, cancelled
- completed/failed/cancelled/timed_out → (terminal states)

---

## Source of Truth
All documentation lives in `.agents/scripts/queue-manager.ps1`.
Edit the script, then run `/sync-adapters` to regenerate this wrapper.
