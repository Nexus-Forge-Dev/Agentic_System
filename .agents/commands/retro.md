# Command: /retro
# .agents/commands/retro.md
# Owner: Intelligence Lead → Session Analyst
# Trigger: /retro — runs at session close

---

## Purpose
Read all 3 observability streams. Compute velocity metrics per agent.
Surface cost breakdown. Identify pattern candidates for /learn.
Produce a session dashboard for the Intelligence archive.

---

## Workflow

```
STEP 1 — Read all 3 observability streams
  audit.jsonl   — action log (what every agent did, in sequence)
  tool_calls.jsonl  — MCP call log (latencies, failures)
  cost.jsonl    — token usage by agent and task

STEP 2 — Compute session metrics

  VELOCITY:
    - Total tasks in task.md vs. completed/failed/blocked
    - Average time from task_start to task_complete per agent (ms)
    - Longest task (by duration) — flag if > 30 minutes

  QUALITY:
    - Average confidence score per agent
    - Agents with < 60% confidence more than twice → flag
    - /review score (if ran) — axis-by-axis breakdown

  COST:
    - Total tokens consumed (input + output)
    - Estimated total session cost (USD)
    - Most expensive agent (by tokens)
    - Most expensive task

  RELIABILITY:
    - Tool failures: which MCP tools failed and how many times
    - Blocked count: how many times agents returned BLOCKED status
    - Escalations: tasks that needed Orchestrator re-delegation

STEP 3 — Identify pattern candidates
  Look for approaches that:
    - Were tried and succeeded (confidence >= 80%)
    - Appear in the task context that matches prior learned patterns
    - Could save time if reused in future sessions
  Flag these for /learn (do NOT write to learned.jsonl directly — that's /learn's job)

STEP 3.5 — Confidence decay on learned.jsonl entries
  Read learned.jsonl
  For each entry, check if it was used this session (match by id in audit.jsonl):

  USED AND WORKED (pattern was applied, outcome was SUCCESS):
    → confidence stays unchanged (or +0.02 if used_count < 3)

  USED AND DID NOT WORK (pattern was applied, outcome was FAILED/BLOCKED):
    → confidence -= 0.1
    → increment sessions_applied count
    → log note: "Applied in session <id>, did not resolve"

  NOT USED (pattern exists but wasn't relevant this session):
    → no change

  Archive threshold:
    → If confidence < 0.5 → move to .agents/learned_archive.jsonl
    → Remove from active learned.jsonl
    → Log: "Pattern <id> archived — confidence below threshold after N sessions"

  Update used_count and last_used on all used patterns.

STEP 4 — Write session dashboard
  File: .agents/sessions/<session-id>/dashboard.md
  Contents:
    - Session summary table (goal, tasks, duration, total cost)
    - Per-agent performance breakdown
    - Cost breakdown
    - Quality gate results
    - Reliability events
    - Pattern candidates
    - Recommended focus for next session

STEP 5 — Report to user
  Present inline summary: session done in X minutes, Y tasks completed,
  total cost ~$Z, /review score, top pattern candidate to save
```

---

## Output Artifacts
- `.agents/sessions/<session-id>/dashboard.md` — full session dashboard

---

## Guardrails
- /retro should run at EVERY session close — it is not optional
- Session Analyst computes the raw numbers; Intelligence Lead synthesizes the narrative
- Pattern candidates are only flagged here — writing to learned.jsonl happens in /learn
- Confidence decay (Step 3.5) IS written directly by /retro — it is maintenance, not learning
- After confidence decay, Intelligence Lead delegates to Optimization Architect for systemic cost analysis
- Optimization Architect writes to `.agents/reports/optimization-<ts>.md` when it identifies patterns
