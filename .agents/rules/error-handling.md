# Error Handling Protocol
# .agents/rules/error-handling.md
# Authority: LAYER 1 — Error handling for all agents
# Source: communication_guardrails_errors.md §5

---

## The Four Error States

| State | Meaning | Agent Action | Escalation |
|-------|---------|-------------|-----------|
| **BLOCKED** | Has a dependency it cannot resolve alone | Stop, describe blocker precisely, wait | Division Lead → Orchestrator → Human |
| **PARTIAL** | Completed some but not all of the task | Report done/remaining, whether rollback needed | Division Lead decides: continue, retry, or rollback |
| **FAILED** | Unrecoverable error — cannot proceed | Attempt rollback, log full error, stop all related work | Orchestrator → Human if needed |
| **TIMEOUT** | Exceeded max turn budget | Save current state, report progress checkpoint | Orchestrator decides: resume or restart |

---

## Error Escalation Chain

```
SPECIALIST encounters error
  │
  ├─ Retry with different approach? (max 2 retries, same strategy = NO)
  │    └─ If retry succeeds → return SUCCESS Result Message
  │
  ├─ Still failing after 2 retries?
  │    └─ Return BLOCKED/FAILED Result Message to Division Lead
  │
  ▼
DIVISION LEAD receives error
  │
  ├─ Can it be resolved within the division? (re-delegate to different specialist)
  │    └─ If yes → re-delegate and monitor
  │
  ├─ Needs cross-division resource?
  │    └─ Escalate to Orchestrator with Result Message
  │
  ├─ Permanent blocker within division?
  │    └─ Escalate to Orchestrator with BLOCKED Result Message
  │
  ▼
ORCHESTRATOR receives escalation
  │
  ├─ Cross-division routing: can another division unblock this?
  │    └─ Route to appropriate Division Lead with context
  │
  ├─ Needs human input to resolve?
  │    └─ Surface to human with: exact blocker, options, recommendation
  │
  ├─ Catastrophic failure (data loss risk, security issue)?
  │    └─ STOP ALL ACTIVE TASKS → Human Intervention Checkpoint
  │
  ▼
HUMAN INTERVENTION CHECKPOINT
  └─ Human reviews audit.jsonl + error context
     Makes a decision:
       → Fix and retry
       → Rollback to last clean state
       → Modify the task scope
       → Abandon the task
```

---

## Retry Protocol

Agents do not retry blindly. Each retry must use a **different approach**.

```
RETRY RULES:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Attempt 1: Original approach
  → If fails: diagnose, form hypothesis, plan different approach

Attempt 2: Different approach (documented in audit.jsonl)
  → If fails: escalate — do NOT attempt a third retry with same strategy

WHAT COUNTS AS A "DIFFERENT APPROACH":
  ✅ Using a different tool to achieve the same goal
  ✅ Breaking the task into smaller sub-tasks
  ✅ Requesting additional context before retrying
  ✅ Trying a simpler variant of the task first

WHAT IS NOT A "DIFFERENT APPROACH":
  ❌ Retrying the exact same operation
  ❌ Retrying with only cosmetic changes to parameters
  ❌ Ignoring the error and hoping it resolves

ESCALATION TRIGGER:
  Any error that repeats after 2 different approaches
  → ALWAYS escalates (never a 3rd attempt without human context)
```

---

## Rollback Procedure

```
PRE-ACTION (before any multi-file operation):
  1. Agent logs all files it will modify to audit.jsonl (scope declaration)
  2. Agent records current git HEAD SHA to audit.jsonl
  3. Agent creates a checkpoint entry in task.md

ON FAILURE:
  1. Agent checks: were any files modified before the failure?
  2. If YES:
     a. List modified files in the FAILED Result Message
     b. Check if git is available → git stash or git checkout <sha>
     c. Report: "Rolled back to <SHA> successfully" OR
                "Rollback failed — manual cleanup required for: <files>"
  3. If NO files modified → FAILED state with no rollback needed

ROLLBACK SCOPE RULES:
  ✅ Any file write during the current task → rollback on FAILED
  ✅ Any git commit made during the current task → revert on FAILED
  ❌ Database migrations → NOT automatically rolled back
       (too dangerous — always surfaces to human for manual decision)
  ❌ External API calls (webhooks, notifications) → NOT rollbackable
       (document what was sent in the error report)
  ❌ Deployed artifacts → NOT automatically rolled back
       (/incident command with rollback plan required)
```

---

## Human Intervention Checkpoint Format

When the system cannot resolve an error without human input:

```
╔══════════════════════════════════════════════════════════════════╗
║           ⚠️  HUMAN INTERVENTION REQUIRED                         ║
╠══════════════════════════════════════════════════════════════════╣
║ Task:         <task description>                                  ║
║ Failed Agent: <role/division>                                    ║
║ Error Type:   <taxonomy type from result-message.md>             ║
║ Session:      <session-id>                                       ║
╠══════════════════════════════════════════════════════════════════╣
║ WHAT HAPPENED:                                                   ║
║ <Concise, factual description of what went wrong>                ║
╠══════════════════════════════════════════════════════════════════╣
║ CURRENT STATE:                                                   ║
║ ✅ Completed: [<what was done before failure>]                   ║
║ ❌ Not done: [<what failed>]                                     ║
║ 🔄 Rolled back: [<what was undone>] / Nothing to roll back       ║
╠══════════════════════════════════════════════════════════════════╣
║ YOUR OPTIONS:                                                    ║
║                                                                  ║
║ OPTION A: <specific action — e.g., "Provide the missing env var  ║
║            STRIPE_SECRET_KEY and re-run the task">               ║
║                                                                  ║
║ OPTION B: <alternative — e.g., "Narrow the task scope to exclude ║
║            the payment integration for now">                     ║
║                                                                  ║
║ OPTION C: Abandon this task entirely                             ║
╠══════════════════════════════════════════════════════════════════╣
║ RECOMMENDATION: Option A                                         ║
║ AUDIT LOG: .agents/sessions/<id>/audit.jsonl                     ║
╚══════════════════════════════════════════════════════════════════╝
```

**Rules for the checkpoint:**
- Options must be specific and actionable — never vague ("fix the issue")
- Always present exactly 3 options (A, B, C = Abandon)
- Recommendation is always stated — the system never presents a neutral "your choice"
- Audit log path is always included so the human can inspect what happened

---

## Conflict Resolution Algorithm

When an agent encounters a conflict between a project rule and a framework default:

```
CONFLICT RESOLUTION ALGORITHM:

1. Is the conflict with an Ironclad Rule (Layer 1)?
   → Layer 1 wins. Always. Agent proceeds under Layer 1.

2. Is the conflict with a security guardrail (Tier 3 hard stop)?
   → Guardrail wins. Always. Agent BLOCKED.

3. Is the conflict between Layer 3 (division rule) and Layer 4 (PROJECT.md)?
   → Layer 3 wins over Layer 4
   → EXCEPTION: If Layer 4 has an explicit "Permitted Overrides" entry → Layer 4 wins.

4. Is the conflict between Layer 4 and Layer 5 (task override)?
   → Layer 5 wins for this task only. Expires after task.

5. Is the conflict genuinely ambiguous?
   → Agent does NOT guess. Returns BLOCKED with:
     "Conflict between project rule X and framework default Y.
      Orchestrator needs to clarify before proceeding."
```
