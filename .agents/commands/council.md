# Command: /council
# .agents/commands/council.md
# Owner: Research Council Moderator
# Trigger: /council "<question>" [--materials <url1> <url2> <file.pdf> ...]
# Invoked ONLY by Orchestrator

---

## Purpose
Run a structured 3-round adversarial debate on a hard decision.
Produces a confidence-scored verdict document and full session transcript. Never produces code.

---

## Activation Criteria (Orchestrator judgment required)

/council should be invoked when:
- Choosing between two or more architectures with significant trade-offs
- Evaluating a new library, framework, or vendor
- A decision has both strong arguments for AND against
- Two divisions disagree and cannot resolve it independently
- A decision is irreversible or has a blast radius across > 3 systems
- Rule of thumb: if a senior engineer would spend a day researching it → use Council

/council should NOT be invoked for:
- Questions with clear best practices (just follow them)
- Simple implementation choices within a known pattern
- Questions that can be answered by reading the documentation
- Any routine task — debate is expensive, reserve for genuinely hard decisions

---

## Evidence Quality Tiers (Moderator assigns before debate begins)

```
TIER 1 — Primary Evidence (highest weight)
  Peer-reviewed research papers
  Official vendor/project benchmarks with reproducible methodology
  Production case studies with disclosed metrics
  Official documentation with version specification

TIER 2 — Secondary Evidence (moderate weight)
  Conference talks with data (not just opinions)
  Engineering blog posts from known practitioners with specifics
  GitHub issue threads with reproduction data
  Stack Overflow answers with vote count > 50

TIER 3 — Tertiary Evidence (low weight, requires corroboration)
  Forum opinions without data
  Blog posts without benchmarks or specifics
  Anonymous reports / "I heard that..." references

TIER 4 — Invalid (rejected, never enters debate)
  Marketing copy / vendor claims without data
  Purely hypothetical scenarios
  Assertions without any supporting reference

Rule: A Tier 1 finding always outweighs a Tier 3 consensus, regardless of how many
voices support the Tier 3 view.
```

---

## Workflow

