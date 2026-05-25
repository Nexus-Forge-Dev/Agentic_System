# Atomic Skill: api_call
# .agents/skills/atomic/api_call.md
# Type: General-Purpose Primitive
# Available to: ALL agents (with Tier 2 approval — always)
# Permission Tier: 2 (requires human confirmation before every execution)

---

## Purpose
Make an outbound HTTP API call to an external service. Always requires explicit
human approval — no API call executes silently. Used for: calling third-party
APIs not covered by specific MCP tools, webhook triggers, health probes.

> ⚠️ **Every api_call is Tier 2.** No exceptions. The agent must describe
> exactly what it is calling and why before the user confirms.

---

## Inputs

| Field | Required | Description |
|-------|----------|-------------|
| `method` | ✅ | `GET` \| `POST` \| `PUT` \| `PATCH` \| `DELETE` |
| `url` | ✅ | Full URL including scheme |
| `headers` | Optional | Key-value map. Credential values MUST be `env:VAR_NAME` references |
| `body` | Optional | Request body (JSON object or string) |
| `timeout_ms` | Optional | Default: 10000 |
| `purpose` | ✅ | One-sentence description of WHY this call is needed |

---

## Execution Protocol

```
PRE-FLIGHT GATE (ALWAYS runs — cannot be skipped):
  1. Present to user:
     ╔════════════════════════════════════════════════════╗
     ║  API CALL APPROVAL REQUIRED (Tier 2)               ║
     ╠════════════════════════════════════════════════════╣
     ║  Method:  <METHOD>                                  ║
     ║  URL:     <url>                                     ║
     ║  Purpose: <purpose>                                 ║
     ║  Body:    <body or "none">                          ║
     ║  Headers: <header keys only — never values>         ║
     ╚════════════════════════════════════════════════════╝
     Approve? [y/n]

  2. If user says n → BLOCKED, log to audit.jsonl, stop
  3. If user says y → proceed to execute

SECURITY CHECKS (before execute):
  - Headers: verify no literal credentials — must be env:VAR references
  - URL: verify not on blocked domain list
  - Body: verify no secrets pattern (API_KEY, TOKEN, PASSWORD, SECRET)
  → If any check fails: BLOCKED, log, stop

EXECUTE:
  Make HTTP call with constructed request
  Record: response status, response headers, response body, latency_ms

LOG to audit.jsonl:
  {
    "action_type": "api_call",
    "method": "<METHOD>",
    "url": "<url>",
    "purpose": "<purpose>",
    "permission_tier": 2,
    "approved_by": "user",
    "status_code": <N>,
    "duration_ms": <N>
  }

RETURN:
  {
    status:     <HTTP status code>,
    ok:         true | false,
    headers:    { ... },
    body:       "<response body>",
    duration_ms: <N>
  }
```

---

## Error Handling

| Status | Action |
|--------|--------|
| 2xx | SUCCESS — return body |
| 3xx | Follow redirect (max 3 hops) then return |
| 4xx | FAILED — return error with body (useful for debugging) |
| 5xx | Retry once after 2s. If still 5xx → FAILED |
| Timeout | FAILED — `{error: "timeout", timeout_ms: <N>}` |

---

## Credential Handling — MANDATORY RULE

```
CORRECT ✅ — reference env var name only:
  headers: { "Authorization": "Bearer env:STRIPE_SECRET_KEY" }

WRONG ❌ — never include literal credential:
  headers: { "Authorization": "Bearer sk_live_abc123..." }

If the calling agent has a literal key in context:
  → STOP immediately
  → Log: "Credential exposure risk — api_call blocked"
  → Ask user to set env var instead
```

---

## Usage Examples

```
# Trigger a webhook (with approval)
api_call(
  method="POST",
  url="https://hooks.slack.com/services/...",
  headers={ "Content-Type": "application/json" },
  body={ "text": "Deployment complete ✅" },
  purpose="Notify #deployments channel that staging deploy succeeded"
)

# Health probe an external service
api_call(
  method="GET",
  url="https://api.thirdparty.com/health",
  purpose="Check if third-party API is responding before integration test"
)

# Call a REST API with auth (from env)
api_call(
  method="GET",
  url="https://api.github.com/repos/org/repo/releases/latest",
  headers={ "Authorization": "Bearer env:GITHUB_PAT" },
  purpose="Check latest release version before generating changelog"
)
```
