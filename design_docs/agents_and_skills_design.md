# Agent & Skills Layer — Deep Design Document

> The detailed design for every division, every role, every skill, and how they all wire together.

---

## Design Philosophy for This Layer

**From `agency-agents`:** Roles organized into **divisions**, each with a clear business domain. Agents inside a division share a professional context and can coordinate within that boundary.

**From `gstack`:** Agents wield **skills** — not just instructions, but executable workflows with a defined preamble, inputs, guardrails, and artifact outputs. Skills chain together into powerful composite operations.

**From user design:** A **Research Council** — an adversarial debate engine where an Advocate argues for, a Skeptic argues against, a Devil's Advocate challenges both sides, and a Domain Expert provides hard constraints. A Moderator drives the structured 3-round debate to a consensus verdict with a confidence score. Council verdicts feed into execution divisions before work begins.

**Tool-Agnostic by Design:** The entire system is built on plain markdown files with defined schemas. This means the core system is compatible with — and can drive — any AI coding tool: Antigravity, Claude Code, Cursor, OpenCode, and OpenAI Codex. Each tool reads agent instructions from a different location; our **Compatibility Adapter Layer** (Section 12) auto-generates the right shim file for each tool from the canonical `.agents/` source.

**The synthesis:** A **division-based hierarchy** where every agent has a **skill catalog** it can invoke, and a dedicated Council handles all high-stakes research decisions before execution begins. Divisions are the org chart. Skills are the actual work. The Council is the truth engine.

---

## 1. The Division Hierarchy

The system has **6 divisions** organized under a single Orchestrator:

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                             ORCHESTRATOR                                      ║
║                       (Chief of Staff / Tech Lead)                            ║
║             Plans · Routes · Delegates · Reviews · Approves                   ║
╠══════════╦══════════════╦═══════════╦══════════════╦════════════╦═════════════╣
║  DIV 1   ║    DIV 2     ║   DIV 3   ║    DIV 4     ║   DIV 5    ║   DIV 6     ║
║          ║              ║           ║              ║            ║             ║
║ ENGINEER-║  PLATFORM /  ║  QUALITY  ║   DESIGN     ║ INTELLIGEN-║  RESEARCH   ║
║ ING      ║  INFRASTRUC- ║           ║              ║ CE         ║  COUNCIL    ║
║          ║  TURE        ║           ║              ║            ║             ║
╠══════════╬══════════════╬═══════════╬══════════════╬════════════╬═════════════╣
║ • Lead   ║ • Lead       ║ • Lead    ║ • Lead       ║ • Lead     ║ • Moderator ║
║ • Senior ║ • DevOps     ║ • SDET    ║ • UI Designer║ • Analyst  ║ • Advocate  ║
║   Eng    ║ • Cloud      ║ • Perf    ║ • UX         ║ • Optimizer║ • Skeptic   ║
║ • Front- ║   Arch       ║   Tester  ║   Researcher ║            ║ • Devil's   ║
║   end    ║ • Security   ║ • Visual  ║ • Design Sys ║            ║   Advocate  ║
║ • Back-  ║   Eng        ║   QA      ║   Eng        ║            ║ • Domain    ║
║   end    ║ • Incident   ║           ║ • Animator   ║            ║   Expert    ║
║ • Data-  ║   Cmdr       ║           ║              ║            ║             ║
║   base   ║ • Database   ║           ║              ║            ║             ║
║          ║   Optimizer  ║           ║              ║            ║             ║
╚══════════╩══════════════╩═══════════╩══════════════╩════════════╩═════════════╝
```

**Key structural rules:**
1. The **Orchestrator** sits above all divisions. It is the only agent that can spawn tasks across division boundaries.
2. Each division has a **Division Lead** — the first point of contact when the Orchestrator delegates to that division. The Lead coordinates internally before reporting back.
3. **Specialists within a division** can be called directly by the Lead without going back to the Orchestrator.
4. **Cross-division work** always routes through the Orchestrator — no specialist talks directly to a specialist in another division.
5. **The Research Council (Div 6) is pre-execution** — its verdicts feed INTO other divisions, never the reverse. It produces decisions; other divisions act on them.
6. **The Council is summoned, not delegated to** — the Orchestrator calls `/council` only when a question requires adversarial scrutiny. The Council's output is always a verdict, never code or config.

---

## 2. The Orchestrator

```yaml
---
role: Orchestrator
division: Executive
aliases: [Tech Lead, Chief of Staff, Engineering Manager]
activatedBy:
  - session_start
  - any slash command (routes to correct division lead)
  - /plan
  - /review
  - /autoplan
mcpAccess: [github]
canDelegateTo: [all division leads]
autonomyLevel: "Plans and routes only — never writes implementation code"
---
```

### Responsibilities
- Owns `task.md` — the single source of truth for all work in a session
- Builds the task DAG and sequences work across divisions
- Routes delegation to the correct Division Lead
- Receives Result Messages from Division Leads and decides next action
- Runs the `/review` quality gate (scores + approve/reject)
- Writes to `learned.jsonl` when a session produces a reusable pattern

### Orchestrator Hard Rules
- ❌ Never write implementation code, CSS, SQL, IaC, or tests directly
- ❌ Never activate a Specialist without going through the Division Lead
- ✅ Always read `learned.jsonl` before starting any planning
- ✅ Always output a structured `task.md` before any code changes begin
- ✅ Always surface cost summary at session end

### Orchestrator Skills
| Skill | What it does |
|-------|--------------|
| `/autoplan` | Chains all review sub-skills in sequence then waits for approval |
| `/plan` | Decomposes a goal into a task DAG — each task tagged with `brief_required` flag and `risk_level` estimate |
| `/brief` | Routes to the assigned specialist to produce an Implementation Brief before any execution begins |
| `/status` | Instant view: which agent is active, what's queued, what's done, session token cost so far |
| `/dashboard` | Full session view at any point — task DAG status, agent outputs, files changed, reports, cost |
| `/review` | Scores staged changes on 6 axes (min 8.0/10 to pass) |
| `/office-hours` | Product reframing: challenges assumptions before any work begins |
| `/retro` | Reads session audit logs and produces a velocity/health summary |
| `/learn` | Extracts patterns from the session and appends to `learned.jsonl` |
| `/sync-adapters` | Regenerates all tool-compatibility shim files (`CLAUDE.md`, `AGENTS.md`, `.cursor/rules/agents.mdc`) from the canonical `.agents/` source. Run after any change to `MANIFEST.md`, `PROJECT.md`, or `rules/global.md`. |

---

## 3. Observability & Output System

> **How you see what agents produced.** Every agent writes to files and generates structured reports. Three visibility levels cover everything from real-time status to post-session analysis.

---

### 3.1 Three Visibility Levels

#### Level 1 — Live (while agents are running)

**`task.md`** updates in real-time as the Orchestrator receives Result Messages:

```markdown
## Session: 2026-05-24 | Goal: Add auth service

- [x] task_001 → SDET: Write failing tests          ✅ Done (92% conf)
- [/] task_002 → Backend Architect: Implement auth   🔄 In progress  
- [ ] task_003 → Security Engineer: Audit            ⏳ Waiting
- [ ] task_004 → QA Automation: Validate DB state    ⏳ Waiting
- [ ] task_005 → Orchestrator: /review              ⏳ Waiting
```

**`/status`** — instant snapshot, available at any point:
```
Active:    Backend Architect — task_002 (6 min elapsed, 88% confidence)
Queued:    Security Engineer, QA Automation Engineer  
Completed: SDET ✅
Failed:    —
Cost:      12,400 tokens (~$0.04) so far
```

Every completed agent also surfaces its Result Message inline — you see the summary, confidence, and files touched without opening anything.

#### Level 2 — Per-Agent Output (after each agent completes)

Each agent's primary output is always a **file artifact** — never just a chat message:

| Agent | Primary Output | Location |
|-------|---------------|----------|
| Frontend Developer | Component code | `src/components/` |
| Backend Architect | Service / route code | `src/services/`, `src/routes/` |
| Database Engineer | Migration + schema | `prisma/migrations/`, `schema.prisma` |
| SDET | Test files | `tests/`, `__tests__/` |
| QA Automation Engineer | E2E results + DB assertion report | `.agents/reports/e2e-<ts>.md` |
| Security Engineer | Security audit report | `.agents/reports/security-<ts>.md` |
| Performance Tester | Benchmark report | `.agents/reports/benchmark-<ts>.md` |
| Visual QA Specialist | Screenshot diff report | `.agents/reports/visual-<ts>.md` |
| Design Lead | Design brief | `.agents/reports/design-brief-<ts>.md` |
| UI Designer | Design system spec | `.agents/reports/design-system-<ts>.md` |
| Session Analyst | Session dashboard | `.agents/sessions/<id>/dashboard.md` |
| Research Council | Verdict | `.agents/council/verdicts/<ts>.md` |
| Incident Commander | Postmortem | `.agents/reports/postmortem-<ts>.md` |

**Reports directory layout:**
```
.agents/
├── reports/
│   ├── security-20260524T220000.md
│   ├── e2e-20260524T220500.md
│   ├── benchmark-20260524T221000.md
│   ├── visual-20260524T221500.md
│   └── postmortem-20260524T230000.md
├── council/
│   └── verdicts/
│       └── 20260524T180000-auth-strategy.md
└── sessions/
    └── <session-id>/
        ├── summary.md
        ├── dashboard.md   ← generated by /dashboard
        ├── task.md
        └── audit.jsonl
```

#### Level 3 — Post-Session (full session analysis)

**`/retro`** — generates by the Session Analyst, written to `sessions/<id>/summary.md`:
```markdown
# Session Retro — 2026-05-24T22:00

## Task Summary
  Completed: 4/5 (80%) | Failed: 1 (QA Automation — DB timeout) | Skipped: 0

## Per-Agent Results
  Backend Architect   → ✅ 88% conf | 2 files created | 0 drift
  SDET                → ✅ 94% conf | 3 test files   | 0 drift
  Security Engineer   → ✅ 76% conf | 0 code files   | report: security-20260524.md
  QA Automation       → ❌ FAILED   | DB MCP timeout | see audit log

## Files Changed This Session
  [CREATED] src/services/auth.service.ts
  [MODIFIED] src/routes/api/login.ts
  [MODIFIED] prisma/schema.prisma
  [CREATED] prisma/migrations/20260524_add_sessions.sql
  [CREATED] tests/auth.service.test.ts

## Reports Generated
  .agents/reports/security-20260524T220000.md
  .agents/reports/e2e-FAILED-20260524T221000.md

## Token Cost
  Total: 47,200 tokens (~$0.14)
  Most expensive agent: Backend Architect (18,400 tokens)
  Tool cache hit rate: 34% (saves ~6,100 tokens)

## Patterns Proposed for learned.jsonl
  1. Auth migration needs staging DB snapshot before apply
  2. QA Automation DB MCP: use connection pool retry on timeout
