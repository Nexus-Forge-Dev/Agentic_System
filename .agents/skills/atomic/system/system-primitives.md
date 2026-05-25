# System Atomic Skill: mcp_call
# Wrapper for all MCP tool invocations — enforces lifecycle protocol
# Internal — not user-invokable
# Source: agents_and_skills_design.md §9.1

---

## Purpose

Wraps every MCP tool invocation with the full Tool Call Lifecycle (see `rules/tool-call-lifecycle.md`):
permission check → cache check → execute → cache write → log → return.

## Inputs

```json
{
  "tool": "github | figma | terraform | k8s | sentry | database | playwright | browser",
  "operation": "<specific operation name>",
  "inputs": { ... },
  "retry_on_error": false,
  "bypass_cache": false
}
```

## Execution Steps

1. **Permission check**: Look up `tool + operation` in the permission tier table
   - Tier 3 → DENY immediately, log denial
   - Tier 1 → auto-approve
   - Tier 2 → present approval prompt, wait for `y`
2. **Cache check** (unless `bypass_cache: true`):
   - Compute `key = hash(tool + ":" + operation + ":" + sorted_inputs_json)`
   - Look up `.agents/cache/<tool>/<key>.json`
   - If found and not expired → return cached result immediately
3. **Execute** the MCP tool call
4. **Write to cache**: Save result with TTL from the rate-limit table
5. **Log to** `sessions/<id>/tool_calls.jsonl`
6. **Return** result to invoking agent

---

# System Atomic Skill: tool_cache_check
# Checks cache before tool invocation
# Internal — not user-invokable

## Purpose

Standalone cache lookup — can be called before `mcp_call` to decide whether to even attempt a call.

## Inputs

```json
{
  "tool": "<tool_name>",
  "operation": "<operation>",
  "inputs": { ... }
}
```

## Output

```json
{
  "hit": true,
  "result": { ... },
  "expires_at": "<ISO-8601>"
}
```
or
```json
{
  "hit": false
}
```

---

# System Atomic Skill: audit_log_write
# Writes a structured entry to audit.jsonl
# Internal — called by agents before executing any action

## Purpose

Ensures the audit trail is written BEFORE the action executes (RULE 02).

## Inputs

```json
{
  "action_type": "tool_call | file_write | skill_activate | brief_submit | brief_approve | agent_delegate",
  "session_id": "sess_<ulid>",
  "task_id": "task_<ulid>",
  "agent": "<role>",
  "tool": "<tool_name or null>",
  "operation": "<operation or null>",
  "permission_tier": 1,
  "approved_by": "auto | user | <role>",
  "inputs_summary": "<brief description of what is being done>",
  "files_scope": ["<path1>", "<path2>"]
}
```

## Behavior

- Appends one JSONL line to: `sessions/<id>/audit.jsonl`
- Never overwrites. Append-only.
- If audit.jsonl is not writable → BLOCK the entire action. Do not proceed.
  (RULE 02: if we can't audit it, we can't do it)

---

# System Atomic Skill: memory_read
# Reads and filters learned.jsonl

## Inputs

```json
{
  "tags": ["<tag1>", "<tag2>"],
  "max_results": 5,
  "min_confidence": 0.6
}
```

## Output

Array of matching memory entries, sorted by confidence DESC, used_count DESC.

---

# System Atomic Skill: memory_write
# Writes a new pattern to learned.jsonl

## Inputs

Memory entry object conforming to the schema in `rules/memory-protocol.md`.

## Behavior

- Validates schema before writing
- Checks for duplicate `pattern` slug — if exists, update `used_count` and `ts` instead
- Appends to `learned.jsonl`

---

# System Atomic Skill: context_compress
# Applies the 4-step context compression protocol

## Inputs

```json
{
  "current_context_tokens": 150000,
  "budget_limit": 200000
}
```

## Behavior

Runs steps 1–3 of the Context Compression Protocol (`rules/context-protocol.md §4.4`).
Never compresses the System Layer (step 4 = no-op).

---

# System Atomic Skill: session_checkpoint
# Saves current session state to disk

## Behavior

Writes or updates:
- `sessions/<id>/summary.md` — session progress summary
- `sessions/<id>/task.md` — current task DAG snapshot
- `sessions/index.json` — updates the session index entry

Call this: at the end of every completed task, and before any TIMEOUT state.

---

# System Atomic Skill: delegate
# Passes work to another agent via the Orchestrator protocol

## Inputs

```json
{
  "to": "<agent-role>",
  "task_id": "task_<ulid>",
  "handoff_packet": {
    "goal": "...",
    "constraints": [],
    "inputs": {},
    "expected_output": "...",
    "relevant_memories": []
  }
}
```

## Behavior

- Validates: `to` agent is in the allowed delegation list (see `rules/agent-capability-matrix.md`)
- Logs delegation to `audit.jsonl`: `{"action":"agent_delegate","from":"<role>","to":"<role>","task_id":"..."}`
- Returns the task to the Orchestrator with the handoff packet

---

# System Atomic Skill: timer
# Non-blocking timer — logs a future checkpoint

## Inputs

```json
{
  "duration_ms": 30000,
  "label": "Wait for CI run to complete"
}
```

## Behavior

- Logs a checkpoint entry to `audit.jsonl`: `{"action":"timer_set","label":"...","fires_at":"<ISO>"}`
- Agent continues other work (non-blocking)
- When timer fires: agent checks the original wait condition and proceeds

---

# System Atomic Skill: notify
# Sends an external notification — ALWAYS Tier 2

## Inputs

```json
{
  "channel": "slack | github-comment | email",
  "message": "...",
  "context": "What triggered this notification"
}
```

## Permission

Always Tier 2 — requires explicit human approval before any external message is sent.
