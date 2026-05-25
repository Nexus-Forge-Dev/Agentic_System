# /codex — Independent Architecture Review Skill
# Second-opinion architecture consultation using independent model/agent perspective
# Owner: Engineering Lead | Trigger: /codex "<architecture-question>"
# Source: agents_and_skills_design.md §8.4 (Composite Skill Catalog)

---

## Preamble (runs first, always)

1. READ `.agents/MANIFEST.md` — current system state
2. READ `.agents/rules/global.md` — 12 ironclad rules
3. READ `.agents/PROJECT.md` — project stack and conventions
4. READ `.agents/learned.jsonl` — tag-filter: `["architecture", "design-decision", "codex"]`
5. CHECK `task.md` — verify task is scoped
6. LOG `{"action":"skill-activate","skill":"/codex","ts":"<ISO>"}` → `audit.jsonl`

---

## When To Use /codex

```
✅ USE FOR:
  - Architecture decisions with real trade-offs
  - Code patterns that feel complex — "is there a simpler way?"
  - Performance bottleneck analysis before committing to a solution
  - Security-sensitive code review (second opinion before /ship)
  - Library or framework selection within Engineering scope

❌ DO NOT USE FOR:
  - Bug fixes (use /investigate)
  - High-stakes multi-division decisions (use /council — it's more rigorous)
  - UI/UX decisions (use Design Division)
  - Infrastructure decisions (use Platform Division)

Rule of thumb: If 1 senior engineer could review this in 15 min → /codex.
              If it needs a team + materials + adversarial debate → /council.
```

---

## Skill Flow

```
User: /codex "<architecture-question>"
  │
  ▼
Engineering Lead receives and activates

Phase 1 — Context Gathering
  → search_code(semantic, "<keywords from the question>")
    Identify relevant files, functions, and existing patterns
  → read_file(relevant-architecture-files)
  → Check if prior /council verdict covers this question (search audit.jsonl)

Phase 2 — Independent Analysis
  Agent simulates an independent senior architect perspective:
  - What is the current approach?
  - What assumptions does it make?
  - What are the trade-offs (performance, maintainability, scalability, cost)?
  - Are there 2–3 viable alternatives worth considering?
  - What would the "simplest possible version" look like?

Phase 3 — Research (if question involves external tech)
  → search_web("<technology> production best practices site:engineering.xxx")
  → browse_url(top results) → extract_text()
  → Cite sources in output

Phase 4 — Produce Codex Report
  Output format:
  ─────────────────────────────────────────────
  # CODEX REPORT: <question>
  
  ## Current Approach
  [What the code currently does and why]
  
  ## Trade-off Analysis
  | Dimension | Current | Alternative A | Alternative B |
  |-----------|---------|---------------|---------------|
  | Performance | ... | ... | ... |
  | Complexity | ... | ... | ... |
  | Maintainability | ... | ... | ... |
  | Risk | ... | ... | ... |
  
  ## Recommendation
  [Clear recommendation with reasoning]
  
  ## Confidence: <0–100%>
  ## Sources: [URLs or file references used]
  ─────────────────────────────────────────────

Phase 5 — Deliver to Engineering Lead
  → Return Result Message with codex report
  → Save to: .agents/reports/codex-<ulid>.md
  → Engineering Lead reviews and decides whether to escalate to /council
```

---

## Output Artifacts

| Artifact | Path |
|----------|------|
| Codex Report | `.agents/reports/codex-<ulid>.md` |

---

## Escalation Rule

If the Codex analysis surfaces a decision with confidence < 60% OR involves irreversible infrastructure changes → Engineering Lead must escalate to `/council` instead of proceeding on Codex output alone.
