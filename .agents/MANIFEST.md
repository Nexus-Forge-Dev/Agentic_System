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
Updated:   2026-05-25T03:21:15Z
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
| Intelligence | Learned patterns (active) | `.agents/learned.jsonl` |
| Intelligence | Learned patterns (archived) | `.agents/learned_archive.jsonl` |
| All agents | Audit trail | `.agents/audit.jsonl` |
| All agents | Token costs | `.agents/cost.jsonl` |

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

## System State

```
Current Session:   [updated by Orchestrator on session start]
Last /retro:       [date of last retrospective]
Last /sync-adapters: 2026-05-25T03:21:15Z
Learned Patterns:  [count from learned.jsonl]
Active Issues:     [count of open GitHub issues filed by agents]
```
