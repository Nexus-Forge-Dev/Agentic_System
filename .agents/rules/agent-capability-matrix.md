# Agent Capability Matrix
# .agents/rules/agent-capability-matrix.md
# Authority: LAYER 2 — Reference for all agents
# Source: agents_and_skills_design.md §10

---

## Capability Matrix

Quick reference for what each agent can do and what tools they can access.

| Agent | Division | MCP Access | Can Delegate To | Key Commands |
|-------|----------|-----------|-----------------|-------------|
| **Orchestrator** | Executive | github | all leads | /plan, /review, /autoplan, /learn, /council, /status, /dashboard, /context-save, /context-restore, /sync-adapters, /plan-tune |
| **Engineering Lead** | Engineering | github | frontend-developer, backend-architect, database-engineer | /investigate, /codex, /document-generate |
| **Frontend Developer** | Engineering | github, figma | — | /design-html (internal), /design-review |
| **Backend Architect** | Engineering | github, docker, sentry | database-engineer | /investigate, /benchmark |
| **Database Engineer** | Engineering | sentry, github | — | /investigate, /benchmark |
| **Platform Lead** | Platform | github, terraform, docker, k8s, sentry | devops-engineer, cloud-architect, security-engineer, incident-commander | /deploy |
| **DevOps Engineer** | Platform | github, docker, k8s | — | /ship, /land-and-deploy, /canary, /document-release, /pipeline-generate, /pipeline-audit |
| **Cloud Architect** | Platform | terraform, github | — | /deploy, /health |
| **Security Engineer** | Platform | github, docker | — | /review (security sub-task), /investigate (security angle) |
| **Incident Commander** | Platform | sentry, k8s, github | — | /incident, /canary, /smoke |
| **Quality Lead** | Quality | github, sentry | sdet, performance-tester, visual-qa-specialist, qa-automation-engineer | /health, /tdd |
| **SDET** | Quality | github, sentry | — | /tdd, /qa, /qa-only, /health |
| **Performance Tester** | Quality | sentry, github | — | /benchmark |
| **Visual QA Specialist** | Quality | figma, github | — | /design-review |
| **QA Automation Engineer** | Quality | database, github, sentry, playwright | — | /e2e, /validate, /smoke, /contract, /dataaudit, /seed, /teardown |
| **Design Lead** | Design | figma | ui-designer, ux-researcher, design-systems-engineer, animator | /plan-design-review |
| **UI Designer** | Design | figma | — | /design-consultation, /plan-design-review, /design-shotgun |
| **UX Researcher** | Design | — | — | /office-hours, /plan-devex-review |
| **Design Systems Engineer** | Design | figma, github | — | /design, /design-consultation |
| **Animator** | Design | figma | — | (inline micro-interaction work — no dedicated slash command) |
| **Intelligence Lead** | Intelligence | sentry | session-analyst, optimization-architect | /retro, /learn |
| **Session Analyst** | Intelligence | — | — | /retro, /learn, /status, /dashboard |
| **Optimization Architect** | Intelligence | sentry | — | (analysis + cost optimization recommendations) |
| **Moderator** | Research Council | browser, github, figma | advocate, skeptic, devils-advocate, domain-expert | /council |
| **Advocate** | Research Council | browser, github | — | /council (round execution — FOR position) |
| **Skeptic** | Research Council | browser, github | — | /council (round execution — AGAINST position) |
| **Devil's Advocate** | Research Council | browser, github | — | /council (frame challenge) |
| **Domain Expert** | Research Council | browser, github, sentry, figma | — | /council (domain constraints, assigned per topic) |

---

## Delegation Rules

```
ALLOWED PATHS:
  Orchestrator → Any Division Lead
  Division Lead → Its own Specialists
  Specialists → (no delegation — they execute)

FORBIDDEN PATHS:
  Specialist → Any other Specialist (cross or same division)
  Specialist → Division Lead of ANOTHER division
  Division Lead → Division Lead of another division
  Orchestrator → Specialist directly (must go through Lead)
```

---

## MCP Access Privileges

### Available MCP Servers

| MCP Server | Purpose | Approval Tier |
|-----------|---------|--------------|
| `github` | Repos, PRs, issues, commits, workflows | Reads: Tier 1 / Writes: Tier 2 |
| `figma` | Design frames, component specs | Reads: Tier 1 |
| `docker` | Images, containers, registries | Reads: Tier 1 / Push: Tier 2 |
| `terraform` | Infrastructure plans and apply | Plan: Tier 1 / Apply: Tier 2 |
| `kubernetes` / `k8s` | Cluster resources, deployments, pods | Reads: Tier 1 / Apply: Tier 2 |
| `sentry` | Error tracking, alerts, performance | Reads: Tier 1 |
| `database` | SQL queries against connected DB | SELECT: Tier 1 / DML: Tier 2 |
| `playwright` | Browser automation for E2E testing | Tier 1 (testing only) |
| `browser` | Web page fetching and crawling | Tier 1 (read) |

---

## Graceful Degradation

When running in a tool with limited capabilities:

```
Full mode (Antigravity / Claude Code with agents):
  Orchestrator → Lead → Specialist → Result Message → Audit Log
  Full division hierarchy, parallel agents, learned.jsonl evolution

Degraded mode (single-agent tools like Cursor):
  Single agent reads MANIFEST.md + all rules + PROJECT.md
  Executes composite skills sequentially (not in parallel)
  Writes audit.jsonl manually as a file
  Still follows all 12 Ironclad Rules
  Still produces all artifact outputs to correct paths
  → The output is the same. Only the execution speed differs.

Key insight: Even in degraded mode, a single Cursor agent reading
MANIFEST.md + CLAUDE.md + the skills knows exactly what to do,
in what order, with what guardrails.
```
