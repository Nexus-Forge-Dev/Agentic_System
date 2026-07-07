# Trace Schema (unified — plan + execution)
# .agents/schemas/trace.schema.md
# Defines the structure for capturing every skill/command/task/tool invocation
# during BOTH plan generation AND task execution.

---

## Purpose

Every agent action — planning or doing — is captured as a **trace entry**.
The trace is a JSONL file, one entry per line, recording
what was loaded, read, written, triggered, or decided — and in what order.

All traces are consolidated into a single unified format: JSONL.
Plan-phase entries use `"phase":"plan"`, execution-phase entries use `"phase":"execute"`.

---

## Storage

| Phase   | File Pattern                          | Format |
|---------|---------------------------------------|--------|
| All     | `.agents/traces/<id>.exec.jsonl`      | JSONL (appended per action during execution) |

Index: `.agents/traces/index.json` — one entry per session, pointing to the exec file.

---

## Entry Schema

```json
{
  "ts":     "<ISO 8601 timestamp>",
  "phase":  "plan | execute",
  "type":   "<entry type>",
  "name":   "<skill / command / task / file / event name>",
  "task_path": "<optional hierarchical task path>",
  "detail": "<human-readable context>",
  "result": "<optional outcome>",
  "duration_ms": 123
}
```

### Fields

| Field | Required | Type | Description |
|-------|----------|------|-------------|
| `ts` | ✅ | string (ISO 8601) | When the invocation happened. Precision to seconds is fine. |
| `phase` | ✅ | enum | `"plan"` during /plan generation, `"execute"` during task execution |
| `type` | ✅ | enum | One of the 10 types below |
| `name` | ✅ | string | Name of the skill, command, task, file, or event |
| `task_path` | ❌ | string | Hierarchical path for N-level task decomposition (e.g., `"001"`, `"001.001"`, `"001.001.002"`) |
| `detail` | ❌ | string | Human-readable context |
| `result` | ❌ | string | What was produced or decided |
| `duration_ms` | ❌ | number | How long it took (when measurable) |

---

## Entry Types

| Type | Phase | What It Captures | Example `name` |
|------|-------|------------------|----------------|
| `skill_load` | plan+exec | A skill `.md` file was loaded via the skill tool | `"blueprint"`, `"backend-patterns"`, `"ui-ux-pro-max"` |
| `command_ref` | plan+exec | A command `.md` was read for workflow instructions | `"/plan"`, `"/review"`, `"/tdd"` |
| `file_read` | plan+exec | Any file read for context | `".agents/MANIFEST.md"`, `"src/index.ts"` |
| `file_write` | plan+exec | Any file written or modified | `".agents/task.md"`, `"services/dashboard-server/src/index.ts"` |
| `audit_write` | plan+exec | An entry written to `audit.jsonl` | `"session_start"`, `"task_start"`, `"task_complete"` |
| `decision` | plan | A branching decision during planning | `"risk_assessment"`, `"decomposition"`, `"brief_flag"` |
| `task_start` | execute | A task began execution | `"task_002"` |
| `task_complete` | execute | A task finished (success/fail/skip) | `"task_002"`, result: "Express server built" |
| `tool_invoke` | execute | A significant tool was invoked | `"edit"`, `"write"`, `"bash"`, `"task"` |
| `agent_delegate` | execute | Delegated work to another agent | `"engineering-lead"`, `"quality-lead"` |
| `task_brief` | execute | Full specification brief for a delegated task — required skills, commands, files, test cases, acceptance criteria | `"task_002 brief"` (detail contains full JSON brief) |
| `task_output` | execute | Final output/result from a completed task — files produced, test results, coverage, quality gate score | `"task_002 output"` (detail contains summary, result links to artifacts) |

---

## Collection Rules

