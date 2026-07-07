# Queue Protocol Schema
# .agents/schemas/queue.schema.md
# Defines the filesystem-based delegation queue protocol
# Replaces Task tool as the architecture center for cross-agent delegation
# Runtime-agnostic: works with OpenCode, Cursor, Antigravity, and any future runtime

---

## Purpose

The queue protocol enables **runtime-agnostic agent delegation** via a standardized
filesystem contract. Instead of calling runtime-specific APIs (Task tool, etc.),
agents communicate by writing structured JSON files to a shared queue directory.

This replaces Task tool as the delegation architecture center because:
1. **Runtime-agnostic** — works in OpenCode, Cursor, Antigravity, CLI, any harness
2. **Observable** — any tool can inspect queue state (dashboard, scripts, humans)
3. **Resumable** — queued tasks survive agent crashes, session restarts, runtime swaps
4. **Traceable** — every delegation leaves a complete filesystem audit trail
5. **Decoupled** — delegator and delegate don't need to be alive simultaneously

---

## Directory Structure

```
.agents/queue/
├── <prompt_id>/                # One directory per prompt/plan (e.g., prompt_001)
│   └── <task_id>/              # One directory per queued task (e.g., task_201)
│       ├── brief.json          # → Written by delegator, read by delegate
│       ├── status.json         # → Updated by delegate throughout lifecycle
│       ├── output.json         # → Written by delegate on completion
│       ├── context.json        # → Optional handoff packet from delegator
│       └── trace.jsonl         # → Delegate's own execution trace
├── index.json                  # → Registry of all queue entries (v2: prompt-grouped)
└── archive/                    # → Completed/failed tasks moved here after review
    └── <task_id>/              #   Same structure, preserved for audit
```

**Prompt grouping:** Tasks from one `prompt_id` are grouped under the same prompt
directory. This keeps related tasks together and prevents collisions. The prompt_id
comes from the plan file (`.agents/plans/<prompt_id>.plan.json`). For ad-hoc tasks
not part of a plan, the default prompt_id is `prompt_adhoc`.

---

## File Schemas

### brief.json — The delegation contract

Written by the delegating agent BEFORE work begins. Contains everything the
delegate needs to execute the task with zero external context.

```json
{
  "schema": "queue-brief-v1",
  "task_id": "task_003",
  "task_path": "003",
  "title": "Build Express dashboard server",
  "delegator": "orchestrator",
  "delegate": "engineering-lead",
  "division": "engineering",
  "risk": "MED",
  "depends_on": ["task_002"],
  "created_at": "2026-06-28T00:00:00Z",
  "deadline": null,
  "context": {
    "goal": "Why this task exists and what success looks like",
    "constraints": [
      "Must use existing Express 4 patterns",
      "All new code must pass /review gate >= 8.0"
    ]
  },
  "skills": [
    {"name": "backend-patterns", "reason": "Express server architecture patterns"},
    {"name": "frontend-design", "reason": "Dashboard HTML/CSS layout patterns"}
  ],
  "commands": [
    {"name": "/design", "reason": "Dashboard layout workflow guidance"}
  ],
  "files_read": [
    "services/dashboard-server/src/index.ts"
  ],
  "files_write": [
    "services/dashboard-server/src/index.ts",
    "services/dashboard-server/src/dashboard.html"
  ],
  "files_delete": [],
  "test_cases": [
    "GET /api/health returns 200",
    "GET / returns dashboard HTML with all panels"
  ],
  "test_files": [
    "services/dashboard-server/__tests__/api.test.ts"
  ],
  "acceptance_criteria": [
    "Server starts on port 3456",
    "All 3 API endpoints respond with 200",
    "Dashboard renders without JS errors"
  ],
  "tdd_required": true,
  "quality_gate_minimum": 8.0,
  "trace_parent": null,
  "rollback_plan": "git checkout -- services/dashboard-server/",
  "open_questions": [],
  "session_id": "sess_20260628_phase1"
}
```

#### Fields

