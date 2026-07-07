# Command: /plan
# .agents/commands/plan.md
# Owner: Orchestrator
# Trigger: /plan "<goal>"

---

## Purpose
Decompose a user's goal into a structured task DAG. Every task is tagged
with a risk level and `brief_required` flag before any execution begins.

---

## Trace (collected throughout plan + execution)

This command generates **plan-phase trace entries**. Execution-phase entries are
appended in real-time by the Orchestrator as tasks are performed.

See `.agents/schemas/trace.schema.md` (supersedes the old plan-trace.schema.md).

Plan trace entries are collected in memory. At STEP 5.5 they are written to
`.agents/traces/<session-id>.plan.json`. The Orchestrator then appends execution
entries to `.agents/traces/<session-id>.exec.jsonl` throughout the session.

Entry types (plan): `skill_load`, `command_ref`, `file_read`, `file_write`, `audit_write`, `decision`
Entry types (exec): `task_start`, `task_complete`, `skill_load`, `command_ref`, `file_read`, `file_write`, `tool_invoke`, `agent_delegate`, `audit_write`

---

## Pre-Flight (8-step — runs before anything else)

Before step 1, initialize the trace array:
```
plan_trace = []
```

Then run:
1. READ `.agents/MANIFEST.md` → trace: `{"type":"file_read","name":".agents/MANIFEST.md","detail":"Pre-flight step 1"}`
2. READ `.agents/rules/global.md` → trace: `{"type":"file_read","name":".agents/rules/global.md","detail":"Pre-flight step 2"}`
3. READ `.agents/PROJECT.md` → trace: `{"type":"file_read","name":".agents/PROJECT.md","detail":"Pre-flight step 3"}`
4. READ `.agents/learned.jsonl` → trace: `{"type":"file_read","name":".agents/learned.jsonl","detail":"Pre-flight step 4 — found N prior patterns"}`
5. CHECK `.agents/task.md` → trace: `{"type":"file_read","name":".agents/task.md","detail":"Pre-flight step 5 — checked for active session"}`
6. VALIDATE permissions — no tool calls needed at this stage
7. CHECK side-effect scope — only writing `task.md`
8. LOG to `audit.jsonl` → trace: `{"type":"audit_write","name":"skill_start","detail":"Pre-flight step 8"}`

---

## Workflow

```
INPUT: User's stated goal

STEP 1 — Understand
  - Restate the goal in your own words to confirm understanding
  - If ambiguous: ask ONE clarifying question (never more than one at a time)
  - Check learned.jsonl for similar prior goals — surface relevant patterns
  → trace: {"type":"decision","name":"goal_restatement","detail":"<restated goal>"}

STEP 2 — Decompose
  - Break the goal into atomic tasks (each task = one agent, one clear output)
  - Identify dependencies (task B cannot start until task A completes)
  - Identify parallel opportunities (tasks that can run simultaneously)
  - Assign each task to a specific agent role
  → trace: {"type":"decision","name":"decomposition","detail":"<N> tasks, <M> dependencies, <K> parallel paths"}

STEP 3 — Risk Assessment
  For each task, score risk using max of 4 dimensions:
    - Surface area: how many files/systems touched?
    - File criticality: config? schema? auth?
    - Operation type: read/create/modify/delete?
    - Reversibility: git revertable? DB migration? External API call?
  Risk levels: LOW | MED | HIGH | CRITICAL
  → trace: {"type":"decision","name":"risk_assessment","detail":"task_001=LOW, task_002=MED, ..."}

STEP 4 — Brief Flag
  Any task with risk >= MED or that touches: schema, auth, production,
  external APIs, or > 3 files → mark brief_required: true
  → trace: {"type":"decision","name":"brief_flag","detail":"<N> tasks require brief"}

STEP 5 — Write task.md
  Write the full task DAG to .agents/task.md
  → trace: {"type":"file_write","name":".agents/task.md","detail":"Wrote <N>-task DAG"}

STEP 5.5 — Initialize session + save trace
  Write to audit.jsonl:
    {"action_type": "session_start", "session_id": "sess_<ulid>",
     "goal": "<goal>", "task_count": <N>, "checkpoint_interval": 10}
  → trace: {"type":"audit_write","name":"session_start","detail":"Session initialized"}
  Create checkpoint directory: .agents/sessions/sess_<ulid>/checkpoints/
  → trace: {"type":"decision","name":"checkpoint_init","detail":".agents/sessions/sess_<ulid>/checkpoints/"}
  WRITE the full trace to: .agents/traces/<session-id>.plan.json
  → trace: {"type":"file_write","name":".agents/traces/<session-id>.plan.json","detail":"Saved <N> plan trace entries"}
  UPDATE .agents/traces/index.json with session reference (use v2 format with files.plan, files.exec, files.final)

STEP 6 — Present plan to user
  Show the trace table (chronological list of every skill/command/file/decision
  invoked during plan generation), followed by the task DAG, then ask:
  "Ready to proceed, or would you like to adjust?"
  Wait for approval before any delegation begins.
```

---

## Output Artifacts
- `.agents/task.md` — updated with full task DAG + trace log section
- `.agents/traces/<session-id>.plan.json` — machine-readable plan trace file
- `.agents/traces/index.json` — updated index (v2 format with files.plan/exec/final)
- Trace table + task DAG presented inline to user

---

## Guardrails
- Never start execution before user approves the plan
- If goal is too vague to decompose → return BLOCKED asking for more specificity
- Maximum 15 tasks per plan — if more needed, phase the work
- Auto-checkpoint every 10 tool calls during execution (see MANIFEST Auto-Checkpoint Policy)
  - Orchestrator tracks tool_call_count in working memory
  - On each checkpoint: write .agents/sessions/<id>/checkpoints/<N>.md + update task.md header
  - This is transparent to the user unless they ask for /status
