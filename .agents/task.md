# Current Session Task DAG
# .agents/task.md
# Single source of truth for all work in the current session
# Updated by Orchestrator — every task lifecycle is tracked here

---

## Session: sess_20260628_fix-gaps
**Goal:** Fix all gaps in the decomposition pipeline, prove queue protocol works end-to-end, then build test suite
**Started:** 2026-06-28T19:15:00Z
**Status:** IN_PROGRESS
**Prior session:** sess_20260628_phase1 (redesign completed, but gaps remained)

---

## System State (as of session start)

### What's Been Built (Redesign — Complete)
| Component | Status | Notes |
|-----------|--------|-------|
| Queue protocol schema (queue.schema.md) | ✅ Complete | 425 lines, 6 file schemas, state machine, validation rules |
| Queue manager script (queue-manager.ps1) | ✅ Complete | 482 lines, 9 operations, transition validation, index sync |
| Delivery adapter (delivery-adapter.ps1) | ✅ Complete | 297 lines, 3 actions, delegation chain validation |
| Trace schema (trace.schema.md) | ✅ Complete | 144 lines, unified JSONL format, 11 entry types |
| Trace index (traces/index.json) | ✅ Complete | v3 format, 36 sessions, exec-only with sub_execution type |
| /delegate command (delegate.md) | ✅ Complete | 341 lines, 10-step queue protocol flow |
| /sequential-execute command (sequential-execute.md) | ✅ Complete | 248 lines, queue protocol execution loop |
| Validators (checkpoint.ps1 + 3 sub-scripts) | ✅ Complete | ~2000 lines total, trace completeness, TDD order, QG enforcement |
| Learned patterns (learned.jsonl) | ✅ Complete | 53 entries including queue protocol, delivery adapter, trace unification |
| Manifest (MANIFEST.md) | ✅ Updated | Queue directory structure + Queue Protocol section added |
| Orchestrator persona (orchestrator.md) | ✅ Updated | Queue protocol flow diagram, delegation patterns, hard rules |

### What's NOT Been Run (Redesign — Never Executed)
| Gap | Impact | Severity |
|-----|--------|----------|
| `.agents/queue/` didn't exist until now | No task has ever been queued | HIGH |
| `queue-manager.ps1` has never executed | Script is untested in real use | HIGH |
| `delivery-adapter.ps1` has never executed | Bridge is untested | HIGH |
| No real Task tool delegation via queue protocol | Full pipeline unproven | HIGH |

### Stale Components (Redesign — Left Behind)
| Component | Problem | Fix Status |
|-----------|---------|------------|
| `plan.md` | Still writes `.plan.json` (deleted format), v2 index, no queue init | 🔧 PENDING |
| `brief.md` | Old markdown format, no queue awareness | 🔧 PENDING |
| `brief-generate.md` | Produces JSON to stdout, not to queue directory | 🔧 PENDING |
| `tdd.md` | References nonexistent `qa-pro-max` skill, old chain | 🔧 PENDING |
| `checkpoint.ps1` | Tests 300-308 looks for deleted `agent_sessions/` dir | 🔧 PENDING |
| `task.md` (this file) | Showed old Phase 1 DAG, not actual state | 🔧 PENDING |

---

## Task DAG (Current Session)

```
Fix Gaps ──┬── Batch 1: Quick Wins
            │   ├── 1.1 Create queue directory ── DONE
            │   ├── 1.2 Rewrite task.md ── IN PROGRESS
            │   ├── 1.3 Deprecate brief.md
            │   └── 1.4 Fix checkpoint.ps1 stale ref
            │
            ├── Batch 2: Pipeline Repairs
            │   ├── 2.1 Rewrite plan.md (no .plan.json, add queue init)
            │   ├── 2.2 Rewrite brief-generate.md (write to queue)
            │   └── 2.3 Rewrite tdd.md (remove stale refs)
            │
            ├── Batch 3: Prove Queue Protocol
            │   ├── 3.1 New-QueueItem
            │   ├── 3.2 Set-QueueStatus lifecycle
            │   ├── 3.3 delivery-adapter generate-prompt
            │   ├── 3.4 Write-QueueOutput
            │   ├── 3.5 Archive-QueueItem
            │   └── 3.6 Verification + trace log
            │
            └── Batch 4: Build Test Suite
                ├── 4.1 test-runner.ps1
                ├── 4.2 Contract tests (queue + trace schemas)
                ├── 4.3 Unit tests (all 6 scripts)
                ├── 4.4 Integration tests (command flows)
                ├── 4.5 E2E agent evals
                └── 4.6 Rule enforcement tests
```

---

## Execution Order
`Batch 1 → Batch 2 → Batch 3 → Batch 4` (strictly sequential — each batch depends on prior)

---

## Task Register

- [x] **1.1** → orchestrator: Create `.agents/queue/` with initial `index.json`
- [ ] **1.2** → orchestrator: Rewrite `task.md` — reflect actual system state, document gaps
- [ ] **1.3** → orchestrator: Deprecate old `brief.md`, redirect to `brief-generate.md`
- [ ] **1.4** → orchestrator: Fix `checkpoint.ps1` stale `agent_sessions/` path reference
- [ ] **2.1** → orchestrator: Rewrite `plan.md` — remove `.plan.json`, v2 index; add queue init step
- [ ] **2.2** → orchestrator: Rewrite `brief-generate.md` — write brief to `.agents/queue/<task_id>/brief.json`
- [ ] **2.3** → orchestrator: Rewrite `tdd.md` — remove stale `qa-pro-max` refs, add queue protocol
- [ ] **3.1** → orchestrator: Run `queue-manager.ps1 New-QueueItem` with valid brief
- [ ] **3.2** → orchestrator: Run `Set-QueueStatus` through full lifecycle (pending→in_progress→completed)
- [ ] **3.3** → orchestrator: Run `delivery-adapter.ps1 generate-prompt` from queued brief
- [ ] **3.4** → orchestrator: Run `Write-QueueOutput` from mock result
- [ ] **3.5** → orchestrator: Run `Archive-QueueItem` — complete lifecycle
- [ ] **3.6** → orchestrator: Verify queue index, trace entries, produce proof report
- [ ] **4.1** → orchestrator: Build `test-runner.ps1` — unified test discovery and execution
- [ ] **4.2** → orchestrator: Build contract tests (queue protocol + trace schema)
- [ ] **4.3** → orchestrator: Build unit tests (all 6 PowerShell scripts)
- [ ] **4.4** → orchestrator: Build integration tests (delegate + sequential-execute flows)
- [ ] **4.5** → orchestrator: Build E2E agent behavior eval harness
- [ ] **4.6** → orchestrator: Build rule enforcement tests (ironclad rules)
- [ ] **4.7** → orchestrator: Add `/test-agentic-system` command definition

---

## Key References
- Queue protocol schema: `.agents/schemas/queue.schema.md`
- Trace schema: `.agents/schemas/trace.schema.md`
- Queue manager: `.agents/scripts/queue-manager.ps1`
- Delivery adapter: `.agents/scripts/delivery-adapter.ps1`
- Validators: `.agents/scripts/checkpoint.ps1`, `trace_completeness.ps1`, `tdd_order.ps1`, `qg_enforcer.ps1`
- Delegation command: `.opencode/commands/delegate.md`
- Execution command: `.opencode/commands/sequential-execute.md`
- Queue directory: `.agents/queue/`
- Trace directory: `.agents/traces/`
- Learned patterns: `.agents/learned.jsonl`