1. **Append-only** — entries are added chronologically, never modified.
2. **Every significant action is tracked** — every skill load, command ref, file write, task transition.
3. **Phase tagging** — plan-phase entries use `"phase":"plan"`, execution entries use `"phase":"execute"`. Both are written to the same JSONL file.
4. **Included in user output** — trace can be queried via `/status` or `/dashboard`.

---

## Writing an Execution Trace Entry (for the Orchestrator)

During execution, every time you perform a significant action, append to:

```
.agents/traces/<current_session_id>.exec.jsonl
```

The current session ID is set at session start and stored in task.md header.

### How to append (JSONL format — simple line append)

```json
{"ts":"2026-06-12T14:05:00Z","phase":"execute","type":"task_start","name":"task_002","detail":"Build Express dashboard server"}
```

To write: read the file, append a line, write back. Or if the file doesn't exist yet, create it with the first entry.

### Mandatory trace points (minimum instrumentation)

Every task:
- `task_start` when you begin working on a task
- `task_brief` BEFORE delegating, with full specification brief as detail
- `task_complete` when you finish a task (with result + confidence proxy)
- `task_output` AFTER task_complete, with summary of what was produced (files, tests, quality gate score)
- All entries for the same task SHOULD include `task_path` set to the task's hierarchical path

Every skill load:
- `skill_load` when you load a skill via the skill tool

Every command:
- `command_ref` when you read a command md file for guidance

Key file operations:
- `file_write` when you write or edit a significant file
- `file_read` when you read a configuration or system file

Agent delegation:
- `agent_delegate` when you use Task tool to delegate to another agent

---

## Example Trace (unified JSONL format — plan + exec in one file)

```jsonl
{"ts":"2026-06-12T14:00:00Z","phase":"plan","type":"command_ref","name":"/plan","detail":"Loaded plan.md workflow"}
{"ts":"2026-06-12T14:00:00Z","phase":"plan","type":"file_read","name":".agents/MANIFEST.md","detail":"Pre-flight step 1"}
{"ts":"2026-06-12T14:00:01Z","phase":"plan","type":"decision","name":"decomposition","detail":"4 tasks, 4 dependencies"}
{"ts":"2026-06-12T14:00:01Z","phase":"plan","type":"file_write","name":".agents/task.md","detail":"Wrote 4-task DAG"}
{"ts":"2026-06-12T14:05:00Z","phase":"execute","type":"task_start","name":"task_002","task_path":"002","detail":"Build Express dashboard server"}
{"ts":"2026-06-12T14:05:01Z","phase":"execute","type":"skill_load","name":"backend-patterns","task_path":"002","detail":"Loaded for Express server pattern guidance"}
{"ts":"2026-06-12T14:05:02Z","phase":"execute","type":"command_ref","name":"/design","task_path":"002","detail":"Loaded design workflow for UI guidance"}
{"ts":"2026-06-12T14:05:03Z","phase":"execute","type":"task_brief","name":"task_002 brief","task_path":"002","detail":"{\"skills\":[\"backend-patterns\"],\"commands\":[\"/design\"],\"files\":[\"services/dashboard-server/src/index.ts\"],\"tests\":[\"GET /api/health returns 200\"],\"acceptance\":[\"Server starts on port 3456\",\"All 4 endpoints respond\"]}"}
{"ts":"2026-06-12T14:05:04Z","phase":"execute","type":"file_write","name":"services/dashboard-server/src/index.ts","task_path":"002","detail":"Wrote Express server with 4 API routes"}
{"ts":"2026-06-12T14:05:05Z","phase":"execute","type":"bash","name":"pnpm install","task_path":"002","detail":"Installed dependencies"}
{"ts":"2026-06-12T14:05:06Z","phase":"execute","type":"task_complete","name":"task_002","task_path":"002","result":"Express server running on port 3456"}
{"ts":"2026-06-12T14:05:07Z","phase":"execute","type":"task_output","name":"task_002 output","task_path":"002","detail":"Server code written, dependencies installed, 4 routes functional","result":"Port 3456, health=ok"}
```
