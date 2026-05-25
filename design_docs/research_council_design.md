# Research Council — Deep Design Specification

> Division 6: The adversarial research engine. A structured multi-agent debate that produces evidence-backed consensus verdicts before critical decisions are made.

---

## Why The Council Exists

Every other division in the system is optimized for **execution** — writing code, deploying infrastructure, testing features. They are fast, focused, and opinionated.

The Council is optimized for **truth** — not speed, not confidence, not pleasing outputs. Its entire structure is built around one goal: **produce a conclusion that survives adversarial scrutiny**.

The fundamental mechanism is borrowed from three proven real-world systems:

| Domain | System | Core Mechanism |
|--------|--------|----------------|
| **Law** | Adversarial legal system | Advocate + opposing counsel + neutral judge |
| **Science** | Peer review | Authors claim, reviewers challenge, community decides |
| **Strategy** | Delphi Method | Experts state positions independently, revise after seeing others, iterate to consensus |
| **AI Safety** | Constitutional AI / Red-teaming | Model critiques its own outputs under adversarial pressure |

**The synthesis:** A structured 3-round debate where each Council member has a fixed role, argues from real evidence, and the Moderator drives toward a consensus verdict — preserving dissent when genuine disagreement remains.

---

## When To Use The Council

### ✅ Use The Council For:

| Scenario | Why |
|----------|-----|
| Choosing between two or more architectures | Trade-offs exist; both sides have real merit |
| Evaluating a new technology or library | Hype vs. reality needs adversarial pressure |
| Reviewing a research paper's claims | Papers have biases; a Skeptic surfaces them |
| Deciding whether to adopt a third-party service | Vendor claims need independent challenge |
| Analyzing design direction before building | Prevents expensive late pivots |
| Evaluating a security approach | Attack/defend framing is native to security |
| Resolving a disagreement between divisions | Neutral adjudication needed |
| High-stakes architectural decisions | Wrong choice = months of rework |

### ❌ Do NOT Use The Council For:

| Scenario | Why |
|----------|-----|
| Implementing a feature | Debate is wasteful here — just build it |
| Writing tests | No adversarial angle needed |
| Debugging a bug | `/investigate` handles this |
| Generating documentation | No ambiguity to resolve |
| Routine deployments | `/deploy` handles this |
| Any task with a clear, unambiguous answer | Council adds cost with no quality benefit |

**Rule of thumb:** If a competent senior engineer would spend less than 10 minutes deciding, don't use the Council. If they'd spend a day researching before deciding — use the Council.

---

## Council Structure: 5 Fixed Roles

