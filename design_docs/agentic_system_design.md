# Enterprise Agentic System — Design Document

> A complete design blueprint covering architecture, memory, context, sessions, tasks, security, and observability for a production-grade multi-agent system.

---

## 1. Design Philosophy

Before any subsystem, three principles anchor every decision:

| Principle | What it means |
|---|---|
| **Least Surprise** | An agent should behave exactly the same given the same inputs. No randomness in critical paths. |
| **Minimal Surface Area** | An agent only knows what it needs to know. Context pollution is the #1 cause of agent degradation. |
| **Human in the Loop — by exception, not by default** | The system handles 90% autonomously. Humans only see what genuinely requires judgment. |

---

## 2. Agent Topology

### 2.1 Structure: Orchestrated Specialist Mesh

The system is **not** a flat pool of identical agents. It is a **two-tier mesh**:

```
┌─────────────────────────────────────────────────────────┐
│                    TIER 1: ORCHESTRATOR                  │
│         Plans · Sequences · Delegates · Approves         │
└────────────────────────────┬────────────────────────────┘
                             │  delegates tasks
         ┌───────────────────┼────────────────────────┐
         ▼                   ▼                         ▼
┌──────────────┐   ┌──────────────────┐   ┌─────────────────┐
│   Engineer   │   │   DevOps         │   │   Designer      │
│   SDET       │   │   Security       │   │   Database      │
│              │   │   Incident       │   │                 │
└──────────────┘   └──────────────────┘   └─────────────────┘
   TIER 2: SPECIALISTS — execute, report results back up
```

**Key rule:** Specialists never talk to each other directly. All inter-agent communication routes through the Orchestrator. This prevents context bleed and makes the execution graph inspectable.

### 2.2 Agent Lifecycle States

Every agent — orchestrator or specialist — moves through a strict state machine:

