# Command: /plan
# .agents/commands/plan.md
# Owner: Orchestrator
# Trigger: /plan "<goal>"

---

## Purpose
Decompose a user's goal into a structured task DAG. Every task is tagged
with a risk level and `brief_required` flag before any execution begins.

---

## Pre-Flight (8-step — runs before anything else)
1. READ `.agents/MANIFEST.md`
2. READ `.agents/rules/global.md`
3. READ `.agents/PROJECT.md`
4. READ `.agents/learned.jsonl` — search for similar prior goals
5. CHECK `.agents/task.md` — is there an active session to resume?
6. VALIDATE permissions — no tool calls needed at this stage
7. CHECK side-effect scope — only writing `task.md`
8. LOG to `audit.jsonl`: `{"action_type":"skill_start","skill":"/plan","goal":"<input>"}`

---

## Workflow

```
INPUT: User's stated goal

STEP 1 — Understand
  - Restate the goal in your own words to confirm understanding
  - If ambiguous: ask ONE clarifying question (never more than one at a time)
  - Check learned.jsonl for similar prior goals — surface relevant patterns

STEP 2 — Decompose
  - Break the goal into atomic tasks (each task = one agent, one clear output)
  - Identify dependencies (task B cannot start until task A completes)
  - Identify parallel opportunities (tasks that can run simultaneously)
  - Assign each task to a specific agent role

STEP 3 — Risk Assessment
  For each task, score risk using max of 4 dimensions:
    - Surface area: how many files/systems touched?
    - File criticality: config? schema? auth?
    - Operation type: read/create/modify/delete?
    - Reversibility: git revertable? DB migration? External API call?
  Risk levels: LOW | MED | HIGH | CRITICAL

STEP 4 — Brief Flag
  Any task with risk >= MED or that touches: schema, auth, production,
  external APIs, or > 3 files → mark brief_required: true

STEP 5 — Write task.md
  Write the full task DAG to .agents/task.md in this format:

    ## Session: <date> | Goal: <goal>
    Session ID: sess_<ulid>
    Checkpoint: every 10 tool calls  ← auto-checkpoint policy
    Next checkpoint at: tool call #10

    - [ ] task_001 -> <Agent>: <description>  [risk: LOW]  [brief: no]
    - [ ] task_002 -> <Agent>: <description>  [risk: HIGH] [brief: yes] [depends: task_001]
    - [ ] task_003 -> <Agent>: <description>  [risk: MED]  [brief: yes] [parallel: task_002]

STEP 5.5 — Initialize session checkpoint counter
  Write to audit.jsonl:
    {"action_type": "session_start", "session_id": "sess_<ulid>",
     "goal": "<goal>", "task_count": <N>, "checkpoint_interval": 10}
  Create checkpoint directory: .agents/sessions/sess_<ulid>/checkpoints/
  This directory receives auto-checkpoint files as the session progresses.

STEP 6 — Present plan to user
  Show the task DAG and ask: "Ready to proceed, or would you like to adjust?"
  Wait for approval before any delegation begins.
```

---

## Output Artifact
- `.agents/task.md` — updated with full task DAG
- Summary presented inline to user

---

## Guardrails
- Never start execution before user approves the plan
- If goal is too vague to decompose → return BLOCKED asking for more specificity
- Maximum 15 tasks per plan — if more needed, phase the work
- Auto-checkpoint every 10 tool calls during execution (see MANIFEST Auto-Checkpoint Policy)
  - Orchestrator tracks tool_call_count in working memory
  - On each checkpoint: write .agents/sessions/<id>/checkpoints/<N>.md + update task.md header
  - This is transparent to the user unless they ask for /status