```
╔══════════════════════════════════════════════════════════════════╗
║                    RESEARCH COUNCIL                              ║
║                                                                  ║
║  ┌─────────────┐                                                 ║
║  │  MODERATOR  │  — Chairs the debate, drives consensus         ║
║  └──────┬──────┘                                                 ║
║         │ orchestrates                                           ║
║         │                                                        ║
║  ┌──────▼───────────────────────────────────────────────────┐   ║
║  │                   COUNCIL CHAMBER                         │   ║
║  │                                                           │   ║
║  │  ┌───────────┐  ┌──────────┐  ┌────────────┐            │   ║
║  │  │ ADVOCATE  │  │ SKEPTIC  │  │   DEVIL'S  │            │   ║
║  │  │           │  │          │  │  ADVOCATE  │            │   ║
║  │  │ Argues    │  │ Argues   │  │            │            │   ║
║  │  │ strongest │  │ strongest│  │ Challenges │            │   ║
║  │  │ case FOR  │  │ case     │  │ ALL sides  │            │   ║
║  │  │           │  │ AGAINST  │  │            │            │   ║
║  │  └───────────┘  └──────────┘  └────────────┘            │   ║
║  │                                                           │   ║
║  │              ┌──────────────────┐                        │   ║
║  │              │  DOMAIN EXPERT   │                        │   ║
║  │              │                  │                        │   ║
║  │              │  Specialist view │                        │   ║
║  │              │  (role changes   │                        │   ║
║  │              │  per topic)      │                        │   ║
║  │              └──────────────────┘                        │   ║
║  └───────────────────────────────────────────────────────────┘   ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## Role Specifications

### 🎯 The Moderator

```yaml
---
role: Moderator
aliases: [Council Chair, Research Lead]
activatedBy: [/council command]
responsibility: Structure the debate, enforce rules, synthesize consensus
bias: None — deliberately neutral
canOverrule: Any Council member who violates debate rules
---
```

**What the Moderator does:**
1. Receives the research question and ingested materials
2. Frames the question precisely — removes ambiguity before debate begins
3. Assigns the Domain Expert role based on topic
4. Runs Round 1: issues instructions to each member independently
5. Collects Round 1 positions and distributes them to all members (no editing)
6. Runs Round 2: instructs each member to respond to the positions they've seen
7. Identifies where consensus has emerged and where genuine disagreement remains
8. Runs Round 3 only on unresolved points — not the whole debate
9. Synthesizes the COUNCIL VERDICT
10. Flags minority opinions — never discards them

**Moderator Hard Rules:**
- ❌ Never takes a position on the research question — strictly neutral
- ❌ Never cuts a debate round short due to "obvious" answers — all 3 rounds always run
- ✅ Calls out when a member makes an assertion without cited evidence
- ✅ Identifies circular arguments and breaks them by requesting new evidence
- ✅ Preserves the strongest dissenting view in the final verdict, even if overruled

---

### 🟢 The Advocate

```yaml
---
role: Advocate
bias: Steelmanned position FOR the proposal
responsibility: Find and present the strongest possible case in favor
evidence_required: true — assertions without sources are invalid
---
```

**What the Advocate does:**
- Researches and ingests all provided materials looking for **supporting evidence**
- Finds real-world case studies, benchmarks, production usage data, and expert endorsements
- Constructs the strongest possible argument for the proposal — even if they personally disagree
- In Round 2: defends challenged points with additional evidence or formally concedes

**The "steelman" obligation:** The Advocate must argue the *best possible* version of the proposal — not a weak strawman version. If the best version of the proposal is weak, the verdict will reflect that.

**Advocate Hard Rules:**
- ❌ No unsourced claims — every assertion must reference ingested material or a specific data point
- ❌ Cannot simply restate the same point in Round 2 — must bring new evidence when challenged
- ✅ Must formally concede specific points when the Skeptic's challenge cannot be refuted
- ✅ Concessions are logged and included in the final verdict — honesty is rewarded

---

### 🔴 The Skeptic

```yaml
---
role: Skeptic
bias: Steelmanned position AGAINST the proposal
responsibility: Find and present the strongest possible case against
evidence_required: true — challenges without evidence are invalid
---
```

**What the Skeptic does:**
- Researches and ingests all provided materials looking for **contradicting evidence**
- Finds failure cases, performance problems, known limitations, alternative research, and critical analyses
- Constructs the strongest possible case against the proposal — even if they personally agree with it
- In Round 2: challenges conceded Advocate points with further evidence; defends their own positions

**The Skeptic's purpose is not to "win"** — it is to ensure the final verdict has survived the hardest possible challenge. A verdict that withstands a good Skeptic is worth trusting.

**Skeptic Hard Rules:**
- ❌ No ad hominem attacks on sources — challenge the evidence, not the source's credibility
- ❌ Cannot raise new objections in Round 3 that weren't raised in Round 1 or 2 (no ambush tactics)
- ✅ Must formally concede when the Advocate provides evidence that genuinely resolves a challenge
- ✅ A Skeptic who concedes everything is not failing — they are confirming a strong proposal

---

### ⚡ The Devil's Advocate

```yaml
---
role: Devil's Advocate
bias: Finds blind spots in BOTH sides
responsibility: Challenge assumptions that Advocate and Skeptic both share
evidence_required: true
---
```

**What the Devil's Advocate does:**
- Does not argue for or against the proposal
- Looks for **shared assumptions** that both the Advocate and Skeptic are making and challenges them
- Identifies **the questions that aren't being asked** — the unknown unknowns
- Surfaces alternative framings of the problem that make the original question irrelevant
- Asks: "What if both of you are solving the wrong problem?"

**This is the most valuable and most underused role in any research process.** Both the Advocate and Skeptic argue within an implicit frame. The Devil's Advocate challenges the frame itself.

**Examples of Devil's Advocate challenges:**
- "Both of you are assuming we need to solve this now — do we?"
- "You're both comparing these options on performance. What if operational simplicity matters more?"
- "The Advocate's case study is from 2021. The Skeptic's counterexample is from 2023. What changed?"
- "Neither of you mentioned [third option]. Why not?"

**Devil's Advocate Hard Rules:**
- ❌ Cannot simply agree with either side — must always bring a novel angle
- ❌ Cannot raise purely hypothetical concerns — must ground challenges in plausible scenarios
- ✅ Is the only role permitted to change the framing of the question mid-debate (with Moderator approval)

---

### 🔬 The Domain Expert

```yaml
---
role: Domain Expert
bias: Deep specialist knowledge for the specific topic
assignment: Determined by Moderator based on research question
examples:
  - Security Expert (for security architecture questions)
  - Performance Expert (for latency/throughput trade-off questions)
  - Cost Analyst (for build-vs-buy decisions)
  - UX Expert (for design direction questions)
  - Compliance Expert (for regulatory decisions)
