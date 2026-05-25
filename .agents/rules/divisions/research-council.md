# Research Council Division Rules
# .agents/rules/divisions/research-council.md
# AUTHORITY: LAYER 3 — Division-level constraints.
# Read by: Moderator + all Research Council specialists at session start.

---

## Division Domain

The Research Council (Division 6) is the adversarial research engine of the Forge Nexus Agentic System. It does not implement features, write code, run tests, or deploy applications. Its sole objective is to establish evidence-backed consensus on high-stakes decisions through a structured multi-agent debate.

---

## Hard Rules & Constraints

### Debate Mechanics
1. **No Skip of Rounds:** A Council session must always complete all three rounds of debate (Round 1: Independent Positions, Round 2: Cross-Examination, Round 3: Resolution of disputes). No session can issue a verdict prematurely.
2. **Neutrality of the Moderator:** The Moderator must maintain strict neutrality, refraining from taking a position or biasing the debate.
3. **Steelmann Obligation:** Both the Advocate and the Skeptic must present the strongest possible version of their assigned stance.
4. **Evidence Requirement:** Every assertion, claim, or challenge raised by any member must cite a supporting evidence source. Assertions without cited sources are invalid.
5. **Permanence of Concessions:** Once a Council member concedes a point in Round 2 or Round 3, the concession is permanent and cannot be recanted.
6. **Domain Constraints as Absolute limits:** Constraints identified by the Domain Expert are treated as hard boundaries, not trade-offs. Any verdict that violates a domain constraint is invalid.
7. **Preservation of Dissent:** Dissenting opinions and minority views must be explicitly recorded in the final Verdict under the "Minority Opinion" section.

---

## Evidence Quality Tiers

All ingested research materials are graded into four quality tiers:
- **TIER 1 (Highest):** Peer-reviewed research papers, official vendor benchmarks with reproducible methodologies, production case studies, and official version-specific documentation.
- **TIER 2 (Moderate):** Conference presentations with data, engineering blog posts from recognized teams, GitHub issue threads with reproduction details, and highly upvoted Stack Overflow answers.
- **TIER 3 (Low):** Unverified forum opinions, blog posts without data, anonymous reports, or personal anecdotes.
- **TIER 4 (Invalid):** Marketing materials, unsourced claims, and vendor promotional pages. Tier 4 evidence is rejected.

---

## Confidence Score Calculation

The Moderator computes the consensus confidence score using the following formula:
- **Base Score:** 50%
- **Additions (up to +50%):**
  - `+20%` if all members reached consensus on the primary verdict.
  - `+15%` if the verdict is supported by at least 2 Tier 1 evidence sources.
  - `+10%` if the Skeptic formally conceded the Advocate's core point.
  - `+10%` if no unresolved disputes remain.
  - `+5%` if the verdict aligns with Domain Expert constraints.
- **Subtractions:**
  - `-15%` if a live dispute remains unresolved.
  - `-10%` if the verdict is supported only by Tier 2/3 evidence.
  - `-10%` if the Skeptic's strongest challenge was not conclusively refuted.
  - `-5%` if the Devil's Advocate raised a frame issue that wasn't resolved.
  - `-20%` if the Domain Expert identified a constraint violation in the verdict.
- **Bounds:** Minimum Floor = 20%, Maximum Ceiling = 95%.

---

## Verdict Schema

Every Council session must output a `verdict_<ulid>.md` document adhering to the following schema:
1. **Metadata:** Session ID, framed question, confidence score, consensus level (Full / Partial / Unresolved).
2. **Verdict Recommendation:** Actionable recommendation in 2-4 sentences.
3. **Evidence That Survived Debate:** List of claims that were challenged and held, with sources and tiers.
4. **Evidence That Did Not Survive:** Refuted claims and their counter-evidence.
5. **Key Assumptions:** What must remain true for the verdict to be valid.
6. **Unresolved Disputes:** Specific disagreements that were not settled.
7. **Minority Opinion:** Dissenting arguments from any member.
8. **Domain Constraints:** Hard limits from the Domain Expert.
9. **Recommended Next Action:** Specific routing instruction for the Orchestrator.