| Field | Required | Description |
|-------|----------|-------------|
| `schema` | ✅ | Always `"queue-brief-v1"` for version detection |
| `task_id` | ✅ | Unique task identifier matching task.md |
| `task_path` | ✅ | Hierarchical path (e.g. `"003"`, `"003.001"`) |
| `prompt_id` | ❌ | Parent prompt/plan ID (e.g. `"prompt_001"`). Added by `/plan` scaffolding. |
| `title` | ✅ | Human-readable task title |
| `delegator` | ✅ | Role of the delegating agent |
| `delegate` | ✅ | Role of the receiving agent |
| `division` | ✅ | Division of the delegate |
| `risk` | ✅ | `LOW`, `MED`, `HIGH`, `CRITICAL` |
| `depends_on` | ❌ | Array of task_ids this depends on |
| `created_at` | ✅ | ISO 8601 timestamp |
| `deadline` | ❌ | Optional deadline timestamp |
| `context` | ✅ | Object with `goal` (string) and `constraints` (string[]) |
| `skills` | ✅ | Array of `{name, reason}` — skills the delegate must load |
| `commands` | ❌ | Array of `{name, reason}` — commands to read |
| `files_read` | ✅ | Files the delegate must read before writing |
| `files_write` | ✅ | Files the delegate will create or modify |
| `files_delete` | ❌ | Files to delete (if any) |
| `test_cases` | ✅ | Array of test case descriptions |
| `test_files` | ❌ | Test file paths |
| `acceptance_criteria` | ✅ | Array of objectively verifiable criteria |
| `tdd_required` | ❌ | Boolean, defaults to true |
| `quality_gate_minimum` | ❌ | Float 0-10, defaults to 8.0 |
| `trace_parent` | ❌ | Path to delegator's trace file for linking |
| `rollback_plan` | ❌ | How to revert changes if task fails |
| `open_questions` | ❌ | Unresolved questions (must be empty before execution) |
| `session_id` | ✅ | Session ID for trace correlation |

---

### status.json — Lifecycle tracker

Updated by the delegate throughout the task lifecycle. Also updated by the
queue manager on timeout detection or admin override.

```json
{
  "schema": "queue-status-v1",
  "task_id": "task_003",
  "status": "pending",
  "created_at": "2026-06-28T00:00:00Z",
  "updated_at": "2026-06-28T00:00:00Z",
  "started_at": null,
  "completed_at": null,
  "actor": null,
  "confidence": null,
  "retry_count": 0,
  "blocker": null,
  "error": null
}
```

#### Status Lifecycle

```
pending ──→ in_progress ──→ completed
  │                            │
  └──→ blocked                 │
  └──→ cancelled               │
                               └──→ reviewed (moved to archive/)
```

#### Fields

| Field | Required | Description |
|-------|----------|-------------|
| `schema` | ✅ | Always `"queue-status-v1"` |
| `task_id` | ✅ | Matching brief.task_id |
| `status` | ✅ | Enum: `pending`, `in_progress`, `completed`, `failed`, `blocked`, `cancelled`, `timed_out` |
| `created_at` | ✅ | When the queue entry was created |
| `updated_at` | ✅ | Last status change timestamp |
| `started_at` | ❌ | When the delegate started working |
| `completed_at` | ❌ | When the task completed/failed |
| `actor` | ❌ | Role of the agent currently/currently working it |
| `confidence` | ❌ | Delegate's self-assessed quality (0-100) |
| `retry_count` | ❌ | Number of retry attempts |
| `blocker` | ❌ | Description of what's blocking (if status=blocked) |
| `error` | ❌ | Error detail (if status=failed/timed_out) |

---

### output.json — Completion report

Written by the delegate when the task reaches a terminal state (completed/failed/blocked).

```json
{
  "schema": "queue-output-v1",
  "task_id": "task_003",
  "task_path": "003",
  "status": "completed",
  "completed_at": "2026-06-28T01:00:00Z",
  "actor": "engineering-lead",
  "summary": "Express dashboard server built with 4 API routes and dark-theme HTML",
  "files_written": [
    "services/dashboard-server/src/index.ts",
    "services/dashboard-server/src/dashboard.html"
  ],
  "files_read": [
    "services/dashboard-server/src/index.ts",
    ".agents/schemas/trace.schema.md"
  ],
  "files_deleted": [],
  "commands_run": [
    "pnpm install",
    "pnpm --filter dashboard-server start"
  ],
  "skills_loaded": ["backend-patterns", "frontend-design"],
  "test_results": {
    "total": 6,
    "passed": 6,
    "failed": 0,
    "coverage": null
  },
  "quality_gate": {
    "score": 9.2,
    "minimum": 8.0,
    "passed": true,
    "axes": {
      "correctness": 9,
      "security": 10,
      "performance": 9,
      "code_style": 9,
      "test_coverage": 9,
      "documentation": 9
    }
  },
  "acceptance_results": [
    {"criterion": "Server starts on port 3456", "passed": true},
    {"criterion": "All 3 API endpoints respond with 200", "passed": true},
    {"criterion": "Dashboard renders without JS errors", "passed": true}
  ],
  "drift": false,
  "drift_detail": null,
  "confidence": 92,
  "trace_file": ".agents/queue/task_003/trace.jsonl",
  "next_recommendation": "Proceed to task_004 — dashboard tree endpoint"
}
```

