# Current Session Task DAG
# .agents/task.md
# Written and maintained EXCLUSIVELY by the Orchestrator.
# Agents read this — they never write to it directly.

---

## Session: [Not started]

> Start a session by running any slash command. The Orchestrator will
> initialize this file with a session ID, goal, and task breakdown.

---

## Template (Orchestrator fills this in on session start)

```markdown
## Session: YYYY-MM-DD | Goal: <user's stated goal>
Session ID: sess_<ulid>
Started:    <ISO timestamp>

### Task DAG

- [ ] task_001 -> <Agent Role>: <task description>  [risk: LOW|MED|HIGH|CRITICAL]
- [ ] task_002 -> <Agent Role>: <task description>  [depends: task_001]
- [ ] task_003 -> <Agent Role>: <task description>  [parallel: task_002]

### Completed

- [x] task_001 -> SDET: Write failing tests  ✅ Done (92% conf) | tests/auth.test.ts
```

### Status Key
- `[ ]` = Not started (waiting)
- `[/]` = In progress (agent actively working)
- `[x]` = Completed successfully
- `[!]` = Failed or blocked (see error in Result Message)
- `[~]` = Rolled back
