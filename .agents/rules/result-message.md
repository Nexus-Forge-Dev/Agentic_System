# Result Message Protocol
# .agents/rules/result-message.md
# Authority: LAYER 1 — Communication contract for all agents
# Source: communication_guardrails_errors.md §1.2, §1.4, §1.5

---

## The Fundamental Communication Rule

```
✅ ALLOWED: Specialist → Division Lead (within same division)
✅ ALLOWED: Division Lead → Orchestrator
✅ ALLOWED: Orchestrator → any Division Lead (cross-division routing)
❌ FORBIDDEN: Specialist (Div A) → Specialist (Div B) — direct cross-division
❌ FORBIDDEN: Division Lead (Div A) → Division Lead (Div B) — direct cross-division
❌ FORBIDDEN: Orchestrator → Specialist (skipping the Lead)
```

**Every message between agents uses the Result Message schema below.** No free-form text. No exception.

---

## Result Message Schema

```
╔══════════════════════════════════════════════════════════════════╗
║                        RESULT MESSAGE                            ║
╠══════════════════════════════════════════════════════════════════╣
║ FROM:          <agent-role>/<division>                           ║
║ TO:            <orchestrator | division-lead>                    ║
║ SESSION_ID:    <ulid>                                            ║
║ TASK_ID:       <ref from task.md>                                ║
║ TIMESTAMP:     <ISO-8601>                                        ║
╠══════════════════════════════════════════════════════════════════╣
║ STATUS:        SUCCESS | PARTIAL | BLOCKED | FAILED | TIMEOUT    ║
║ CONFIDENCE:    <0–100%> (agent's self-assessed quality)          ║
╠══════════════════════════════════════════════════════════════════╣
║ SUMMARY:                                                         ║
║   <2–4 sentences: what was done, why it matters>                 ║
╠══════════════════════════════════════════════════════════════════╣
║ OUTPUT:                                                          ║
║   type: <code | config | analysis | verdict | plan | report>     ║
║   artifacts: [<list of files created or modified>]               ║
║   content: <the actual output or path to the output file>        ║
╠══════════════════════════════════════════════════════════════════╣
║ SIDE_EFFECTS:                                                    ║
║   files_modified: [<paths>]                                      ║
║   commands_run: [<commands executed>]                            ║
║   external_calls: [<MCP tools invoked>]                          ║
╠══════════════════════════════════════════════════════════════════╣
║ DRIFT: <true | false>                                            ║
║   (true if agent touched files not listed in Implementation Brief)║
║   drift_detail: [<extra files touched and why>]                  ║
╠══════════════════════════════════════════════════════════════════╣
║ BLOCKERS: (only if STATUS = BLOCKED)                             ║
║   - <what is blocking progress — specific, not vague>            ║
║   - <what the Orchestrator or human needs to resolve it>         ║
╠══════════════════════════════════════════════════════════════════╣
║ PARTIAL_COMPLETION: (only if STATUS = PARTIAL)                   ║
║   completed: [<what was done>]                                   ║
║   remaining: [<what still needs to be done>]                     ║
║   rollback_needed: true | false                                  ║
╠══════════════════════════════════════════════════════════════════╣
║ ERROR: (only if STATUS = FAILED | TIMEOUT)                       ║
║   type: <tool_failure | permission_denied | invalid_state |      ║
║          context_overflow | external_api_error | logic_error |   ║
║          ambiguous_instruction | missing_dependency>             ║
║   message: <exact error message>                                 ║
║   stack: <relevant trace or context>                             ║
║   rollback_performed: true | false                               ║
╠══════════════════════════════════════════════════════════════════╣
║ LEARNINGS: (optional — propose pattern for learned.jsonl)        ║
║   <Pattern worth saving — only if non-trivial and replicable>    ║
╠══════════════════════════════════════════════════════════════════╣
║ NEXT_ACTION_RECOMMENDATION:                                      ║
║   <what the Orchestrator should do next — specific suggestion>   ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## Status Definitions

| Status | Meaning | Agent Action |
|--------|---------|-------------|
| **SUCCESS** | Task completed fully, output meets success definition | Return result, update task.md to `done` |
| **PARTIAL** | Completed some but not all of the task | Report done/remaining, note if rollback needed |
| **BLOCKED** | Has a dependency it cannot resolve alone | Describe blocker precisely, wait for resolution |
| **FAILED** | Unrecoverable error after 2 retry attempts | Attempt rollback, log full error, stop related work |
| **TIMEOUT** | Exceeded max turn budget | Save current state, report progress checkpoint |

---

## Error Type Taxonomy

```
tool_failure          → A tool call (MCP, shell, file op) returned an error
permission_denied     → Agent attempted an action it doesn't have permission for
invalid_state         → System in unexpected state (file missing, wrong branch)
context_overflow      → Task context exceeded model window; cannot continue safely
external_api_error    → Third-party API (Sentry, GitHub, etc.) returned an error
logic_error           → Agent's own reasoning produced an internally inconsistent result
ambiguous_instruction → Task description has conflicting requirements
missing_dependency    → A required resource (file, env var, service) doesn't exist
```

---

## Audit Trail Requirement (§1.5)

Every Result Message is appended to `sessions/<id>/audit.jsonl` **by the RECEIVING agent** before any further action is taken. This ensures the full chain of delegation is always reconstructible.

```jsonl
{"ts":"...","from":"sdet","to":"quality-lead","task":"task_001","status":"SUCCESS","confidence":92,"artifacts":["tests/signup.test.ts"]}
{"ts":"...","from":"quality-lead","to":"orchestrator","task":"task_001","status":"DELEGATING","next":"backend-architect"}
{"ts":"...","from":"orchestrator","to":"engineering-lead","task":"task_001","status":"DELEGATING","context_passed":["failing-tests-summary"]}
```

**Who logs what:**
- Specialist sends Result Message → **Division Lead logs it** to audit.jsonl
- Division Lead sends Result Message → **Orchestrator logs it** to audit.jsonl
- Orchestrator sends Result Message → **Orchestrator logs it** (it is also the receiver in session terms)

---

## Context Isolation Rules (§1.4)

| Rule | Enforcement |
|------|------------|
| Each agent reads only its own division context + what the Orchestrator explicitly passes | Orchestrator is the gatekeeper of what crosses division lines |
| No agent carries state from a previous unrelated task | Each task starts from a clean preamble read |
| Division Leads summarize before escalating | Never forward raw specialist output — always a summary |
| Only the Orchestrator writes to `task.md` | Agents read it; specialists never write to it |
| MCP tool call results are scoped to the invoking agent | Tool results returned only to the agent that called them |
