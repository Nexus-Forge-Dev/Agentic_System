# Forge Nexus Agentic System — MANIFEST
# .agents/MANIFEST.md
#
# The master routing table and system state document.
# Every agent reads this on every pre-flight check.
# Only the Orchestrator writes to this file.

---

## System Identity

```
System:    Forge Nexus Agentic System
Version:   1.0.0
Canonical: .agents/ (this directory)
Adapters:  CLAUDE.md | AGENTS.md | .cursor/rules/agents.mdc
Updated:   2026-06-28T19:00:00Z
```

---

## Division Registry

| Division | Lead Role | Specialists | Domain |
|----------|-----------|-------------|--------|
| Engineering | Engineering Lead | Frontend Developer, Backend Architect, Database Engineer | Code implementation, APIs, data |
| Platform / Infrastructure | Platform Lead | DevOps Engineer, Cloud Architect, Security Engineer, Incident Commander | CI/CD, cloud, security, reliability |
| Quality | Quality Lead | SDET, Performance Tester, Visual QA Specialist, QA Automation Engineer | Tests, coverage, performance, visual fidelity |
| Design | Design Lead | UI Designer, UX Researcher, Design Systems Engineer, Animator | UI/UX, design system, brand |
| Intelligence | Intelligence Lead | Session Analyst, Optimization Architect | Memory, learning, cost optimization |
| Research Council | Moderator | Advocate, Skeptic, Devil's Advocate, Domain Expert | High-stakes decisions, adversarial research |

---

## Skill Routing Table

Use this table to determine which skill / division to activate for any situation.

```
Situation                                             -> Skill / Division
----------------------------------------------------- -> --------------------------------
User has a new idea or goal                           -> /office-hours  (UX Researcher)
User wants to scope and plan work                     -> /plan          (Orchestrator)
User wants full pre-build review                      -> /autoplan      (Orchestrator)
User wants to build a UI component                    -> /design        (Design -> Engineering)
User wants TDD implementation                         -> /tdd           (Quality -> Engineering)
User wants to audit existing code                     -> /review        (Orchestrator + Security)
User wants to debug a production bug                  -> /investigate   (Engineering)
User wants to ship code to a PR                       -> /ship          (DevOps)
User wants to deploy to an environment                -> /deploy        (Platform Lead)
User wants to generate a CI/CD pipeline               -> /pipeline-generate (DevOps)
User wants to audit an existing pipeline              -> /pipeline-audit    (DevOps)
Production is broken / incident                       -> /incident      (Incident Commander)
User wants full system health check                   -> /health        (Quality Lead)
User wants E2E / black-box validation                 -> /e2e           (QA Automation Engineer)
User wants smoke test after deploy                    -> /smoke         (QA Automation Engineer)
User wants API contract test                          -> /contract      (QA Automation Engineer)
User wants DB data integrity audit                    -> /dataaudit     (QA Automation Engineer)
User wants test data seeded                           -> /seed          (QA Automation Engineer)
User needs a structured specification brief for a task  -> /brief-generate  (Any agent - generates skills/commands/files/tests/acceptance brief)
User needs to delegate a task to another agent           -> /delegate       (Orchestrator or Division Lead - full delegation lifecycle with trace)
User wants to execute tasks from the DAG sequentially    -> /sequential-execute (Orchestrator or Division Lead - execution queue manager)
Session is ending / save memory                       -> /learn + /retro (Intelligence)
High-stakes decision with real trade-offs             -> /council       (Research Council)
Choosing between two architectures                    -> /council       (Research Council)
Evaluating a new technology or vendor                 -> /council       (Research Council)
Reviewing a research paper's claims                   -> /council       (Research Council)
Two divisions disagree on approach                    -> /council       (Research Council)

-- General-Purpose Primitives (any agent, any situation) --
Need full content from a webpage                      -> browse_url
Need ALL content from a docs site / domain            -> crawl_site (depth 1-5)
Need to find something online                         -> search_web -> browse_url
Need to read a PDF, DOCX, XLSX, CSV file              -> read_document
Need to call an external API                          -> api_call (Tier 2 approval required)
Need to validate a JSON/YAML payload                  -> validate_schema
Need to convert data between formats                  -> transform_data
Need to query the project database (read-only)        -> query_db (SELECT auto-approved)
Need to find a function/class across the codebase     -> search_code (semantic mode)
Need to trace who calls / what a function calls       -> trace_call
Need to explain code to a non-technical stakeholder   -> explain_code (audience=non-tech)
Need to condense a large document or crawl result     -> summarize
Need to compare two versions of a file or spec        -> diff_content (semantic mode)
Need to draft a message, spec, or issue               -> draft (human approves before send)
```

---

## Communication Protocol