```

**`/dashboard`** — full live or post-session view, written to `sessions/<id>/dashboard.md`. Contains everything `/retro` has, plus the full task DAG with implementation briefs, the complete file change manifest, and links to every report generated.

---

### 3.2 The `/status` vs `/dashboard` vs `/retro` Distinction

| Command | When | Output | Cost |
|---------|------|--------|------|
| `/status` | Anytime, instant | 5-line text snapshot of current state | ~100 tokens |
| `/dashboard` | Anytime during or after session | Full markdown report: tasks + agents + files + cost | ~800 tokens |
| `/retro` | Post-session | Deep analysis: patterns, learnings, improvement proposals | ~2,000 tokens |

**Rule:** `/status` is for "what's happening now". `/dashboard` is for "show me everything". `/retro` is for "what did we learn".

---

### 3.3 Drift Detection in Outputs

When a completed agent's files-touched list doesn't match its Implementation Brief's files-planned list, the audit log marks `drift: true`. The Division Lead's output review automatically flags this:

```
⚠️  DRIFT DETECTED — Backend Architect (task_002)
  Planned:  src/services/auth.service.ts, prisma/schema.prisma
  Actual:   src/services/auth.service.ts, prisma/schema.prisma,
            src/middleware/authenticate.ts  ← NOT IN BRIEF
  Action:   Division Lead review required before Orchestrator can proceed
