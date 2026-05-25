# Agent Communication, Guardrails & Error Handling — Deep Design

> The operational layer: how agents talk, what they cannot do, how failures are handled, and where project-specific rules live.

---

## 1. Agent Communication Protocol

### 1.1 The Fundamental Rule: All Cross-Division Communication Goes Through The Orchestrator

```
╔══════════════════════════════════════════════════════════╗
║                    ORCHESTRATOR                          ║
║              (the only cross-division router)            ║
╠══════════╦══════════════╦═══════════╦═════════╦═════════╣
║  DIV 1   ║    DIV 2     ║   DIV 3   ║  DIV 4  ║  DIV 5  ║
║          ║              ║           ║         ║         ║
║  Lead ←→ ║  Lead ←→     ║  Lead ←→  ║ Lead ←→ ║ Lead ←→ ║
║  Spec A  ║  Spec A      ║  Spec A   ║ Spec A  ║ Spec A  ║
║  Spec B  ║  Spec B      ║  Spec B   ║ Spec B  ║ Spec B  ║
╚══════════╩══════════════╩═══════════╩═════════╩═════════╝

✅ ALLOWED: Spec A → Lead (within same division)
✅ ALLOWED: Lead → Orchestrator
✅ ALLOWED: Orchestrator → any Lead (cross-division)
❌ FORBIDDEN: Spec A (Div 1) → Spec A (Div 2) — direct cross-division
❌ FORBIDDEN: Lead (Div 1) → Lead (Div 2) — direct cross-division
❌ FORBIDDEN: Orchestrator → Specialist (skipping the Lead)
```

**Why:** Context isolation. If the Backend Architect talks directly to the Visual QA Specialist, both agents accumulate each other's context and the Orchestrator loses its ability to coordinate, gate, and audit what is happening. The Orchestrator is the single source of truth for session state.

---

### 1.2 The Result Message Schema

Every agent communicates by returning a **Result Message** — a structured output that the recipient (Lead or Orchestrator) reads before deciding what to do next. This is not free-form conversation. It is a typed contract.

```
╔══════════════════════════════════════════════════════════════════╗
║                        RESULT MESSAGE                            ║
╠══════════════════════════════════════════════════════════════════╣
║ FROM:          <agent-role>/<division>                           ║
║ TO:            <orchestrator | division-lead>                    ║
║ SESSION_ID:    <ulid>                                            ║
║ TASK_ID:       <ref from task.md>                                ║
║ TIMESTAMP:     <ISO-8601>                                        ║
╠══════════════════════════════════════════════════════════════════╣
║ STATUS:        SUCCESS | PARTIAL | BLOCKED | FAILED | TIMEOUT    ║
║ CONFIDENCE:    <0–100%> (agent's self-assessed quality)          ║
╠══════════════════════════════════════════════════════════════════╣
║ SUMMARY:                                                         ║
║   <2–4 sentences: what was done, why it matters>                 ║
╠══════════════════════════════════════════════════════════════════╣
║ OUTPUT:                                                          ║
║   type: <code | config | analysis | verdict | plan | report>     ║
║   artifacts: [<list of files created or modified>]               ║
║   content: <the actual output>                                   ║
╠══════════════════════════════════════════════════════════════════╣
║ SIDE_EFFECTS:                                                     ║
║   files_modified: [<paths>]                                      ║
║   commands_run: [<commands executed>]                            ║
║   external_calls: [<MCP tools invoked>]                          ║
╠══════════════════════════════════════════════════════════════════╣
║ BLOCKERS: (only if STATUS = BLOCKED)                             ║
║   - <what is blocking progress — specific, not vague>            ║
║   - <what the Orchestrator or human needs to resolve it>         ║
╠══════════════════════════════════════════════════════════════════╣
║ PARTIAL_COMPLETION: (only if STATUS = PARTIAL)                   ║
║   completed: [<what was done>]                                   ║
║   remaining: [<what still needs to be done>]                     ║
║   rollback_needed: true | false                                  ║
╠══════════════════════════════════════════════════════════════════╣
║ ERROR: (only if STATUS = FAILED | TIMEOUT)                       ║
║   type: <tool_failure | permission_denied | invalid_state |      ║
║          context_overflow | external_api_error | logic_error>    ║
║   message: <exact error message>                                 ║
║   stack: <relevant trace or context>                             ║
║   rollback_performed: true | false                               ║
╠══════════════════════════════════════════════════════════════════╣
║ NEXT_ACTION_RECOMMENDATION:                                      ║
║   <what the Orchestrator should do next — specific suggestion>   ║
╚══════════════════════════════════════════════════════════════════╝
```

