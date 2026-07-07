# Validation Report — §7 Security & Governance
# Source: Agentic_System/design_docs/agentic_system_design.md (lines 348–396)
# Generated: 2026-05-28

---

## Feature: Permission Tiers (§7.1)

| Tier | Design Spec | Status | Implementation |
|------|-------------|--------|----------------|
| T1 — Auto-approve | Read-only, safe, idempotent | ✅ | `rules/global.md` + `rules/tool-call-lifecycle.md` — detailed examples |
| T2 — Require approval | Reversible real-world effects | ✅ | Per-tool per-operation tiers in `mcp/settings.json` |
| T3 — Deny | Irreversible, high-blast-radius | 🔷 Surpassed | Same + `global_blocked_patterns` list (`rm -rf`, `DROP DATABASE`, `curl | bash`, etc.) |

## Feature: Audit Log (§7.2)

| Aspect | Design Spec | Status | Detail |
|--------|-------------|--------|--------|
| Location | `sessions/<id>/audit.jsonl` | ⚠️ Differs | Global `.agents/audit.jsonl` instead of per-session; `tool_calls.jsonl` is per-session |
| Schema | ts, agent, action, tool, tier, result, duration | ✅ | `tool-call-lifecycle.md` — matching schema |
| Append-only | Immutable, cannot be modified | ✅ | RULE 02 — logged BEFORE execution |

## Feature: Secret Hygiene (§7.3)

| Practice | Design Spec | Status | Detail |
|----------|-------------|--------|--------|
| `env:VAR` references | All credentials as env vars | ✅ | PROJECT.md: "All credentials live in `.env.agents`" |
| Never print/log secrets | Prohibited | ✅ | RULE 01 — "No secrets in output" |
| Static secret scan on outputs | Auto-scan before surfacing | ❌ Missing | No rule file or mechanism implements this |
| `.env.agents` gitignored | Enforced | ✅ | Confirmed in PROJECT.md |

## Key Gaps

1. **Audit log location mismatch** — design doc expects `sessions/<id>/audit.jsonl` (per-session), implementation uses `.agents/audit.jsonl` (global)
2. **No automated secret-pattern scan** on agent outputs — RULE 01 prohibits it but no scanning mechanism exists
3. **Bonus:** `global_blocked_patterns` in `mcp/settings.json` adds protection beyond design doc spec