```

Drift is not automatically a failure — the agent may have had a valid reason. But it always requires an explanation in the Result Message.

---

## 4. Implementation Brief System

> **What it is:** Before a specialist touches a single file, it produces an Implementation Brief — a structured pre-execution plan that makes the agent's intent fully visible and auditable before any side-effects occur.

This is the answer to: *"does the agent generate a detailed plan including file names, functions changed, and why?"* — **Yes, always for non-trivial work. The Brief is that plan.**

---

### 3.1 Brief Schema

Every Brief follows this exact format. It is written to `audit.jsonl` before execution begins.

```
╔══════════════════════════════════════════════════════════════════════════╗
║                       IMPLEMENTATION BRIEF                               ║
╠══════════════════════════════════════════════════════════════════════════╣
║ task_id:    <ref from task.md>                                           ║
║ agent:      <role / division>                                            ║
║ risk_level: LOW | MEDIUM | HIGH | CRITICAL                               ║
║ confidence: <0–100%>                                                     ║
║ approval:   AUTO_PROCEED | DIVISION_LEAD | ORCHESTRATOR | HUMAN          ║
╠══════════════════════════════════════════════════════════════════════════╣
║ FILES TO TOUCH:                                                          ║
║                                                                          ║
║   [CREATE] src/services/auth.service.ts                                  ║
║     functions:                                                           ║
║       + createSession(userId, deviceId) → SessionToken                   ║
║       + validateToken(token) → User | null                               ║
║       + revokeSession(sessionId) → void                                  ║
║     why: New file — auth logic isolated from user service (SRP)          ║
║                                                                          ║
║   [MODIFY] src/routes/api/login.ts  (lines ~40–80)                       ║
║     functions:                                                           ║
║       ~ loginHandler() — replace inline JWT logic with AuthService call  ║
║     why: Route handler was doing auth directly — violation of SRP        ║
║                                                                          ║
║   [MODIFY] prisma/schema.prisma                                          ║
║     changes:                                                             ║
║       + Session model: id, userId, token, expiresAt, deviceId            ║
║     why: Persistent sessions required for revocation support             ║
║                                                                          ║
║   [CREATE] prisma/migrations/20260524_add_sessions.sql                   ║
║     why: Schema change always requires a versioned migration             ║
║                                                                          ║
║ FILES EXPLICITLY NOT TOUCHED:                                            ║
║   src/services/user.service.ts — no changes needed                       ║
║   src/middleware/rate-limit.ts — out of scope for this task              ║
║                                                                          ║
╠══════════════════════════════════════════════════════════════════════════╣
║ SIDE EFFECTS:                                                            ║
║   - Migration must run before deploy or login breaks in production       ║
║   - Existing JWT tokens will be invalid after cutover (breaking change)  ║
║   - Session table will be empty on first deploy — expected               ║
║                                                                          ║
║ RISKS:                                                                   ║
║   HIGH  — Migration is irreversible without a down migration             ║
║   MED   — Token format change affects all active sessions                ║
║                                                                          ║
║ ROLLBACK PLAN:                                                           ║
║   git revert this branch + run prisma migrate down (if supported)        ║
║   Fallback: restore from pre-migration DB snapshot                       ║
║                                                                          ║
║ OPEN QUESTIONS: (agent must resolve before proceeding — never guess)     ║
║   Q1: Hard 30-day session expiry or configurable per environment?        ║
╚══════════════════════════════════════════════════════════════════════════╝
```

**Legend:** `+` = added, `~` = modified, `-` = deleted, `[CREATE]` = new file, `[MODIFY]` = existing file changed, `[DELETE]` = file removed

---

### 3.2 Risk Scoring — How the Risk Level Is Determined

Risk level is computed from four dimensions. The **highest single dimension** sets the overall level.

#### Dimension 1 — Surface Area (files touched)
| Files Touched | Score |
|--------------|-------|
| 1 file | LOW |
| 2–4 files | MEDIUM |
| 5–9 files | HIGH |
| 10+ files | CRITICAL |

#### Dimension 2 — File Criticality
| File Category | Score |
|--------------|-------|
| Docs, comments, config formatting | LOW |
| Tests, scripts, non-production code | LOW |
| UI components, styles, static assets | MEDIUM |
| Business logic, services, API routes | HIGH |
| Auth, payments, sessions, permissions | CRITICAL |
| Database migrations, schema changes | CRITICAL |
| Infrastructure / IaC (Terraform, K8s manifests) | CRITICAL |

#### Dimension 3 — Operation Type
| Operation | Score |
|-----------|-------|
| CREATE (new file, additive only) | LOW–MEDIUM |
| MODIFY (changing existing behaviour) | MEDIUM–HIGH |
| DELETE (removing file or function) | HIGH |
| RENAME / MOVE (breaks imports) | MEDIUM |
| REFACTOR (same behaviour, new structure) | MEDIUM |

#### Dimension 4 — Reversibility
| Reversibility | Score |
|--------------|-------|
| Fully reversible with `git revert` | LOW |
| Reversible but requires manual steps | MEDIUM |
| Hard to reverse (migration, external API call, S3 upload) | HIGH |
| Irreversible (data deletion, prod infra teardown) | CRITICAL |

**Composite rule:** Take the maximum score across all four dimensions. That is the Brief's `risk_level`.

---

### 3.3 Trigger Table — When Is a Brief Required?

| Scenario | Brief Required? | Approval Level |
|----------|----------------|---------------|
| New service, module, or API endpoint | ✅ Full Brief | DIVISION_LEAD |
| New database model or schema change | ✅ Full Brief | ORCHESTRATOR |
| Modifying auth, payments, or sessions | ✅ Full Brief | HUMAN |
| Modifying existing business logic (>1 file) | ✅ Full Brief | DIVISION_LEAD |
| Infrastructure / IaC change | ✅ Full Brief | HUMAN |
| Production deployment | ✅ Full Brief | HUMAN |
| Refactor touching 5+ files | ✅ Full Brief | ORCHESTRATOR |
| Bug fix touching 2–4 files | ✅ Brief (summary form) | DIVISION_LEAD |
| Dependency version bump (CVE fix) | 🟡 One-liner only | AUTO_PROCEED |
| Bug fix, single file, isolated | ⚡ No Brief | AUTO_PROCEED |
| Tests only (no production code touched) | ⚡ No Brief | AUTO_PROCEED |
| Docs / comments only | ⚡ No Brief | AUTO_PROCEED |
| Config formatting, whitespace | ⚡ No Brief | AUTO_PROCEED |
| Adding a log statement | ⚡ No Brief | AUTO_PROCEED |

**Summary form** = Brief with only `FILES TO TOUCH` and `ROLLBACK PLAN` — no function-level detail required.

**One-liner** = A single sentence: `"Bumping lodash from 4.17.20 to 4.17.21 to resolve CVE-2021-23337."`

---

### 3.4 Approval Routing

```
Risk Level   → Approval Required From
──────────── → ─────────────────────────────────────────────
LOW          → AUTO_PROCEED (no review, agent executes immediately)
MEDIUM       → DIVISION_LEAD (Lead reviews Brief, approves or requests changes)
HIGH         → ORCHESTRATOR (Lead escalates to Orchestrator, Orchestrator reviews)
CRITICAL     → HUMAN (Orchestrator surfaces checkpoint — human must explicitly approve)
```

**Division Lead approval** = Lead reads the Brief, checks for scope creep, architectural violations, and rollback plan validity. Approves or sends back with specific change requests.

**Orchestrator approval** = Orchestrator reads the Lead's summary + the Brief. Validates it fits the task.md scope. Checks for cross-division impact. Approves or reroutes.

**Human checkpoint** = The full Brief is surfaced with explicit options (Proceed / Modify / Reject). Execution does not resume until the human responds.

---

### 3.5 Brief Is Always Logged First

The Brief is written to `audit.jsonl` **before** the first tool call executes. This means:

- If the agent fails mid-execution, the audit log shows exactly what it *intended* to do vs. what it *actually* completed — enabling precise rollback
- If the agent's execution drifts from the Brief (touches a file not listed), that is flagged as an anomaly by the Division Lead on result review
- The Brief doubles as the change documentation — no separate "what did I change and why" writeup needed

```jsonl
{"ts":"...","type":"brief","task_id":"task_001","agent":"backend-architect","risk":"HIGH","approval":"ORCHESTRATOR","files_planned":["src/services/auth.service.ts","prisma/schema.prisma"],"status":"AWAITING_APPROVAL"}
{"ts":"...","type":"brief_approved","task_id":"task_001","approved_by":"orchestrator","status":"EXECUTING"}
{"ts":"...","type":"file_write","task_id":"task_001","file":"src/services/auth.service.ts","op":"CREATE","status":"SUCCESS"}
{"ts":"...","type":"file_write","task_id":"task_001","file":"prisma/schema.prisma","op":"MODIFY","status":"SUCCESS"}
{"ts":"...","type":"brief_completed","task_id":"task_001","files_actual":["src/services/auth.service.ts","prisma/schema.prisma"],"drift":false}
```

`drift: true` means the agent touched files not listed in the Brief — this triggers a mandatory Division Lead review of the completed output even if the task succeeded.

---

### 3.6 Orchestrator Skill Addition

The `/plan` command now explicitly includes a Brief-generation step:

| Skill | What it does |
|-------|-------------|
| `/plan` | Decomposes a goal into a task DAG → each task entry includes a `brief_required` flag and `risk_level` estimate |
| `/brief` | Specialist command — generates an Implementation Brief for a specific task before executing it |

---

## 4. Division 1 — Engineering

**Domain:** Writing, reviewing, and maintaining all implementation code.

### 3.1 Engineering Lead

```yaml
---
role: Engineering Lead
division: Engineering
aliases: [Senior Engineer, Tech Architect]
activatedBy: [delegation from Orchestrator]
mcpAccess: [github]
canDelegateTo: [frontend, backend, database]
---
```

**Responsibilities:** Receive scoped tasks from Orchestrator. Understand the full engineering context. Decide whether to handle directly or delegate to a specialist. Own the engineering quality bar for the session.

**Hard Rules:**
- Reviews all code produced by specialists before reporting back to Orchestrator
- Catches architecture violations (N+1 queries, missing validation, broken abstractions) before they reach `/review`
- Never merges code with failing type checks or lint errors

### 3.2 Frontend Developer

```yaml
---
role: Frontend Developer
division: Engineering
activatedBy: [delegated by Engineering Lead, /design command output]
mcpAccess: [github, figma]
specializes: [UI implementation, component architecture, accessibility, performance]
---
```

**Responsibilities:** Translate designs and specs into working UI code. Own Core Web Vitals. Enforce accessibility.

**Hard Rules:**
- Mobile-first by default — no desktop-only layouts
- All interactive elements: keyboard navigable + ARIA labels
- No hardcoded visual values — all from design tokens
- Bundle size budget enforced: no single lazy chunk over 150KB gzipped
- No `any` types in component prop interfaces

**Skill Catalog:**
| Skill | Type | Description |
|-------|------|-------------|
| `/design-html` | Composite | Generates semantic, production-ready markup from a spec |
| `/design-review` | Composite | Screenshots live app, compares to Figma, fixes CSS mismatches |
| `/design-shotgun` | Composite | Generates 3 alternative UI approaches for comparison |
| `/design-consultation` | Composite | Builds a full design token system (colors, spacing, type, radius) |
| `ui-styling` (context) | Intelligence | Injected before any markup generation — enforces the 67 visual style rules |

### 3.3 Backend Architect

```yaml
---
role: Backend Architect
division: Engineering
activatedBy: [delegated by Engineering Lead]
mcpAccess: [github, docker, sentry]
specializes: [API design, service boundaries, caching, data contracts]
---
```

**Responsibilities:** Design and implement service APIs. Define data contracts. Design caching and retry strategies. Own the API spec.

**Hard Rules:**
- All writes must be idempotent — idempotency keys on all external calls
- Input validation at the API boundary — never trust raw request body
- No N+1 queries — explicit relationship loading only
- All new endpoints must have a corresponding OpenAPI spec entry
- Error responses must follow RFC 7807 (Problem Details for HTTP APIs)

**Skill Catalog:**
| Skill | Description |
|-------|-------------|
| `/investigate` | Root-cause debugging — iron law: no fix before hypothesis verified |
| `/codex` | Second-opinion architecture review using an independent model |
| `/benchmark` | Runs perf benchmarks and compares against previous baseline |

### 3.4 Database Engineer

```yaml
---
role: Database Engineer
division: Engineering
activatedBy: [delegated by Engineering Lead or Backend Architect, slow query alert from Sentry]
mcpAccess: [sentry, github]
specializes: [schema design, migrations, indexing, query optimization]
---
```

**Responsibilities:** Own database schemas. Write migrations. Design index strategies. Optimize slow queries.

**Hard Rules:**
- Every new index requires a query plan analysis before being applied
- Migrations follow **expand-contract pattern** — backward compatible for exactly one deploy cycle
- Never drop a column and migrate data in the same changeset
- No raw string-interpolated queries — parameterized only, always
- Foreign keys must always have corresponding indexes

**Skill Catalog:**
| Skill | Description |
|-------|-------------|
| `/investigate` | Traces a slow query to its root cause using Sentry performance data |
| `/benchmark` | Compares query latency before/after an index or schema change |

---

## 4. Division 2 — Platform / Infrastructure

**Domain:** Everything that makes code run in production — CI/CD, containers, cloud, security posture, reliability.

### 4.1 Platform Lead

```yaml
---
role: Platform Lead
division: Platform / Infrastructure
aliases: [SRE Lead, DevOps Lead]
activatedBy: [delegation from Orchestrator, /deploy command]
mcpAccess: [github, terraform, docker, kubernetes, sentry]
canDelegateTo: [devops, cloud-architect, security-engineer, incident-commander, database-optimizer]
---
```

**Responsibilities:** Own the production environment. Coordinate infrastructure changes. Ensure all deployments are safe, observable, and reversible.

**Hard Rules:**
- All infra changes run a dry-run plan first — never blind apply
- No deployment without a rollback plan defined in `task.md`

### 4.2 DevOps Engineer

```yaml
---
role: DevOps Engineer
division: Platform / Infrastructure
activatedBy: [delegated by Platform Lead]
mcpAccess: [github, docker, kubernetes, terraform]
specializes: [CI/CD pipelines, container builds, deployment automation, pipeline authoring]
---
```

**Responsibilities:** Build and maintain CI/CD pipelines. Containerize services. Automate deployments. Author pipeline YAML from scratch for new services. Audit existing pipelines for security, correctness, and efficiency.

**Hard Rules:**
- All GitHub Action/pipeline step versions pinned to exact SHA — no floating tags
- Secrets sourced from environment only — never in pipeline YAML, Dockerfile layers, or logs
- All deployments use rolling or blue-green strategy — never replace-all
- Build images must pass a CVE scan before being pushed to any registry
- Generated pipelines must always include: lint, test, build, scan, and deploy stages — never a single-stage pipeline
- Pipeline audit findings must be filed as GitHub issues, not left as inline suggestions

**Skill Catalog:**
| Skill | Description |
|-------|-------------|
| `/ship` | Runs tests → `/review` → version bump → commit → push → opens PR |
| `/land-and-deploy` | Merges PR → monitors CI → performs HTTP health checks on live URL |
| `/canary` | Runs repeated health checks on critical production paths post-deploy |
| `/document-release` | Generates changelog from git log between current and previous tags |
| `/pipeline-generate` | Generates a full CI/CD pipeline YAML for a new service. Reads the project stack from `PROJECT.md`, identifies required stages (lint → test → build → scan → deploy), selects appropriate runners/actions, pins all step versions to exact SHAs, and writes the pipeline file to `.github/workflows/` or equivalent. Outputs a `pipeline-manifest.md` explaining each stage and its purpose. |
| `/pipeline-audit` | Audits an existing CI/CD pipeline file. Checks: unpinned step versions, secrets in YAML, missing stages (e.g. no security scan, no health check), inefficient job ordering (e.g. expensive build before cheap lint), overly broad permissions, and missing timeout/cancellation policies. Produces a scored audit report at `.agents/reports/pipeline-audit-<ts>.md` with severity-ranked findings and suggested fixes. |

### 4.3 Cloud Architect

```yaml
---
role: Cloud Architect
division: Platform / Infrastructure
activatedBy: [delegated by Platform Lead]
mcpAccess: [terraform, github]
specializes: [IaC design, cloud resource provisioning, cost optimization, network topology]
---
```

**Responsibilities:** Design and provision cloud infrastructure using IaC. Optimize resource costs. Design network topology and access controls.

**Hard Rules:**
- All Terraform modules must declare `required_providers` with version constraints
- Cloud resources must be tagged (environment, owner, service)
- `terraform apply` always requires a prior approved `plan` output — never apply without plan
- Least-privilege IAM: start with no permissions, add only what is required

**Skill Catalog:**
| Skill | Description |
|-------|-------------|
| `/deploy` | Full pipeline: plan → approve → apply → health-check |
| `/health` | Runs linters, validators (`terraform validate`), and state checks |

### 4.4 Security Engineer

```yaml
---
role: Security Engineer
division: Platform / Infrastructure
activatedBy: [all /review runs (parallel), any auth/permission code change]
mcpAccess: [github, docker]
specializes: [threat modeling, OWASP audits, static analysis, CVE scanning, access control]
---
```

**Responsibilities:** Audit all code changes for security issues. Run vulnerability scans on images. Own threat modeling for new features.

**Hard Rules:**
- Runs in parallel with every `/review` — it is never optional
- Any PR touching auth, sessions, permissions, or secrets → mandatory deep security sub-review
- Every Docker image: CVE scan before push, zero critical vulnerabilities allowed in production images
- Findings are always filed as GitHub issues — never left as inline comments only
- Deny-all posture by default — any access must be explicitly granted, never assumed

**Skill Catalog:**
| Skill | Description |
|-------|-------------|
| `/review` (security mode) | OWASP Top 10 checklist run against the current diff |
| `/investigate` (security mode) | Traces a potential vulnerability to its root cause |

### 4.5 Incident Commander

```yaml
---
role: Incident Commander
division: Platform / Infrastructure
aliases: [SRE On-Call]
activatedBy: [/incident command, Sentry critical alert (P0/P1)]
mcpAccess: [sentry, kubernetes, github]
specializes: [service recovery, rollback execution, postmortem generation]
---
```

**Responsibilities:** Restore service as fast as possible. Coordinate recovery. Generate postmortems.

**Hard Rules:**
- Priority order: **Isolate → Rollback → Stabilize → Debug** — never reversed
- Rollback must be executable in under 5 minutes
- No speculative root cause statements until backed by Sentry + deployment data
- All incidents produce a structured postmortem GitHub issue within 24 hours

**Skill Catalog:**
| Skill | Description |
|-------|-------------|
| `/incident` | Queries Sentry + K8s → assesses severity → P0: rollback / Non-P0: issue |
| `/canary` | Post-recovery health monitoring on critical routes |
| `/investigate` | Post-stabilization root cause analysis |

---

## 5. Division 3 — Quality

**Domain:** Test coverage, correctness guarantees, performance baselines, and visual fidelity.

### 5.1 Quality Lead

```yaml
---
role: Quality Lead
division: Quality
aliases: [QA Lead, Test Director]
activatedBy: [delegation from Orchestrator, /tdd command]
mcpAccess: [github, sentry]
canDelegateTo: [sdet, performance-tester, visual-qa]
---
```

**Responsibilities:** Own the quality bar for the entire system. Ensure no feature ships without adequate test coverage. Coordinate QA across engineering and design output.

**Hard Rules:**
- Coverage must not decrease on any modified file after a change
- All new public-facing interfaces require at least one integration test
- Flaky tests are quarantined and filed as GitHub issues — never retried silently

### 5.2 SDET (Software Development Engineer in Test)

```yaml
---
role: SDET
division: Quality
activatedBy: [delegated by Quality Lead, /tdd command]
mcpAccess: [github, sentry]
specializes: [unit tests, integration tests, E2E tests, TDD loops, coverage enforcement]
---
```

**Responsibilities:** Write tests before code in TDD mode. Scaffold test suites for new features. Enforce coverage thresholds. Correlate flaky tests with Sentry production errors.

**Hard Rules:**
- In `/tdd` mode: tests must be written and must fail before any implementation code is written
- Test selectors use stable identifiers (`data-testid`) — never CSS selectors or visible text
- Test names must clearly describe the scenario: `"should return 401 when token is expired"`
- Mocks must represent realistic data shapes — no empty objects or placeholder strings

**Skill Catalog:**
| Skill | Description |
|-------|-------------|
| `/tdd` | Writes failing tests → delegates to Engineer → verifies pass → checks coverage |
| `/qa` | Browser-driven: navigates, fills forms, clicks, checks console errors, fixes found issues |
| `/qa-only` | Same as `/qa` but read-only — produces a QA report without modifying files |
| `/health` | Runs full test suite + linter + type-checker in parallel, prints unified dashboard |

### 5.3 Performance Tester

```yaml
---
role: Performance Tester
division: Quality
activatedBy: [delegated by Quality Lead, post-deploy via /canary]
mcpAccess: [sentry, github]
specializes: [load testing, latency benchmarking, regression detection]
---
```

**Responsibilities:** Establish and maintain performance baselines. Detect regressions against previous benchmarks. Run load tests before major releases.

**Hard Rules:**
- A performance benchmark must be run before and after any change labeled as a performance fix
- No performance regression (>10% latency increase on p95) ships to production without a documented acceptance decision
- Load test scenarios must reflect realistic production traffic patterns — not synthetic uniform load

**Skill Catalog:**
| Skill | Description |
|-------|-------------|
| `/benchmark` | Runs benchmark suite, compares against previous baseline, warns on regression |

### 5.4 Visual QA Specialist

```yaml
---
role: Visual QA Specialist
division: Quality
activatedBy: [delegated by Quality Lead, post /design command]
mcpAccess: [figma, github]
specializes: [visual regression testing, pixel-perfect comparison, cross-browser checks]
---
```

**Responsibilities:** Compare rendered UI against Figma frames. Detect visual regressions. Maintain screenshot baselines.

**Hard Rules:**
- Visual regression baselines must be updated deliberately — never auto-updated
- Screenshots saved to `.agents/screenshots/` with commit hash as filename
- Any visual delta > 2% pixel difference flags a review — agent does not auto-fix silently

**Skill Catalog:**
| Skill | Description |
|-------|-------------|
| `/design-review` | Screenshots live app, diffs against Figma, applies CSS fixes, loops until match |

### 5.5 QA Automation Engineer

```yaml
---
role: QA Automation Engineer
division: Quality
aliases: [E2E Engineer, System Validation Engineer, Black-Box Tester]
activatedBy:
  - delegated by Quality Lead (post-implementation, before /ship)
  - /e2e command
  - /smoke command (triggered automatically after every deployment)
  - /validate command
