# Validation Report — §10 Observability & Tracing
# Source: Agentic_System/design_docs/agentic_system_design.md (lines 507–546)
# Generated: 2026-05-28

---

## Feature: Tracking Streams (§10.1)

| Stream | File | Design Spec | Status | Actual Data |
|--------|------|-------------|--------|-------------|
| Audit Log | `audit.jsonl` | Every agent action, tier, result | ✅ Live | 15 entries, real sessions (sess_01J0MXZ..., sess_01J0N2A...) |
| Tool Log | `tool_calls.jsonl` | Every MCP call, latency, cache | ⚠️ Schema | Template at `sessions/templates/tool_calls.jsonl.schema` — not verified with actual data |
| Cost Log | `cost.jsonl` | Token usage per agent/task/session | ✅ Live | 9 entries, 2 sessions tracked, $0.05–$0.74 range |

## Feature: Cost Tracking Schema (§10.2)

| Field | Design Spec | Schema Template | Actual Data | Status |
|-------|-------------|----------------|-------------|--------|
| session_id | ✅ | ✅ | ✅ | ✅ |
| agent | ✅ | ✅ | ✅ | ✅ |
| task_id | ✅ | ✅ | ✅ | ✅ |
| model | gemini-2.5-pro | generic | claude-sonnet-4-20260525 | ✅ |
| input_tokens | ✅ | ✅ | ✅ | ✅ |
| output_tokens | ✅ | ✅ | ✅ | ✅ |
| cached_tokens | ✅ | ✅ | ❌ Not in actual data | ⚠️ Unpopulated |
| tool_calls | ✅ | ✅ | ❌ Not in actual data | ⚠️ Unpopulated |
| tool_cache_hits | ✅ | ✅ | ❌ Not in actual data | ⚠️ Unpopulated |
| estimated_cost_usd | ✅ | ✅ | ✅ | ✅ |
| total_tokens | — | — | ✅ Added in real data | 🔷 Improvement |

## Feature: Session Dashboard (§10.3)

| Aspect | Design Spec | Status | Detail |
|--------|-------------|--------|--------|
| Dashboard | "Future" — post-Phase 1 | ✅ Correct | Not implemented — correctly deferred |
| Uses logged data | Builds on existing JSONL | ✅ | Data is being collected (cost.jsonl, audit.jsonl) |

## Gaps

1. **`cached_tokens`, `tool_calls`, `tool_cache_hits`** defined in schema but never populated in actual cost.jsonl entries — cost tracking is incomplete
2. **tool_calls.jsonl** schema defined but not confirmed with actual data
