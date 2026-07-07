# Validation Report — §8 Tool & MCP Integration
# Source: Agentic_System/design_docs/agentic_system_design.md (lines 398–460)
# Generated: 2026-05-28

---

## Feature: Tool Registry (§8.1)

| Aspect | Design Spec | Status | Detail |
|--------|-------------|--------|--------|
| Config location | `.agents/mcp/` | ✅ | `mcp/settings.json` |
| Agent-to-tool mapping | Which agents can call what | ✅ | `allowed_agents` per tool — 8 tools registered |
| Per-operation tiers | Auto-approve vs gated | ✅ | `tier_defaults` per operation per tool |
| Rate limits | Defined in registry | ✅ | `rate_limit` per tool |

## Feature: Tool Call Lifecycle (§8.2)

| Step | Design Spec | Status | Detail |
|------|-------------|--------|--------|
| Permission check | 3-tier gate | ✅ | `rules/tool-call-lifecycle.md` — exact same flowchart |
| Cache check | Hit → return, miss → execute | ✅ | Same + retry_on_error branch |
| Audit log | Log after execute | ✅ | `tool_calls.jsonl` schema defined |
| Retry logic | — | 🔷 Added | `max_retries` per tool config |

## Feature: Tool Result Caching (§8.3)

| Aspect | Design Spec | Status | Detail |
|--------|-------------|--------|--------|
| Key formula | `hash(tool + op + inputs)` | ✅ | `hash(tool + ":" + op + ":" + JSON.stringify(sorted_inputs))` |
| TTL | 5 min volatile / 24h stable | 🔷 More granular | Per-tool per-operation TTLs in settings.json |
| Storage path | `.agents/cache/<tool>/<hash>.json` | ✅ | Structure matches |
| Actual entries | — | ⚠️ Empty | `cache/` dir exists but has no cached results |

## Feature: Rate Limiting (§8.4)

| Aspect | Design Spec | Status | Detail |
|--------|-------------|--------|--------|
| Coverage | 3 tools (github, figma, sentry) | 🔷 Surpassed | 8 tools fully configured — 5 more than spec |
| Config fields | rpm, retry_on_429, backoff | 🔷 Added | Extra field: `max_retries` |
| Backoff types | exponential / linear | ✅ | Both used per tool |

## Key Gaps

1. **Cache is empty** — structure exists but no cached results stored
2. **Implementation surpasses spec** — 8 tools vs 3 in design doc; `max_retries` field added
