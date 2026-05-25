# /plan-tune — System Configuration Skill
# Adjusts system-level settings (verbosity, model routing, review strictness)
# Owner: Orchestrator | Trigger: /plan-tune <mode>
# Source: agents_and_skills_design.md §8.4

---

## Preamble

1. READ `.agents/MANIFEST.md`
2. READ `.agents/rules/global.md`
3. LOG `{"action":"skill-activate","skill":"/plan-tune","ts":"<ISO>"}` → `audit.jsonl`

---

## Available Modes

```
/plan-tune verbose        → Agents output detailed reasoning at every step
/plan-tune concise        → Agents output only summaries and artifacts (default)
/plan-tune strict-review  → /review requires 9/10 score before /ship proceeds
/plan-tune fast-review    → /review accepts 7/10 score (use for hotfixes)
/plan-tune tdd-mandatory  → All implementation tasks require /tdd first
/plan-tune tdd-optional   → /tdd is recommended but not gating (default)
/plan-tune council-auto   → High-risk tasks auto-trigger /council
/plan-tune council-manual → /council only on explicit user request (default)
/plan-tune show           → Display current settings without making changes
```

---

## Skill Flow

```
User: /plan-tune <mode>
  │
  ▼
Orchestrator validates mode name is in the allowed list above.
  If invalid → BLOCKED: "Unknown mode '<mode>'. Run '/plan-tune show' to see options."

  └─ Valid mode:
      → Read: .agents/settings.json (create if missing with defaults)
      → Update the relevant setting in settings.json
      → Log the change to audit.jsonl:
        {"ts":"...","action":"plan-tune","mode":"<mode>","prev":"<old-value>","new":"<new-value>"}
      → Confirm: "✅ Mode updated: <mode> = <value>. Effective immediately."
```

---

## settings.json Schema

```json
{
  "_generated": "ISO-8601 timestamp",
  "_source": "/plan-tune command",
  "verbosity": "concise | verbose",
  "review_threshold": 7,
  "tdd_mode": "optional | mandatory",
  "council_trigger": "manual | auto",
  "notes": "Human-readable log of tune history"
}
```

---

## Default Settings

```json
{
  "verbosity": "concise",
  "review_threshold": 7,
  "tdd_mode": "optional",
  "council_trigger": "manual"
}
```

---

## Security Rule

`/plan-tune` can NEVER disable:
- Audit logging
- Security guardrails
- Rollback planning
- Human approval for production deployments

These are Ironclad Rule-protected — no configuration can bypass them.