### 1.3 Message Flow Examples

**Example A: Simple success flow**
```
User: /tdd "add email validation to signup form"
  │
  ▼
Orchestrator creates task.md entry
  │ delegates →
Quality Lead
  │ delegates →
SDET
  │ writes failing tests, returns →

RESULT MESSAGE
  FROM: sdet/quality
  TO: quality-lead
  STATUS: SUCCESS
  CONFIDENCE: 92%
  SUMMARY: "Wrote 4 failing tests covering empty email,
            invalid format, duplicate, and success cases.
            All tests fail as expected (TDD phase 1 complete)."
  OUTPUT:
    type: code
    artifacts: [tests/signup.test.ts]
  SIDE_EFFECTS:
    files_modified: [tests/signup.test.ts]
  NEXT_ACTION_RECOMMENDATION:
    "Delegate implementation to Engineering Lead → Backend Architect"

Quality Lead forwards to Orchestrator
  │ delegates →
Engineering Lead
  │ delegates →
Backend Architect implements
  │ returns →
Result Message (SUCCESS, 88%)
  │
Orchestrator: both tasks done → runs /review
```

**Example B: Blocked flow**
```
DevOps Engineer executing /deploy staging
  │
  BLOCKED: "Staging Kubernetes namespace 'app-staging' does not
            exist. Need Platform Lead to provision it before
            deployment can proceed."
  │
RESULT MESSAGE
  FROM: devops/platform
  TO: platform-lead
  STATUS: BLOCKED
  BLOCKERS:
    - K8s namespace 'app-staging' missing
    - Requires: Cloud Architect to provision namespace + RBAC
  NEXT_ACTION_RECOMMENDATION:
    "Route to Cloud Architect to provision namespace,
     then retry /deploy staging"

Platform Lead escalates to Orchestrator
  Orchestrator routes to Cloud Architect
  Cloud Architect provisions namespace → returns SUCCESS
  Orchestrator re-triggers /deploy staging
```

### 1.4 Context Isolation Rules

| Rule | Enforcement |
|------|------------|
| Each agent reads only its own division's context + what the Orchestrator explicitly passes | Orchestrator is the gatekeeper of what context crosses division lines |
| No agent carries state from a previous unrelated task | Each task starts from a clean preamble read |
| Division Leads summarize before escalating | They never forward raw specialist output to the Orchestrator — always a summary |
| The Orchestrator writes to `task.md` — agents read it, they don't write to it | Only the Orchestrator updates the task DAG |
| MCP tool call results are scoped — a Backend Architect's GitHub MCP call cannot be read by the Design Division | Tool call results are returned only to the invoking agent |

### 1.5 Audit Trail Requirement

Every Result Message is appended to `audit.jsonl` **by the receiving agent** before any further action is taken. This ensures the full chain of delegation is always reconstructible.

```jsonl
{"ts":"2026-05-24T16:45:00Z","from":"sdet","to":"quality-lead","task":"signup-email-validation","status":"SUCCESS","confidence":92,"artifacts":["tests/signup.test.ts"]}
{"ts":"2026-05-24T16:45:02Z","from":"quality-lead","to":"orchestrator","task":"signup-email-validation","status":"DELEGATING","next":"backend-architect"}
{"ts":"2026-05-24T16:45:05Z","from":"orchestrator","to":"engineering-lead","task":"signup-email-validation","status":"DELEGATING","context_passed":["failing-tests-summary"]}
```

---

## 2. Guardrail Architecture

Guardrails are organized in **three tiers**. Higher tiers cannot be overridden by lower tiers.

```
TIER 1: SYSTEM-LEVEL HARD STOPS
  (Cannot be overridden by ANY instruction, project rule, or agent)
       │
TIER 2: DIVISION-LEVEL CONSTRAINTS
  (Cannot be overridden by project rules — enforced by Division Lead)
       │
TIER 3: SKILL-LEVEL PRE-FLIGHT CHECKS
  (Enforced before every composite skill execution — project rules can refine these)
```

### 2.1 Tier 1 — System-Level Hard Stops

