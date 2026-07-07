# Plan Schema
# .agents/schemas/plan.schema.md
# Defines the structured task DAG produced by /plan and consumed by plan-validator.ps1 and plan-scaffold.ps1
# Runtime-agnostic: plans are JSON files stored in .agents/plans/

---

## Purpose

A plan is the machine-readable output of the `/plan` command. It captures the
decomposition of a user's goal into a task DAG. Each task specifies what agent
should execute it, what division it belongs to, its risk level, and its
dependencies on other tasks.

The plan file is:
1. **Written by** the Orchestrator (LLM) after decomposing the user's goal
2. **Validated by** `plan-validator.ps1` (script enforces schema rules)
3. **Scaffolded by** `plan-scaffold.ps1` (creates queue directories for every task)
4. **Consumed by** `/sequential-execute` to execute tasks in dependency order

---

## File Location

```
.agents/plans/
├── <prompt_id>.plan.json    # One plan file per user prompt
└── index.json               # Optional: registry of all plans
```

---

## Schema: `prompt-plan-v1`

```json
{
  "schema": "prompt-plan-v1",
  "prompt_id": "prompt_001",
  "goal": "Build customer dashboard with auth",
  "session_id": "sess_20260628_001",
  "trace_file": ".agents/traces/sess_20260628_001.exec.jsonl",
  "created_at": "2026-06-28T20:00:00Z",
  "notes": null,
  "tasks": [
    {
      "id": "task_201",
      "title": "Create user schema and migration",
      "agent": "database-engineer",
      "division": "engineering",
      "risk": "LOW",
      "depends_on": [],
      "brief_required": false,
      "estimated_files": 1,
      "notes": null
    },
    {
      "id": "task_202",
      "title": "Implement auth service (JWT login/register/refresh)",
      "agent": "backend-architect",
      "division": "engineering",
      "risk": "HIGH",
      "depends_on": ["task_201"],
      "brief_required": true,
      "estimated_files": 4,
      "notes": "JWT tokens, bcrypt passwords, refresh token rotation"
    }
  ]
}
```

---

## Fields

### Root Object

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `schema` | ✅ | string | Always `"prompt-plan-v1"` for version detection |
| `prompt_id` | ✅ | string | Unique identifier for this plan, e.g. `prompt_001`. No spaces or special chars beyond underscore. |
| `goal` | ✅ | string | The user's stated goal in one sentence |
| `session_id` | ✅ | string | The session ULID this plan belongs to |
| `trace_file` | ✅ | string | Path to the session's unified execution trace file |
| `created_at` | ✅ | string | ISO 8601 timestamp |
| `notes` | ❌ | string or null | Optional notes about the plan (assumptions, scope notes) |
| `tasks` | ✅ | array | Array of task objects (see below). Minimum 1, maximum 15. |

### Task Object

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `id` | ✅ | string | Unique task identifier within this plan, e.g. `task_201`. Globally unique across all plans. |
| `title` | ✅ | string | Human-readable task title. Should be descriptive enough for a fresh agent to understand what to do. |
| `agent` | ✅ | string | Agent role from MANIFEST.md division registry. Must be a valid specialist or lead role. |
| `division` | ✅ | string | Division name from MANIFEST.md. Must match the division that `agent` belongs to. |
| `risk` | ✅ | string | One of: `LOW`, `MED`, `HIGH`, `CRITICAL`. Determined by max of 4 dimensions (surface area, file criticality, operation type, reversibility). |
| `depends_on` | ✅ | array | Array of task IDs this task depends on. Empty array `[]` if no dependencies. |
| `brief_required` | ✅ | boolean | `true` if task risk >= MED or touches schema/auth/production/external APIs or > 3 files. |
| `estimated_files` | ✅ | integer | Estimated count of files to create or modify. Must be >= 1. |
| `notes` | ❌ | string or null | Optional implementation notes, tricky edge cases, or guidance for the delegate. |

