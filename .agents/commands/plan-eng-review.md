# /plan-eng-review — Engineering Feasibility Review Skill
# Deep technical review of a plan before implementation begins
# Owner: Engineering Lead | Trigger: /plan-eng-review
# Source: agents_and_skills_design.md §8.4 (part of /autoplan chain)
# Output artifact: docs/eng-review.md

---

## Preamble

1. READ `.agents/MANIFEST.md`
2. READ `.agents/rules/global.md`
3. READ `.agents/PROJECT.md` (stack, conventions, known gotchas)
4. READ `.agents/rules/divisions/engineering.md`
5. READ `task.md` (the plan to review)
6. READ `.agents/learned.jsonl` — tag-filter: `["engineering", "architecture", "debt"]`
7. LOG `{"action":"skill-activate","skill":"/plan-eng-review","ts":"<ISO>"}` → `audit.jsonl`

---

## Purpose

Reviews a proposed plan from the **engineering/technical** lens. This is not a code review — it's a pre-implementation architecture and feasibility review.

---

## Review Dimensions

The Engineering Lead rates the plan on these 6 dimensions:

| Dimension | Score | What It Assesses |
|-----------|-------|-----------------|
| Feasibility | 0–10 | Can this actually be built with the current stack? |
| Architecture Fit | 0–10 | Does this align with the existing patterns or create debt? |
| Complexity | 0–10 | How complex is implementation? (10 = simple, 0 = extremely complex) |
| Risk | 0–10 | How risky is the implementation? (10 = very safe, 0 = high risk) |
| Testability | 0–10 | Can we write good tests for this? |
| Reversibility | 0–10 | If this is wrong, how easy is it to undo? |

**Overall score** = average of 6 dimensions. Below 7.0 = red flags to resolve before proceeding.

---

## Skill Flow

```
User or Orchestrator: /plan-eng-review
  │
  ▼
Engineering Lead activates

Phase 1 — Plan Analysis
  → Read the plan (task.md or referenced plan document)
  → Identify: what systems are touched, what data is modified, what APIs are called
  → Check: does this touch any "Known Gotchas" from PROJECT.md?

Phase 2 — Architecture Assessment
  → search_code(semantic, "<key concepts from plan>")
    Identify existing patterns and where this fits
  → Does this plan require a new pattern → flag as architecture decision
  → Does this plan conflict with an existing pattern → flag as debt risk

Phase 3 — Scoring (6 dimensions above)

Phase 4 — Produce Engineering Review
  → Write: docs/eng-review.md (format below)

Phase 5 — Flags and Actions
  If any dimension score < 6:
    → Flag as RED — Engineering Lead escalates to Orchestrator before proceeding
  If architecture decision needed:
    → Recommend: /council for architecture decision (if high stakes) or /codex (lighter)
  If score ≥ 7.0 on all:
    → Recommend: proceed with /tdd or /plan
```

---

## Output Format: docs/eng-review.md

```markdown
# Engineering Review: <plan name>
Date: <ISO>
Reviewer: Engineering Lead

## Feasibility Analysis
[Can this be built? What dependencies are needed?]

## Architecture Assessment
[How does this fit existing patterns? What debt does it create?]

## Scores
| Dimension | Score | Notes |
|-----------|-------|-------|
| Feasibility | N/10 | |
| Architecture Fit | N/10 | |
| Complexity | N/10 | |
| Risk | N/10 | |
| Testability | N/10 | |
| Reversibility | N/10 | |
| **Overall** | **N.N/10** | |

## Red Flags (scores < 6)
[List of specific concerns with actionable suggestions]

## Architecture Decisions Required
[Decisions that must be made before implementation — route to /codex or /council]

## Recommended Next Step
[PROCEED with /tdd | RESOLVE red flags first | ESCALATE to /council]
```