These are enforced by the **Orchestrator** and are absolute. No agent, no task, no project rule, no user instruction can bypass them.

| Hard Stop | Trigger | Action |
|-----------|---------|--------|
| **Production push without approval** | Any attempt to push to `main`, `master`, or `production` branch | BLOCKED immediately, human checkpoint required |
| **Secret/credential in output** | Any tool output or file write containing `API_KEY`, `SECRET`, `PASSWORD`, `TOKEN` pattern | Tool call cancelled, error logged, task FAILED |
| **Data deletion without confirmation** | DROP TABLE, DELETE FROM without WHERE, hard-delete endpoints | BLOCKED, human confirmation required |
| **Direct DB write to production** | Any SQL write to production DB URI | BLOCKED, must go through migration pipeline |
| **Skipping the /review gate** | Any attempt to ship code without running /review | /ship command refuses to proceed |
| **Orchestrator bypass** | Any cross-division direct communication | Message rejected, re-routed through Orchestrator |
| **File write outside workspace** | Any write to paths outside the project root | Tool call refused |
| **Unapproved external HTTP calls** | Any HTTP call to non-allowlisted domains | Requires explicit permission grant |

### 2.2 Tier 2 — Division-Level Constraints

Enforced by **Division Leads** — they verify these before accepting output from specialists and before forwarding to the Orchestrator.

**Engineering Division:**
- No code ships without type check and lint passing
- No N+1 queries (Backend Architect verifies query patterns)
- No `any` type in TypeScript interfaces
- No hardcoded environment values — all from config/env

**Platform Division:**
- No `terraform apply` without a prior approved `plan` output
- No deployment without a documented rollback plan
- All secrets sourced from environment only — never in pipeline YAML
- CVE scan must pass before any image is pushed

**Quality Division:**
- Test coverage must not decrease on any modified file
- No flaky tests silently retried — always filed as issues
- Visual regression baselines updated only deliberately, never auto

**Design Division:**
- No component implementation without a reviewed Figma frame or design brief
- All design output must pass the ui-ux-pro-max pre-delivery checklist
- No arbitrary font choices — must come from curated pairs
- Industry matching is mandatory before any design generation

**Intelligence Division:**
- No model routing switch without a shadow-test quality baseline
- No pattern saved to `learned.jsonl` without a minimum 2-session recurrence

**Research Council:**
- No verdict issued without all 3 rounds completing
- No assertion without a cited evidence source
- Minority opinions always preserved — never discarded

### 2.3 Tier 3 — Skill-Level Pre-Flight Checks

Every composite skill runs this pre-flight sequence before executing:

```
PRE-FLIGHT CHECKLIST (runs on every /command):
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. READ MANIFEST.md           → current system state + routing table
2. READ .agents/rules/global.md  → ironclad rules (confirms they're loaded)
3. READ .agents/PROJECT.md    → project-specific overrides (if exists)
4. READ learned.jsonl         → tag-filtered prior patterns for this task type
5. CHECK task.md              → verify task exists and is correctly scoped
6. VALIDATE permissions       → all planned tool calls are in approved tier
7. CHECK side-effect scope    → identify all files that will be modified
8. LOG activation             → write to audit.jsonl before doing anything
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Only after all 8 checks pass → proceed with skill execution
```

If any check fails, the skill enters **BLOCKED** state and returns a Result Message explaining which check failed and what is needed to resolve it.

---

## 3. Ironclad Rules — Universal (All Agents, All Tasks)

These 12 rules apply to **every agent, every division, every task, at all times**. They cannot be overridden by project rules, user instructions, or task context. They are the constitutional layer of the system.