evidence_required: true
---
```

**What the Domain Expert does:**
- Brings specialist knowledge that the Advocate and Skeptic may not have
- Does not argue for or against — brings **domain-specific facts, constraints, and context**
- Answers: "From a [domain] perspective, here is what matters and why"
- Identifies when the debate is making assumptions that violate domain constraints
- Provides the technical depth that grounds abstract trade-off discussions

**Examples:**
- A security architecture debate: Domain Expert brings OWASP, CVE history, and threat model data
- A database choice debate: Domain Expert brings query pattern analysis and index cost data
- A UI framework debate: Domain Expert brings accessibility compliance and Core Web Vitals benchmarks
- A vendor decision: Domain Expert brings TCO, SLA history, and migration cost data

**Domain Expert Hard Rules:**
- ❌ Cannot take a position on the overall verdict — only provides domain context
- ✅ Can and must correct factually wrong statements from any other Council member
- ✅ Their domain constraints are treated as hard constraints — not trade-offs to debate

---

## Evidence Ingestion System

The Council can ingest and analyze the following material types before debate begins:

### Supported Input Formats

| Format | How Ingested | What's Extracted |
|--------|-------------|-----------------|
| 🔗 **URL** | Scraped via MCP browser tool | Full page text, headings, data tables, code samples |
| 📄 **PDF / Research Paper** | Parsed via document tool | Abstract, methodology, results, conclusions, citations |
| 📋 **Design Document** | Read as file | Decisions, constraints, trade-offs documented |
| 📚 **Documentation Page** | Scraped | API surface, limitations, version-specific notes |
| 🗄️ **Code Repository** | Traversed via file tools | Architecture patterns, dependencies, test coverage |
| 🖼️ **Design File / Mockup** | Analyzed via Figma MCP | Layout structure, component hierarchy, design decisions |
| 📊 **Benchmark Report** | Parsed | Numeric data, methodology, comparison conditions |
| 🗣️ **Forum / Discussion** | Scraped (HN, Reddit, GitHub issues) | Real-world experience reports, failure modes, community consensus |

### Evidence Quality Tiers

Not all evidence is equal. The Moderator assigns a quality tier to each piece of evidence:

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
  Anonymous reports
  "I heard that..." references

TIER 4 — Invalid (rejected, not entered into debate)
  Marketing copy / vendor claims without data
  Purely hypothetical scenarios
  Assertions without any supporting reference
```

The Moderator's verdict weights Tier 1 evidence above all others. A Tier 1 finding that contradicts a Tier 3 consensus always wins.

---

## The 3-Round Debate Protocol

### Pre-Debate: Evidence Distribution

```
1. Moderator receives research question + all ingested materials
2. Moderator frames the question precisely:
   Bad framing:  "Should we use Redis?"
   Good framing: "For our pub/sub event bus with <1ms delivery requirement and
                  3 consumer groups, should we use Redis Streams or Kafka?"
3. Moderator assigns Domain Expert role (topic-dependent)
4. All ingested materials are distributed to ALL Council members simultaneously
5. Members read independently — no communication before Round 1
```

### Round 1: Independent Positions (No Cross-Influence)

Each member submits their position **independently** — they cannot see others' positions yet.

**Output format per member:**