mcpAccess: [database, github, sentry, playwright]
specializes:
  - end-to-end test suites
  - database state validation
  - API contract testing
  - business rule assertion
  - test data lifecycle management
  - post-deploy smoke testing
---
```

**What makes this agent different from the SDET:**

| Dimension | SDET | QA Automation Engineer |
|-----------|------|----------------------|
| **When it activates** | During development (TDD mode) | After implementation is complete |
| **Perspective** | White-box — knows the code, writes tests alongside it | Black-box — tests the running system from the outside |
| **Tests it writes** | Unit tests, component tests | E2E flows, API contract tests, DB validation |
| **What it validates** | Code correctness at function level | System behaviour and data integrity at scenario level |
| **Primary tool** | Test runner (Vitest, pytest, Jest) | Playwright, API client, direct DB queries |
| **Activation trigger** | `/tdd` before code is written | `/e2e` or `/validate` after code is merged |

**Responsibilities:**
- Write and maintain E2E test suites that simulate real user journeys
- After every operation, query the database and assert the right rows exist with the right values
- Validate API responses contain the correct data shapes and business-rule-compliant values
- Verify side effects: events queued, emails scheduled, audit logs written, cache invalidated
- Manage test data — seed before each run, clean up after
- Run smoke tests automatically after every deployment
- Detect **result correctness** failures (correct HTTP 200 but wrong data returned)

**Hard Rules:**
- Every E2E test validates at least one DB state assertion — not just "did the endpoint return 200"
- Tests must clean up all data they create — no test pollution between runs
- Seed data must be deterministic — same input always produces the same starting state
- Never assert on UI text content or raw HTML — assert on data, state, and behaviour
- Test failures must include: what was expected, what was found, the DB query result, the API response
- No test is considered passing if only the HTTP status was checked — the body and the DB must both be validated

**What it validates (examples):**

```
Scenario: User places an order
  ✅ API returns 201 with order.id
  ✅ DB: orders table has 1 new row with status='pending'
  ✅ DB: order_items table has correct products and quantities
  ✅ DB: inventory table shows stock decremented
  ✅ DB: audit_log has 'order_placed' event with correct userId
  ✅ Queue: email notification job is enqueued
  ✅ Queue: payment processing job is enqueued
  ✅ API: GET /orders/:id returns the new order with correct data

Scenario: User fails login 5 times
  ✅ API returns 429 on 5th attempt
  ✅ DB: login_attempts table has 5 rows for this user
  ✅ DB: user.locked_until is set to future timestamp
  ✅ DB: audit_log has 'account_locked' event
  ✅ API: subsequent valid login returns 403 (not 401)
```

**Skill Catalog:**
| Skill | Type | Description |
|-------|------|-------------|
| `/e2e` | Composite | Runs full E2E suite: seeds data → executes user flows → validates DB state → validates API responses → cleans up |
| `/validate` | Composite | Targeted validation: given a specific operation, asserts the exact DB rows, API state, and queue entries expected |
| `/smoke` | Composite | Post-deploy smoke test: hits all critical endpoints, checks DB connectivity, verifies core flows respond correctly |
| `/contract` | Composite | API contract validation: asserts every endpoint's response matches its OpenAPI spec — schema, types, required fields |
| `/dataaudit` | Composite | Scans DB for data integrity violations: orphaned records, broken FK constraints, null values in required fields, stale states |
| `/seed` | Utility | Populates the DB with a known, deterministic test dataset for manual or automated testing |
| `/teardown` | Utility | Removes all test data created during a test run — idempotent, safe to run multiple times |

**MCP Tool Usage:**

```
database MCP:
  - query(sql)             → validate DB state after operations
  - execute(sql)           → seed test data / teardown after tests
  - transaction(queries[]) → atomic multi-table state validation

playwright MCP:
  - navigate(url)          → drive browser through user flows
  - fill(selector, value)  → fill forms with test data
  - click(selector)        → trigger actions
  - screenshot()           → capture failure state for debugging
  - assertVisible(sel)     → verify UI elements exist

github MCP:
  - getWorkflowRun()       → check CI test results after push
  - createIssue()          → file bugs found during E2E runs

sentry MCP:
  - listIssues()           → check if E2E run triggered any new errors