```
╔══════════════════════════════════════════════════════════════════╗
║               THE 12 IRONCLAD RULES                              ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║  RULE 01 — NO SECRETS IN OUTPUT                                  ║
║  Never write credentials, API keys, tokens, passwords, or        ║
║  private URLs to any file, log, or message. If a task requires   ║
║  a secret, reference the env var name — never the value.         ║
║                                                                  ║
║  RULE 02 — AUDIT BEFORE ACTION                                   ║
║  Every tool call, file write, and external API call is logged    ║
║  to audit.jsonl BEFORE it executes. No silent actions.           ║
║                                                                  ║
║  RULE 03 — HUMAN IS ALWAYS IN CONTROL                            ║
║  No agent can make a change that prevents a human from           ║
║  reverting it. All production actions require explicit human      ║
║  approval. The system never locks out its owner.                 ║
║                                                                  ║
║  RULE 04 — NO HALLUCINATED RESULTS                               ║
║  If a tool call fails, the agent reports the failure — it        ║
║  never fabricates a "success" result. Fake results cascade       ║
║  into catastrophic downstream failures.                          ║
║                                                                  ║
║  RULE 05 — READ BEFORE WRITING                                   ║
║  An agent must read a file before modifying it. Never write      ║
║  a file based on assumptions about its current state.            ║
║                                                                  ║
║  RULE 06 — SCOPE BEFORE EXECUTING                                ║
║  Before any multi-step operation, the agent identifies all       ║
║  files and systems it will touch and logs them. No surprise       ║
║  side-effects.                                                   ║
║                                                                  ║
║  RULE 07 — FAIL LOUD, NEVER SILENT                               ║
║  Any error, unexpected result, or ambiguous situation is         ║
║  immediately reported up the chain. Agents do not paper over     ║
║  problems or hope they resolve themselves.                       ║
║                                                                  ║
║  RULE 08 — ROLLBACK IS ALWAYS PLANNED                            ║
║  Before any destructive or irreversible action, a rollback       ║
║  path is identified and documented in task.md. If no rollback    ║
║  path exists, the action does not proceed.                       ║
║                                                                  ║
║  RULE 09 — LEARNED PATTERNS FIRST                                ║
║  Every agent reads learned.jsonl at session start. Established   ║
║  patterns from prior sessions are not ignored.                   ║
║                                                                  ║
║  RULE 10 — NO CROSS-DIVISION DIRECT TALK                         ║
║  All cross-division communication routes through the             ║
║  Orchestrator. No shortcuts. Period.                             ║
║                                                                  ║
║  RULE 11 — CONFIDENCE IS HONEST                                  ║
║  Confidence scores in Result Messages are never inflated to      ║
║  appear more capable. A 40% confidence output is valid.          ║
║  The Orchestrator decides what to do with it.                    ║
║                                                                  ║
║  RULE 12 — PROJECT RULES NEVER OVERRIDE SECURITY                 ║
║  Project-specific rules can customize behavior. They can never   ║
║  disable security guardrails, audit logging, or approval gates.  ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## 4. Per-Project Rules — Placement and Layering

### 4.1 The Problem

The framework is project-agnostic. But every real project has its own:
- Tech stack (Next.js vs. Rails vs. Go, Postgres vs. MySQL, etc.)
- Naming conventions (camelCase vs. snake_case, file structure)
- Deployment targets (AWS vs. GCP vs. Vercel vs. self-hosted)
- Business rules (specific compliance requirements, team preferences)
- Design constraints (brand colors, existing design system tokens)

These cannot live in the framework layer — they pollute every project. But they also can't just be ad-hoc — agents need to reliably find and respect them.

### 4.2 The Five-Layer Override System

Rules are resolved in this precedence order. **Lower numbers = higher authority**.

```
LAYER 1: IRONCLAD RULES (.agents/rules/global.md)
  Authority: ABSOLUTE — cannot be overridden
  Content: The 12 rules above + system-level hard stops
  Who reads it: Every agent, on every pre-flight check
  ↑ CANNOT BE OVERRIDDEN BY ANYTHING BELOW

LAYER 2: FRAMEWORK DEFAULTS (agents_and_skills_design.md)
  Authority: HIGH — defines all roles, skills, and default behaviors
  Content: Division structure, agent personas, skill catalogs
  Who reads it: System-level reference; not loaded per-task
  ↑ Can only be overridden by project rules within permitted scopes

LAYER 3: DIVISION RULES (.agents/rules/divisions/<name>.md)
  Authority: MEDIUM-HIGH — project-specific for a division
  Content: Tech stack for that division, framework-specific rules
  Example (engineering.md): "This project uses Next.js 14 App Router.
    All components are in /src/app. Use server components by default."
  Who reads it: Division Lead + all specialists in that division

LAYER 4: PROJECT RULES (.agents/PROJECT.md)
  Authority: MEDIUM — cross-cutting project conventions
  Content: Stack overview, naming conventions, env vars, team preferences
  Who reads it: Orchestrator (always), all agents on first task of session
  Can override: Division defaults, agent defaults, skill defaults
  Cannot override: Ironclad rules, security guardrails