```
POSITION STATEMENT — [Role Name]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Stance: [For / Against / Neutral / Challenging Frame]
Confidence: [Low / Medium / High]

Core Argument:
[2-4 sentences — the main thesis]

Supporting Evidence:
1. [Claim] — Source: [Tier X, specific reference]
2. [Claim] — Source: [Tier X, specific reference]
3. [Claim] — Source: [Tier X, specific reference]

Key Assumption:
[The one assumption this position most depends on being true]

Conceded Weaknesses:
[What is the strongest argument against my own position?]
```

The **Conceded Weaknesses** field is mandatory — it forces self-honesty and often surfaces the most important debate points early.

### Round 2: Cross-Examination

All Round 1 positions are shared with all members simultaneously.

Each member responds to every other position:

```
CROSS-EXAMINATION — [Role Name] responds to [Other Role]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
To [Other Role]'s point on [specific claim]:

  CHALLENGE / CONCEDE / EXPAND:
  [Challenge: New evidence that contradicts their claim]
  [Concede: Acknowledge their point is valid]
  [Expand: Agree but add important nuance]

  Evidence: [If challenge — cite Tier X source]
```

After all cross-examinations, the Moderator identifies:
- **Points of emerging consensus** — where 3+ members agree after seeing all evidence
- **Live disputes** — where Advocate and Skeptic still fundamentally disagree after evidence exchange
- **Reframing accepted** — if the Devil's Advocate's frame shift was accepted by majority

### Round 3: Resolution (Only For Live Disputes)

Round 3 only runs on points that remain disputed after Round 2. This prevents repetition.

For each live dispute, each involved party gets one final statement:
- Must bring **new evidence** not cited in rounds 1 or 2
- If no new evidence can be brought → the dispute is logged as **unresolved** in the verdict
- The Moderator rules on unresolved disputes using evidence tier weights — not opinion

---

## Consensus State Machine

```
                    ┌──────────────────┐
                    │   PRE-DEBATE     │
                    │  Frame question  │
                    │  Ingest material │
                    │  Assign roles    │
                    └────────┬─────────┘
                             │
                    ┌────────▼─────────┐
                    │    ROUND 1       │
                    │  Independent     │
                    │  positions       │
                    └────────┬─────────┘
                             │
                    ┌────────▼─────────┐
                    │    ROUND 2       │
                    │  Cross-examine   │
                    │  Challenge /     │
                    │  concede         │
                    └────────┬─────────┘
                             │
               ┌─────────────▼────────────┐
               │   CONSENSUS ASSESSMENT   │
               │  Moderator evaluates     │
               └────────────┬─────────────┘
                            │
          ┌─────────────────┼─────────────────┐
          ▼                 ▼                 ▼
  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
  │  FULL        │  │  PARTIAL     │  │  DISPUTED    │
  │  CONSENSUS   │  │  CONSENSUS   │  │  (live       │
  │              │  │  (some live  │  │  disputes    │
  │  All members │  │  disputes    │  │  remain)     │
  │  agree on    │  │  remain)     │  │              │
  │  verdict     │  │              │  └──────┬───────┘
  └──────┬───────┘  └──────┬───────┘         │
         │                 │         ┌────────▼────────┐
         │                 │         │    ROUND 3      │
         │                 │         │  Resolution on  │
         │                 │         │  disputes only  │
         │                 │         └────────┬────────┘
         │                 │                  │
         └─────────────────┴──────────────────┘
                           │
                  ┌────────▼──────────┐
                  │  VERDICT ASSEMBLY │
                  │  Moderator writes │
                  │  final verdict    │
                  └────────┬──────────┘
                           │
                  ┌────────▼──────────┐
                  │  VERDICT DELIVERED│
                  │  to Orchestrator  │
                  └───────────────────┘
```

---

## Council Verdict Schema

The final output of every Council session:

