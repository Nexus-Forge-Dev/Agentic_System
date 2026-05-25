# /plan-ceo-review — Executive Strategy Review Skill
# High-level strategic review of a plan from a product/business perspective
# Owner: Orchestrator → UX Researcher (product angle) | Trigger: /plan-ceo-review
# Source: agents_and_skills_design.md §8.4 (part of /autoplan chain)
# Output artifact: docs/ceo-review.md

---

## Preamble

1. READ `.agents/MANIFEST.md`
2. READ `.agents/rules/global.md`
3. READ `.agents/PROJECT.md`
4. READ `task.md` (or the plan document being reviewed)
5. LOG `{"action":"skill-activate","skill":"/plan-ceo-review","ts":"<ISO>"}` → `audit.jsonl`

---

## Purpose

Reviews a proposed plan or feature from the **product/business/strategic** lens before engineering begins. Challenges assumptions from a customer and business value perspective — not a technical one.

---

## Questions This Review Answers

1. **Value**: What is the user/customer value of this feature? Is it solving a real problem?
2. **Scope**: Is the scope right? What is the smallest version that delivers value?
3. **Priority**: Is this the highest-leverage thing to build right now?
4. **Risk**: What are the strategic risks (reputation, user trust, market position)?
5. **Success metric**: How would we know this worked? What would we measure?
6. **Assumptions**: What assumptions are baked in that could be wrong?

---

## Skill Flow

```
User or Orchestrator: /plan-ceo-review
  │
  ▼
Orchestrator reads task.md (or specified plan document)
  │
UX Researcher activates (product lens):
  → Reads the plan / task list
  → Applies the 6 review questions above
  → Challenges "build it" assumptions with "should we build it?"
  → Identifies the minimum lovable version (not MVP — lovable)
  → Produces: docs/ceo-review.md

Format of docs/ceo-review.md:
  ─────────────────────────────────────────────
  # CEO Review: <plan name>
  Date: <ISO>
  
  ## Value Assessment
  [Is this solving a real user problem? How do we know?]
  
  ## Scope Challenge
  [Is this the right scope? What is the minimum that delivers value?]
  
  ## Priority Check
  [Is this highest-leverage right now? What are we not building?]
  
  ## Strategic Risks
  [Reputation, user trust, market position implications]
  
  ## Success Metrics
  [How we'll know this worked — specific and measurable]
  
  ## Flagged Assumptions
  [Assumptions that could be wrong and should be validated first]
  
  ## Recommendation
  [PROCEED | SCOPE-DOWN | POSTPONE | CHALLENGE]
  Reasoning: ...
  ─────────────────────────────────────────────
```

---

## Output

| Artifact | Path |
|----------|------|
| Executive Review | `docs/ceo-review.md` |
