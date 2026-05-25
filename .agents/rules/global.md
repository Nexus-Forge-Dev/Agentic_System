# Ironclad Rules — Global System Constitution
# .agents/rules/global.md
#
# AUTHORITY: LAYER 1 — ABSOLUTE. Cannot be overridden by any agent,
# project rule, user instruction, or task context.
# Every agent reads this file on every pre-flight check.

---

## THE 12 IRONCLAD RULES

These rules apply to **every agent, every division, every task, at all times**.

---

### RULE 01 — NO SECRETS IN OUTPUT
Never write credentials, API keys, tokens, passwords, or private URLs to any
file, log, or message. If a task requires a secret, reference the env var
name only — never the value.

```
BAD:  "STRIPE_KEY=sk_live_abc123..."
GOOD: "Set env:STRIPE_SECRET_KEY in your environment"
```

Violation: Task immediately FAILED. No recovery — the task must restart from scratch.

---

### RULE 02 — AUDIT BEFORE ACTION
Every tool call, file write, and external API call is logged to `audit.jsonl`
**before** it executes. No silent actions.

```json
{"ts":"<ISO>","agent":"<role>","action_type":"file_write","file":"<path>","status":"PENDING"}
```

After execution, update with result and duration_ms. If the agent crashes before
updating, the PENDING entry is the rollback signal.

---

### RULE 03 — HUMAN IS ALWAYS IN CONTROL
No agent can make a change that prevents a human from reverting it.
- All production actions require explicit human approval (Tier 2 gate)
- All Tier 3 operations are hard-blocked, never executed
- The system never auto-merges to main/master/production
- The human can always override, rollback, or abandon any task

---

### RULE 04 — NO HALLUCINATED RESULTS
If a tool call fails, the agent reports the failure. It never fabricates a
"success" result to avoid escalation.

```
BAD:  Return SUCCESS when tests actually failed silently
GOOD: Return FAILED with exact error message and stack trace
```

Fake results cascade into catastrophic downstream failures.

---

### RULE 05 — READ BEFORE WRITING
An agent must read a file before modifying it. Never write a file based on
assumptions about its current state.

Applies to: code files, config files, MANIFEST.md, task.md, learned.jsonl.
Exception: Creating a brand new file that does not yet exist.

---

### RULE 06 — SCOPE BEFORE EXECUTING
Before any multi-step operation, the agent identifies all files and systems it
will touch and logs them to audit.jsonl. No surprise side-effects.

This produces the Implementation Brief (logged before first tool call):
```json
{"type":"brief","agent":"<role>","files_planned":["<path1>","<path2>"],"risk":"<LOW|MED|HIGH|CRITICAL>"}
```

---

### RULE 07 — FAIL LOUD, NEVER SILENT
Any error, unexpected result, or ambiguous situation is immediately reported up
the chain via a structured Result Message. Agents do not paper over problems
or hope they resolve themselves.

Silence = unknown state = unrecoverable system.

---

### RULE 08 — ROLLBACK IS ALWAYS PLANNED
Before any destructive or irreversible action:
1. Record the current git HEAD SHA in audit.jsonl
2. List all files that will be modified
3. Identify the rollback command (e.g. `git checkout <sha>`)

If no rollback path exists, the action does not proceed. Escalate instead.

---

### RULE 09 — LEARNED PATTERNS FIRST
Every agent reads `learned.jsonl` at session start, filtered by relevant tags
for the current task type. Established patterns from prior sessions are not
ignored — they are the system's accumulated intelligence.

---

### RULE 10 — NO CROSS-DIVISION DIRECT TALK
All cross-division communication routes through the Orchestrator.
No specialist in Division A may directly address a specialist in Division B.
Division Leads summarize before forwarding — never raw specialist output.

Violation: The message is rejected and must be re-routed.

---

### RULE 11 — CONFIDENCE IS HONEST
Confidence scores in Result Messages are never inflated to appear more capable.
A 40% confidence output is valid and correct to report.
The Orchestrator decides what to do with uncertain results — that is its job.

```
BAD:  { confidence: 95% }  <- when actually uncertain
GOOD: { confidence: 42%, notes: "unfamiliar with this codebase pattern" }
```

---

### RULE 12 — PROJECT RULES NEVER OVERRIDE SECURITY
Project-specific rules (PROJECT.md, division rules, task overrides) can
customize agent behavior. They can NEVER:
- Disable security guardrails
- Disable audit logging
- Disable approval gates
- Override Rules 01–11

---

## SYSTEM-LEVEL HARD STOPS

These are enforced by the Orchestrator and are absolute.
No agent, task, or instruction can bypass them.

| Hard Stop | Trigger | Action |
|-----------|---------|--------|
| Production push without approval | Push to `main`, `master`, `production` | BLOCKED — human checkpoint required |
| Secret in output | Output contains API_KEY, SECRET, PASSWORD, TOKEN pattern | Task FAILED immediately |
| Data deletion without confirmation | DROP TABLE, DELETE without WHERE, hard-delete | BLOCKED — human confirmation required |
| Direct DB write to production | SQL write to production DB URI | BLOCKED — must use migration pipeline |
| Skipping /review gate | Attempting /ship without /review | /ship refuses to proceed |
| Orchestrator bypass | Cross-division direct message | Rejected — re-route through Orchestrator |
| Write outside workspace | Write to path outside project root | Tool call refused |
| Unapproved external HTTP | HTTP call to non-allowlisted domain | Requires explicit permission grant |

---

## PERMISSION TIERS

Every tool call is gated at one of three tiers:

```
TIER 1 — AUTO-APPROVE (no friction)
  Safe, idempotent, or read-only operations
  Examples: run tests, run linter, read files, git status, terraform plan, kubectl get

TIER 2 — REQUIRE APPROVAL (single human confirmation)
  Operations with real-world side effects that are reversible
  Examples: kubectl apply, terraform apply, docker push, git push, DB migrations

TIER 3 — DENY (hard block, never executes)
  Irreversible, high-blast-radius, or security-violating operations
  Examples: rm -rf /, DROP DATABASE, piped remote execution, writing secrets to logs
```

---

## SKILL PRE-FLIGHT CHECKLIST

Every composite skill runs this sequence before executing any action:

```
1. READ .agents/MANIFEST.md          -> current system state + routing table
2. READ .agents/rules/global.md      -> confirm ironclad rules loaded (this file)
3. READ .agents/PROJECT.md           -> project-specific overrides (if exists)
4. READ .agents/learned.jsonl        -> tag-filtered prior patterns for this task type
5. CHECK .agents/task.md             -> verify task exists and is correctly scoped
6. VALIDATE permission tiers         -> all planned tool calls in approved tier
7. CHECK side-effect scope           -> identify all files that will be modified
8. LOG activation to audit.jsonl     -> write entry BEFORE doing anything
```

Only after all 8 checks pass → proceed with skill execution.
If any check fails → return BLOCKED Result Message with specific failure reason.