#### Fields

| Field | Required | Description |
|-------|----------|-------------|
| `schema` | ✅ | Always `"queue-output-v1"` |
| `task_id` | ✅ | Matching brief.task_id |
| `task_path` | ✅ | Matching brief.task_path |
| `status` | ✅ | Terminal status: `completed`, `failed`, `blocked` |
| `completed_at` | ✅ | ISO 8601 completion timestamp |
| `actor` | ✅ | Role of the agent that did the work |
| `summary` | ✅ | 1-3 sentence human-readable summary |
| `files_written` | ✅ | All files created or modified |
| `files_read` | ❌ | Files read during execution |
| `files_deleted` | ❌ | Files deleted |
| `commands_run` | ❌ | Commands/shell commands executed |
| `skills_loaded` | ❌ | Skills loaded during execution |
| `test_results` | ❌ | Object with total/passed/failed/coverage |
| `quality_gate` | ❌ | Full quality gate assessment |
| `acceptance_results` | ❌ | Array of per-criterion pass/fail |
| `drift` | ✅ | Boolean — true if files_outside brief's files_write were touched |
| `drift_detail` | ❌ | Explanation if drift=true |
| `confidence` | ❌ | 0-100 self-assessed quality |
| `trace_file` | ❌ | Path to delegate's trace.jsonl |
| `next_recommendation` | ❌ | Suggested next action for delegator |

---

### context.json — Optional handoff packet

Provides filtered context from the delegator to the delegate. Keeps the
brief focused on the task while the context packet provides environmental
information.

```json
{
  "schema": "queue-context-v1",
  "task_id": "task_003",
  "handoff": {
    "relevant_memories": [
      "mem_608e3246fa5f2d",
      "mem_958c269daa7bd1"
    ],
    "prior_outputs": {
      "task_002": ".agents/queue/task_002/output.json"
    },
    "constraints_filtered": [
      "All new routes must be added to the existing Express app instance",
      "Dashboard must use dark theme matching existing style"
    ],
    "inputs": {
      "files": ["services/dashboard-server/src/index.ts"],
      "tool_results": {}
    }
  }
}
```

---

### trace.jsonl — Delegate's execution trace

Standard JSONL trace following trace.schema.md format. Captures every
significant action the delegate takes during task execution.

```jsonl
{"ts":"2026-06-28T00:30:00Z","phase":"execute","type":"skill_load","name":"backend-patterns","task_path":"003","detail":"Loaded Express patterns"}
{"ts":"2026-06-28T00:30:01Z","phase":"execute","type":"file_read","name":"services/dashboard-server/src/index.ts","task_path":"003","detail":"Read existing server code"}
{"ts":"2026-06-28T00:30:05Z","phase":"execute","type":"file_write","name":"services/dashboard-server/src/index.ts","task_path":"003","detail":"Added 4 API routes"}
{"ts":"2026-06-28T00:31:00Z","phase":"execute","type":"task_complete","name":"task_003","task_path":"003","result":"Completed: 6/6 tests pass, QG=9.2"}
```

---

### index.json — Queue registry (v2: prompt-grouped)

Registry of all queue entries, grouped by prompt/plan. Each prompt has its own
array of tasks. This replaces the flat v1 structure.

```json
{
  "schema": "queue-index-v2",
  "version": 2,
  "created": "2026-06-28T19:15:00Z",
  "updated": "2026-06-28T20:00:00Z",
  "prompts": [
    {
      "prompt_id": "prompt_001",
      "goal": "Build customer dashboard with auth",
      "created_at": "2026-06-28T20:00:00Z",
      "status": "in_progress",
      "tasks": [
        {"task_id": "task_201", "path": "prompt_001/task_201/", "status": "pending"},
        {"task_id": "task_202", "path": "prompt_001/task_202/", "status": "in_progress"},
        {"task_id": "task_203", "path": "prompt_001/task_203/", "status": "completed"}
      ]
    }
  ],
  "archive": [
    {
      "task_id": "task_001",
      "title": "Initial setup",
      "status": "completed",
      "archived_at": "2026-06-28T00:30:00Z",
      "path": ".agents/queue/archive/task_001/"
    }
  ]
}
```

#### Index v2 Fields

