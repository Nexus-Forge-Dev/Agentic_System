# /plan-devex-review — Developer Experience Review Skill
# Analyzes developer experience: TTHW, magic moments, friction points
# Owner: UX Researcher | Trigger: /plan-devex-review
# Source: agents_and_skills_design.md §6.3, §8.4 (part of /autoplan chain)
# Output artifact: docs/devex-review.md

---

## Preamble

1. READ `.agents/MANIFEST.md`
2. READ `.agents/rules/global.md`
3. READ `.agents/PROJECT.md`
4. READ `task.md` (the plan to review)
5. LOG `{"action":"skill-activate","skill":"/plan-devex-review","ts":"<ISO>"}` → `audit.jsonl`

---

## Purpose

Reviews the developer-facing experience of a proposed feature or API. Surfaces friction before it is built in. Measures **Time-To-Hello-World (TTHW)** — the time for a new developer to achieve a first success moment.

---

## Review Questions

1. **TTHW**: How long does it take a new developer to get a first successful result?
2. **Magic Moment**: What is the "wow" moment when the feature clicks for a developer?
3. **Friction Points**: What are the steps where developers are most likely to get stuck?
4. **Error Quality**: When something goes wrong, are the error messages useful?
5. **Discovery**: Can developers find this feature without reading docs?
6. **API Ergonomics**: Is the interface natural to use? Can it be misused easily?

---

## Skill Flow

```
User or Orchestrator: /plan-devex-review
  │
  ▼
UX Researcher activates (DevEx lens — developer as the "user")

Phase 1 — User Flow Mapping
  → Draw the step sequence a new developer goes through to use this feature
  → Identify: every step where they need to look something up, make a decision, or wait

Phase 2 — TTHW Measurement
  → Walk through the steps from fresh start to first success
  → Count: clicks, commands, config values, concepts to understand
  → Target: TTHW < 5 minutes for well-designed APIs
  → Flag: any step that adds > 1 minute to TTHW

Phase 3 — Friction Analysis
  → Steps requiring reading docs before proceeding → friction
  → Error messages with no actionable guidance → friction
  → Config values with no good defaults → friction
  → Concepts that aren't named consistently → friction

Phase 4 — Magic Moment Identification
  → The step where the developer says "oh this is cool" or "it just works"
  → Confirm: is the magic moment reachable before > 5 minutes?
  → Optimize: remove steps between start and magic moment

Phase 5 — Produce DevEx Review
  → Write: docs/devex-review.md (format below)
```

---

## Output Format: docs/devex-review.md

```markdown
# DevEx Review: <feature/API name>
Date: <ISO>
Reviewer: UX Researcher (Developer Experience Lens)

## TTHW Analysis
Measured steps to Hello World:
1. Step 1: [action] — Time: ~30s
2. Step 2: [action] — Time: ~2min (friction!)
...

Estimated TTHW: X minutes
Target: < 5 minutes
Status: ✅ PASSES | ⚠️ BORDERLINE | ❌ FAILS

## Magic Moment
[The specific step where this becomes obviously valuable]
Reached at step: X (within TTHW? ✅/❌)

## Friction Points
| Step | Friction Type | Suggestion |
|------|--------------|-----------|
| Step 2 | Requires reading docs | Add default config value |

## Error Message Quality
[Sample error scenarios — are messages actionable?]

## API Ergonomics
[Is the API natural? What are common misuse patterns?]

## Recommendations
[Prioritized list of improvements to reduce friction]
```