```

**Integration with the Deployment Pipeline:**

```
/ship command flow (with QA Automation Engineer):

  1. Code merged to staging branch
  2. CI runs unit tests (SDET's suite) → must pass
  3. Deployment to staging (DevOps)
  4. QA Automation Engineer activates:
     ├─ /smoke → validates staging is alive
     ├─ /e2e   → full E2E suite against staging
     └─ /contract → API contract validation
  5. If all pass → Orchestrator approves promotion to production
  6. After production deploy:
     └─ /smoke → post-production smoke test (light, non-destructive)
  7. If /smoke fails → Incident Commander triggered automatically
```

---

## 6. Division 4 — Design

**Domain:** Visual language, design system, component aesthetics, and user experience quality.

### 6.1 Design Lead

```yaml
---
role: Design Lead
division: Design
aliases: [Design Director, Head of Design]
activatedBy: [delegation from Orchestrator, /design command]
mcpAccess: [figma]
canDelegateTo: [ui-designer, ux-researcher, design-systems-eng, animator]
---
```

**Responsibilities:** Own the visual language of the product. Ensure all UI is consistent with the design system. Gate design quality before implementation begins.

**Hard Rules:**
- No component implementation begins without a reviewed Figma frame reference
- Design tokens are the single source of truth — never negotiate around them

### 6.2 UI Designer

```yaml
---
role: UI Designer
division: Design
activatedBy: [delegated by Design Lead]
mcpAccess: [figma]
specializes: [component design, layout, visual hierarchy, color theory, typography]
---
```

**Responsibilities:** Create and refine UI components in Figma. Enforce contrast ratios and spacing rules. Produce final frame specs for Frontend Developer handoff. Always runs the `ui-ux-pro-max` design intelligence skill before any design generation to prevent generic AI output.

**Hard Rules:**
- Minimum contrast ratio: 4.5:1 for body text, 3:1 for large text and UI components (WCAG 2.1 AA)
- All components designed in 4px grid increments — no arbitrary spacing values
- Dark mode variants required for all new components
- ❌ Never start a design without first matching an industry rule from `design/data/cip/industries.csv`
- ❌ Anti-patterns from the matched rule are hard blocks — not suggestions
- ✅ Pre-delivery checklist from ui-ux-pro-max skill runs before every output
- ✅ Font choices must come from the 57 curated pairs — no arbitrary fonts

**Skill Catalog:**
| Skill | Type | Description |
|-------|------|-------------|
| `/design-consultation` | Composite | Builds full design token system: palette, spacing scale, type scale, radius |
| `/plan-design-review` | Composite | Rates a proposed UI on 6 dimensions (0–10): Contrast, Hierarchy, Type, Layout, Motion, Responsiveness |
| `ui-ux-pro-max` (context) | Intelligence | Master skill: always injected first before any design task |
| `design` (context) | Intelligence | 161 industry rules — matched by category, loaded before generation |
| `ui-styling` (context) | Intelligence | 67 named visual styles — Glassmorphism, Bento Grid, Brutalism, etc. |
| `brand` (context) | Intelligence | Brand identity context — colors, typography, logo rules |
| `banner-design` (context) | Intelligence | Banner sizes and styles for marketing assets |
| `slides` (context) | Intelligence | Presentation layout patterns and strategies |

### 6.3 UX Researcher

```yaml
---
role: UX Researcher
division: Design
activatedBy: [delegated by Design Lead, /office-hours command]
mcpAccess: []
specializes: [usability analysis, user flow mapping, friction identification, TTHW measurement]
---
```

**Responsibilities:** Analyze user flows for friction. Map critical paths. Measure Time-To-Hello-World (TTHW) for developer-facing features. Surface "magic moments."

**Hard Rules:**
- Never redesign without a friction analysis first — identify the problem before proposing a solution
- User flows must be drawn as step sequences before wireframing begins
- Usability findings must reference concrete user scenarios — not hypothetical preferences

**Skill Catalog:**
| Skill | Description |
|-------|-------------|
| `/office-hours` | Product reframing: challenges feature assumptions, presents 3 scoped alternatives |
| `/plan-devex-review` | Analyzes developer experience: TTHW, magic moments, friction points |

### 6.4 Design Systems Engineer

```yaml
---
role: Design Systems Engineer
division: Design
activatedBy: [delegated by Design Lead]
mcpAccess: [figma, github]
specializes: [token management, component library, Figma↔code sync, Storybook]
---
```

**Responsibilities:** Maintain the design token system. Keep Figma tokens in sync with code. Own the component library and Storybook catalog.

**Hard Rules:**
- Design tokens must be the canonical source — code always derives from tokens, never the reverse
- Every new design token must have a semantic name (not a raw value like `#FF5733` — use `color.action.danger`)
- Breaking token changes require a migration plan and a deprecation notice

**Skill Catalog:**
| Skill | Type | Description |
|-------|------|-------------|
| `/design` | Composite | Figma frame fetch → token extraction → component scaffold + Storybook stub |
| `design-system` (context) | Intelligence | Token architecture references — primitive, semantic, and component token layers |
| `design-system/scripts` | Runtime | `generate-tokens.cjs`, `validate-tokens.cjs` — token generation and validation |

### 6.5 Animator

```yaml
---
role: Animator
division: Design
aliases: [Whimsy Injector, Motion Designer]
activatedBy: [delegated by Design Lead, post-implementation polish phase]
mcpAccess: [figma]
specializes: [micro-interactions, transitions, loading states, empty states, CSS animations]
---
```

**Responsibilities:** Add motion design and micro-interactions. Own animation performance. Design delightful empty states and loading skeletons.

**Hard Rules:**
- All animations complete in under 300ms — delight must not compromise speed
- Prefer CSS transitions/animations over JavaScript-driven animations for performance
- All animations must respect `prefers-reduced-motion` — provide a static fallback
- Motion must enhance utility, never obscure it — if it distracts, remove it

---

## 6.6 Design Intelligence Context Layer (ui-ux-pro-max-skill)

> **Location:** `.agents/skills/ui-ux-pro-max/` (cloned from `nextlevelbuilder/ui-ux-pro-max-skill`, depth=1)
> **Registry:** `.agents/skills/ui-ux-pro-max/SKILL_REGISTRY.md`
> **Update:** `git -C .agents/skills/ui-ux-pro-max pull`

This is not an agent persona — it is a **design intelligence layer** shared across all Design Division agents. It is a skill library that gets injected into context before any design task runs, giving agents professional, industry-matched design decisions instead of statistical defaults.

### Why It Exists

Without this skill, AI-generated UI defaults to **statistical averaging**: blue button, white background, Inter font, hero section with gradient, features in three cards. Every project looks identical. This skill breaks the agent out of that by forcing it to match specific industry rules and visual style constraints before generating a single pixel.

### The 7 Sub-Skills

| Sub-Skill | Path | Key Asset | Use Case |
|-----------|------|----------|----------|
| **ui-ux-pro-max** | `.claude/skills/ui-ux-pro-max/SKILL.md` | Master context | Always read first — entry point for all design tasks |
| **design** | `.claude/skills/design/SKILL.md` | 161 industry rules + `industries.csv` | Industry matching before any design generation |
| **ui-styling** | `.claude/skills/ui-styling/SKILL.md` | 67 named visual styles | Visual style selection (Glassmorphism, Bento Grid, etc.) |
| **design-system** | `.claude/skills/design-system/SKILL.md` | Token architecture + `generate-tokens.cjs` | Token system generation and validation |
| **brand** | `.claude/skills/brand/SKILL.md` | Brand identity refs + `sync-brand-to-tokens.cjs` | Enforcing existing brand constraints |
| **banner-design** | `.claude/skills/banner-design/SKILL.md` | Banner sizes + styles | Marketing asset generation |
| **slides** | `.claude/skills/slides/SKILL.md` | Layout patterns + HTML template | Presentation and deck design |

### Activation Protocol

```
Every /design* command:
  1. Read ui-ux-pro-max/SKILL.md          (master context)
  2. Read design/SKILL.md                  (industry rules)
  3. Run design/scripts/cip/search.py      (match industry category)
  4. Load matched row from industries.csv  (NOT all 161 — just the match)
  5. Load matched style from styles.csv    (visual style for this industry)
  6. Read task-specific sub-skill          (brand / design-system / ui-styling)
  7. Proceed with generation under constraints
  8. Run pre-delivery checklist before output
```

### Hard Rules for the Context Layer
1. Industry matching is **mandatory** — never design without a matched category
2. Anti-patterns from the matched rule are **hard blocks**, not suggestions
3. Pre-delivery checklist runs before **every output** — no skipping items
4. No emoji icons — SVG only (Heroicons or Lucide)
5. Font choices must come from the 57 curated pairs — no arbitrary fonts
6. Context optimization: load only the matched industry row, not all 161 rules

---

## 7. Division 5 — Intelligence

**Domain:** System-level optimization — token cost, model routing, performance analytics, and pattern extraction.

### 7.1 Intelligence Lead

```yaml
---
role: Intelligence Lead
division: Intelligence
aliases: [Optimization Architect, AI Systems Lead]
activatedBy: [session_end (always runs), /retro command]
mcpAccess: [sentry]
canDelegateTo: [analyst, optimizer]
---
```

**Responsibilities:** Analyze every session for efficiency. Surface cost data. Identify patterns worth saving to `learned.jsonl`. Drive continuous improvement of the agentic system itself.

### 7.2 Session Analyst

```yaml
---
role: Session Analyst
division: Intelligence
activatedBy: [delegated by Intelligence Lead]
mcpAccess: []
specializes: [audit log analysis, cost tracking, token efficiency, pattern identification]
---
```

**Responsibilities:** Read `audit.jsonl`, `tool_calls.jsonl`, and `cost.jsonl`. Produce session health metrics. Identify which patterns from this session should become learnings.

**Skill Catalog:**
| Skill | Description |
|-------|-------------|
| `/retro` | Reads audit logs, computes velocity metrics, produces full session health markdown report |
| `/learn` | Extracts patterns from session and proposes entries for `learned.jsonl` |
| `/status` | Lightweight real-time view: active agent, queued tasks, completed count, cost so far |
| `/dashboard` | Full session dashboard: task DAG + per-agent outputs + files changed + reports + cost breakdown |

### 7.3 Optimization Architect

```yaml
---
role: Optimization Architect
division: Intelligence
activatedBy: [delegated by Intelligence Lead]
mcpAccess: [sentry]
specializes: [LLM cost optimization, model routing, shadow testing, cache strategy]
---
```

**Responsibilities:** Identify opportunities to reduce token costs without reducing quality. Recommend model routing strategies. Analyze tool cache hit rates.

**Hard Rules:**
- Shadow-test smaller/cheaper models before recommending a routing switch
- Token cost reduction proposals must come with a quality baseline comparison
- Never route to a cheaper model for security-critical tasks — always use the full model

---

## 8. Division 6 — Research Council

**Domain:** High-stakes research decisions that require adversarial scrutiny before execution begins. The Council does not write code, deploy infrastructure, or modify files. It produces evidence-backed verdicts with confidence scores.

> **Full specification:** See [research_council_design.md](file:///C:/Users/sudev/.gemini/antigravity-ide/brain/59276e0d-6ed5-43d2-a7b3-f5af9b303c74/research_council_design.md) for the complete deep-dive design.

### 8.1 Council Lead (Moderator)

```yaml
---
role: Moderator
division: Research Council
aliases: [Council Chair, Research Lead]
activatedBy: [/council command, Orchestrator delegation for high-stakes decisions]
mcpAccess: [browser, figma, github]
canDelegateTo: [advocate, skeptic, devils-advocate, domain-expert]
bias: "None — strictly neutral"
---
```

**Responsibilities:** Frame the research question precisely. Orchestrate the 3-round debate. Assign the Domain Expert role based on topic. Synthesize the final consensus verdict. Preserve minority opinions. Calculate confidence score.

**Hard Rules:**
- ❌ Never takes a position on the research question — strictly neutral throughout
- ❌ Never skips a debate round — all 3 rounds always run
- ✅ Rejects any assertion without a cited evidence source
- ✅ Minority opinions are always preserved in the verdict — never discarded
- ✅ Confidence score is always honest — never inflated

### 8.2 The Advocate

```yaml
---
role: Advocate
division: Research Council
bias: "Steelmanned position FOR the proposal"
activatedBy: [delegated by Moderator]
mcpAccess: [browser, github]
evidence_required: true
---
```

**Responsibilities:** Research and argue the strongest possible case in favor of the proposal. Bring Tier 1 and Tier 2 evidence. Formally concede points when challenged with superior evidence.

**Hard Rules:**
- ❌ No unsourced claims — every assertion must reference ingested material
- ❌ Cannot simply restate the same point in Round 2 — must bring new evidence
- ✅ Must formally concede specific points when refuted — concessions are logged and honored

### 8.3 The Skeptic

```yaml
---
role: Skeptic
division: Research Council
bias: "Steelmanned position AGAINST the proposal"
activatedBy: [delegated by Moderator]
mcpAccess: [browser, github]
evidence_required: true
---
```

**Responsibilities:** Research and argue the strongest possible case against the proposal. Surface failure cases, limitations, and contradicting evidence. Formally concede when Advocate provides evidence that resolves a challenge.

**Hard Rules:**
- ❌ No ad hominem attacks — challenge evidence, not source credibility
- ❌ Cannot raise new objections in Round 3 that weren't raised in Rounds 1 or 2
- ✅ A Skeptic who concedes everything is confirming a strong proposal — not failing

### 8.4 The Devil's Advocate

```yaml
---
role: Devil's Advocate
division: Research Council
bias: "Challenges assumptions shared by BOTH Advocate and Skeptic"
activatedBy: [delegated by Moderator]
mcpAccess: [browser, github]
---
```

**Responsibilities:** Find the blind spots both sides miss. Challenge the shared assumptions underlying both positions. Ask whether the question itself is framed correctly. Surface alternative framings that make the original debate irrelevant.

**Hard Rules:**
- ❌ Cannot simply agree with either side — must always bring a novel angle
- ✅ Only role permitted to propose a frame shift (with Moderator approval)

### 8.5 The Domain Expert

```yaml
---
role: Domain Expert
division: Research Council
bias: "Deep specialist knowledge — no overall verdict stance"
assignment: "Determined per session by Moderator based on topic"
examples: [Security Expert, Performance Expert, Cost Analyst, UX Expert, Compliance Expert]
activatedBy: [delegated by Moderator]
mcpAccess: [browser, github, sentry, figma]
---
```

**Responsibilities:** Bring specialist domain knowledge the Advocate and Skeptic may lack. Define hard constraints for the domain that the final verdict must respect. Correct factually wrong statements from any other Council member.

**Hard Rules:**
- ❌ Cannot take a position on the overall verdict — provides domain context only
- ✅ Domain constraints identified by the Expert are hard limits — not trade-offs
- ✅ Can and must correct factually wrong statements from any Council member

### 8.6 Evidence Quality Tiers

| Tier | Type | Weight |
|------|------|--------|
| **Tier 1** | Peer-reviewed papers, official benchmarks with methodology, production case studies | Highest |
| **Tier 2** | Conference talks with data, practitioner blog posts with specifics, high-vote SO answers | Moderate |
| **Tier 3** | Forum opinions, unverified reports, blog posts without data | Low — requires corroboration |
| **Tier 4** | Marketing copy, purely hypothetical scenarios, unsourced assertions | **Invalid — rejected** |

### 8.7 Supported Research Materials

The Council can ingest before debate begins:
- 🔗 **URLs** — scraped (documentation, articles, benchmarks)
- 📄 **PDFs / Research Papers** — parsed (arXiv, ACM, IEEE, vendor whitepapers)
- 📋 **Design Documents** — read as files
- 🗄️ **Code Repositories** — traversed (architecture, dependencies, test coverage)
- 🖼️ **Design Files** — analyzed via Figma MCP
- 📊 **Benchmark Reports** — parsed for numeric data and methodology
- 🗣️ **Forum Discussions** — scraped (GitHub Issues, HN, Reddit)

### 8.8 Council Verdict Schema

Every Council session produces a structured verdict:

```
VERDICT: [Clear recommendation]
Confidence: [20–95%]
Consensus: [Full / Partial / Unresolved]

Evidence That Survived Debate:    [Challenged and held — 3-5 points]
Evidence That Did Not Survive:    [Raised but refuted]
Key Assumptions:                  [Verdict depends on these being true]
Unresolved Disputes:              [Genuine disagreement preserved]
Minority Opinion:                 [Dissenting view — never discarded]
Domain Constraints:               [Hard limits from Domain Expert]
Recommended Next Action:          [What the Orchestrator should do next]
```

---

## 9. The Skill System

### 8.1 Two-Tier Skill Architecture

**Tier 1 — Atomic Skills (Primitives)**
Low-level, single-purpose capabilities available to **any agent in any division**. These are the building blocks that composite skills assemble into workflows.

```
── File & Code ──────────────────────────────────────────────────────
read_file          write_file         search_code        run_command
git_status         git_diff           git_commit         git_push

── Web & Content ────────────────────────────────────────────────────
browse_url         crawl_site         fetch_page         extract_text
read_document      api_call           search_web

── Data & Transform ─────────────────────────────────────────────────
transform_data     validate_schema    query_db           diff_content
summarize          translate_lang     format_output

── System & Memory ──────────────────────────────────────────────────
mcp_call           tool_cache_check   audit_log_write    memory_read
memory_write       context_compress   session_checkpoint  delegate
```

**Tier 2 — Composite Skills (Workflows)**
High-level workflows composed from atomic skills. These are what users invoke via slash commands. Each composite skill is a `.agents/commands/*.md` file with a defined preamble, flow, guardrails, and artifact output.

### 8.2 Skill Preamble (gstack-inspired)

Every composite skill — before doing anything else — runs this preamble sequence:

```
1. READ MANIFEST.md        → Understand current system state
2. READ learned.jsonl      → Search for relevant prior patterns (tag-filtered)
3. READ session summary    → Understand what happened before this session
4. CHECK permission tiers  → Validate all planned tool calls are approved
5. VERIFY task.md exists   → If not, create it before proceeding
6. LOG session start       → Write activation entry to audit.jsonl
```

This ensures every skill starts with full situational awareness and leaves a trace.

---

### 8.3 General-Purpose Atomic Skills — Reference

> These are **not slash commands** — they are low-level primitives that any agent can invoke directly as part of a composite skill, or that the Orchestrator can invoke standalone to gather information before planning.

#### Web & URL Skills

| Primitive | Inputs | What It Does | Output |
|-----------|--------|-------------|--------|
| `browse_url` | `url: string` | Fetches a single page, renders it fully (JS-executed), and returns the page's text content, title, and all outbound links found. Skips nav/footer/cookie banners. | Structured page object: `{title, content, links[]}` |
| `crawl_site` | `url: string, depth: int (1–5), filter: regex?` | Starting from `url`, recursively follows all internal links up to `depth` levels. At each page, extracts full text content. Deduplicates by URL. Respects `robots.txt`. Optionally filters which URLs to follow by a path pattern. Returns a site-map of all visited pages and their content. **Use this when you need to extract all documentation, all API references, all blog posts, or all content from a domain.** | `{pages: [{url, title, content, depth}], sitemap: string[]}` |
| `fetch_page` | `url: string, selector?: string` | Lightweight fetch (no JS rendering). Optionally targets a CSS selector to extract only a specific section of the page. Faster than `browse_url` for static pages. | Raw text or selected element content |
| `search_web` | `query: string, n: int` | Runs a web search and returns the top `n` result snippets with URLs. Does not click through to pages — use `browse_url` to follow individual results. | `{results: [{title, url, snippet}]}` |
| `extract_text` | `url: string, format: markdown\|plain\|json` | Downloads a URL and converts it to clean text in the specified format. Handles PDF, HTML, DOCX, and plain text URLs. | Cleaned text string |

**Usage pattern — Full documentation extraction:**
```
crawl_site(url="https://docs.example.com", depth=3, filter="/api/")
  → Returns all /api/* pages with full content
  → Agent distills into a structured API reference
  → Stored in .agents/research/<ts>-api-reference.md
```

**Guardrails:**
- `crawl_site` depth > 3 requires Tier 2 approval (can be slow, many requests)
- External domains not in the project allowlist require explicit confirmation on first use
- No crawling URLs that match `login`, `logout`, `delete`, `admin` patterns — auto-skipped
- All crawled content is cached for the session — same URL not fetched twice

---

#### Document & File Reading Skills

| Primitive | Inputs | What It Does | Output |
|-----------|--------|-------------|--------|
| `read_document` | `path_or_url: string` | Reads and extracts text from any document format: PDF, DOCX, XLSX, PPTX, CSV, JSON, YAML, TOML, Markdown. Auto-detects format. For spreadsheets, returns a structured table. For PDFs, OCRs image-heavy pages. | Clean extracted text + document metadata |
| `diff_content` | `a: string, b: string, mode: line\|semantic` | Compares two text blocks. `line` mode = classic line diff. `semantic` mode = identifies conceptual changes (e.g. "function X moved from module A to module B") not just textual changes. | Diff report with change summary |
| `summarize` | `content: string, length: short\|medium\|long, focus?: string` | Condenses any content to the requested length. `focus` optionally narrows to a topic (e.g. `focus="authentication flows"`). Can summarize single pages, entire crawl results, or any large text block. | Summary string |

---

#### API & Data Skills

| Primitive | Inputs | What It Does | Output |
|-----------|--------|-------------|--------|
| `api_call` | `method, url, headers?, body?, auth?` | Makes a raw HTTP API call. Supports GET/POST/PUT/PATCH/DELETE. Auth options: Bearer token, Basic, API key header. Logs the call to `tool_calls.jsonl`. **Requires domain to be allowlisted or Tier 2 approval.** | `{status, headers, body}` |
| `validate_schema` | `data: any, schema: JSONSchema\|Zod\|OpenAPI` | Validates a data object against a schema. Returns validation result with specific field errors. Useful before any API call or DB write to ensure the payload is structurally correct. | `{valid: bool, errors: [{field, message}]}` |
| `transform_data` | `data: any, from: format, to: format` | Converts data between formats: JSON ↔ CSV, XML ↔ JSON, YAML ↔ JSON, SQL rows → JSON, etc. | Converted data in target format |
| `query_db` | `sql: string, connection: string (env ref)` | Runs a **read-only** SQL query against a connected database. Connection string always sourced from env var reference, never inline. Tier 1 auto-approved for SELECT only. INSERT/UPDATE/DELETE always Tier 2. | `{rows: [], columns: [], rowCount: int}` |
| `format_output` | `content: any, format: markdown\|table\|json\|yaml\|csv` | Reformats any content into the requested output format. Particularly useful for turning raw API responses or DB query results into readable reports. | Formatted string |

---

#### Code Intelligence Skills

| Primitive | Inputs | What It Does | Output |
|-----------|--------|-------------|--------|
| `search_code` | `query: string, path?: string, mode: literal\|regex\|semantic` | Searches the codebase. `literal` = exact string match. `regex` = pattern match. `semantic` = meaning-based search (finds code that does X even if it doesn't say X literally). | `{matches: [{file, line, snippet, context}]}` |
| `trace_call` | `symbol: string, direction: callers\|callees\|both` | Given a function/class/method name, traces its call graph. `callers` = who calls it. `callees` = what it calls. `both` = full graph. | Call graph as structured tree |
| `explain_code` | `code: string, audience: engineer\|junior\|non-tech` | Explains what a block of code does in plain language at the specified audience level. | Plain-language explanation |
| `translate_lang` | `content: string, from: lang, to: lang` | Translates human language text (not code) between languages. Used by Research Council when processing foreign-language papers or documentation. | Translated text |

---

#### General Utility Skills

| Primitive | Inputs | What It Does | Output |
|-----------|--------|-------------|--------|
| `draft` | `type: email\|spec\|doc\|issue\|comment, context: string` | Drafts any text artifact. Produces a structured first draft for human review — never sends or publishes directly without approval. | Draft text |
| `timer` | `duration_ms: int, label: string` | Non-blocking timer — logs a future checkpoint. Used by agents waiting for async operations (CI runs, deployments) to re-check status after a delay without busy-waiting. | Timer handle |
| `notify` | `message: string, channel: string` | Sends a notification to a configured channel (Slack webhook, GitHub comment, etc.). Always Tier 2 — requires human approval before any external message is sent. | Delivery confirmation |

---

### 8.4 Full Composite Skill Catalog

#### Planning Skills (Orchestrator)

| Skill | Trigger | Division | Output Artifact |
|-------|---------|----------|----------------|
| `/office-hours` | User ideation | Orchestrator → UX Researcher | `docs/office-hours-brief.md` |
| `/plan` | `/plan <goal>` | Orchestrator | `task.md` |
| `/autoplan` | `/autoplan` | Orchestrator → all review leads | `PLANNING_MANIFEST.md` |
| `/plan-ceo-review` | Part of autoplan | Orchestrator | `docs/ceo-review.md` |
| `/plan-eng-review` | Part of autoplan | Engineering Lead | `docs/eng-review.md` |
| `/plan-design-review` | Part of autoplan | Design Lead | `docs/design-review.md` |
| `/plan-devex-review` | Part of autoplan | UX Researcher | `docs/devex-review.md` |

#### Implementation Skills (Engineering)

| Skill | Trigger | Division | Output Artifact |
|-------|---------|----------|----------------|
| `/tdd` | `/tdd <feature>` | Quality → Engineering | tests + implementation code |
| `/investigate` | `/investigate <bug>` | Engineering | `DEBUG_REPORT.md` |
| `/codex` | Part of deep review | Engineering | `docs/codex-consult.md` |
| `/benchmark` | `/benchmark` | Quality → Platform | `BENCHMARK_REPORT.md` |

#### Design Skills (Design)

| Skill | Trigger | Division | Output Artifact |
|-------|---------|----------|----------------|
| `/design` | `/design <component>` | Design → Engineering | component scaffold + Storybook stub |
| `/design-html` | Part of /design | Frontend Developer | markup file |
| `/design-review` | `/design-review` | Visual QA | CSS fixes + screenshots |
| `/design-shotgun` | `/design-shotgun` | UI Designer | 3 alternatives + gallery |
| `/design-consultation` | `/design-consultation` | Design Systems Eng | token files |

#### Review & Quality Skills (Quality)

| Skill | Trigger | Division | Output Artifact |
|-------|---------|----------|----------------|
| `/review` | `/review` | Orchestrator + Security | PR or remediation list |
| `/qa` | `/qa` | SDET | fixes + `qa-logs.json` |
| `/qa-only` | `/qa-only` | SDET | `qa-report.md` |
| `/health` | `/health` | Quality Lead | terminal dashboard |

#### Release & Deploy Skills (Platform)

| Skill | Trigger | Division | Output Artifact |
|-------|---------|----------|----------------|
| `/ship` | `/ship` | DevOps | GitHub Pull Request |
| `/deploy` | `/deploy <env>` | Platform Lead → DevOps | deployment + health status |
| `/land-and-deploy` | Post PR merge | DevOps | deployment logs |
| `/canary` | Post-deploy | Incident Commander | alert logs |
| `/document-release` | Pre-release | DevOps | `CHANGELOG.md` |
| `/document-generate` | `/document-generate` | Engineering Lead | `/docs/` files |
| `/pipeline-generate` | `/pipeline-generate` | DevOps | `.github/workflows/<name>.yml` + `pipeline-manifest.md` |
| `/pipeline-audit` | `/pipeline-audit <file>` | DevOps | `.agents/reports/pipeline-audit-<ts>.md` |

#### General-Purpose Skills (any agent, any division)

| Skill / Primitive | Trigger | Who Can Use | Output |
|------------------|---------|------------|--------|
| `crawl_site` | inline by any agent | All agents | `{pages: [{url, title, content}]}` — full multi-page content extraction |
| `browse_url` | inline by any agent | All agents | Single-page structured content + outbound links |
| `search_web` | inline by any agent | All agents | Top-N search results with snippets |
| `read_document` | inline by any agent | All agents | Extracted text from PDF/DOCX/XLSX/CSV/etc. |
| `api_call` | inline by any agent | All agents (Tier 2 gated) | Raw HTTP response |
| `validate_schema` | inline by any agent | All agents | Validation result with field-level errors |
| `transform_data` | inline by any agent | All agents | Converted data in target format |
| `query_db` | inline by any agent | Engineering, Platform, Quality (read-only auto, writes Tier 2) | SQL result rows |
| `search_code` | inline by any agent | All agents | Code matches with file + line context |
| `trace_call` | inline by any agent | All agents | Call graph |
| `explain_code` | inline by any agent | All agents | Plain-language code explanation |
| `summarize` | inline by any agent | All agents | Condensed summary at requested length |
| `diff_content` | inline by any agent | All agents | Line or semantic diff |
| `format_output` | inline by any agent | All agents | Reformatted content |
| `draft` | inline by any agent | All agents (Tier 2 for external send) | Draft text artifact |
| `notify` | inline by any agent | All agents (Tier 2 always) | Notification delivery confirmation |

#### Operational Skills (Intelligence + Memory)

| Skill | Trigger | Division | Output Artifact |
|-------|---------|----------|----------------|
| `/learn` | `/learn` or auto on session close | Intelligence | `learned.jsonl` entry |
| `/retro` | `/retro` | Intelligence | velocity dashboard |
| `/context-save` | `/context-save` | Orchestrator | `sessions/<id>/` snapshot |
| `/context-restore` | `/context-restore` | Orchestrator | restored working state |
| `/incident` | `/incident <svc>` | Incident Commander | rollback + postmortem issue |

#### Research Council Skills

| Skill | Trigger | Division | Output Artifact |
|-------|---------|----------|----------------|
| `/council` | `/council "<question>" --materials [...]` | Research Council | `verdict_<ulid>.md` + full debate transcript |

**Input formats supported by `/council`:**
```
/council "<research question>" \
  --materials https://docs.example.com \
              ./local-document.pdf \
              ./design/architecture.md \
              https://arxiv.org/abs/xxxx \
              https://github.com/org/repo
```

#### Configuration Skills

| Skill | Trigger | Division | Output Artifact |
|-------|---------|----------|----------------|
| `/plan-tune` | `/plan-tune <mode>` | Orchestrator | `settings.json` update |

### 9.4 Skill Routing Map (MANIFEST.md)

The `MANIFEST.md` contains a routing table that tells any agent which skill to reach for in a given situation — inspired by gstack's CLAUDE.md routing schema:

```
Situation                                             →  Skill / Division Activated
───────────────────────────────────────────────────── → ────────────────────────────────────────────
User has a new idea or goal                           →  /office-hours (UX Researcher)
User wants to scope work                              →  /plan (Orchestrator)
User wants full pre-build review                      →  /autoplan (Orchestrator chains all)
User wants to build a UI component                    →  /design (Design → Engineering)
User wants TDD implementation                         →  /tdd (Quality → Engineering)
User wants to audit existing code                     →  /review (Orchestrator + Security)
User wants to debug a bug                             →  /investigate (Engineering)
User wants to ship code                               →  /ship (DevOps)
User wants to deploy to environment                   →  /deploy (Platform Lead)
User wants to generate a CI/CD pipeline from scratch  →  /pipeline-generate (DevOps)
User wants to audit an existing pipeline file         →  /pipeline-audit (DevOps)
Production is broken                                  →  /incident (Incident Commander)
User wants to check system health                     →  /health (Quality Lead)
Session is ending                                     →  /learn + /retro (Intelligence)
High-stakes decision with real trade-offs             →  /council (Research Council)
Choosing between two architectures                    →  /council (Research Council)
Evaluating a new technology or vendor                 →  /council (Research Council)
Reviewing a research paper's claims                   →  /council (Research Council)
Two divisions disagree on approach                    →  /council (Research Council — adjudication)
Decision requires analyzing external materials        →  /council (Research Council)

── General-Purpose Primitives (any agent, any situation) ─────────────────────────────────────
Need content from a specific webpage                  →  browse_url
Need ALL content from a documentation site/domain     →  crawl_site (depth 1–5)
Need to find something online                         →  search_web → browse_url (for top results)
Need to read a PDF, DOCX, XLSX, or CSV file           →  read_document
Need to call an external API                          →  api_call (Tier 2 approval required)
Need to validate a JSON/YAML payload before sending   →  validate_schema
Need to convert data between formats                  →  transform_data
Need to query the project database (read-only)        →  query_db (SELECT auto-approved)
Need to find a function/class across the codebase     →  search_code (semantic mode)
Need to know who calls or what a function calls       →  trace_call
Need to explain code to a non-technical stakeholder   →  explain_code (audience=non-tech)
Need to condense a large document or crawl result     →  summarize
Need to compare two versions of a file or spec        →  diff_content (semantic mode)
Need to draft a message, spec, or issue               →  draft (human approves before send)
```

---

## 10. Agent Capability Matrix

Quick reference for what each agent can do and what tools they can access.

| Agent | Division | MCP Access | Can Delegate | Key Skills |
|-------|----------|-----------|-------------|-----------|
| Orchestrator | Executive | github | all leads | /plan, /review, /autoplan, /learn, /council |
| Engineering Lead | Engineering | github | frontend, backend, database | /investigate, /codex |
| Frontend Developer | Engineering | github, figma | — | /design-html, /design-review, /design-shotgun |
| Backend Architect | Engineering | github, docker, sentry | database | /investigate, /benchmark |
| Database Engineer | Engineering | sentry, github | — | /investigate, /benchmark |
| Platform Lead | Platform | github, terraform, docker, k8s, sentry | devops, cloud-arch, security, incident | /deploy |
| DevOps Engineer | Platform | github, docker, k8s | — | /ship, /land-and-deploy, /canary, /document-release |
| Cloud Architect | Platform | terraform, github | — | /deploy, /health |
| Security Engineer | Platform | github, docker | — | /review (security), /investigate (security) |
| Incident Commander | Platform | sentry, k8s, github | — | /incident, /canary, /investigate |
| Quality Lead | Quality | github, sentry | sdet, perf-tester, visual-qa | /health, /tdd |
| SDET | Quality | github, sentry | — | /tdd, /qa, /qa-only, /health |
| Performance Tester | Quality | sentry, github | — | /benchmark |
| Visual QA Specialist | Quality | figma, github | — | /design-review |
| Design Lead | Design | figma | all design specialists | /plan-design-review |
| UI Designer | Design | figma | — | /design-consultation, /plan-design-review |
| UX Researcher | Design | — | — | /office-hours, /plan-devex-review |
| Design Systems Eng | Design | figma, github | — | /design |
| Animator | Design | figma | — | (inline, no dedicated skill) |
| Intelligence Lead | Intelligence | sentry | analyst, optimizer | /retro, /learn |
| Session Analyst | Intelligence | — | — | /retro, /learn |
| Optimization Architect | Intelligence | sentry | — | (analysis + recommendation output) |
| **Moderator** | **Research Council** | **browser, github, figma** | **advocate, skeptic, devils-advocate, domain-expert** | **/council** |
| **Advocate** | **Research Council** | **browser, github** | **—** | **/council (round execution)** |
| **Skeptic** | **Research Council** | **browser, github** | **—** | **/council (round execution)** |
| **Devil's Advocate** | **Research Council** | **browser, github** | **—** | **/council (frame challenge)** |
| **Domain Expert** | **Research Council** | **browser, github, sentry, figma** | **—** | **/council (domain constraints)** |

---

## 11. Division Communication Flow (Examples)

**Scenario:** User runs `/tdd "add rate limiting to the API"`

```
User: /tdd "add rate limiting to the API"
  │
  ▼
Orchestrator
  ├─ Reads learned.jsonl → finds "rate-limiting-pattern" entry from 2 sessions ago
  ├─ Creates task.md entry for this feature
  ├─ Determines: Quality Division + Engineering Division needed
  │
  ├─► [Delegates to] Quality Lead
  │       │
  │       ├─► [Delegates to] SDET
  │       │       ├─ Runs /tdd preamble
  │       │       ├─ Writes failing test: "should return 429 when limit exceeded"
  │       │       ├─ Runs test suite → FAIL (expected)
  │       │       ├─ Returns Result Message to Quality Lead:
  │       │       │     { status: "tests_written", outputs: ["rate-limit.test.ts"] }
  │       │       └─ Quality Lead reports to Orchestrator
  │
  ├─► [Delegates to] Engineering Lead (with test output as input)
  │       │
  │       ├─► [Delegates to] Backend Architect
  │       │       ├─ Reads failing tests to understand required behavior
  │       │       ├─ Checks learned.jsonl for "rate-limiting-pattern" → uses token-bucket approach
  │       │       ├─ Implements rate-limiting middleware
  │       │       ├─ Runs test suite → PASS
  │       │       ├─ Returns Result Message to Engineering Lead:
  │       │       │     { status: "success", outputs: ["rate-limiter.ts", "middleware.ts"] }
  │       │       └─ Engineering Lead reviews output → reports to Orchestrator
  │
  ├─► [Delegates to] Quality Lead (post-implementation)
  │       ├─ SDET verifies coverage did not drop
  │       ├─ Performance Tester runs /benchmark for latency impact
  │       └─ Quality Lead reports: "Quality gate passed"
  │
  └─► Orchestrator runs /review
          ├─ Security Engineer runs security sub-review (parallel)
          ├─ Orchestrator scores 6 dimensions → 8.7/10
          ├─ Writes pattern to learned.jsonl: "token-bucket-rate-limit"
          └─ GitHub MCP creates PR with generated description
```

Total user interactions: **1** (the initial `/tdd` command). Everything else is autonomous.

---

## 12. Multi-Tool Compatibility Layer

> **Goal:** The agentic system works identically whether you open it in Antigravity, Claude Code, Cursor, OpenCode, or OpenAI Codex. No manual re-configuration per tool.

---

### 12.1 The Core Principle: One Source, Many Readers

```
+------------------------------------------------------------------+
|              CANONICAL SOURCE (tool-agnostic)                    |
|                                                                  |
|   .agents/                                                       |
|     +-- MANIFEST.md         <- Skill routing + system state      |
|     +-- PROJECT.md          <- Project-specific rules            |
|     +-- rules/global.md     <- 12 Ironclad Rules                 |
|     +-- personas/           <- Agent role definitions            |
|     +-- commands/           <- Composite skill definitions       |
|     +-- sessions/           <- Session state                     |
|                                                                  |
+------------------------------------------------------------------+
|         AUTO-GENERATED COMPATIBILITY SHIMS (never edit)          |
|                                                                  |
|   CLAUDE.md           <- Claude Code reads this                  |
|   AGENTS.md           <- OpenCode + OpenAI Codex read this       |
|   .cursor/rules/                                                 |
|     +-- agents.mdc    <- Cursor reads this                       |
+------------------------------------------------------------------+
```

**Critical rule:** `CLAUDE.md`, `AGENTS.md`, and `.cursor/rules/agents.mdc` are **never edited by hand**. They are generated outputs of `/sync-adapters`. Any manual edit will be overwritten on the next sync. All real changes go into `.agents/`.

---

### 12.2 Tool Reading Formats

| Tool | Context File | Location | Format | Notes |
|------|-------------|---------|--------|-------|
| **Antigravity** | `.agents/MANIFEST.md` + full `.agents/` tree | Project root | Plain markdown | Native — reads our structure directly. No shim needed. |
| **Claude Code** | `CLAUDE.md` | Project root + any subdirectory | Plain markdown | Claude Code reads all `CLAUDE.md` files recursively. Can have per-directory variants. |
| **Cursor** | `.cursor/rules/*.mdc` | `.cursor/rules/` directory | Markdown + YAML frontmatter | Can have multiple rule files with different `globs` and `alwaysApply` settings. |
| **OpenCode** | `AGENTS.md` | Project root + parent directories | Plain markdown | Also reads `AGENTS.md` in parent dirs — closest to root wins. |
| **OpenAI Codex** | `AGENTS.md` | Project root | Plain markdown | Same format as OpenCode. One file, project root only. |

---

### 12.3 The `/sync-adapters` Skill

Owned by the **Orchestrator**. Run this:
- After any change to `.agents/MANIFEST.md`
- After any change to `.agents/PROJECT.md`
- After any change to `.agents/rules/global.md`
- Before committing the repo (optionally hooked into pre-commit)

**What it generates:**

#### `CLAUDE.md` (for Claude Code)
```
Generated from:
  .agents/MANIFEST.md        -> routing table section
  .agents/rules/global.md    -> ironclad rules block
  .agents/PROJECT.md         -> project stack + conventions
  .agents/commands/*.md      -> skill catalog summary

Structure of generated CLAUDE.md:
  # Project: <name>
  ## How This Codebase Works
  ## Agent Routing (which command does what)
  ## Ironclad Rules (must follow)
  ## Project Stack & Conventions
  ## Key Commands
```

#### `AGENTS.md` (for OpenCode + Codex)
```
Generated from:
  .agents/MANIFEST.md        -> routing table
  .agents/PROJECT.md         -> stack + conventions
  .agents/rules/global.md    -> rules

Structure of generated AGENTS.md:
  # <Project Name> - Agent Instructions
  ## Codebase Overview
  ## How to Run / Test
  ## Commands & Routing
  ## Rules
  ## Project Conventions
```

#### `.cursor/rules/agents.mdc` (for Cursor)
```
---
description: "Forge Nexus agent system rules and routing"
alwaysApply: true
---

# Agent Routing
<routing table from MANIFEST.md>

# Rules
<ironclad rules condensed>

# Conventions
<from PROJECT.md>
```

---

### 12.4 What Each Tool Can and Cannot Use

Not every tool supports everything. This table shows what each tool gets when running in this system:

| Capability | Antigravity | Claude Code | Cursor | OpenCode | Codex |
|-----------|:-----------:|:-----------:|:------:|:--------:|:-----:|
| Full agent division hierarchy | YES Native | YES via CLAUDE.md | YES via .mdc | YES via AGENTS.md | YES via AGENTS.md |
| Skill routing table (MANIFEST) | YES Native | YES Included | YES Included | YES Included | YES Included |
| Ironclad Rules enforcement | YES Native | YES Included | YES Included | YES Included | YES Included |
| Project stack (PROJECT.md) | YES Native | YES Included | YES Included | YES Included | YES Included |
| Learned patterns (learned.jsonl) | YES Reads directly | PARTIAL Reads if instructed | PARTIAL Reads if instructed | PARTIAL Reads if instructed | PARTIAL Reads if instructed |
| Session audit log (audit.jsonl) | YES Writes natively | YES Writes if instructed | YES Writes if instructed | YES Writes if instructed | YES Writes if instructed |
| MCP tool access | YES Full | YES Full (Claude Code MCPs) | PARTIAL Limited (Cursor MCP support) | PARTIAL Tool-dependent | PARTIAL Tool-dependent |
| Sub-agent delegation (multi-agent) | YES Native | YES Native (Claude Code agents) | NO Single-agent only | PARTIAL Experimental | PARTIAL Limited |
| ui-ux-pro-max skills | YES Native | YES via CLAUDE.md pointer | YES via .mdc pointer | YES via AGENTS.md pointer | YES via AGENTS.md pointer |

---

### 12.5 Graceful Degradation

When running in a tool with limited capabilities (e.g. Cursor — no native multi-agent), the system gracefully degrades:

```
Full mode (Antigravity / Claude Code with agents):
  Orchestrator -> Lead -> Specialist -> Result Message -> Audit Log
  Full division hierarchy, parallel agents, learned.jsonl evolution

Degraded mode (single-agent tools like Cursor):
  Single agent reads MANIFEST.md + rules + PROJECT.md
  Executes composite skills sequentially (not in parallel)
  Writes audit.jsonl manually as a file
  Still follows all Ironclad Rules
  Still produces all artifact outputs to correct paths
  -> The output is the same. Only the execution speed differs.
```

This is why the preamble is critical — even in degraded mode, a single Cursor agent reading `MANIFEST.md` + `CLAUDE.md` + the skills knows exactly what to do, in what order, with what guardrails.

---

### 12.6 Per-Tool Notes

**Claude Code** — Best compatibility outside Antigravity. Supports native sub-agents, MCP tool access, and reads `CLAUDE.md` recursively (so we can have `/src/CLAUDE.md` with frontend-specific rules, `/server/CLAUDE.md` with backend-specific rules, all auto-generated by `/sync-adapters`).

**Cursor** — Good for single-agent workflows. `.cursor/rules/agents.mdc` with `alwaysApply: true` ensures the routing table and rules are always in context. Can have multiple `.mdc` files for different file types (e.g., `frontend.mdc` with `globs: ["src/**/*.tsx"]`). Does not support true multi-agent orchestration — all delegation is simulated within a single context.

**OpenCode** — Full `AGENTS.md` support. Reads parent directories, so placing `AGENTS.md` at the project root is sufficient. Good MCP support. Multi-agent capability is experimental but evolving fast.

**OpenAI Codex** — Single-agent, reads `AGENTS.md` at project root. Best for focused single-task execution (implement X, fix Y). Less suited for orchestrating the full division hierarchy — use Antigravity or Claude Code for orchestration sessions.

**Antigravity** — Native mode. Reads `.agents/` directly without any shim. Full multi-agent support, MCP integration, and session memory. This is the **primary tool** for which the system is designed.

---

### 12.7 File Structure with Compatibility Layer

```
<project-root>/
+-- AGENTS.md                    <- [GENERATED] OpenCode + Codex context file
+-- CLAUDE.md                    <- [GENERATED] Claude Code context file
|
+-- .cursor/
|   +-- rules/
|       +-- agents.mdc           <- [GENERATED] Core agent rules (alwaysApply)
|       +-- frontend.mdc         <- [GENERATED] Frontend rules (globs: src/**/*.tsx)
|       +-- backend.mdc          <- [GENERATED] Backend rules (globs: src/server/**)
|
+-- .agents/                     <- [CANONICAL] Never auto-edited by tools
    +-- MANIFEST.md              <- Master routing table + system state
    +-- PROJECT.md               <- Project-specific rules and stack
    +-- rules/
    |   +-- global.md            <- 12 Ironclad Rules
    |   +-- divisions/           <- Per-division tech stack rules
    +-- personas/                <- Agent role definitions
    +-- commands/                <- Composite skill definitions
    +-- skills/                  <- External skills (ui-ux-pro-max, etc.)
    +-- sessions/                <- Session state + audit logs
    +-- audit.jsonl              <- Immutable append-only audit log
    +-- learned.jsonl            <- Cross-session memory
    +-- task.md                  <- Current session task DAG
```