---

## Validation Rules (enforced by plan-validator.ps1)

### Structural Rules

| # | Rule | Error Message |
|---|------|---------------|
| 1 | All task IDs must be unique within the plan | `Duplicate task ID: <id>` |
| 2 | Every `depends_on` task must exist in the plan | `Dependency <dep_id> not found in plan` |
| 3 | No circular dependencies (cycle detection) | `Cycle detected: <id> → <id2> → ... → <id>` |
| 4 | `agent` must be a valid role from MANIFEST.md | `Invalid agent role: <role>` |
| 5 | `division` must match a division from MANIFEST.md | `Invalid division: <division>` |
| 6 | `agent` must belong to the specified `division` | `Agent <role> is not in division <division>` |
| 7 | `risk` must be one of: LOW, MED, HIGH, CRITICAL | `Invalid risk: <risk>` |
| 8 | If `risk` is HIGH or CRITICAL, `brief_required` must be true | `Task <id> has risk <risk> but brief_required is false` |
| 9 | `estimated_files` must be a positive integer | `Task <id> has invalid estimated_files: <value>` |
| 10 | `prompt_id` must match pattern: `^[a-zA-Z0-9_]+$` | `Invalid prompt_id format: <prompt_id>` |
| 11 | At least 1 task must exist | `Plan has no tasks` |
| 12 | Maximum 15 tasks per plan | `Plan exceeds maximum 15 tasks (has <N>)` |
| 13 | `id` must match pattern: `^task_\d+$` | `Invalid task ID format: <id>` |

### Agent → Division Mapping

Validated by plan-validator.ps1 using the division registry from MANIFEST.md.

| Division | Valid Agent Roles |
|----------|------------------|
| `engineering` | `engineering-lead`, `frontend-developer`, `backend-architect`, `database-engineer` |
| `platform` | `platform-lead`, `devops-engineer`, `cloud-architect`, `security-engineer`, `incident-commander` |
| `quality` | `quality-lead`, `sdet`, `performance-tester`, `visual-qa-specialist`, `qa-automation-engineer` |
| `design` | `design-lead`, `ui-designer`, `ux-researcher`, `design-systems-engineer`, `animator` |
| `intelligence` | `intelligence-lead`, `session-analyst`, `optimization-architect` |
| `research-council` | `moderator`, `advocate`, `skeptic`, `devils-advocate`, `domain-expert` |

---

## Lifecycle

```
┌──────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  LLM     │     │  plan-       │     │  plan-       │     │  sequential-  │
│  writes  │ ──→ │  validator   │ ──→ │  scaffold    │ ──→ │  execute      │
│  plan    │     │  .ps1 checks │     │  .ps1 creates│     │  runs tasks   │
└──────────┘     └──────────────┘     │  queue dirs  │     └──────────────┘
                                      └──────────────┘
```

1. **LLM writes** — Orchestrator analyzes the goal, decomposes into tasks, writes `.agents/plans/<prompt_id>.plan.json`
2. **Validator checks** — `plan-validator.ps1` validates all 13 rules. If invalid, fix and re-validate. Never proceed with an invalid plan.
3. **Scaffold creates** — `plan-scaffold.ps1` reads the plan, creates `.agents/queue/<prompt_id>/<task_id>/` directories with initial `status.json` files, and updates `queue/index.json`.
4. **Execute runs** — `/sequential-execute` reads the queue, processes tasks in dependency order, delegating each via the queue protocol.

---

## Guardrails

- The plan file is the **source of truth** for what work needs to be done
- If the plan is invalid, fix it — never execute from an unvalidated plan
- Plans are immutable after scaffolding: if the plan needs to change, create a new plan
- Maximum 15 tasks per plan prevents context overflow during planning
- Each task must have a clear, single-agent scope — if a task needs multiple agents, decompose further
- `estimated_files` helps with resource planning but is advisory — actual files written may differ