```
ALLOWED:   Specialist -> Division Lead (within same division)
ALLOWED:   Division Lead -> Orchestrator
ALLOWED:   Orchestrator -> any Division Lead (cross-division)
FORBIDDEN: Specialist (Div A) -> Specialist (Div B)   [direct cross-division]
FORBIDDEN: Lead (Div A) -> Lead (Div B)               [direct cross-division]
FORBIDDEN: Orchestrator -> Specialist (skipping Lead) [skip-level]
```

All Result Messages use the structured schema defined in `.agents/rules/global.md`.

---

## File Locations — Where Each Agent Writes

| Agent | Primary Output | Location |
|-------|---------------|----------|
| Frontend Developer | Component code | `src/components/` |
| Backend Architect | Service / route code | `src/services/`, `src/routes/` |
| Database Engineer | Migration + schema | `prisma/migrations/`, schema file |
| SDET | Test files | `tests/`, `__tests__/` |
| QA Automation Engineer | E2E results + DB report | `.agents/reports/e2e-<ts>.md` |
| Security Engineer | Security audit report | `.agents/reports/security-<ts>.md` |
| Performance Tester | Benchmark report | `.agents/reports/benchmark-<ts>.md` |
| Visual QA Specialist | Screenshot diff report | `.agents/reports/visual-<ts>.md` |
| Design Lead | Design brief | `.agents/reports/design-brief-<ts>.md` |
| DevOps Engineer | Pipeline YAML | `.github/workflows/` |
| DevOps Engineer | Pipeline audit | `.agents/reports/pipeline-audit-<ts>.md` |
| Session Analyst | Session dashboard | `.agents/sessions/<id>/dashboard.md` |
| Animator | Animation spec + implementation | `src/components/` (motion layer added) |
| Optimization Architect | Cost/efficiency report | `.agents/reports/optimization-<ts>.md` |
| Research Council | Verdict | `.agents/council/verdicts/<ts>-<slug>.md` |
| Research Council | Full session transcript | `.agents/council/sessions/<council-id>/positions/` |
| Research Council | Evidence manifest | `.agents/council/sessions/<council-id>/evidence_manifest.json` |
| Incident Commander | Postmortem | `.agents/reports/postmortem-<ts>.md` |
| Orchestrator | Task DAG | `.agents/task.md` |
| Orchestrator | Task plan DAG (JSON) | `.agents/plans/<prompt_id>.plan.json` |
| Orchestrator | Delegation queue | `.agents/queue/<prompt_id>/<task_id>/` (brief.json, status.json, output.json, trace.jsonl) |
| Intelligence | Learned patterns (active) | `.agents/learned.jsonl` |
| Intelligence | Learned patterns (archived) | `.agents/learned_archive.jsonl` |
| All agents | Audit trail | `.agents/audit.jsonl` |
| All agents | Token costs | `.agents/cost.jsonl` |

---

## Plans — Task DAG Specification

Task plans are JSON files conforming to the `prompt-plan-v1` schema, validated by script:

```
.agents/plans/
├── <prompt_id>.plan.json   # DAG with tasks, deps, agents, risk scores
└── plan.schema.md          # Schema specification (13 validation rules)
```

**Workflow:**
1. ORCHESTRATOR writes `.agents/plans/<prompt_id>.plan.json` (prompt-plan-v1 schema)
2. `.agents/scripts/plan-validator.ps1` validates against 13 rules (IDs, deps, cycles, agents)
3. `.agents/scripts/plan-scaffold.ps1` creates queue directories from the plan
4. Tasks are briefed individually via `/brief-generate`
5. Tasks are executed sequentially via `/sequential-execute`

See `.agents/schemas/plan.schema.md` for the full schema specification.

---

## Queue Protocol — Delegation Handoff Surface

All cross-agent delegation uses the **queue protocol**: a filesystem-based, runtime-agnostic
handoff standard. Tasks are grouped by **prompt_id** (from the plan), so each delegated task
has its own directory under `.agents/queue/<prompt_id>/<task_id>/`.

```
.agents/queue/
├── <prompt_id>/
│   ├── <task_id>/
│   │   ├── brief.json        # Task specification (skills, files, tests, acceptance)
│   │   ├── context.json      # Handoff packet (prior outputs, relevant memories)
│   │   ├── status.json       # State machine: pending → in_progress → completed|failed|blocked
│   │   ├── output.json       # Final result (files written, test results, QG score)
│   │   └── trace.jsonl       # Subagent execution trace (JSONL per significant action)
│   └── <task_id>/            # (next task under same prompt)
├── prompt_adhoc/             # Tasks not part of a plan
│   └── <task_id>/
├── archive/                  # Completed/archived tasks (preserves prompt grouping)
│   └── <prompt_id>/
│       └── <task_id>/
└── index.json                # Queue index (v2: prompt-grouped, all active + archived items)
```

