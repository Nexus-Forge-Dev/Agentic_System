# Command: /delegate
# .agents/commands/delegate.md
# Owner: Orchestrator (or any Division Lead for sub-delegation)
# Trigger: /delegate <task_id> --to <agent_role> [--brief "<inline brief>" | --brief-file <path>]
# Source: Phase 3 — Standardized Delegation Protocol

---

## Purpose

Standardize the delegation of a task from one agent to another, with full
trace logging before, during, and after the delegation. Handles the complete
lifecycle: brief → Task tool call → result receipt → output logging.

This works for ANY level in the decomposition hierarchy:
- Orchestrator → Division Lead
- Division Lead → Specialist
- Specialist → Sub-specialist (recursive multi-hop)

---

## When to Use

| Situation | Use /delegate? |
|-----------|---------------|
| Delegating any task to another agent | ✅ ALWAYS |
| Decomposing a task into subtasks | ✅ ALWAYS |
| Handing off work that requires a different skill set | ✅ ALWAYS |
| Parallelizing independent work | ✅ YES — one /delegate per parallel branch |
| Self-execution (no delegation) | ❌ NONE — use /sequential-execute instead |

---

## Workflow

### Pre-flight: Validate delegation is allowed
- Check communication protocol (MANIFEST.md): direct/skip-level delegations are FORBIDDEN
  - ✅ Orchestrator → Division Lead
  - ✅ Division Lead → Specialist (same division)
  - ❌ Orchestrator → Specialist (skip-level)
  - ❌ Specialist (Div A) → Specialist (Div B)
- Verify the recipient agent role exists in MANIFEST.md division registry

### Step 1: Generate or load the brief
If no brief exists for this task yet:
  - Run `/brief-generate` first
  - The brief becomes the delegation spec

If a brief already exists (from prior `/brief-generate` or parent task):
  - Load and verify it
  - Add any additional context from the current execution state

### Step 2: Log to trace (pre-delegation)
Write these trace entries BEFORE calling the Task tool:

The agent session file will be named: `<parent_session_id>__<agent_role>__<task_path>.exec.jsonl`
(replace `.` in task_path with `_`) — save it in `trace entry detail` for reference.

```jsonl
{"ts":"<ISO>","phase":"execute","type":"task_brief","name":"<task_id> brief","task_path":"<path>","detail":"<full JSON brief as string>","skills":["<skills>"],"commands":["<commands>"],"files":["<files>"],"tests":["<tests>"],"acceptance":["<acceptance>"]}
{"ts":"<ISO>","phase":"execute","type":"agent_delegate","name":"<agent_role>","task_path":"<path>","detail":"Delegating <task_id> to <agent_role>","agent_session_file":"<parent_session_id>__<agent_role>__<task_path>.exec.jsonl"}
```

### Step 3: Call Task tool
Construct the Task tool call with:
- `subagent_type`: the agent role (e.g., `engineering-lead`, `frontend-developer`)
- `description`: short task description (3-5 words)
- `prompt`: the FULL brief content including:
  - Task context (what, why)
  - Skills to load (with reasons)
  - Commands to read
  - Files to read before writing
  - Files to create/modify
  - Test cases to implement (TDD: RED first)
  - Acceptance criteria
  - Task_path for trace continuity
  - Expected Result Message format

The prompt MUST be self-contained — the receiving agent gets NO context beyond what's in the prompt.

### Step 4: Receive result
When the subagent returns its Result Message:
- Extract: files written, test results, quality gate score, confidence
- Verify acceptance criteria were met (check each one)
- If result indicates failure, refer to error handling below

### Step 5: Log to trace (post-delegation)
Write these trace entries AFTER the delegation completes:

```jsonl
{"ts":"<ISO>","phase":"execute","type":"task_output","name":"<task_id> output","task_path":"<path>","detail":"<summary of what was produced>","result":"<QG score, test results>"}
{"ts":"<ISO>","phase":"execute","type":"task_complete","name":"<task_id>","task_path":"<path>","result":"<success|fail|blocked>"}
```

### Step 6: Audit log
Write to audit.jsonl:

```jsonl
{"ts":"<ISO>","agent":"<your_role>","action_type":"delegation_complete","task":"<task_id>","delegate_to":"<agent_role>","result":"success|fail","files_written":["<files>"],"quality_gate":"<score>","confidence":<0-1>,"agent_session_file":"<parent_session_id>__<agent_role>__<task_path>.exec.jsonl"}
```

---