```
              ┌──────────┐
    ───────►  │  IDLE    │  ◄─────────────────────────┐
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

## 3. Memory Management

This is the most critical subsystem. Agents degrade fast when memory is unstructured. We use a **four-layer memory architecture**.

### 3.1 Memory Layers

```
┌────────────────────────────────────────────────────────────────────┐
│  LAYER 4 — SEMANTIC MEMORY (Knowledge Base)                        │
│  What: Accumulated facts, patterns, architecture decisions          │
│  Storage: learned.jsonl (structured entries)                        │
│  Scope: Permanent, shared across all agents and all sessions        │
│  Access: Read at session start, write on explicit /learn trigger    │
├────────────────────────────────────────────────────────────────────┤
│  LAYER 3 — EPISODIC MEMORY (Session History)                       │
│  What: What happened in previous sessions: decisions, outcomes      │
│  Storage: sessions/<id>/summary.md (auto-generated on close)        │
│  Scope: Persistent, per-session, read by next session on restore    │
│  Access: Injected as a compressed summary at session start          │
├────────────────────────────────────────────────────────────────────┤
│  LAYER 2 — WORKING MEMORY (Active Context Window)                  │
│  What: The current task, active rules, tool outputs, agent scratchpad│
│  Storage: In-context (model's context window — ephemeral)           │
│  Scope: Current invocation only — destroyed when agent returns      │
│  Access: Directly available to the model at inference time          │
├────────────────────────────────────────────────────────────────────┤
│  LAYER 1 — TOOL CACHE (Recent Tool Results)                        │
│  What: Last N results from MCP tool calls                           │
│  Storage: .agents/cache/<tool>/<hash>.json (TTL-based)              │
│  Scope: Session-scoped, shared between agents in same session       │
│  Access: Agent checks cache before making identical tool call       │
└────────────────────────────────────────────────────────────────────┘
```

### 3.2 Memory Retrieval Strategy

**At session start, the system runs a memory bootstrap:**

1. Read `learned.jsonl` → filter entries by `tags` relevant to current task → inject top 5 most relevant as context prefix
2. Read `sessions/latest/summary.md` → inject as "Previous Session" block
3. Read path-scoped rules → inject the applicable rule files only
4. Warm tool cache from disk for any tool likely to be called (e.g., if working on infra, preload last terraform plan result)

**Retrieval is tag-based, not vector-search**, because:
- Tag search is deterministic (same result every time — no surprises)
- No external embedding model dependency
- Faster, zero-latency, zero-cost

**When to write to Semantic Memory:**
- Agent successfully resolves a non-trivial problem (not solvable from rules alone)
- Agent discovers a project pattern not documented in any rule file
- Triggered explicitly by `/learn` command or post-`/review` approval

### 3.3 Memory Entry Schema

```json
{
  "id": "mem_<ulid>",
  "ts": "2026-05-24T14:00:00Z",
  "agent": "engineer",
  "tags": ["auth", "token-refresh", "edge-case"],
  "pattern": "silent-token-refresh-race-condition",
  "context": "What situation triggered this learning",
  "resolution": "What the agent did to solve it",
  "confidence": 0.95,
  "used_count": 3,
  "last_used": "2026-05-24T18:00:00Z"
}
```

`confidence` decays on reuse if the pattern doesn't apply correctly. High-confidence entries get priority injection. Entries with `confidence < 0.5` are archived.

---

## 4. Context Management

### 4.1 The Context Budget Problem

Every agent invocation has a finite context window. The system must spend that budget deliberately.

**Context Budget Allocation (example for a 200K token model):**

```
┌─────────────────────────────────────────────────────────┐
│                    CONTEXT WINDOW                        │
│  ┌───────────────────────────────────────────────────┐  │
│  │  SYSTEM LAYER (always-on)              ~5K tokens  │  │
│  │  MANIFEST.md + active persona + rules             │  │
│  ├───────────────────────────────────────────────────┤  │
│  │  MEMORY LAYER (injected at start)      ~10K tokens │  │
│  │  Top 5 semantic memories + session summary        │  │
│  ├───────────────────────────────────────────────────┤  │
│  │  TASK LAYER (current work)             ~20K tokens │  │
│  │  task.md + relevant files + tool results          │  │
│  ├───────────────────────────────────────────────────┤  │
│  │  EXECUTION BUFFER (free for the agent) ~165K tokens│  │
│  │  Tool calls, reasoning, code output               │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

**Rules:**
- System layer is always injected first — never compressed or dropped
- Memory layer is injected second — compressed if > budget limit
- Task layer only injects files **directly relevant** to the current task — no full-codebase dumps
- Execution buffer is left as large as possible for the agent to work in

### 4.2 Path-Scoped Rule Injection

Rules are not all loaded all the time. They are injected based on what the agent is actually touching:

```
Trigger Condition                     →  Rule File Injected
──────────────────────────────────── → ───────────────────
Always                               →  common.md
Always                               →  git.md
Always                               →  security.md
Agent is engineer or sdet            →  [project-specific later]
Agent is devops                      →  infrastructure.md
File path matches pattern X          →  [project overlay later]
```

This prevents **context pollution** — the #1 cause of agent errors is an agent having too much irrelevant context and pattern-matching incorrectly.

### 4.3 Context Handoff Between Agents

When the Orchestrator delegates to a Specialist, it does **not** pass the full context. It passes a **handoff packet**:

```json
{
  "task_id": "task_<ulid>",
  "goal": "one-sentence description of what to do",
  "constraints": ["list of constraints from rules"],
  "inputs": { "files": [...], "tool_results": {...} },
  "expected_output": "description of what success looks like",
  "relevant_memories": ["mem_id_1", "mem_id_2"]
}
```

The Specialist loads only this packet + its own persona + applicable rules. It never sees the Orchestrator's full planning context. This keeps each agent's working memory lean and focused.

### 4.4 Context Compression

When a session gets long and context approaches the limit:

1. **Summarize completed tasks**: Completed items in `task.md` get replaced by a one-line summary
2. **Drop stale tool results**: Tool results older than 5 steps are dropped from context (but saved to tool cache on disk)
3. **Compress episodic memory**: If session summary is large, re-summarize it to key bullet points
4. **Never compress**: System layer (rules + persona) — these must always be intact

---

## 5. Session Management

### 5.1 Session Lifecycle

```
CREATE                       ACTIVE                      CLOSE
  │                            │                           │
  ▼                            ▼                           ▼
Bootstrap              Run tasks / call tools          Generate summary
+ Load rules           + Write to tool cache          + Append to learned.jsonl
+ Inject memories      + Track all agent actions      + Save session record
+ Generate session ID  + Checkpoint on milestones     + Clear working memory
```

### 5.2 Session Record Structure

```
.agents/sessions/
├── <session-ulid>/
│   ├── session.json          # Metadata: id, start, end, trigger, agents_activated
│   ├── summary.md            # Auto-generated natural language summary of what happened
│   ├── task.md               # The task backlog for this session (snapshot at close)
│   ├── audit.jsonl           # Append-only log of every agent action (see §7)
│   └── tool_calls.jsonl      # Every MCP/tool call with input, output, latency
└── index.json                # Ordered list of all session IDs + one-line summaries
```

### 5.3 Session Restore

On starting a new session after a previous one closed:

1. Orchestrator reads `sessions/index.json` → finds last session
2. Reads `sessions/<last-id>/summary.md` → injects as "Continuing from previous session"
3. Reads `sessions/<last-id>/task.md` → checks for uncompleted tasks
4. If uncompleted tasks exist → presents them to user: "Continue these tasks or start fresh?"
5. Injects any new semantic memories written since last session

### 5.4 Session Checkpointing

For long-running tasks (e.g., a multi-hour `/deploy`), the system creates **mid-session checkpoints**:

- Triggered every N tool calls (configurable, default: every 10 tool calls)
- Writes a partial `summary.md` to `sessions/<id>/checkpoints/<n>.md`
- If the session crashes, it can be restored from the last checkpoint instead of starting over

---

## 6. Task Orchestration

### 6.1 Tasks as a DAG (Directed Acyclic Graph)

Complex goals decompose into tasks with dependencies. The Orchestrator builds a DAG, not a flat list:

```
Goal: "Add authentication to the API"

        ┌──────────────────────┐
        │  Design auth schema  │  (database agent)
        └──────────┬───────────┘
                   │
        ┌──────────▼───────────┐
        │  Write auth service  │  (engineer agent)
        └──────────┬───────────┘
                   │
     ┌─────────────┴──────────────┐
     ▼                            ▼
┌─────────────┐         ┌──────────────────┐
│ Write tests │         │  Security audit  │  (parallel)
│  (sdet)     │         │  (security)      │
└──────┬──────┘         └────────┬─────────┘
       │                         │
       └────────────┬────────────┘
                    ▼
           ┌──────────────┐
           │  Final review│  (orchestrator)
           └──────────────┘
```

The Orchestrator knows which tasks can run in parallel and which must wait for dependencies. This is serialized to `task.md` as a structured checklist with dependency markers.

### 6.2 Task Schema

```json
{
  "id": "task_<ulid>",
  "goal": "Write auth service",
  "agent": "engineer",
  "status": "pending | in_progress | done | failed | blocked",
  "depends_on": ["task_<ulid-of-schema-task>"],
  "inputs": ["schema design output"],
  "outputs": ["service code", "API spec"],
  "created": "2026-05-24T14:00:00Z",
  "started": null,
  "completed": null,
  "notes": ""
}
```

### 6.3 Task Recovery

If a task fails:

1. Capture the error state → write to `audit.jsonl`
2. Check `learned.jsonl` for any matching prior failure pattern
3. If match found → attempt auto-recovery using the matched pattern
4. If no match → escalate to Orchestrator with full error context
5. Orchestrator decides: retry, reassign to different agent, or surface to user
6. User only sees the task if it fails after 2 auto-recovery attempts

---

## 7. Security & Governance

### 7.1 Permission Tiers

Every tool call and command runs through a 3-tier gate:

```
TIER 1 — AUTO-APPROVE (no friction)
  ▶ Safe, idempotent, read-only, or purely local operations
  ▶ Examples: run tests, run linter, read files, git status, terraform plan, kubectl get

TIER 2 — REQUIRE APPROVAL (single human confirmation)
  ▶ Operations with real-world side effects that are reversible
  ▶ Examples: kubectl apply, terraform apply, docker push, git push --force, DB migrations

TIER 3 — DENY (hard block, never executes)
  ▶ Irreversible, high-blast-radius, or security-violating operations
  ▶ Examples: rm -rf /, DROP DATABASE, piped remote execution, writing secrets to logs
```

### 7.2 Audit Log

Every agent action — whether it runs a tool, reads a file, or writes output — is logged to `sessions/<id>/audit.jsonl`:

```json
{
  "ts": "2026-05-24T14:00:00Z",
  "session_id": "sess_<ulid>",
  "agent": "devops",
  "action_type": "tool_call | file_write | delegation | decision",
  "tool": "kubernetes",
  "operation": "apply_manifest",
  "permission_tier": 2,
  "approved_by": "user | auto",
  "inputs": { "manifest": "deployment.yaml" },
  "result": "success | failure | skipped",
  "duration_ms": 1240
}
```

This audit log is **append-only and immutable**. It cannot be modified by any agent.

### 7.3 Secret Hygiene

- All credentials are referenced as `env:VARIABLE_NAME` in MCP configs — never inline
- Agents are prohibited from printing or logging anything that matches secret patterns (token, password, key, secret)
- A static secret-pattern scan runs on all agent outputs before they are surfaced to the user
- `.env.agents` is always in `.gitignore` — enforced at session start

---

## 8. Tool & MCP Integration Model

### 8.1 Tool Registry

All tools live in `.agents/mcp/` as JSON configs. The registry (`settings.json`) maps:
- Which agents can call which tools
- Which operations are auto-approved vs. gated
- Rate limits and retry policies per tool

### 8.2 Tool Call Lifecycle

```
Agent decides to call a tool
         │
         ▼
  Check permission tier
         │
    ┌────┴─────┐
    ▼           ▼
  Deny        Auto-approve or require approval
    │               │
 Log + stop         ▼
               Check tool cache
                    │
              ┌─────┴──────┐
              ▼             ▼
          Cache hit     Cache miss
              │             │
         Return cached   Execute tool call
         result           │
              │           ▼
              │       Write result to cache
              │           │
              └─────┬─────┘
                    ▼
              Return to agent
                    │
                    ▼
             Log to audit.jsonl
```

### 8.3 Tool Result Caching

- Cache key: `hash(tool_name + operation + inputs)`
- Default TTL: 5 minutes for volatile results (pod status), 24 hours for stable results (Figma frames)
- Cache is stored at `.agents/cache/<tool>/<hash>.json`
- Cache hit rate is tracked in session metadata (cost optimization signal)

### 8.4 Rate Limiting

Each MCP server has a rate limit config:

```json
{
  "github": { "requests_per_minute": 60, "retry_on_429": true, "backoff": "exponential" },
  "figma":  { "requests_per_minute": 30, "retry_on_429": true, "backoff": "linear" },
  "sentry": { "requests_per_minute": 100, "retry_on_429": false }
}
```

Agents don't manage this — the tool call lifecycle handles it transparently.

---

## 9. Inter-Agent Communication

### 9.1 Delegation Protocol

When the Orchestrator assigns a task to a Specialist, it sends a **Delegation Message**:

```
┌─────────────────────────────────────────────────────────┐
│  DELEGATION MESSAGE                                      │
│  ─────────────────────────────────────────────────────  │
│  From:          orchestrator                             │
│  To:            engineer                                 │
│  Task ID:       task_<ulid>                              │
│  Goal:          [one sentence]                           │
│  Constraints:   [from rules — pre-filtered for relevance]│
│  Inputs:        [file paths, prior task outputs]         │
│  Success:       [clear definition of done]               │
│  Deadline:      [optional, for time-sensitive tasks]     │
└─────────────────────────────────────────────────────────┘
```

### 9.2 Result Message

When a Specialist completes a task, it returns a **Result Message**:

```
┌─────────────────────────────────────────────────────────┐
│  RESULT MESSAGE                                          │
│  ─────────────────────────────────────────────────────  │
│  From:          engineer                                 │
│  To:            orchestrator                             │
│  Task ID:       task_<ulid>                              │
│  Status:        success | partial | failed               │
│  Outputs:       [file paths created/modified]            │
│  Decisions:     [non-obvious choices made + rationale]   │
│  Learnings:     [optional: patterns worth saving]        │
│  Next:          [optional: suggested follow-up tasks]    │
└─────────────────────────────────────────────────────────┘
```

The Orchestrator uses `Decisions` and `Learnings` fields to decide what to write to `learned.jsonl`.

---

## 10. Observability & Tracing

### 10.1 What We Track

Every session produces three observable streams:

| Stream | File | Purpose |
|--------|------|---------|
| **Audit Log** | `audit.jsonl` | Every agent action, permission tier, result |
| **Tool Log** | `tool_calls.jsonl` | Every MCP call, latency, cache hit/miss |
| **Cost Log** | `cost.jsonl` | Token usage per agent, per task, per session |

### 10.2 Cost Tracking

```json
{
  "session_id": "sess_<ulid>",
  "agent": "engineer",
  "task_id": "task_<ulid>",
  "model": "gemini-2.5-pro",
  "input_tokens": 12400,
  "output_tokens": 3200,
  "cached_tokens": 8000,
  "tool_calls": 7,
  "tool_cache_hits": 3,
  "estimated_cost_usd": 0.042
}
```

Cost entries accumulate per session. The orchestrator surfaces a cost summary at session close: "This session used ~50K tokens (~$0.15)."

### 10.3 Session Dashboard (Future)

The observability data feeds a future lightweight dashboard:
- Active agents and their current states
- Task DAG visualization (pending / in_progress / done)
- Token spend per agent per day
- Memory confidence distribution (are learnings being used?)
- Tool cache efficiency (hit rate over time)

---

## 11. The Full System Map

```
╔══════════════════════════════════════════════════════════════════════════╗
║                    ENTERPRISE AGENTIC SYSTEM                             ║
╠══════════════════════════════════════════════════════════════════════════╣
║                                                                          ║
║  ┌─────────────────┐     ┌─────────────────┐     ┌──────────────────┐  ║
║  │  MEMORY SYSTEM  │     │  CONTEXT SYSTEM  │     │  SESSION SYSTEM  │  ║
║  │                 │     │                  │     │                  │  ║
║  │  Layer 4        │◄───►│  Budget tracking │◄───►│  Lifecycle mgmt  │  ║
║  │  Semantic       │     │  Rule injection  │     │  Checkpointing   │  ║
║  │  Layer 3        │     │  Compression     │     │  Restore         │  ║
║  │  Episodic       │     │  Handoff packets │     │  Index           │  ║
║  │  Layer 2        │     │                  │     │                  │  ║
║  │  Working        │     └────────┬─────────┘     └────────┬─────────┘  ║
║  │  Layer 1        │              │                         │            ║
║  │  Tool Cache     │              ▼                         ▼            ║
║  └─────────────────┘   ┌──────────────────────────────────────────┐    ║
║                         │         ORCHESTRATOR AGENT               │    ║
║                         │   Plans · Sequences · Delegates · Reviews│    ║
║                         └──────────────────┬───────────────────────┘    ║
║                                            │                            ║
║           ┌────────────────────────────────┼────────────────────────┐  ║
║           ▼                                ▼                        ▼   ║
║  ┌────────────────┐             ┌──────────────────┐    ┌────────────┐ ║
║  │  SPECIALISTS   │             │  TASK SYSTEM     │    │  SECURITY  │ ║
║  │                │             │                  │    │            │ ║
║  │  engineer      │             │  DAG execution   │    │  Tier gates│ ║
║  │  devops        │             │  Recovery        │    │  Audit log │ ║
║  │  sdet          │             │  Parallelism     │    │  Secrets   │ ║
║  │  security      │             │  Checkpoints     │    │            │ ║
║  │  database      │             │                  │    └────────────┘ ║
║  │  incident      │             └──────────────────┘                   ║
║  │  designer      │                                                     ║
║  └────────┬───────┘                                                     ║
║           │                                                             ║
║           ▼                                                             ║
║  ┌─────────────────────────────────────────────────────────────────┐   ║
║  │                    MCP TOOL LAYER                                │   ║
║  │  figma  │  github  │  terraform  │  docker  │  k8s  │  sentry   │   ║
║  │  ───────────────────────────────────────────────────────────  │   ║
║  │  Permission tiers · Rate limiting · Caching · Audit logging     │   ║
║  └─────────────────────────────────────────────────────────────────┘   ║
╚══════════════════════════════════════════════════════════════════════════╝
```

---

## 12. Key Design Decisions & Trade-offs

| Decision | Choice Made | Reason | Trade-off |
|----------|-------------|--------|-----------|
| **Agent communication** | All routes through Orchestrator | Inspectable, no context bleed | Slightly higher latency than direct P2P |
| **Memory retrieval** | Tag-based, not vector search | Deterministic, zero-cost, zero-latency | Requires disciplined tagging; won't surface fuzzy matches |
| **Context injection** | Path-scoped, minimal | Prevents token waste and noise | Requires good trigger condition definitions |
| **Tool caching** | Hash-based, TTL-driven | Eliminates redundant API calls | Stale results possible if TTL is too long |
| **Task model** | DAG, not flat list | Enables parallelism and dependency tracking | More complex to serialize to `task.md` |
| **Session restore** | Summary injection, not full replay | Avoids context window overflow | Very long chains of sessions may lose nuance |
| **Audit log** | Append-only JSONL | Immutable, trivially parseable | Large over time; needs periodic archiving |
| **Permission model** | 3-tier explicit tiers | Balances autonomy with safety | Auto-approve list needs careful curation |

---

## 13. What We Are NOT Building (Deliberate Exclusions)

| Excluded | Why |
|----------|-----|
| **Vector database / embedding search** | Adds infra complexity with marginal benefit over tag-based retrieval for our use case |
| **Separate agent processes / microservices** | Overkill for a developer workspace system; adds network latency and failure modes |
| **Real-time streaming between agents** | The Orchestrator-mediated model is simpler and more inspectable |
| **Fine-tuned models per agent** | Persona YAML achieves behavioral differentiation at zero model cost |
| **UI dashboard (Phase 1)** | Observability data is logged; UI can be built later on top of existing JSONL files |
| **External vector memory store** | `learned.jsonl` with tag-based retrieval covers 95% of cases without external dependencies |
