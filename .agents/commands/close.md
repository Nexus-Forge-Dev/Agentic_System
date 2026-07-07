# Command: /close
# .agents/commands/close.md
# Owner: Orchestrator
# Trigger: /close — runs at session end

---

## Purpose
Finalize a session cleanly: save snapshot, compute metrics, extract patterns, write
the session record, update the index, and clear working memory. Orchestrates
`/context-save` → `/retro` → `/learn` → `session.json` write in one step.

---

## Workflow

```
STEP 0 — Prerequisite check
  Verify the session has an active session_id.
  If none: generate sess_<ulid> now.
  Read the current task.md to count completed/pending/failed tasks.
  Read cost.jsonl to sum tokens for this session_id.
  Read audit.jsonl tail for this session_id.
  Read learned.jsonl to diff new patterns added this session.

STEP 1 — Save session snapshot (same as /context-save)
  Write: .agents/sessions/<session-id>/snapshot.md
  Copy: task.md → .agents/sessions/<session-id>/task.md
  Extract: last 100 audit entries → .agents/sessions/<session-id>/audit-tail.jsonl
  Write: learned-candidates.json (unwritten patterns from this session)

STEP 2 — Run session retrospective (same as /retro)
  Read all 3 observability streams (audit.jsonl, tool_calls.jsonl, cost.jsonl)
  Compute VELOCITY, QUALITY, COST, RELIABILITY metrics
  Apply confidence decay on learned.jsonl
  Write: .agents/sessions/<session-id>/dashboard.md

STEP 3 — Extract learned patterns (same as /learn)
  Review pattern candidates from dashboard
  Apply recurrence threshold against learned.jsonl
  Write FAILED patterns (equally important)
  Append new patterns to learned.jsonl

STEP 4 — Write session.json
  File: .agents/sessions/<session-id>/session.json
  Schema:

  {
    "session_id": "<sess_ulid>",
    "goal": "<one-line goal>",
    "started_at": "<ISO-8601>",
    "completed_at": "<ISO-8601>",
    "status": "completed",
    "agent_invocations": <count>,
    "tasks_created": <count>,
    "tasks_completed": <count>,
    "tasks_failed": <count>,
    "tokens_used": {
      "input": <sum>,
      "output": <sum>,
      "cached": <sum>
    },
    "estimated_cost_usd": <total>,
    "files_modified": ["path1", "path2"],
    "agents_activated": ["orchestrator", "backend-architect", ...],
    "git_head_sha_start": "<sha>" or null,
    "git_head_sha_end": "<sha>" or null,
    "learned_patterns_added": <count>
  }

  Aggregate from:
    - sessions/<id>/dashboard.md (metrics, cost)
    - sessions/<id>/snapshot.md (files modified)
    - audit.jsonl (agent_invocations, agents_activated)
    - cost.jsonl (tokens_used, estimated_cost_usd)
    - learned.jsonl diff between session start and now (learned_patterns_added)

STEP 5 — Update sessions/index.json
  Read .agents/sessions/index.json
  Find entry matching session_id
  Update:
    status: "COMPLETED"
    tasks_done: <actual count>
    tasks_pending: 0
    ts: <current ISO>
  If no entry exists (session was never saved via /context-save):
    Append a new entry with status "COMPLETED"

STEP 6 — Report to user
  Present inline summary:
    "Session <id> closed.
     Duration: X min | Tasks: Y completed, Z failed
     Total cost: ~$W | Patterns learned: N
     Dashboard: .agents/sessions/<id>/dashboard.md
     Record: .agents/sessions/<id>/session.json"

STEP 7 — Clear working memory
  No data is deleted — working memory (in-context state) is released when the
  agent returns to IDLE. Episodic memory (summary.md, snapshot.md) persists
  on disk for /context-restore.
```

---

## Output Artifacts
- `.agents/sessions/<session-id>/session.json` — structured session metadata record
- `.agents/sessions/<session-id>/snapshot.md` — human-readable snapshot (via context-save)
- `.agents/sessions/<session-id>/dashboard.md` — metrics dashboard (via retro)
- `.agents/learned.jsonl` — new patterns appended (via learn)
- `.agents/sessions/index.json` — index updated to COMPLETED

---

## Guardrails
- /close must run at EVERY session end — it is not optional
- All 7 steps run even if an intermediate step fails; log the failure and continue
- session.json is APPENDED (written once) — never overwritten mid-session
- If /context-save already ran this session, its snapshot artifacts already
  exist — step 1 overwrites them with the final snapshot
- Do NOT delete any files during close — only write final state
- If /retro or /learn were already run manually via command, steps 2-3 should
  detect that (check if dashboard.md exists) and skip to avoid duplicate work
- The Orchestrator must verify /close produced all 4 output artifacts before
  returning to IDLE — if any artifact is missing, log a WARNING to audit.jsonl
- After /close, the session is COMPLETED — /context-restore will not find it
  as the most recent IN_PROGRESS session