LAYER 5: TASK OVERRIDES (inline in task.md or slash command flags)
  Authority: LOW — one-time exception for a specific task
  Content: "For this task only, skip the visual regression baseline update"
  Who reads it: The assigned agent for that specific task only
  Expires: After the task completes — does not persist to next task
  Cannot override: Layers 1-2
```

### 4.3 Directory Structure

```
<project-root>/
└── .agents/
    ├── MANIFEST.md              # Skill routing table + system state
    ├── PROJECT.md               # Layer 4: project-wide rules (see contract below)
    │
    ├── rules/
    │   ├── global.md            # Layer 1: ironclad rules (ship once, never edit)
    │   └── divisions/
    │       ├── engineering.md   # Layer 3: tech stack, framework, conventions
    │       ├── platform.md      # Layer 3: cloud provider, CI/CD specifics
    │       ├── quality.md       # Layer 3: test framework, coverage thresholds
    │       ├── design.md        # Layer 3: brand colors, design system specifics
    │       └── intelligence.md  # Layer 3: model routing, cost targets
    │
    ├── personas/                # Agent role definitions
    ├── commands/                # Composite skill definitions
    ├── sessions/                # Session state and snapshots
    ├── skills/                  # External skills (ui-ux-pro-max, etc.)
    │
    ├── audit.jsonl              # Immutable append-only audit log
    ├── learned.jsonl            # Session-extracted patterns
    ├── cost.jsonl               # Token cost tracking per session
    └── task.md                  # Current session task DAG
```

### 4.4 The PROJECT.md Contract

`PROJECT.md` is the **single file every agent reads** to understand the specific project it is working in. It must follow this structure:

```markdown
# PROJECT: <Project Name>

## Stack
- Runtime: <Node.js 20 / Python 3.12 / Go 1.22 / etc.>
- Framework: <Next.js 14 App Router / FastAPI / Gin / etc.>
- Database: <PostgreSQL 16 / MongoDB / etc.>
- ORM: <Prisma / SQLAlchemy / GORM / etc.>
- Styling: <Tailwind CSS / CSS Modules / styled-components>
- Test Framework: <Vitest / pytest / Go test>
- CI/CD: <GitHub Actions / GitLab CI / CircleCI>
- Cloud: <AWS / GCP / Vercel / Railway>