| Field | Required | Description |
|-------|----------|-------------|
| `schema` | ✅ | `"queue-index-v2"` for version detection |
| `version` | ✅ | Always `2` |
| `created` | ✅ | ISO 8601 creation timestamp |
| `updated` | ✅ | ISO 8601 last-updated timestamp |
| `prompts` | ✅ | Array of prompt objects (see below) |
| `archive` | ❌ | Array of archived task entries (same format as v1 archive) |

#### Prompt Object

| Field | Required | Description |
|-------|----------|-------------|
| `prompt_id` | ✅ | Matches the plan's prompt_id |
| `goal` | ✅ | The user's stated goal from the plan |
| `created_at` | ✅ | When this prompt was created |
| `status` | ✅ | Aggregate status: `pending`, `in_progress`, `completed`, `blocked` |
| `tasks` | ✅ | Array of task references |

#### Task Reference Object

| Field | Required | Description |
|-------|----------|-------------|
| `task_id` | ✅ | Task identifier |
| `path` | ✅ | Relative path from queue root (e.g. `"prompt_001/task_201/"`) |
| `status` | ✅ | Task status: `pending`, `in_progress`, `completed`, `failed`, `blocked`, `cancelled`, `timed_out` |

#### Auto-Migration from v1

When queue-manager.ps1 reads a v1 index, it auto-migrates to v2:
- Active `queues[]` entries are moved under a `prompt_legacy` prompt
- `archive[]` entries are preserved as-is
- Index is rewritten to v2 format on first write

---

## Queue Protocol Workflow

```
DELEGATOR                          QUEUE FILESYSTEM                     DELEGATE
==========                         =================                    ========

1. Write brief.json ─────────────→ .agents/queue/<prompt_id>/<task_id>/brief.json
                                   .agents/queue/<prompt_id>/<task_id>/status.json  ←── set to "pending"
                                   .agents/queue/<prompt_id>/<task_id>/context.json (optional)
                                   .agents/queue/index.json ←─── add entry under prompt

2.                              Delivery adapter reads brief.json
                                (runtime-specific: Task tool, webhook, polling, etc.)

                                                                     3. Read brief.json ──┐
                                                                     4. Update status.json ──┼──→ set to "in_progress"
                                                                     5. Execute task ────────┘
                                                                     6. Write output.json ──┐
                                                                     7. Update status.json ──┼──→ set to "completed"
                                                                     8. Write trace.jsonl ───┘

9. Poll status.json ←──────── or receive notification
10. Read output.json ←───────
11. Verify acceptance criteria
12. Archive queue entry ─────→ .agents/queue/archive/<task_id>/
13. Update index.json ───────→ set status, archive path
```

---

## Runtime Adapter Pattern

The queue protocol is runtime-agnostic. Each runtime needs a thin adapter
that bridges the filesystem queue to the runtime's agent delivery mechanism.

### OpenCode Adapter

The OpenCode adapter reads `brief.json` from the queue, constructs a
self-contained Task tool prompt from the brief fields, calls Task tool
with the appropriate subagent_type, and writes results to `output.json`.

```
OpenCode Adapter Flow:
1. Watch .agents/queue/ for new brief.json files with status=pending
2. Read brief.json from .agents/queue/<prompt_id>/<task_id>/brief.json
3. Construct Task tool prompt from brief fields
4. Call Task(subagent_type=brief.delegate, prompt=constructed_prompt)
5. On result: write output.json, update status.json, update index.json
```

**Path resolution:** The adapter resolves `<prompt_id>/<task_id>/` by reading
`queue/index.json` and finding the task's path entry. Use `Resolve-TaskPath`
from `queue-manager.ps1` for reliable path lookup.

### Cursor / Antigravity Adapter

Similar pattern — read brief from shared filesystem, deliver via the
runtime's mechanism (agent spawning, process forking, etc.), capture
output, write back to filesystem.

---

## Validation Rules

1. `brief.json` must have all required fields before a task enters the queue
2. `status.json` must never transition backward (completed → in_progress is invalid)
3. `output.json` must only be written when status reaches a terminal state
4. `index.json` must be kept in sync with queue directory contents
5. A task cannot be delegated if its dependencies are not complete
6. `files_write` in output.json must include all files actually written (drift=false)
7. `acceptance_criteria` must all pass for status=completed
8. `quality_gate.score` must be >= `quality_gate_minimum` for status=completed
9. Tasks in `archive/` are read-only — never modified after archival
10. `prompt_id` in brief.json must match the parent directory name if present
11. Tasks from the same prompt must all be in the same prompt directory
12. Index v2 `prompts[].tasks[].path` must be relative to the queue root
