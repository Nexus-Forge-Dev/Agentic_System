# Task DAG Schema
# .agents/rules/task-schema.md
# Authority: LAYER 1 — Task representation for all agents
# Source: agentic_system_design.md §6

---

## Task JSON Schema

Every task in the system (whether in task.md or in memory) conforms to this schema:

```json
{
  "id": "task_<ulid>",
  "goal": "One sentence: what this task accomplishes",
  "agent": "<persona-file-name-without-extension>",
  "division": "<engineering|platform|quality|design|intelligence|council>",
  "status": "pending | in_progress | done | failed | blocked | skipped",
  "risk_level": "LOW | MEDIUM | HIGH | CRITICAL",
  "brief_required": true,
  "depends_on": ["task_<ulid-of-dependency>"],
  "inputs": ["output of task_X", "path/to/input/file.ts"],
  "outputs": ["path/to/expected/output.ts", "artifact description"],
  "created": "2026-05-24T14:00:00Z",
  "started": null,
  "completed": null,
  "confidence": null,
  "drift": false,
  "notes": ""
}
```

### Field Definitions

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | ULID-prefixed with `task_`. Unique, immutable once set. |
| `goal` | string | One sentence. Precise. Includes success criterion. |
| `agent` | string | Maps to `personas/<name>.md`. e.g., `backend-architect` |
| `division` | enum | Which division owns this task. |
| `status` | enum | Current lifecycle state (see below). |
| `risk_level` | enum | Computed by risk scoring (see `/brief`). |
| `brief_required` | bool | Whether `/brief` must run before execution. |
| `depends_on` | array | Task IDs that must be `done` before this task can start. |
| `inputs` | array | What this task needs: prior task outputs or file paths. |
| `outputs` | array | What this task will produce. |
| `created` | ISO-8601 | When the Orchestrator added this task to the DAG. |
| `started` | ISO-8601 or null | When the assigned agent moved to EXECUTING. |
| `completed` | ISO-8601 or null | When the task reached `done` or `failed`. |
| `confidence` | 0–100 or null | Agent's self-assessed quality from Result Message. |
| `drift` | bool | Set to `true` if agent touched files not in the Implementation Brief. |
| `notes` | string | Agent notes, decisions made, blockers encountered. |

---

## Task Status Transitions

```
           ┌─────────┐
           │ PENDING │  ← created by Orchestrator
           └────┬────┘
                │ all dependencies done AND agent available
                ▼
           ┌───────────┐
           │ IN_PROGRESS│  ← agent moves to EXECUTING
           └────┬───────┘
                │
         ┌──────┼───────┐
         ▼      ▼        ▼
      ┌─────┐ ┌───────┐ ┌─────────┐
      │ DONE│ │BLOCKED│ │ FAILED  │
      └─────┘ └───────┘ └─────────┘
                 │           │
                 ▼           ▼
         [Orchestrator    [Orchestrator
          resolves and     decides: retry,
          re-queues]       reassign, or
                           surface to human]
```

- **PENDING** → IN_PROGRESS: When dependency tasks are done AND the assigned agent is activated
- **IN_PROGRESS** → DONE: Agent returns SUCCESS Result Message
- **IN_PROGRESS** → BLOCKED: Agent cannot proceed (missing dependency, ambiguous instruction)
- **IN_PROGRESS** → FAILED: Unrecoverable error after 2 retry attempts
- **BLOCKED** → PENDING: After Orchestrator resolves the blocker
- **FAILED** → PENDING: After Orchestrator explicitly retries (new task entry, new ULID)

---

## Task DAG Rules

1. **Orchestrator owns the DAG** — no Specialist modifies `task.md` directly
2. **Parallel tasks** = tasks with no `depends_on` overlap can be activated simultaneously
3. **Dependency order** = a task cannot move to IN_PROGRESS until all `depends_on` are DONE
4. **Cascade failure** = if a task FAILS and downstream tasks depend on it, they move to BLOCKED
5. **Maximum chain depth** = if `depends_on` chain is > 8 tasks deep, Orchestrator must review for scope creep

---

## Task Recovery Protocol (§6.3)

If a task fails:

```
1. Capture error state → write to sessions/<id>/audit.jsonl immediately
2. Check learned.jsonl for any entry matching the failure context (same tags)
3. If match found:
     → Attempt auto-recovery using the matched pattern (documented in notes)
     → Count as retry attempt #1
4. If no match OR auto-recovery fails:
     → Form a different approach hypothesis
     → Attempt retry with different approach
     → Count as retry attempt #2
5. If still failing after 2 attempts:
     → Move task to BLOCKED
     → Write Result Message to Orchestrator: status=BLOCKED, full error context
6. Orchestrator decides:
     → Re-delegate to different agent
     → Surface to human with options
     Human only sees the task if it fails after 2 auto-recovery attempts
```

---

## task.md File Format

The living task board, owned exclusively by the Orchestrator:

```markdown
## Session: <ISO-date> | Goal: <one-line session goal>
## Session ID: sess_<ulid>

---

### Active Tasks

- [/] task_<ulid> → <Agent>: <goal>  🔄 In progress (confidence: ~<N>%)
  depends_on: [task_<ulid>]

### Queued Tasks

- [ ] task_<ulid> → <Agent>: <goal>  ⏳ Waiting on: task_<ulid>

### Completed Tasks

- [x] task_<ulid> → <Agent>: <goal>  ✅ Done (<N>% conf, <N> files)

### Failed/Blocked Tasks

- [!] task_<ulid> → <Agent>: <goal>  ❌ FAILED: <brief reason>
- [~] task_<ulid> → <Agent>: <goal>  🔒 BLOCKED: <what's blocking it>
```