## Conventions
- Language: TypeScript (strict mode) / Python (type hints required) / Go
- Naming: camelCase for variables / PascalCase for types / kebab-case for files
- File Structure: [describe the project's specific structure]
- Import Style: [absolute imports from src/ / relative imports]

## Environment
- Local: .env.local
- Staging: .env.staging (in 1Password vault "Engineering")
- Production: Managed in AWS Secrets Manager

## Deployment
- Staging: Auto-deploy on merge to 'develop' branch
- Production: Manual approval required, deploy from 'main' only
- Rollback: <specific rollback procedure for this project>

## Design System
- Tokens: /src/design-tokens/
- Component Library: shadcn/ui + custom components in /src/components/ui/
- Brand Colors: Primary #1A2B3C, Accent #FF6B35, etc.
- Font: Geist Sans / Geist Mono

## Hard Project Rules
# Rules that apply to this project beyond the framework defaults
- [e.g., "All API routes require authentication — no public endpoints"]
- [e.g., "Database models must have soft-delete (deleted_at) — no hard deletes"]
- [e.g., "All external API calls must go through /src/lib/api-client.ts"]

## Permitted Overrides
# Framework defaults that this project explicitly changes
- [e.g., "Bundle size limit is 200KB gzipped for this project (not 150KB default)"]
- [e.g., "Dark mode variants are NOT required — this is a light-only product"]

## Known Gotchas
# Documented project-specific pitfalls for agents to know before starting
- [e.g., "The auth module has a circular dependency issue — see DEBUG_REPORT.md"]
- [e.g., "Environment variables are snake_case in this project, not SCREAMING_SNAKE"]
```

### 4.5 How Agents Resolve Conflicting Rules

When an agent encounters a conflict between a project rule and a framework default:

```
CONFLICT RESOLUTION ALGORITHM:

1. Is the conflict with an Ironclad Rule (Layer 1)?
   → Layer 1 wins. Always. Agent proceeds under Layer 1.

2. Is the conflict with a security guardrail (Tier 1)?
   → Guardrail wins. Always. Agent BLOCKED.

3. Is the conflict between Layer 3 and Layer 4?
   → Layer 3 (division rule) wins over Layer 4 (project rule)
   → BUT: If Layer 4 has an explicit "Permitted Overrides" entry, it wins.

4. Is the conflict between Layer 4 and Layer 5?
   → Layer 5 wins for this task only.

5. Is the conflict genuinely ambiguous?
   → Agent does NOT guess. Returns BLOCKED with:
      "Conflict between project rule X and framework default Y.
       Orchestrator needs to clarify before proceeding."
```

---

## 5. Error Handling

### 5.1 The Four Error States

| State | Meaning | Agent Action | Escalation |
|-------|---------|-------------|-----------|
| **BLOCKED** | Has a dependency it cannot resolve alone | Stop, describe the blocker precisely, wait | Division Lead → Orchestrator → Human |
| **PARTIAL** | Completed some but not all of the task | Report what's done, what remains, whether rollback is needed | Division Lead decides: continue, retry, or rollback |
| **FAILED** | Unrecoverable error — cannot proceed | Attempt rollback, log full error, stop all related work | Orchestrator → Human if needed |
| **TIMEOUT** | Took too long (exceeds max turn budget) | Save current state, report progress checkpoint | Orchestrator decides: resume or restart |

### 5.2 Error Type Taxonomy

```
tool_failure          → A tool call (MCP, shell command, file op) returned an error
permission_denied     → Agent attempted an action it doesn't have permission for
invalid_state         → The system is in an unexpected state (file missing, branch wrong)
context_overflow      → Task context exceeded model window; cannot continue safely
external_api_error    → Third-party API (Sentry, GitHub, etc.) returned an error
logic_error           → Agent's own reasoning produced an internally inconsistent result
ambiguous_instruction → The task description has conflicting requirements
missing_dependency    → A required resource (file, env var, service) doesn't exist
```

### 5.3 Error Escalation Chain

```
SPECIALIST encounters error
  │
  ├─ Retry with different approach? (max 2 retries, same strategy = no)
  │    └─ If retry succeeds → return SUCCESS Result Message
  │
  ├─ Still failing after retries?
  │    └─ Return BLOCKED/FAILED Result Message to Division Lead
  │
  ▼
DIVISION LEAD receives error
  │
  ├─ Can it be resolved within the division? (e.g., re-delegate to different specialist)
  │    └─ If yes → re-delegate and monitor
  │
  ├─ Needs cross-division resource?
  │    └─ Escalate to Orchestrator with Result Message
  │
  ├─ Permanent blocker within division?
  │    └─ Escalate to Orchestrator with BLOCKED Result Message
  │
  ▼
ORCHESTRATOR receives escalation
  │
  ├─ Cross-division routing: can another division unblock this?
  │    └─ Route to appropriate Division Lead with context
  │
  ├─ Needs human input to resolve?
  │    └─ Surface to human with: exact blocker, options, recommendation
  │
  ├─ Catastrophic failure (data loss risk, security issue)?
  │    └─ STOP ALL ACTIVE TASKS → Human Intervention Checkpoint
  │
  ▼
HUMAN INTERVENTION CHECKPOINT
  │
  └─ Human reviews audit.jsonl + error context
     Makes a decision:
       → Fix and retry
       → Rollback to last clean state
       → Modify the task scope
       → Abandon the task
```

### 5.4 Retry Protocol

Agents do not retry blindly. Each retry must use a **different approach**.

```
RETRY RULES:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Attempt 1: Original approach
  → If fails: diagnose, form hypothesis, plan different approach

Attempt 2: Different approach (documented in audit.jsonl)
  → If fails: escalate — do NOT attempt a third retry with same strategy

WHAT COUNTS AS A "DIFFERENT APPROACH":
  ✅ Using a different tool to achieve the same goal
  ✅ Breaking the task into smaller sub-tasks
  ✅ Requesting additional context before retrying
  ✅ Trying a simpler variant of the task first

WHAT IS NOT A "DIFFERENT APPROACH":
  ❌ Retrying the exact same operation
  ❌ Retrying with only cosmetic changes to parameters
  ❌ Ignoring the error and hoping it resolves

ESCALATION TRIGGER:
  Any error that repeats after 2 different approaches
  → ALWAYS escalates (never a 3rd attempt without human context)
```

### 5.5 Rollback Procedure

```
ROLLBACK PROTOCOL:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

PRE-ACTION (before any multi-file operation):
  1. Agent logs all files it will modify to audit.jsonl
  2. Agent records current git HEAD SHA to audit.jsonl
  3. Agent creates a checkpoint entry in task.md

ON FAILURE:
  1. Agent checks: were any files modified before the failure?
  2. If YES:
     a. List modified files in the FAILED Result Message
     b. Check if git is available → git stash or git checkout <sha>
     c. Report: "Rolled back to <SHA> successfully" OR
                "Rollback failed — manual cleanup required for: <files>"
  3. If NO files modified → FAILED state with no rollback needed

ROLLBACK SCOPE RULES:
  ✅ Any file write during the current task → rollback on FAILED
  ✅ Any git commit made during the current task → revert on FAILED
  ❌ Database migrations → NOT automatically rolled back
       (too dangerous — always surfaces to human for manual decision)
  ❌ External API calls (webhooks, notifications) → NOT rollbackable
       (document what was sent in the error report)
  ❌ Deployed artifacts → NOT automatically rolled back
       (/incident command with rollback plan required)
```

### 5.6 Human Intervention Checkpoint Format

When the system cannot resolve an error without human input, it surfaces a checkpoint in this format:

```
╔══════════════════════════════════════════════════════════════════╗
║           ⚠️ HUMAN INTERVENTION REQUIRED                         ║
╠══════════════════════════════════════════════════════════════════╣
║ Task:         <task description>                                 ║
║ Failed Agent: <role/division>                                    ║
║ Error Type:   <taxonomy type>                                    ║
║ Session:      <session-id>                                       ║
╠══════════════════════════════════════════════════════════════════╣
║ WHAT HAPPENED:                                                   ║
║ <Concise, factual description of what went wrong>                ║
╠══════════════════════════════════════════════════════════════════╣
║ CURRENT STATE:                                                   ║
║ ✅ Completed: [<what was done before failure>]                    ║
║ ❌ Not done: [<what failed>]                                      ║
║ 🔄 Rolled back: [<what was undone>] / Nothing to roll back        ║
╠══════════════════════════════════════════════════════════════════╣
║ YOUR OPTIONS:                                                    ║
║                                                                  ║
║ OPTION A: <specific action — e.g., "Provide the missing env var  ║
║            STRIPE_SECRET_KEY and re-run the task">               ║
║                                                                  ║
║ OPTION B: <alternative — e.g., "Narrow the task scope to exclude ║
║            the payment integration for now">                     ║
║                                                                  ║
║ OPTION C: Abandon this task entirely                             ║
╠══════════════════════════════════════════════════════════════════╣
║ RECOMMENDATION: Option A                                         ║
║ AUDIT LOG: .agents/audit.jsonl (session: <id>)                   ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## 6. Summary — The Complete Operational Contract

```
COMMUNICATION:
  ✅ All cross-division messages route through Orchestrator
  ✅ All messages use the structured Result Message schema
  ✅ Context is isolated per-division — Orchestrator summarizes before forwarding
  ✅ Every message is logged to audit.jsonl

GUARDRAILS (3 Tiers):
  Tier 1: System-level hard stops (production push, secrets, DB delete) — ABSOLUTE
  Tier 2: Division-level constraints (code quality, deploy safety, design rules)
  Tier 3: Skill-level pre-flight checks (8-step preamble before every command)

IRONCLAD RULES (12):
  Applied to every agent, every task, every time.
  Cannot be overridden by project rules, user instructions, or task context.

PROJECT RULES (5 Layers):
  Layer 1: global.md — ironclad, never changes
  Layer 2: Framework defaults — overridable in permitted scope
  Layer 3: Division rules — tech stack per division
  Layer 4: PROJECT.md — cross-cutting project conventions
  Layer 5: Task overrides — one-time, expires after task

ERROR HANDLING:
  4 states: BLOCKED → PARTIAL → FAILED → TIMEOUT
  Escalation chain: Specialist → Lead → Orchestrator → Human
  Retry: Max 2 attempts, different approach required
  Rollback: Pre-planned, logged, automated for files/git
  Human checkpoint: Structured options always presented, never vague
```
