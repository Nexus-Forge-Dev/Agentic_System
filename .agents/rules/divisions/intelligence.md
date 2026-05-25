# Intelligence Division Rules
# .agents/rules/divisions/intelligence.md
# AUTHORITY: LAYER 3 — Division-level constraints.
# Read by: Intelligence Lead + all Intelligence specialists at session start.

---

## Hard Intelligence Rules (cannot be overridden by PROJECT.md)

### Pattern Learning
- No pattern is saved to `learned.jsonl` without a minimum 2-session recurrence
  (a pattern seen only once may be a one-off, not a generalizable insight)
- All patterns must have tags for filtering: `[division, task_type, language, framework]`
- Patterns that were tried and FAILED must also be saved (as negative examples) — tagged `outcome: FAILED`
- Pattern entries are append-only — never edit or delete existing entries

### Model Routing
- No model routing switch without a shadow-test quality baseline first
- Cost vs. quality tradeoffs must be documented in the routing decision
- Token budget targets per agent role (per session):
  - Orchestrator: ≤ 50K tokens
  - Division Lead: ≤ 30K tokens
  - Specialist: ≤ 40K tokens
  - Research Council (full): ≤ 200K tokens (adversarial debate is token-intensive)

### Session Analysis
- Every session produces a `/retro` report — this is not optional
- The retro reads all three observability streams: `audit.jsonl`, `tool_calls.jsonl`, `cost.jsonl`
- Velocity metrics computed: tasks completed, avg confidence score, avg duration per agent, total cost
- Any agent that returned < 60% confidence more than twice in a session is flagged for review

---

## learned.jsonl Entry Schema

```json
{
  "ts": "<ISO-8601>",
  "session_id": "<ulid>",
  "tags": ["<division>", "<task_type>", "<language>", "<framework>"],
  "pattern_name": "<short descriptive name>",
  "context": "<when this pattern applies>",
  "approach": "<what to do>",
  "outcome": "SUCCESS | FAILED",
  "confidence": <0-100>,
  "sessions_seen": <count>
}
```

---

## cost.jsonl Entry Schema

```json
{
  "ts": "<ISO-8601>",
  "session_id": "<ulid>",
  "agent": "<role>",
  "task_id": "<ref>",
  "model": "<model-name>",
  "input_tokens": <n>,
  "output_tokens": <n>,
  "total_tokens": <n>,
  "estimated_cost_usd": <float>
}
```
