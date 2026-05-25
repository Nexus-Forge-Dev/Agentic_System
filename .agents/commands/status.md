# Command: /status
# .agents/commands/status.md
# Owner: Orchestrator
# Trigger: /status

## Purpose
Instant session snapshot — active agent, queue, done list, cost so far.

## Output
```
/status — <timestamp>
========================
Goal:    <current session goal>
Active:  <agent role> — <task> (started <N> min ago)
Queued:  <agent role>: <task> | <agent role>: <task>
Done:    <N> tasks ✅  |  <M> blocked ⚠️

Quality Gate: <PENDING | PASSED 8.7/10 | FAILED 6.2/10>
Cost:    <N> tokens (~$<X> est.)
Time:    <session duration>
```

## Notes
- Never modifies any files (Tier 1, read-only)
- Sources data from: task.md (task status) + cost.jsonl (running total) + audit.jsonl (active agent)
