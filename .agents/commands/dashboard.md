# Command: /dashboard
# .agents/commands/dashboard.md
# Owner: Orchestrator
# Trigger: /dashboard

## Purpose
Full session view — task DAG with all statuses, agent outputs, files changed, reports generated, and running cost.

## Output
```
FORGE NEXUS DASHBOARD — <timestamp>
=====================================
Session: <id> | Goal: <goal>

TASK DAG
--------
[x] task_001 → SDET: Write failing tests       ✅ 4 tests written (8 min, 94% conf)
[x] task_002 → Backend Architect: Implement    ✅ All tests passing (12 min, 88% conf)
[/] task_003 → Security Engineer: Security review  🔄 In progress (3 min)
[ ] task_004 → DevOps Engineer: /ship              ⏳ Waiting

QUALITY GATE
------------
/review: PENDING

FILES CHANGED
-------------
  src/services/auth.ts              MODIFIED
  src/routes/auth.ts                MODIFIED
  tests/auth.test.ts                CREATED

REPORTS
-------
  .agents/reports/review-<ts>.md   (when ready)

COST
----
  Total tokens: 28,450 input / 8,200 output
  Estimated cost: ~$0.14
  Most expensive: Backend Architect (12,000 tokens)
```

## Notes
- Read-only (Tier 1)
- Sources: task.md + audit.jsonl + cost.jsonl + reports/ directory listing
