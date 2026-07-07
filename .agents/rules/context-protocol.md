# Context Protocol
# .agents/rules/context-protocol.md
# Authority: LAYER 1 — Context management for all agents
# Source: agentic_system_design.md §4

---

## §4.1 Context Budget Allocation

Every agent invocation has a finite context window. This budget is allocated deliberately:

```
┌─────────────────────────────────────────────────────┐
│                    CONTEXT WINDOW                    │
│  ┌───────────────────────────────────────────────┐  │
│  │  SYSTEM LAYER (always-on)          ~5K tokens  │  │
│  │  MANIFEST.md + active persona + global rules   │  │
│  ├───────────────────────────────────────────────┤  │
│  │  MEMORY LAYER (injected at start)  ~10K tokens │  │
│  │  Top 5 semantic memories + session summary     │  │
│  ├───────────────────────────────────────────────┤  │
│  │  TASK LAYER (current work)         ~20K tokens │  │
│  │  task.md + relevant files + tool results       │  │
│  ├───────────────────────────────────────────────┤  │
│  │  EXECUTION BUFFER (free for agent) ~165K tokens│  │
│  │  Tool calls, reasoning, code output            │  │
│  └───────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

### Budget Rules

1. **System layer is always injected first** — never compressed or dropped
2. **Memory layer is injected second** — compressed if > budget limit (see §4.4)
3. **Task layer** only injects files **directly relevant** to the current task — no full-codebase dumps
4. **Execution buffer** is left as large as possible for the agent to work in

---

## §4.2 Path-Scoped Rule Injection

Rules are NOT all loaded all the time. Only inject rules based on what the agent is actively doing.

```
Trigger Condition                           Rule File Injected
───────────────────────────────────────── → ──────────────────────────────────────
Always (every agent, every invocation)   → .agents/rules/global.md
Always (every agent, every invocation)   → .agents/rules/agent-lifecycle.md
Always (every agent, every invocation)   → .agents/rules/result-message.md
Agent is devops / cloud-architect        → .agents/rules/divisions/platform.md
Agent is engineer / backend / frontend   → .agents/rules/divisions/engineering.md
Agent is database-engineer               → .agents/rules/divisions/engineering.md
Agent is sdet / quality / visual-qa      → .agents/rules/divisions/quality.md
Agent is ui-designer / ux / animator     → .agents/rules/divisions/design.md
Agent is intelligence / analyst          → .agents/rules/divisions/intelligence.md
File path matches *.tf or *.yaml (k8s)  → .agents/rules/divisions/platform.md
File path matches *.test.* or *.spec.*  → .agents/rules/divisions/quality.md
File path matches prisma/schema*         → .agents/rules/divisions/engineering.md
```

**Why:** Context pollution is the #1 cause of agent errors. An agent having too much irrelevant context pattern-matches incorrectly. Inject only what applies.

---

## §4.3 Context Handoff Packet

When the Orchestrator delegates to a Specialist, it does NOT pass the full context.
It passes a **Handoff Packet** — a minimal, scoped bundle:

```json
{
  "task_id": "task_<ulid>",
  "goal": "One sentence: what to do and what success looks like",
  "constraints": [
    "Constraint from rules directly relevant to this task",
    "Constraint from PROJECT.md relevant to this task"
  ],
  "inputs": {
    "files": ["path/to/relevant/file1.ts", "path/to/relevant/file2.ts"],
    "tool_results": {
      "description": "What prior tool outputs are relevant",
      "data": {}
    }
  },
  "expected_output": "Description of what the Specialist must produce to complete the task",
  "relevant_memories": ["mem_<ulid1>", "mem_<ulid2>"]
}
```

### Handoff Rules

- **The Specialist loads ONLY this packet + its own persona + applicable rules**
- **The Specialist NEVER sees** the Orchestrator's full planning context
- **Constraints field** must be pre-filtered — only constraints relevant to THIS task
- **relevant_memories** must be the actual `mem_id` values from `learned.jsonl` — Specialist reads those specific entries
- **Division Leads summarize before escalating** — they never forward raw specialist output

---

## §4.4 Context Compression Protocol

When a session grows long and context approaches the window limit, compression runs in this order:

```
STEP 1 — Summarize Completed Tasks
  In task.md: Replace each [x] completed task entry with a one-line summary
  Before: "- [x] task_001 → Backend Architect: Implement auth service, createSession,
            validateToken, revokeSession, update login.ts, add Session model to schema,
            write migration. All tests pass. 88% confidence."
  After:  "- [x] task_001 → Backend Architect: Auth service ✅ (3 files, 88%)"

STEP 2 — Drop Stale Tool Results
  Tool results older than 5 agent steps are removed from working memory
  BUT saved to tool cache on disk (.agents/cache/) before removal
  Use: powershell .agents/scripts/cache.ps1 write <tool> <operation> "<inputs_json>" "<result_json>" <ttl>
  Rule: "older than 5 steps" = the result was injected more than 5 tool calls ago

STEP 3 — Compress Episodic Memory
  If session summary is > 3,000 tokens:
    Re-summarize the session summary to key bullet points only
    Preserve: decisions made, files created, errors encountered, confidence scores
    Remove: step-by-step narration, intermediate reasoning

STEP 4 — NEVER Compress System Layer
  The following are NEVER removed, NEVER compressed, NEVER truncated:
  - .agents/rules/global.md (ironclad rules)
  - Active persona file
  - MANIFEST.md routing table
  - Current task entry in task.md (the specific task being executed now)
```

---

## §4.5 Context Isolation Rules

| Rule | What It Means |
|------|--------------|
| Division-scoped context | Each agent reads only its own division's context + what the Orchestrator explicitly passes in the Handoff Packet |
| No state bleed | Each task starts from a clean preamble read — no agent carries state from a previous unrelated task |
| Lead-first summarization | Division Leads NEVER forward raw Specialist output to Orchestrator — always produce a summary first |
| Orchestrator owns task.md | Orchestrator writes to task.md. Agents read it. Specialists never write to it. |
| MCP result scoping | Tool call results are returned only to the invoking agent — a Backend Architect's GitHub MCP call result is not visible to the Design Division |
