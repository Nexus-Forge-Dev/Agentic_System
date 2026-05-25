# /context-restore — Session Restore Skill
# Restores working state from a previous session
# Owner: Orchestrator | Trigger: /context-restore [session-id]
# Source: agentic_system_design.md §5.3

---

## Preamble (runs first, always)

1. READ `.agents/MANIFEST.md` — current system state + routing table
2. READ `.agents/rules/global.md` — confirm 12 ironclad rules loaded
3. READ `.agents/PROJECT.md` — project-specific context
4. READ `.agents/learned.jsonl` — tag-filtered patterns (all tags, restore = general context)
5. LOG `{"action":"context-restore","ts":"<ISO>"}` → `audit.jsonl` (before anything else)

---

## Skill Flow

```
User: /context-restore [optional: session-id]
  │
  ▼
Step 1 — Identify Session to Restore
  If session-id provided:
    → Look up sessions/<session-id>/
  If no session-id provided:
    → Open sessions/index.json
    → Find most recent completed session by timestamp
    → Present to user: "Restoring session <id> from <timestamp>: <goal>"
    → Confirm before proceeding

Step 2 — Read Session Records
  Read: sessions/<id>/summary.md         (what happened in the session)
  Read: sessions/<id>/task.md            (the task DAG with statuses)
  Read: sessions/<id>/audit.jsonl        (last 10 entries for context)
  Check: Were there uncompleted tasks? (status: pending or in_progress)

Step 3 — Present Session State to Human
  Output:
  ╔══════════════════════════════════════════════╗
  ║  RESTORING SESSION: <session-id>             ║
  ║  Date: <timestamp> | Goal: <session goal>    ║
  ╠══════════════════════════════════════════════╣
  ║  COMPLETED TASKS:                            ║
  ║  ✅ [list of done tasks]                     ║
  ╠══════════════════════════════════════════════╣
  ║  UNCOMPLETED TASKS:                          ║
  ║  ⏳ [list of pending/in-progress tasks]       ║
  ╠══════════════════════════════════════════════╣
  ║  KEY DECISIONS MADE:                         ║
  ║  [From summary.md — decisions that matter]   ║
  ╠══════════════════════════════════════════════╣
  ║  READY TO CONTINUE:                          ║
  ║  → Next task: [first uncompleted task]       ║
  ╚══════════════════════════════════════════════╝

Step 4 — If Uncompleted Tasks Exist
  Ask: "Resume from where we left off? (y/n)"
  If y:
    → Re-activate the first pending task in the DAG
    → Copy session goal and task.md into active memory
    → Continue execution from the uncompleted task
  If n:
    → Session state loaded as read-only context
    → User starts a new task from here

Step 5 — Inject New Memories
  Compare current learned.jsonl entries vs. those at session close time
  For each new entry added since the session ended:
    → Announce: "📚 New pattern learned since last session: <pattern>"
  This ensures the restored session benefits from patterns learned in other sessions
```

---

## Output

```
Artifacts: None (restore is non-destructive — no new files written)
Logs: audit.jsonl entry with "action":"context-restore"
Side effects: Active memory is now loaded with prior session context
```

---

## Error Cases

| Error | Action |
|-------|--------|
| Session ID not found | List all available sessions → prompt user to choose |
| sessions/index.json missing | Scan sessions/ directory and reconstruct index |
| summary.md corrupt or empty | Read task.md directly and reconstruct state from it |
| All tasks in session were completed | Inform user: "Previous session complete. Starting fresh." |