**Lifecycle:** See `.agents/schemas/queue.schema.md` (v2) for full state machine, validation rules,
and runtime adapter patterns. See `.agents/scripts/queue-manager.ps1` for queue operations
(New-QueueItem, Set-QueueStatus, Write-QueueOutput, etc.) with v2 index support and
`Resolve-TaskPath` for prompt-grouped path resolution. See
`.agents/scripts/delivery-adapter.ps1` for bridging briefs to runtime-specific Task prompts
(with `Resolve-TaskPath` fallback layers).

---

## MCP Tool Registry

| Tool | Agents With Access | Purpose |
|------|--------------------|---------|
| `github` | Orchestrator, Engineering Lead, Frontend, Backend, Quality Lead, SDET, Visual QA, DevOps, Security, Incident | Git ops, PR, issues |
| `docker` | DevOps, Security, Platform Lead, Backend | Build, push, CVE scan |
| `kubernetes` | DevOps, Platform Lead, Incident Commander | Deploy, rollback, status |
| `terraform` | Cloud Architect, Platform Lead, DevOps | IaC plan/apply |
| `sentry` | Incident Commander, Platform Lead, Performance Tester, Quality Lead, Backend, Database, Intelligence Lead | Error tracking, performance |
| `figma` | Visual QA, Frontend Developer, UI Designer, Design Lead, Research Council | Design assets, frames |
| `database` | QA Automation Engineer, Database Engineer | DB state validation (read-only default) |
| `playwright` | QA Automation Engineer, SDET | Browser-driven E2E testing |
| `browser` | Research Council (Moderator) | Research, documentation crawling |

Config files: `.agents/mcp/settings.json` — per-tool permission tiers, rate limits, retry policies, cache TTLs, allowed agents list.

---

## Auto-Checkpoint Policy

For long-running sessions, the system maintains automatic checkpoints:

```
TRIGGER: Every 10 tool calls executed by any agent in a session

ACTION:
  1. Orchestrator writes a checkpoint entry to task.md:
     [CHECKPOINT] <timestamp> — <N tool calls> executed, <M tasks> done, <K pending>
  2. Extracts last 50 lines from audit.jsonl
  3. Saves partial snapshot to:
       .agents/sessions/<session-id>/checkpoints/<N>.md
     Contents: current task states, agent in progress, files modified so far

PURPOSE:
  - If the session crashes or times out, work can be resumed from the nearest checkpoint
  - Checkpoints are LIGHTWEIGHT — they do not snapshot the full context window
  - They serve as breadcrumbs for /context-restore to reconstruct what happened

MANUAL TRIGGER:
  - User can always run /context-save to force a full snapshot
  - /context-save > auto-checkpoint (more complete)

CLEANUP:
  - Checkpoints are deleted on /context-save (replaced by the full snapshot)
  - Checkpoints older than 48 hours are purged on next /retro
```

---

## Runtime Status

```
Multi-Agent Runtime:    ACTIVE
Agent Registry:         28 personas defined in .agents/personas/ — delegated
                        via Orchestrator → Division Lead → Specialist chain
Command Registry:       52 commands defined in .opencode/commands/ — classified
                        by Orchestrator against the routing table above
Skills Path:           .agents/skills/ + .claude/skills/
Scripts Path:          .agents/scripts/ — plan-validator.ps1, plan-scaffold.ps1,
                        queue-manager.ps1 (v2), delivery-adapter.ps1 (v2),
                        checkpoint.ps1, qg_enforcer.ps1, trace_completeness.ps1,
                        tdd_order.ps1
Schema Path:           .agents/schemas/ — plan.schema.md (prompt-plan-v1),
                        queue.schema.md (v2: prompt-grouped), trace.schema.md
Intent Routing:        Raw prompts classified and routed by Orchestrator
```

**MCP Tool Scoping:** The MCP Tool Registry below specifies design intent
for which agents are expected to use which tools. Runtime enforcement depends
on the adapter (CLAUDE.md / AGENTS.md / .cursor/rules/) and tool configuration
for the specific environment.

## System State

```
Current Session:      sess_20260628_fix-gaps (agenda.md)
Last /retro:          [none yet]
Last /sync-adapters:  2026-06-15T21:00:00Z
Learned Patterns:     [count from learned.jsonl]
Active Issues:        [count of open GitHub issues filed by agents]
Queue Index Version:  1 (auto-migrates to v2 on first script access)
Plans Directory:      .agents/plans/ — contains 0 plan files
Queue Layout:         .agents/queue/<prompt_id>/<task_id>/ (v2 structure)
```