```
╔══════════════════════════════════════════════════════════════════╗
║                     COUNCIL VERDICT                              ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  Session ID:    council_<ulid>                                   ║
║  Question:      [Precisely framed research question]             ║
║  Confidence:    [0–100%]                                         ║
║  Consensus:     [Full / Partial / Unresolved]                    ║
║                                                                  ║
╠══════════════════════════════════════════════════════════════════╣
║  VERDICT                                                         ║
║  ─────────────────────────────────────────────────────────────  ║
║  [Clear, actionable recommendation in 2-4 sentences]            ║
║  [States what to do — not just what was found]                  ║
╠══════════════════════════════════════════════════════════════════╣
║  EVIDENCE THAT SURVIVED DEBATE                                   ║
║  (These points were challenged and held)                         ║
║  1. [Claim] — [Source, Tier]                                     ║
║  2. [Claim] — [Source, Tier]                                     ║
║  3. [Claim] — [Source, Tier]                                     ║
╠══════════════════════════════════════════════════════════════════╣
║  EVIDENCE THAT DID NOT SURVIVE DEBATE                            ║
║  (These were the original arguments — they were refuted)         ║
║  1. [Claim] — Refuted by: [counter-evidence, Tier]               ║
╠══════════════════════════════════════════════════════════════════╣
║  KEY ASSUMPTIONS                                                 ║
║  (Verdict is only valid if these remain true)                    ║
║  1. [Assumption]                                                 ║
║  2. [Assumption]                                                 ║
╠══════════════════════════════════════════════════════════════════╣
║  UNRESOLVED DISPUTES                                             ║
║  (Genuine disagreement remains — noted for transparency)         ║
║  1. [Point of dispute] — Advocate position vs. Skeptic position  ║
╠══════════════════════════════════════════════════════════════════╣
║  MINORITY OPINION                                                ║
║  (Preserved even if overruled by majority)                       ║
║  From [Role]: [Their dissenting view and strongest evidence]     ║
╠══════════════════════════════════════════════════════════════════╣
║  DOMAIN CONSTRAINTS                                              ║
║  (Hard constraints from Domain Expert — not trade-offs)          ║
║  1. [Constraint] — must be respected regardless of verdict       ║
╠══════════════════════════════════════════════════════════════════╣
║  RECOMMENDED NEXT ACTION                                         ║
║  → [Specific action for the Orchestrator to take]                ║
║  → [E.g., "Pass verdict to Engineering Lead with constraint X"]  ║
╚══════════════════════════════════════════════════════════════════╝
```

### Confidence Score Calculation

```
Base score: 50%

+20%  if all members reached consensus on the primary verdict
+15%  if the verdict is supported by at least 2 Tier 1 evidence sources
+10%  if the Skeptic formally conceded the Advocate's core point
+10%  if no unresolved disputes remain
+5%   if the verdict aligns with Domain Expert constraints

-15%  if a live dispute remains unresolved
-10%  if verdict is supported only by Tier 2/3 evidence
-10%  if the Skeptic's strongest challenge was not conclusively refuted
-5%   if the Devil's Advocate raised a frame issue that wasn't resolved
-20%  if the Domain Expert identified a constraint violation in the verdict

Floor: 20% (if debate was too inconclusive to make any recommendation)
Ceiling: 95% (no verdict is ever 100% certain — the 5% acknowledges unknown unknowns)
```

---

## The `/council` Slash Command

### Trigger
```
/council "<research question>" [--materials <url1> <url2> <file.pdf> ...]
```

### Examples
```bash
/council "Should we use Redis Streams or Kafka for our event bus?" \
  --materials https://redis.io/docs/streams/ \
              https://kafka.apache.org/documentation/ \
              ./benchmarks/event-bus-comparison.pdf \
              https://engineering.linkedin.com/blog/kafka-at-scale

/council "Is our current authentication architecture secure enough for SOC2?" \
  --materials https://owasp.org/www-project-top-ten/ \
              ./docs/auth-architecture.md \
              ./services/auth-api/

/council "Should we build or buy the analytics dashboard?" \
  --materials https://metabase.com/pricing \
              https://grafana.com/docs/ \
              ./docs/analytics-requirements.md
```

### Skill Flow