## Task Tool Prompt Template

```
## Task: <task_id> — <title>
Task Path: <task_path>
Risk: <risk_level>
Parent Task: <parent_task_path> (if applicable)

### Context
<Why this task exists, what the parent produces>

### Required Skills
Load these skills before starting:
- <skill_name> — <reason>
- <skill_name> — <reason>

### Required Commands
Read these commands before starting:
- <command_name> — <reason>

### Files to Read First
- <file_path> — <reason>
- <file_path> — <reason>

### Test-Driven Development
1. RED: Write tests FIRST in <test_file>
2. GREEN: Implement to pass tests
3. REFACTOR: Add comprehensive edge-case tests
4. VERIFY: All tests pass before returning

### Test Cases
- <test case 1>
- <test case 2>

### Files to Create/Modify
- <file_path> — CREATE | MODIFY — <reason>
- <file_path> — CREATE | MODIFY — <reason>

### Acceptance Criteria
- [ ] <criterion 1>
- [ ] <criterion 2>

### Agent-Level Trace File (MANDATORY)
As a subagent, you MUST write your own trace file to capture your internal work.

1. Create/modify the trace file at: `.agents/traces/agent_sessions/<parent_session_id>__<your_role>__<task_path>.exec.jsonl`
2. Write ONE JSON line per significant action (following trace.schema.md entry types):
   - `skill_load` — when you load a skill
   - `command_ref` — when you read a command
   - `file_read` — when you read a file (include path in `name`)
   - `file_write` — when you write a file (include path in `name`)
   - `decision` — when you make a key decision
   - `task_start` / `task_brief` / `task_output` / `task_complete` — delegation lifecycle
   - `agent_delegate` — if YOU delegate a sub-task further
3. Each entry MUST have: `ts`, `phase` (`"execute"`), `type`, `name`, `task_path`, `detail`
4. Append with `fs.appendFileSync` or write at the end

Your trace file proves what you actually did. It is REQUIRED for dashboard visibility.

### Result Message Format
Return:
{
  "task_id": "<task_id>",
  "status": "completed|failed|blocked",
  "files_written": [...],
  "test_results": "...",
  "quality_gate_score": <0-10>,
  "confidence": <0-1>,
  "notes": "...",
  "agent_trace_file": "<parent_session_id>__<your_role>__<task_path>.exec.jsonl"  // ← path to your agent-level trace
}
```

---

## Error Handling

| Error | Handling |
|-------|----------|
| Subagent returns error/failure | Log `task_complete` with `result: "failed"` and detail. Do NOT proceed to dependent tasks. Escalate to division lead or orchestrator. |
| Subagent timeout | Log `task_complete` with `result: "timeout"`. The task can be retried with smaller scope or higher timeout. |
| Subagent produces unexpected files | Log a drift warning. If drift is benign (test files, docs), proceed. If drift is harmful (modified files outside scope), escalate. |
| Acceptance criteria not verifiable | Task is NOT complete. Re-delegate with narrower scope. |

---

## Trace Integration

Every `/delegate` invocation MUST produce exactly these trace entries:

```
Pre-delegation:
  1. task_brief — the full brief (JSON in detail)
  2. agent_delegate — who, what, task_path, agent_session_file ref

Post-delegation:
  3. task_output — summary of what was produced
  4. task_complete — success/fail/blocked
```

Total: **4 mandatory trace entries** per delegation (2 before, 2 after).

### Agent-Level Trace File

In addition to the 4 parent trace entries, the subagent MUST write its own
trace file to `.agents/traces/agent_sessions/{parent_session_id}__{agent_role}__{task_path}.exec.jsonl`.

This file captures the subagent's internal steps: skills loaded, files read/written,
decisions made, and delegation sub-chain references. The dashboard reads these
files to render the Agent Logs panel (🤖 panel).

The agent session file is linked from:
- The `agent_sessions[]` array on the task tree node
- The `agent_delegate` trace entry's `agent_session_file` field
- The `agent_session_file` field in the Result Message

---

## Guardrails

- NEVER delegate without a brief first (use `/brief-generate` first)
- NEVER skip-level (Orchestrator → Specialist is FORBIDDEN)
- NEVER delegate to a role not in MANIFEST.md
- The Task tool prompt MUST be self-contained — no implicit context
- ALWAYS verify acceptance criteria before marking task complete
- If brief has `open_questions`, resolve them before delegating
- For CRITICAL risk tasks: STOP after brief generation, wait for human approval
