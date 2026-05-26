# qa-pro-max — Deep Range Testing Intelligence Skill
# .agents/skills/qa-pro-max/SKILL_REGISTRY.md
#
# This skill is the testing intelligence layer for the Quality Division.
# It defines WHAT to test, WHY, in what ORDER, and what to ASSERT.
# It does not dictate which tools to use — tools are declared in PROJECT.md.
#
# Analogous to ui-ux-pro-max for design — this skill prevents shallow testing:
# asserting only HTTP status codes and leaving DB state, side effects, and
# failure modes unverified.

---

## Philosophy

Most AI agents test only what is obvious: the happy-path response code.
A production system requires testing the entire call chain:

```
Input Validation → Service Layer → DB Transaction → Side Effect Queue
→ Worker Execution → Cache Invalidation → Audit Trail → Error Rollback
```

This skill enforces that every layer is verified before code ships.

---

## Sub-Skill Map

### Checklists — WHAT to verify per layer

| Checklist | File | Primary Agents | Activated By |
|---|---|---|---|
| **Frontend** | `checklists/frontend.md` | visual-qa-specialist, qa-automation-engineer, frontend-developer | /e2e, /qa, /qa-only, /design-review |
| **Backend API** | `checklists/backend.md` | sdet, qa-automation-engineer, backend-architect | /tdd, /e2e, /contract, /review |
| **Database** | `checklists/database.md` | sdet, database-engineer, qa-automation-engineer | /tdd, /e2e, /dataaudit |
| **Workers & Queues** | `checklists/workers-queues.md` | sdet, qa-automation-engineer, backend-architect | /e2e, /health |
| **Cache** | `checklists/cache.md` | sdet, qa-automation-engineer | /health, /e2e |
| **Security** | `checklists/security.md` | security-engineer, sdet | /review, /e2e, /pipeline-audit |
| **Pre-Ship Gate** | `checklists/pre-ship.md` | quality-lead, orchestrator | /ship (mandatory gate) |

### Methodologies — HOW to test

| Methodology | File | Primary Consumer | Activated When |
|---|---|---|---|
| **Layer Testing Order** | `methodologies/layer-testing-order.md` | All QA agents | Start of any multi-layer test session |
| **Boundary Analysis** | `methodologies/boundary-analysis.md` | sdet | Before writing any test file |
| **TDD Protocol** | `methodologies/tdd-protocol.md` | sdet | /tdd command |
| **Contract Testing** | `methodologies/contract-testing.md` | sdet, qa-automation-engineer | /contract command |
| **Error Taxonomy** | `methodologies/error-taxonomy.md` | All QA agents | Error path test design |
| **Load Testing** | `methodologies/load-testing.md` | performance-tester | /benchmark command |
| **Chaos Engineering** | `methodologies/chaos-engineering.md` | performance-tester, platform-lead | /health, post-deploy validation |
| **Data Integrity** | `methodologies/data-integrity.md` | sdet, database-engineer | /dataaudit, /e2e DB assertion phase |

### CI/CD Contracts — Pipeline standards

| Contract | File | Enforced By |
|---|---|---|
| **Exit Codes** | `ci-cd/exit-codes.md` | All CI steps |
| **Report Formats** | `ci-cd/report-formats.md` | All test commands |
| **Artifact Layout** | `ci-cd/artifact-layout.md` | All CI runs |
| **Quality Gates** | `ci-cd/gates.md` | /ship, pipeline merge checks |
| **GitHub Actions** | `ci-cd/github-actions.md` | DevOps Engineer, Platform Lead |

### Templates

| Template | File | Used By |
|---|---|---|
| **Test Plan** | `templates/test-plan.md` | sdet, qa-automation-engineer |
| **Bug Report** | `templates/bug-report.md` | All QA agents |
| **Load Test Report** | `templates/load-test-report.md` | performance-tester |

---

## Activation Protocol

When any quality command runs, agents load skills in this order:

```
1. qa-pro-max/SKILL_REGISTRY.md           ← orientation (always first)
2. methodologies/layer-testing-order.md   ← determine which layers apply
3. [relevant checklist per layer]          ← load ONE checklist at a time
4. ci-cd/gates.md                         ← load before reporting any result
```

**Context optimization:** Load only the checklist for the current layer being
tested. Do not load all checklists simultaneously — same principle as
ui-ux-pro-max loading only the matched industry section, not all 161 rules.

---

## Hard Rules (Non-Negotiable)

1. **Layer order is mandatory** — database layer tested before E2E (inside-out)
2. **DB assertions are required** — HTTP response codes alone are never sufficient
3. **Side effects must be verified** — events, emails, cache, audit log
4. **Exit code 0 = success only** — `|| true` is a hard block in all CI scripts
5. **Pre-ship checklist runs before every /ship** — no exceptions
6. **Mocks represent real data shapes** — no `{}` or `"test"` placeholder values
7. **Flaky tests are quarantined** — never silently retried
8. **Test selectors use data-testid** — never CSS classes, never visible text