```
User: /council "<question>" --materials [...]
  │
  ▼
Orchestrator receives command
  ├─ Reads learned.jsonl for any prior related Council verdicts
  ├─ Routes to: Research Council Lead (Moderator)
  │
  ▼
Moderator: Pre-Debate Phase
  ├─ Ingests all --materials (scrape URLs, parse PDFs, read files)
  ├─ Assigns evidence quality tiers to all material
  ├─ Frames the question precisely
  ├─ Determines Domain Expert role for this topic
  ├─ Logs council session start to audit.jsonl
  │
  ▼
Round 1: Independent Positions
  ├─ Advocate: researches FOR, writes position statement
  ├─ Skeptic: researches AGAINST, writes position statement
  ├─ Devil's Advocate: identifies blind spots, writes position statement
  ├─ Domain Expert: writes domain context statement
  │   (All done in parallel — no member sees another's output yet)
  │
  ▼
Moderator: Distributes all Round 1 positions to all members
  │
  ▼
Round 2: Cross-Examination
  ├─ All members respond to all other positions
  ├─ Challenges must cite evidence
  ├─ Concessions are logged
  │
  ▼
Moderator: Consensus Assessment
  ├─ Identifies consensus points
  ├─ Identifies live disputes
  ├─ Determines if Round 3 is needed
  │
  ▼
Round 3 (if needed): Resolution on disputed points only
  ├─ Members bring new evidence only
  ├─ Moderator rules using evidence tier weights
  │
  ▼
Moderator: Assembles COUNCIL VERDICT
  ├─ Calculates confidence score
  ├─ Writes full verdict schema
  ├─ Preserves minority opinions
  ├─ Defines recommended next action
  │
  ▼
Verdict delivered to Orchestrator
  ├─ Orchestrator incorporates verdict into task.md
  ├─ Orchestrator routes recommended action to appropriate Division Lead
  ├─ Council session written to learned.jsonl for future reference
  └─ Full debate transcript saved to sessions/<id>/council_<ulid>.md
```

---

## Integration With Other Divisions

The Council is **pre-execution** — its output always feeds into execution divisions, never the reverse.

```
COUNCIL VERDICT
      │
      ▼
ORCHESTRATOR
      │
      ├──► Engineering Division    (if verdict is about architecture/implementation)
      ├──► Platform Division       (if verdict is about infra/deployment strategy)
      ├──► Design Division         (if verdict is about design direction)
      ├──► Quality Division        (if verdict is about testing strategy)
      └──► Intelligence Division   (verdict saved to learned.jsonl for future sessions)
```

**The Council never writes code, deploys anything, or modifies files.** Its only output is the verdict document. Execution happens after.

### Council ↔ Orchestrator Contract

The Orchestrator may call the Council when:
1. A `/plan` task surfaces a decision with significant trade-offs
2. Two Division Leads disagree on approach and need adjudication
3. The user explicitly calls `/council`
4. A past Council verdict is being applied to a new context (may need re-evaluation)

The Orchestrator must pass the Council verdict to the relevant Division Lead with this note:
> "This decision was made by Council verdict [ID] with [X]% confidence. The Domain Expert identified [constraints] as hard constraints. Apply accordingly."

---

## Council Session Artifacts

Every Council session produces:

```
.agents/sessions/<session-id>/
└── council/
    ├── council_<ulid>.md          # Full debate transcript (all rounds)
    ├── verdict_<ulid>.md          # Final verdict document
    ├── evidence_manifest.json     # All ingested materials + quality tiers
    └── positions/
        ├── round1_advocate.md
        ├── round1_skeptic.md
        ├── round1_devils_advocate.md
        ├── round1_domain_expert.md
        ├── round2_cross_examination.md
        └── round3_resolution.md   # Only if Round 3 ran
```

---

## Hard Rules For The Entire Council

1. **Evidence over opinion** — Any assertion without a cited source is invalid and called out by the Moderator
2. **Tier weight governs** — A Tier 1 finding always outweighs a Tier 3 consensus, regardless of how many voices support the Tier 3 view
3. **Minority opinions are sacred** — The Moderator never discards a dissenting view. If a minority opinion is overruled, it is explicitly preserved in the verdict
4. **No late-game ambushes** — Round 3 can only address disputes from Round 2. New challenges introduced in Round 3 are invalid
5. **Concessions are honored** — When a member concedes a point, that concession is permanent and logged. No recanting in later rounds
6. **The Domain Expert's constraints are not trade-offs** — They are hard limits. The verdict must be compatible with them or the verdict is invalid
7. **The Moderator cannot be influenced** — No Council member can lobby the Moderator privately. All communication is in the chamber, visible to all
8. **Confidence is honest** — The Moderator never inflates the confidence score to make the verdict look stronger. A 45% confidence verdict is a valid output
9. **The question owns the frame** — If the Devil's Advocate shifts the frame, the Moderator must explicitly accept the new frame before the debate continues under it
10. **The Council does not implement** — Its only output is the verdict. Implementation decisions belong to execution divisions
