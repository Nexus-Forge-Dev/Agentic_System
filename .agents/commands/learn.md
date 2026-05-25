# Command: /learn
# .agents/commands/learn.md
# Owner: Intelligence Lead
# Trigger: /learn — runs at session close, after /retro

---

## Purpose
Extract reusable patterns from the current session and write them to learned.jsonl.
Patterns must meet the recurrence threshold (>= 2 sessions seen) or be exceptional enough to record as a first occurrence with notes.

---

## Workflow

```
INPUT: /retro dashboard output (pattern candidates section)

STEP 1 — Review pattern candidates from /retro
  Read the pattern candidates section of the session dashboard
  For each candidate:
    Search learned.jsonl for similar existing patterns (semantic match on pattern_name + tags)

STEP 2 — Apply recurrence threshold
  IF similar pattern EXISTS in learned.jsonl:
    → This is confirmed as recurring → write/update entry
    → Increment sessions_seen count
    → Update confidence based on additional evidence
  IF NO similar pattern found:
    → First occurrence → record with sessions_seen: 1, confidence: 50
    → Flag: "not yet confirmed — needs one more session recurrence"

STEP 3 — Write FAILED patterns (equally important)
  Any approach tried this session that FAILED with clear evidence:
    → Write to learned.jsonl with outcome: "FAILED"
    → Include: what was tried, why it failed, what to do instead
    → This is the system's "don't make this mistake again" memory

STEP 4 — Append to learned.jsonl
  For each pattern (success or failed):
    Append one JSON line per pattern:
    {
      "ts": "<ISO>",
      "session_id": "<ulid>",
      "tags": ["<division>", "<task_type>", "<language>", "<framework>"],
      "pattern_name": "<short descriptive name>",
      "context": "<when does this pattern apply>",
      "approach": "<what to do — specific, not generic>",
      "outcome": "SUCCESS | FAILED",
      "confidence": <0-100>,
      "sessions_seen": <count>
    }
```

---

## Guardrails
- Never EDIT existing learned.jsonl entries — APPEND only
- Never DELETE existing learned.jsonl entries — even failed patterns are permanent
- Minimum specificity: a pattern like "use React" is not a pattern — be specific
  Good: "use token bucket for rate limiting when client is known (has userId)"
  Bad:  "use rate limiting"
- Confidence calibration:
  - sessions_seen = 1: max 60%
  - sessions_seen = 2: max 80%
  - sessions_seen >= 3: up to 95%
