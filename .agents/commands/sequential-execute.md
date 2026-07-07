# Command: /sequential-execute
# .agents/commands/sequential-execute.md
# Owner: Orchestrator (or any Division Lead for sub-sequences)
# Trigger: /sequential-execute [--task <task_id>] [--from <start_task>] [--all]
# Source: Phase 3 — Sequential Execution Queue Manager

---

## Purpose

Execute tasks from the task DAG strictly one at a time, in dependency order.
No parallelism. Each task completes fully (including quality gate) before the next begins.

This is the **primary execution mode** of the system. The company model demands
sequential execution because parallel tasks cannot share context, and sequential
execution ensures that every task benefits from complete upstream outputs.

---

## When to Use

| Situation | Use /sequential-execute? |
|-----------|------------------------|
| Beginning a new session with a task DAG | ✅ ALWAYS — run `/sequential-execute --all` |
| Resuming after a partial session | ✅ YES — run `/sequential-execute --from <last_completed_task>` |
| A Division Lead has subtasks to execute | ✅ YES — run within the division for sub-tasks |
| Running a single task with all its dependencies | ✅ YES — run `/sequential-execute --task <task_id>` |

---

## Workflow

### Pre-flight
1. READ `.agents/task.md` — load the current task DAG
2. READ `.agents/traces/<session_id>.exec.jsonl` — check which tasks are already done
3. RESOLVE the execution order (see Step 1)

### Step 1: Resolve execution order
From the task DAG, compute a topological order respecting dependencies:

```
Example DAG:
  task_201 (no deps)
  task_202 (depends: task_201)
  task_203 (depends: task_202)
  task_204 (depends: task_203)
  task_205 (depends: task_204)
  task_206 (depends: task_205)

Execution order: task_201 → task_202 → task_203 → task_204 → task_205 → task_206
```

Rules:
- A task cannot execute until ALL its dependencies are complete
- If `depends_on` is empty/absent, the task has no upstream dependency
- Detect cycles — if a cycle is found, report it and BLOCK
- Tasks with no dependencies can run... but only if `--parallel` is explicitly set (default: sequential)

### Step 2: Identify the first pending task
Scan the resolved order. Find the first task that is NOT yet complete:
- Check task.md status (`[ ]` = pending, `[x]` = done)
- Check trace for existing `task_complete` entries (cross-verify)
- If `--task <task_id>` is specified, start from that task (verify its deps are done)

### Step 3: Execute loop
For each pending task (one at a time, strictly sequential):

```
while tasks_remain:
  1. SELECT next pending task from resolved order
  2. MARK task as in_progress in task.md
  3. LOG task_start to trace (with task_path)
  4. ASSESS risk level (from task DAG)
  5. IF risk >= MEDIUM OR task requires delegation:
     a. RUN /brief-generate <task_id>
     b. RUN /delegate <task_id> --to <assigned_agent>
  6. ELSE (LOW risk, self-executable):
     a. Execute the task directly (read, write, test)
     b. Run /review quality gate
  7. LOG task_output to trace
  8. LOG task_complete to trace
  9. MARK task as done in task.md
  10. LOG to audit.jsonl
  end
```

### Step 4: Handle each task execution

For each task, the execution follows the **atomic task flow**:

```
1. task_start        → trace
2. skill_load(s)     → trace (load skills listed in brief/requires)
3. command_ref(s)    → trace (read commands listed in brief/requires)
4. file_read(s)      → trace (read files needed for context)
5. [optional] brief  → step skipped if self-executing LOW risk
6. [optional] delegate → step skipped if self-executing
7. file_write(s)     → trace
8. /review           → quality gate (must pass ≥ 8.0/10)
9. task_output       → trace
10. task_complete    → trace
```

### Step 5: Error handling in the loop

| Situation | Action |
|-----------|--------|
| Task fails | Mark as `blocked` in task.md. Log detail. STOP the sequence — do NOT proceed to downstream tasks. |
| Task times out | Mark as `blocked`. Log detail. Offer to retry with narrower scope or higher timeout. |
| Quality gate fails (< 8.0/10) | Do NOT mark as complete. Log remediation items. Re-execute or re-delegate. Do NOT proceed to downstream tasks. |
| Task partially completes | If core acceptance criteria are met but edge cases remain, mark as `completed` and create a follow-up task for edge cases. |

### Step 6: Completion
When all tasks are done (or blocked):
- Log summary to trace
- Update task.md status to COMPLETED or BLOCKED
- Write `session_end` to audit.jsonl
- Run `/learn` to extract patterns
- Run `/retro` to compute velocity metrics

---

## Execution Order Resolution Algorithm

```
function resolve_order(tasks):
  graph = build_dependency_graph(tasks)
  order = topological_sort(graph)
  if cycle_detected:
    return ERROR("Cycle detected in task dependencies")
  return order
```

For tasks at the same dependency level (no inter-dependency), the order is:
1. By risk level (HIGH → LOW) — higher risk first, more careful execution
2. By task number (lower first) — tiebreaker

---

## State Management

The execution queue state is tracked in `task.md`:

```markdown
| Task | Status | Risk | Dependencies |
|------|--------|------|-------------|
| 201  | ✅ done | LOW  | — |
| 202  | ✅ done | LOW  | 201 |
| 203  | 🔄 in_progress | MED | 202 |
| 204  | ⏳ pending | MED | 203 |
| 205  | ⏳ pending | LOW | 204 |
| 206  | ⏳ pending | LOW | 205 |
```

`current_blocker` field in task.md JSON DAG records WHY a task is blocked:

```json
{
  "id": "204",
  "status": "blocked",
  "blocker": "task_203 failed quality gate (6.2/10)",
  "blocked_by": ["task_203"]
}
```

---

## Trace Integration

Each full loop iteration produces these trace entries:

```
1. task_start       — beginning execution
2. task_brief       — brief generated (if MEDIUM+ risk)
3. skill_load       — each skill loaded
4. command_ref      — each command read
5. file_read        — each file read
6. agent_delegate   — if delegated
7. file_write       — each file written
8. task_output      — summary of results
9. task_complete    — success/fail/blocked
```

---

## Guardrails

- ONLY ONE task is `in_progress` at any time — strictly sequential
- NEVER skip a task — if `--task <id>` is used, verify all its deps are done first
- ALWAYS run /review quality gate before marking a task complete
- NEVER mark a task complete if quality gate < 8.0/10
- If a task is blocked, ALL downstream tasks are also blocked (cascading block)
- Detect and report dependency cycles immediately — do not attempt to execute
- Task execution order is deterministic — same input always produces same order
