# Memory Protocol
# .agents/rules/memory-protocol.md
# Authority: LAYER 1 — Memory architecture for all agents
# Source: agentic_system_design.md §3

---

## The Four-Layer Memory Architecture

```
┌────────────────────────────────────────────────────────────────────┐
│  LAYER 4 — SEMANTIC MEMORY (Knowledge Base)                        │
│  What: Accumulated facts, patterns, architecture decisions          │
│  Storage: learned.jsonl (structured entries — see schema below)     │
│  Scope: Permanent, shared across all agents and all sessions        │
│  Access: Read at session start, write on /learn trigger             │
├────────────────────────────────────────────────────────────────────┤
│  LAYER 3 — EPISODIC MEMORY (Session History)                       │
│  What: What happened in previous sessions: decisions, outcomes      │
│  Storage: sessions/<id>/summary.md (auto-generated on close)        │
│  Scope: Persistent per-session, read by next session on restore     │
│  Access: Injected as a compressed summary at session start          │
├────────────────────────────────────────────────────────────────────┤
│  LAYER 2 — WORKING MEMORY (Active Context Window)                  │
│  What: The current task, active rules, tool outputs, scratchpad     │
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

---

## Memory Entry Schema (`learned.jsonl`)

Every entry in `learned.jsonl` MUST conform to this schema exactly:

```json
{
  "id": "mem_<ulid>",
  "ts": "2026-05-24T14:00:00Z",
  "agent": "<agent-role>",
  "tags": ["<tag1>", "<tag2>", "<tag3>"],
  "pattern": "<short slug: the-pattern-name>",
  "context": "What situation triggered this learning — specific enough to match",
  "resolution": "What the agent did to solve it — replicable steps",
  "confidence": 0.95,
  "used_count": 0,
  "last_used": null,
  "session_id": "sess_<ulid>"
}
```

### Field Rules
- `id`: ULID-prefixed with `mem_`. Never reuse.
- `tags`: 2–5 tags. Use: technology names, problem area, agent role, pattern type.
  - Good: `["auth", "token-refresh", "race-condition", "typescript"]`
  - Bad: `["problem", "solution", "fix"]` — too generic to match
- `pattern`: kebab-case slug. Unique within `learned.jsonl`.
- `context`: Must be specific enough that a future agent reading it knows whether it applies.
- `resolution`: Must be replicable — not "I fixed it" but "Used debounce(500ms) on the token refresh call"
- `confidence`: 0.0–1.0. Start at 0.8 for new patterns. Decays on failed application (see `/retro`).
- `used_count`: Incremented each time this entry is successfully applied.

---

## Memory Bootstrap Protocol

**At every session start, before any task executes, the system runs:**

```
STEP 1 — Read Semantic Memory
  Open learned.jsonl
  Parse all entries
  Filter by tags matching the current task context
    → Match: any entry whose tags overlap with the current task's domain
    → Example: task involves "auth" → include all entries tagged ["auth"]
  Sort by: confidence DESC, used_count DESC
  Select: top 5 entries (or fewer if fewer than 5 match)
  Inject as: "RELEVANT PRIOR PATTERNS" context block

STEP 2 — Read Episodic Memory
  Open sessions/index.json
  Find last completed session ID
  Read sessions/<last-id>/summary.md
  Inject as: "PREVIOUS SESSION SUMMARY" context block
  Check: does previous session have uncompleted tasks?
    → If yes: note them for Step 4 decision

STEP 3 — Inject Path-Scoped Rules
  Always inject:
    - .agents/rules/global.md (ironclad rules)
    - .agents/rules/agent-lifecycle.md (this file)
    - .agents/rules/result-message.md
  Conditionally inject based on active division:
    - devops / platform → .agents/rules/divisions/platform.md
    - engineer / backend / frontend / database → .agents/rules/divisions/engineering.md
    - quality / sdet / qa / visual → .agents/rules/divisions/quality.md
    - design / ui / ux / animator → .agents/rules/divisions/design.md
    - intelligence → .agents/rules/divisions/intelligence.md

STEP 4 — Warm Tool Cache
  Run: powershell .agents/scripts/cache.ps1 clear
  This removes stale entries from prior sessions.
  Then based on task type, pre-load likely tool results from cache:
    → Infra task: load last terraform plan result if cached
    → Test task: load last test run result if cached
    → Design task: load last Figma frame hash if cached
  This reduces latency on first tool call of the session.

STEP 5 — Load Cache Utility Reference
  Note: .agents/scripts/cache.ps1 is available for cache check/write/clear.
  Use it before every tool call as specified in tool-call-lifecycle.md §Cache Enforcement.
```

---

## When to Write to Semantic Memory

Write a new `learned.jsonl` entry ONLY when:
1. Agent successfully resolves a non-trivial problem (not solvable from rules alone)
2. Agent discovers a project pattern not documented in any rule file
3. The resolution is replicable (another agent could follow the same steps)
4. Triggered explicitly by `/learn` or post-`/review` approval

**Do NOT write:**
- Obvious problems with obvious solutions (e.g., "fixed a typo")
- Anything that is already documented in a rule file
- Failed approaches (these are archived — write the successful resolution)
- Patterns with fewer than 2 confirmed successful applications

---

## Confidence Decay Rules

`confidence` values evolve over time based on application outcomes:

| Event | Confidence Change |
|-------|------------------|
| Successfully applied (agent reported it helped) | +0.02 (max: 0.98) |
| Applied but did not help (agent noted mismatch) | -0.10 |
| Applied and caused confusion (agent flagged as wrong) | -0.20 |
| Not used in 5+ sessions | -0.05 per session (passive decay) |

**Archiving rule:** Entries with `confidence < 0.5` are moved to `learned_archive.jsonl` and excluded from future bootstraps. This keeps `learned.jsonl` high-signal.
