# Command: /context-save
# .agents/commands/context-save.md
# Owner: Orchestrator
# Trigger: /context-save — run before ending a long session

## Purpose
Snapshot current session state so it can be restored in a future session.
Prevents losing context on multi-day tasks. Also updates sessions/index.json.

## What Gets Saved
```
.agents/sessions/<session-id>/
  snapshot.md              <- Human-readable session summary
  task.md                  <- Copy of current task.md state
  audit-tail.jsonl         <- Last 100 audit entries
  learned-candidates.json  <- Pattern candidates not yet written to learned.jsonl
```

## Workflow

```
STEP 1 — Determine session ID
  If no active session ID: generate sess_<ulid>
  Use it for all artifact paths

STEP 2 — Write snapshot.md

STEP 3 — Copy task.md → .agents/sessions/<session-id>/task.md

STEP 4 — Extract last 100 lines from audit.jsonl
  Write to: .agents/sessions/<session-id>/audit-tail.jsonl

STEP 5 — Write learned-candidates.json
  List all pattern candidates identified this session but not yet written
  to learned.jsonl (these can be picked up by /learn next session)

STEP 6 — Update sessions/index.json  ← GAP FIX
  Read existing .agents/sessions/index.json (create if not exists)
  Append entry for this session:
  {
    "session_id": "<id>",
    "ts": "<ISO>",
    "goal": "<goal summary>",
    "status": "IN_PROGRESS | COMPLETED",
    "tasks_done": <N>,
    "tasks_pending": <M>,
    "snapshot_path": ".agents/sessions/<id>/snapshot.md"
  }
  Write updated index back to .agents/sessions/index.json

STEP 7 — Confirm
  "Session saved as <id>. Resume with: /context-restore <id>"
```

## snapshot.md Contents
```markdown
# Session Snapshot — <date>
Session ID: <id>
Goal: <goal>
Status: IN_PROGRESS

## What Was Completed
<list of done tasks with confidence scores>

## What Remains
<list of pending tasks with dependencies>

## Context for Next Session
<key decisions made, patterns discovered, blockers encountered>

## Files Modified This Session
<list of all modified files from audit.jsonl>

## How to Resume
Run: /context-restore <session-id>
```

---

# Command: /context-restore
# Owner: Orchestrator
# Trigger: /context-restore "<session-id>"

## Purpose
Restore context from a saved session snapshot to resume work.
If no session ID given, reads sessions/index.json to find the most recent IN_PROGRESS session.

## Workflow
```
STEP 1 — Resolve session ID
  If session ID provided: use it
  If NOT provided:
    Read .agents/sessions/index.json
    Find most recent entry with status = "IN_PROGRESS"
    Use that session ID

STEP 2 — Read .agents/sessions/<session-id>/snapshot.md

STEP 3 — Restore task.md
  Merge pending tasks from session/task.md with current .agents/task.md
  Pending tasks from prior session take priority at the top of the list

STEP 4 — Inject learned candidates
  Read session/learned-candidates.json
  Remind agent: "These patterns were identified but not yet saved — run /learn at end of session"

STEP 5 — Surface summary to user
  "Restoring session <id> from <date>.
   Goal: <goal>
   Remaining tasks: <N> — showing below."
  Print the pending task list.

STEP 6 — Ask: "Continue where we left off? [y/n]"

STEP 7 — If yes: Resume from first pending task in restored task.md
```
