# Command: /brief
# .agents/commands/brief.md
# Owner: Orchestrator → assigns to specialist
# Trigger: /brief "<task>" — auto-triggered for all tasks with brief_required: true
# Source: agents_and_skills_design.md §4 — Implementation Brief System

---

## Purpose

Produce an Implementation Brief before any execution begins for a risky task.
The brief is written by the specialist who will execute the task.
A written intent before action prevents scope creep, surprise side effects, and drift.

---

## §4.3 Brief Trigger Table

When is a brief required?

| Scenario | Brief Required? | Brief Level |
|----------|----------------|-------------|
| Any task that modifies auth, payments, or security-critical code | ✅ MANDATORY | Full |
| Any database schema change (CREATE, ALTER, DROP) | ✅ MANDATORY | Full |
| Any task touching > 3 files | ✅ MANDATORY | Full |
| Any production deployment | ✅ MANDATORY | Full |
| Any external API integration | ✅ MANDATORY | Full |
| Risk score = HIGH or CRITICAL | ✅ MANDATORY | Full |
| Risk score = MEDIUM and 2–3 files | ✅ MANDATORY | Abbreviated |
| Bug fix touching 1–2 files with clear scope | ⚠️ OPTIONAL | One-liner |
| Adding a comment or docstring | ❌ NONE | — |
| Renaming a local variable | ❌ NONE | — |
| Formatting-only change | ❌ NONE | — |
| Reading-only task (no files written) | ❌ NONE | — |

---

## §4.2 Risk Scoring — 4 Dimensions

Risk level is computed as the MAX across 4 dimensions (not an average):

### Dimension 1: Surface Area

| Files Touched | Score |
|--------------|-------|
| 1 file | LOW |
| 2–3 files | MEDIUM |
| 4–7 files | HIGH |
| 8+ files | CRITICAL |

### Dimension 2: File Criticality

| File Type / Location | Score |
|---------------------|-------|
| Test files only | LOW |
| Configuration files (.env, package.json) | MEDIUM |
| Core business logic (services, controllers) | HIGH |
| Auth, payment, security, database schema | CRITICAL |

### Dimension 3: Operation Type

| Operation | Score |
|-----------|-------|
| Read-only, no writes | LOW |
| Add new file (no edits to existing) | LOW |
| Modify existing non-critical file | MEDIUM |
| Modify critical file OR add migration | HIGH |
| Delete, truncate, or irreversible modify | CRITICAL |

### Dimension 4: Reversibility

| Reversibility | Score |
|--------------|-------|
| Fully reversible (git revert is sufficient) | LOW |
| Reversible with effort (migration rollback needed) | MEDIUM |
| Difficult to reverse (data transformation, cache clear) | HIGH |
| Irreversible (external API call, deployed artifact, prod DB write) | CRITICAL |

**Overall Risk** = `MAX(Dimension1, Dimension2, Dimension3, Dimension4)`

---

## §4.4 Approval Routing

Based on overall risk level:

| Risk Level | Approval Required | Who Approves |
|-----------|------------------|-------------|
| LOW | ❌ Auto-approved | None needed — execute immediately |
| MEDIUM | ⚠️ Division Lead | Division Lead reviews brief before execution |
| HIGH | ✅ Orchestrator | Orchestrator reviews + confirms before delegation |
| CRITICAL | 🔴 HUMAN REQUIRED | Human must explicitly approve — no agent can bypass |

---

## §4.5 Brief Audit Sequence

The following events MUST be logged to `audit.jsonl` in this order:

```jsonl
{"ts":"...","action":"brief","task_id":"task_<ulid>","agent":"<role>","risk":"HIGH","files":["src/auth.ts","prisma/schema.prisma"]}
{"ts":"...","action":"brief_approved","task_id":"task_<ulid>","approved_by":"orchestrator | user | division-lead","notes":"..."}
{"ts":"...","action":"file_write","task_id":"task_<ulid>","agent":"<role>","file":"src/auth.ts"}
{"ts":"...","action":"brief_completed","task_id":"task_<ulid>","agent":"<role>","drift":false,"actual_files":["src/auth.ts","prisma/schema.prisma"]}
```

`drift: true` is set in `brief_completed` if any file was touched that was NOT listed in the brief.

---

## Brief Schema

The specialist assigned to this task writes and returns this document:

```markdown
# Implementation Brief — <task title>
Agent: <role>
Task ID: <task_id from task.md>
Date: <ISO>
Risk Level: LOW | MEDIUM | HIGH | CRITICAL
Approval Required: AUTO | DIVISION_LEAD | ORCHESTRATOR | HUMAN

## What I Will Do
<1-2 sentence summary of the exact change>

## Files I Will Touch
| File | Operation | Why |
|------|-----------|-----|
| src/services/auth.ts | MODIFY | Add rate-limit check to login handler |
| prisma/schema.prisma | MODIFY | Add rate_limit_events table |
| tests/auth.test.ts | CREATE | Tests for new rate-limit behavior |

## Files I Will NOT Touch
<All other files in the same module are NOT touched>
(This is the drift boundary — any unlisted file touched = drift event)

## Functions/Endpoints Changed
| Name | File | Change Type | Reason |
|------|------|-------------|--------|
| handleLogin() | auth.ts | MODIFY | Add rate check before credential validation |
| POST /api/auth/login | routes/auth.ts | MODIFY | Apply rate-limit middleware |

## Risk Assessment
- Surface area (files): 3 files → Dimension 1: MEDIUM
- File criticality: auth.ts (CRITICAL — auth system), schema (CRITICAL — DB change)
- Operation type: MODIFY + migration → Dimension 3: HIGH
- Reversibility: git revert + migration rollback → Dimension 4: MEDIUM
- **Overall Risk (MAX): CRITICAL**

## Side Effects
- Adds new DB table (rate_limit_events)
- Requires prisma migrate deploy on next deployment
- No cache invalidation needed
- No external API calls

## Rollback Plan
1. git revert <commit> — reverts all code changes
2. Run: prisma migrate resolve --rolled-back <migration-name>
3. Verify: run smoke test suite
4. Estimated rollback time: ~10 minutes

## Open Questions
- None / <specific questions that must be answered before proceeding>

## Approval Required
CRITICAL — Human approval required before any file is touched
```

---

## Guardrails

- No agent starts execution on a `brief_required: true` task until the brief is accepted
- Brief must be LOGGED to audit.jsonl (`{"action":"brief","..."}`) before any file is touched
- `brief_approved` entry must appear in audit.jsonl before first file write
- `brief_completed` entry written after task completes, with `drift` field
- If a specialist cannot write a brief (doesn't understand the task) → BLOCKED, escalate
- CRITICAL risk tasks: agent MUST STOP and wait for explicit human approval — no auto-proceed
