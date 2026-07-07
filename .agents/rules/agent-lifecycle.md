# Agent Lifecycle Protocol
# .agents/rules/agent-lifecycle.md
# Authority: LAYER 1 — applies to every agent, every invocation, every task
# Source: agentic_system_design.md §2.2

---

## The 8-State Agent Lifecycle

Every agent — Orchestrator or Specialist — moves through this exact state machine.
**No agent skips states.** No agent invents additional states.

```
              ┌──────────┐
    ───────►  │   IDLE   │  ◄─────────────────────────┐
              └────┬─────┘                             │
                   │ activated by trigger               │
                   ▼                                    │
              ┌──────────┐                             │
              │ LOADING  │  reads rules + memory        │
              └────┬─────┘                             │
                   │ context ready                      │
                   ▼                                    │
              ┌──────────┐                             │
              │ PLANNING │  decomposes goal             │
              └────┬─────┘                             │
                   │ plan approved (or auto-approved)   │
                   ▼                                    │
              ┌──────────────┐                         │
              │  EXECUTING   │  calls tools, writes     │
              └──────┬───────┘                         │
                     │                                  │
         ┌──────────┴──────────┐                      │
         ▼                     ▼                       │
   ┌──────────┐         ┌───────────┐                 │
   │  ERROR   │         │ REVIEWING │                 │
   │ RECOVERY │         │ (self)    │                 │
   └──────┬───┘         └─────┬─────┘                 │
          │                   │                        │
          └──────────┬────────┘                        │
                     ▼                                 │
             ┌──────────────┐                         │
             │   REPORTING  │  returns result up       │
             └──────┬───────┘                         │
                    │                                  │
                    └──────────────────────────────────┘
                             back to IDLE
```

---

## State Definitions

### IDLE
- Agent is inactive. No context loaded. No task in progress.
- **Entry:** After completing REPORTING, or on initial startup.
- **Exit:** Triggered by: slash command, Orchestrator delegation, session event.

### LOADING
- Agent reads its preamble in this exact order:
  1. `MANIFEST.md` — current system state + routing table
  2. `.agents/rules/global.md` — 12 ironclad rules (confirms loaded)
  3. `.agents/PROJECT.md` — project-specific overrides (if exists)
  4. `learned.jsonl` — tag-filtered prior patterns for this task type (top 5 by confidence)
  5. Session summary (`sessions/<last-id>/summary.md`) if resuming
  6. Own persona file (`personas/<role>.md`)
  7. Division rules (`rules/divisions/<division>.md`)
- **Exit:** All 7 reads complete, context confirmed ready.
- **Error:** If any required file is missing → BLOCKED immediately, log to audit.jsonl.

### PLANNING
- Agent decomposes the goal into sub-tasks.
- For the Orchestrator: builds the task DAG, writes to `task.md`.
- For Specialists: identifies files to touch, determines risk level, produces Implementation Brief.
- **Exit:** Plan complete AND (auto-approved OR explicit approval received).
- **Never skip for:** Any task touching > 1 file, any MEDIUM+ risk task.

### EXECUTING
- Agent executes planned actions: tool calls, file writes, code generation.
- Every tool call goes through the Tool Call Lifecycle (see `rules/tool-call-lifecycle.md`).
- Every file write logged to `audit.jsonl` BEFORE the write executes.
- **Exit:** All planned actions complete → move to REVIEWING.
- **On error:** Move to ERROR RECOVERY.

### ERROR RECOVERY
- Agent encountered a failure during EXECUTING.
- Protocol:
  1. Log the error to `audit.jsonl` immediately
  2. Check `learned.jsonl` for matching prior failure pattern
  3. If match found → attempt auto-recovery with matched approach
  4. If no match → attempt retry with a **different approach** (max 2 retries total)
  5. If still failing → move to REPORTING with `status: FAILED`
- **Exit:** Recovered → move to REVIEWING. Unrecoverable → move to REPORTING.

### REVIEWING (Self-Review)
- Agent reviews its own output before reporting.
- Checks:
  - Did actual files touched match the Implementation Brief? If not → flag `drift: true`
  - Does output meet the task's success definition?
  - Are there any security patterns in the output (secrets, credentials)?
  - Does the output introduce any new errors detectable by static analysis?
- **Exit:** Review complete (pass or flag) → move to REPORTING.

### REPORTING
- Agent constructs a **Result Message** (see `rules/result-message.md`) and returns it.
- Result Message is logged to `audit.jsonl` by the **receiving agent** (not the sender).
- If `drift: true` detected in REVIEWING → Result Message must note drift and list actual files.
- **Exit:** Result Message sent → move to IDLE.

---

## Activation Triggers

| Agent | Trigger |
|-------|---------|
| Orchestrator | Any slash command (including `/close`), session start |
| Division Leads | Orchestrator delegation message |
| Specialists | Division Lead delegation message |
| Research Council | `/council` command only |
| Intelligence Lead | Session end (always), `/retro` |
| Incident Commander | `/incident`, Sentry P0/P1 alert |

---

## Lifecycle Invariants (Never Violated)

1. **No agent skips LOADING** — preamble always runs before any action
2. **No agent skips PLANNING for non-trivial tasks** — intent is always declared before execution
3. **No agent executes without logging to audit.jsonl first** — RULE 02
4. **ERROR RECOVERY max 2 retries** — never a 3rd attempt with the same strategy
5. **REPORTING always produces a Result Message** — no silent completions (RULE 07)
6. **Drift is never silently ignored** — always flagged in Result Message
