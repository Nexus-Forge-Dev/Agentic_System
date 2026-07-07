# Command: /brief-generate
# .agents/commands/brief-generate.md
# Owner: Orchestrator → any agent
# Trigger: /brief-generate "<task_id>" [--context "<additional context>"]
# Source: Phase 3 — Structured Brief System

---

## Purpose

Generate a structured, machine-readable specification brief for a task.
The brief captures everything needed before delegation: required skills, commands,
files, test cases, and acceptance criteria.

This replaces ad-hoc task descriptions with a standardized spec format that
any agent at any level of decomposition can consume and execute against.

---

## When to Use

| Situation | Use /brief-generate? |
|-----------|---------------------|
| Before delegating a MEDIUM+ risk task | ✅ ALWAYS |
| Before delegating a task touching 3+ files | ✅ ALWAYS |
| Before delegating a task to another agent (Task tool) | ✅ ALWAYS |
| Before delegating a subtask from a decomposed parent | ✅ ALWAYS |
| For LOW risk 1-file changes | ⚠️ OPTIONAL — one-liner brief instead |

---

## Workflow

### Step 1: Check requirements
- Read the task from task.md (task ID, description, risk level, dependencies)
- Read any existing brief or prior output if task has `depends_on`
- Determine what skills, commands, files, tests, and acceptance criteria are needed

### Step 2: Generate brief JSON
Produce a brief with this exact schema:

```json
{
  "task_id": "task_003",
  "task_path": "003",
  "title": "Build Express dashboard server",
  "risk": "MED",
  "agent": "orchestrator",
  "depends_on": ["task_002"],
  "skills": [
    {"name": "backend-patterns", "reason": "Express server patterns"},
    {"name": "frontend-design", "reason": "Dashboard HTML/CSS"}
  ],
  "commands": [
    {"name": "/design", "reason": "Dashboard layout workflow"}
  ],
  "files_read": [
    ".agents/schemas/trace.schema.md",
    "services/dashboard-server/src/index.ts"
  ],
  "files_write": [
    "services/dashboard-server/src/index.ts",
    "services/dashboard-server/src/dashboard.html"
  ],
  "files_delete": [],
  "test_cases": [
    "GET /api/health returns 200",
    "GET /api/traces returns session list",
    "GET / returns dashboard HTML"
  ],
  "test_files": [
    "services/dashboard-server/__tests__/api.test.ts"
  ],
  "acceptance_criteria": [
    "Server starts on port 3456",
    "All 3 API endpoints respond with 200",
    "Dashboard renders without JS errors"
  ],
  "estimated_files_touched": 3,
  "rollback_plan": "git revert <commit>; or pnpm stop && git checkout -- services/dashboard-server/",
  "open_questions": []
}
```

### Step 3: Validate brief
- `skills` array is never empty (at least one skill must be listed)
- `files_write` must include all files that will be created or modified
- `test_cases` must have at least 1 test per function/endpoint changed
- `acceptance_criteria` must be objectively verifiable (pass/fail, not subjective)
- `risk` must match the risk from task.md or be higher (never lower)

### Step 4: Log to trace
Write a `task_brief` entry to the execution trace:

```jsonl
{"ts":"<ISO>","phase":"execute","type":"task_brief","name":"task_003 brief","task_path":"003","detail":"<the full JSON brief as string>"}
```

### Step 5: Return brief
Return the brief JSON as the result. The brief is now ready for:
- `/delegate` to hand off the task to another agent
- Direct execution if the agent will do the work themselves
- `/review` quality gate after completion

---

## Brief Levels

| Level | Fields Required | When |
|-------|----------------|------|
| **Full** | All fields | MEDIUM+ risk, 3+ files, ANY delegation |
| **Abbreviated** | task_id, skills, files_write, test_cases, acceptance_criteria | LOW risk, 1-2 files, self-execution |
| **One-liner** | task_id, title, files_write | Trivial change (typo, rename, comment) |

---

## Trace Integration

Every `/brief-generate` invocation MUST produce exactly these trace entries:

```
1. skill_load — any skill loaded during brief generation
2. command_ref — /brief-generate itself
3. task_brief — the generated brief (full JSON in detail)
```

The brief is loaded later by whoever executes the task:

```
4. skill_load — skills listed in the brief (loaded before execution)
5. command_ref — commands listed in the brief (loaded before execution)
6. file_read — files_read from the brief
7. file_write — files_write as they are created
```

---

## Guardrails

- The brief is the **contract**. If execution touches a file NOT listed in `files_write`, that's a drift event and must be logged
- Skills and commands listed in the brief MUST be loaded/read before execution begins
- If an acceptance criterion cannot be verified, the task is NOT complete
- If `open_questions` is non-empty, those questions must be resolved before delegation
- The brief MUST contain all information needed for a fresh agent to execute the task cold