```
INPUT: "<question>" + optional --materials list
  Good: "Should we use Redis Streams or Kafka for our event bus?"
  Bad:  "What database should we use?" (too vague)

STEP 0 — Moderator: Pre-Debate Setup
  Ingest all --materials (scrape URLs, read files, parse docs)
  Assign evidence quality tier to each piece of material
  Write evidence_manifest.json:
    File: .agents/council/<session-id>/evidence_manifest.json
    Schema: [{ "source": "<url|path>", "type": "<URL|PDF|doc|code>", "tier": <1-4>, "key_claims": ["..."] }]
  Reframe the question to be specific and answerable
  Assign Domain Expert role based on topic
  Brief all participants
  Log session start to audit.jsonl

--- ROUND 1 — Independent Position Statements (ALL PARALLEL) ---

  Each member writes their statement INDEPENDENTLY — no member sees another's output yet.

  REQUIRED POSITION STATEMENT FORMAT for each member:
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  POSITION STATEMENT — [Role Name]
  Stance:      [For / Against / Neutral / Challenging Frame]
  Confidence:  [Low / Medium / High]

  Core Argument:
  [2-4 sentences — the main thesis, specific and direct]

  Supporting Evidence:
  1. [Claim] — Source: [Tier X, specific reference/URL]
  2. [Claim] — Source: [Tier X, specific reference/URL]
  3. [Claim] — Source: [Tier X, specific reference/URL]

  Key Assumption:
  [The ONE assumption this position most depends on being true]

  Conceded Weaknesses:
  [What is the strongest argument against my own position? Be honest.]
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  The "Conceded Weaknesses" field is MANDATORY — it forces self-honesty.
  A position statement without it is returned to the member for completion.

  Save each position to:
    .agents/council/<session-id>/positions/round1_advocate.md
    .agents/council/<session-id>/positions/round1_skeptic.md
    .agents/council/<session-id>/positions/round1_devils_advocate.md
    .agents/council/<session-id>/positions/round1_domain_expert.md

  Moderator collects all 4 statements and distributes to ALL members simultaneously.

--- ROUND 2 — Cross-Examination (sequential, all respond to all) ---

  Each member responds to every other member's Round 1 position.

  CROSS-EXAMINATION FORMAT:
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  CROSS-EXAMINATION — [Role Name] responds to [Other Role]

  To [Other Role]'s point on [specific claim]:
    CHALLENGE | CONCEDE | EXPAND:
    [Challenge: New evidence that contradicts their claim — cite Tier X source]
    [Concede: Acknowledge their point is valid — a concession is permanent]
    [Expand: Agree but add important nuance with additional evidence]
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Save to: .agents/council/<session-id>/positions/round2_cross_examination.md

  Moderator identifies:
    - Points of emerging consensus (3+ members agree after evidence exchange)
    - Live disputes (Advocate and Skeptic still fundamentally disagree)
    - Frame shifts accepted (if Devil's Advocate's reframe was accepted by majority)

--- ROUND 3 — Resolution (ONLY for live disputes from Round 2) ---

  Round 3 runs ONLY on points that remain disputed. This prevents repetition.
  Members must bring NEW evidence not cited in Rounds 1 or 2.
  If no new evidence available → dispute logged as UNRESOLVED (never forced to verdict).
  Moderator rules on unresolved disputes using evidence tier weights — not opinion.

  Save to: .agents/council/<session-id>/positions/round3_resolution.md
           (only written if Round 3 runs)

--- VERDICT — Moderator synthesizes ---

  CONFIDENCE SCORE FORMULA:
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Base score: 50%

  POSITIVE ADJUSTMENTS:
  +20%  All members reached consensus on the primary verdict
  +15%  Verdict supported by at least 2 Tier 1 evidence sources
  +10%  Skeptic formally conceded the Advocate's core point
  +10%  No unresolved disputes remain
  +5%   Verdict aligns with Domain Expert's hard constraints

  NEGATIVE ADJUSTMENTS:
  -15%  A live dispute remains unresolved after Round 3
  -10%  Verdict supported only by Tier 2/3 evidence
  -10%  Skeptic's strongest challenge was not conclusively refuted
  -5%   Devil's Advocate raised a frame issue that wasn't fully resolved
  -20%  Domain Expert identified a constraint violation in the verdict

  Floor: 20% (debate too inconclusive for any recommendation)
  Ceiling: 95% (no verdict is ever 100% certain)
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Moderator writes verdict to:
    .agents/council/verdicts/<ts>-<question-slug>.md

  FULL VERDICT SCHEMA:
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  # Council Verdict — <question>
  Session: <council-session-id> | Date: <ISO>
  Verdict: APPROVED | REJECTED | CONDITIONAL | INCONCLUSIVE
  Confidence: <X>%  (computed from formula above)
  Consensus: Full | Partial | Unresolved

  ## Reasoning
  [2-3 paragraphs synthesizing all 3 rounds — specific, not vague]

  ## Evidence That Survived Debate
  (These points were challenged and held)
  1. [Claim] — [Source, Tier]

  ## Evidence That Did NOT Survive Debate
  1. [Claim] — Refuted by: [counter-evidence, Tier]

  ## Key Assumptions
  (Verdict only valid if these remain true)
  1. [Assumption]

  ## Unresolved Disputes
  1. [Point of dispute] — Advocate position vs. Skeptic position

  ## Minority Opinion (NEVER discarded)
  From [Role]: [Their dissenting view and strongest evidence]

  ## Domain Constraints
  (Hard constraints — not trade-offs)
  1. [Constraint]

  ## Conditions (if CONDITIONAL)
  [Specific conditions that must be met for this verdict to hold]

  ## Recommended Next Action
  → [Specific action for the Orchestrator]
  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  Report verdict to Orchestrator via Result Message.
  Save council verdict to learned.jsonl for future reference (tagged with question domain).
```

---

## Output Artifacts
```
.agents/council/
└── verdicts/
    └── <ts>-<question-slug>.md        ← THE verdict

.agents/council/<session-id>/
    evidence_manifest.json             ← ingested materials + tiers
    positions/
        round1_advocate.md
        round1_skeptic.md
        round1_devils_advocate.md
        round1_domain_expert.md
        round2_cross_examination.md
        round3_resolution.md           ← only if Round 3 ran
```

---

## Guardrails
- All 3 rounds must complete — no shortcuts to verdict
- Every claim needs a cited source — unsourced assertions are called out by Moderator
- Minority opinions always preserved in the verdict document — never discarded
- Council never produces code, config, or implementation plans
- Inconclusive verdicts (20% confidence floor) are valid — never force a verdict
- Concessions are permanent — a member cannot recant in a later round
- Domain Expert constraints are hard limits — not trade-offs to debate
