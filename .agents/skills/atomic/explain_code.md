# Atomic Skill: explain_code
# .agents/skills/atomic/explain_code.md
# Type: General-Purpose Primitive
# Available to: ALL agents
# Permission Tier: 1 (auto-approved — read-only)

---

## Purpose
Produce a clear, audience-calibrated explanation of a code block, function,
module, or system. Adjusts vocabulary, depth, and metaphors based on the
target audience. Never modifies code — purely explanatory.

---

## Inputs

| Field | Required | Description |
|-------|----------|-------------|
| `target` | ✅ | Code block (string), file path, or function name |
| `audience` | Optional | `engineer` (default) \| `non-tech` \| `junior` \| `senior` \| `pm` \| `exec` |
| `format` | Optional | `prose` (default) \| `bullets` \| `analogy` \| `annotated` |
| `focus` | Optional | What to emphasize: `what` \| `why` \| `how` \| `risks` \| `all` (default) |
| `context` | Optional | Extra context: "this is called during checkout" |

---

## Audience Calibration

| Audience | Vocabulary | Depth | Metaphors |
|----------|-----------|-------|-----------|
| `engineer` | Technical terms fine | Full detail | Code-based |
| `senior` | Advanced terms, no basics | Pattern + trade-off focus | Architecture-level |
| `junior` | Simple terms, define jargon | Step-by-step | Relatable real-world |
| `non-tech` | Zero jargon | What it does, not how | Everyday life analogies |
| `pm` | Product outcomes focus | What it enables, constraints | Feature/user impact |
| `exec` | Business outcomes only | Risk, cost, capability | Business analogies |

---

## Format Options

| Format | Output Style |
|--------|-------------|
| `prose` | 2-4 paragraph narrative explanation |
| `bullets` | Concise bullet points — one idea per bullet |
| `analogy` | One core analogy that maps the code to something familiar |
| `annotated` | Returns the code with inline comments added at key lines |

---

## Execution Protocol

```
STEP 1 — Resolve target
  If target is a function name → search_code to locate it → read_file to get content
  If target is a file path → read_document(path=<target>)
  If target is a code string → use directly

STEP 2 — Analyze code structure
  Identify: inputs, outputs, side effects, dependencies called, error paths
  Classify: pure function | stateful | I/O-bound | CPU-bound | mixed

STEP 3 — Generate explanation
  Apply audience calibration
  Apply format rules
  Apply focus filter:
    what:  What does this do? What problem does it solve?
    why:   Why was it built this way? What alternatives were rejected?
    how:   Step-by-step walkthrough of the logic
    risks: What can go wrong? Edge cases, failure modes
    all:   Full coverage (what + why + how + risks)

STEP 4 — Quality check
  - Does the explanation use any jargon inappropriate for the audience?
  - Is it accurate — does it match what the code actually does?
  - For 'non-tech' or 'pm': contains no code-specific terms?

RETURN:
  {
    audience:     "<audience>",
    format:       "<format>",
    focus:        "<focus>",
    explanation:  "<the explanation>",
    summary:      "<one sentence TL;DR>",
    key_concepts: ["<concept1>", "<concept2>"]  // for engineer/senior audience
  }
```

---

## Usage Examples

```
# Explain a function to a non-technical PM
explain_code(
  target="src/services/auth.service.ts",
  audience="pm",
  format="bullets",
  focus="what"
)
# Output: "This file handles user login. It checks if the username and
# password match, creates a session so the user stays logged in, and
# records when they signed in."

# Explain a complex algorithm to a junior engineer
explain_code(
  target="src/lib/rate-limiter.ts",
  audience="junior",
  format="prose",
  focus="how"
)

# Get annotated version of a complex function
explain_code(
  target="processPayment",
  audience="engineer",
  format="annotated",
  focus="all"
)

# Quick analogy for a data structure
explain_code(
  target="src/lib/lru-cache.ts",
  audience="non-tech",
  format="analogy"
)
# Output: "Think of it like a whiteboard with limited space. When it fills up,
# you erase whatever you wrote longest ago to make room for something new."

# Risk-focused review for a security engineer
explain_code(
  target="validateJWT",
  audience="senior",
  format="bullets",
  focus="risks"
)
```
