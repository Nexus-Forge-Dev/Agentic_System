# Tool Call Lifecycle
# .agents/rules/tool-call-lifecycle.md
# Authority: LAYER 1 — applies to every tool call by every agent
# Source: agentic_system_design.md §8.2, §8.3, §8.4

---

## The Tool Call Lifecycle Flowchart

Every single tool call — MCP, shell, file operation — goes through this exact sequence:

```
Agent decides to call a tool
         │
         ▼
  CHECK PERMISSION TIER (§7.1)
         │
    ┌────┴─────┐
    ▼           ▼
  Tier 3       Tier 1 or Tier 2
  (DENY)        │
    │           ▼
 Log +     TIER 1?           TIER 2?
 STOP       │                  │
            Auto-approve    Present approval prompt
            │                  │
            │              Wait for user [y/n]
            │                  │
            │              n → BLOCKED, log, stop
            │              y → proceed
            │                  │
            └──────────────────┘
                     │
                     ▼
              CHECK TOOL CACHE
                     │
               ┌─────┴──────┐
               ▼             ▼
           Cache hit     Cache miss
               │             │
          Return cached   Execute tool call
          result               │
               │           ┌──┴──────────────────┐
               │           │ Tool call succeeds   │
               │           ├─────────────────────┤
               │           │ Write result to cache│
               │           │ key: hash(tool+op+in)│
               │           │ with TTL per table   │
               │           └──────────┬──────────┘
               │                      │
               │              Tool call fails?
               │                      │
               │              ├─ Retry (if retry_on_error)
               │              └─ Return error to agent
               │
               └──────────────────────┘
                            │
                            ▼
                    Return to agent
                            │
                            ▼
                   LOG to audit.jsonl
```

---

## Permission Tier Reference

```
TIER 1 — AUTO-APPROVE (no friction)
  Safe, idempotent, read-only, or purely local operations
  Examples:
    run tests, run linter, read files, git status, git diff,
    terraform plan, kubectl get, docker inspect, search_code,
    browse_url, crawl_site (depth ≤ 3), query_db (SELECT),
    validate_schema, transform_data, summarize, diff_content

TIER 2 — REQUIRE APPROVAL (single human confirmation)
  Operations with real-world side effects that are reversible
  Examples:
    kubectl apply, terraform apply, docker push, git push,
    api_call (all), notify (all), query_db (INSERT/UPDATE/DELETE),
    crawl_site (depth > 3), draft (when sending)

TIER 3 — DENY (hard block, never executes)
  Irreversible, high-blast-radius, or security-violating operations
  Examples:
    rm -rf without explicit bounds, DROP DATABASE, DROP TABLE,
    DELETE FROM without WHERE, piped remote execution (curl | sh),
    writing secrets to any file or log,
    pushing directly to main/master/production branch without PR,
    query_db (ALTER, TRUNCATE) — use migration pipeline instead
```

---

## Cache Key Schema

Cache key is always computed as:

```
key = hash(tool_name + ":" + operation + ":" + JSON.stringify(sorted_inputs))
```

- `tool_name`: The MCP server name (e.g., `github`, `browser`, `terraform`)
- `operation`: The specific operation called (e.g., `read_file`, `list_issues`)
- `sorted_inputs`: Inputs JSON-stringified with keys sorted (for determinism)

### Cache Storage

```
.agents/cache/
├── <tool_name>/
│   └── <hash>.json
│
Cache entry format:
{
  "key":        "<hash>",
  "tool":       "<tool_name>",
  "operation":  "<operation>",
  "inputs":     { ... },
  "result":     { ... },
  "ts":         "<ISO-8601>",
  "ttl_seconds": <N>,
  "expires_at": "<ISO-8601>"
}
```

### TTL Reference

| Tool / Operation | TTL |
|-----------------|-----|
| `browser` / page read | 3600s (1 hour) |
| `browser` / live data page (status pages) | 300s (5 min) |
| `github` / repo content, PRs, issues | 300s |
| `github` / workflow runs (live CI) | 60s |
| `terraform` / plan output | 1800s (30 min) |
| `kubernetes` / pod status | 30s |
| `sentry` / issues list | 120s |
| `figma` / frame content | 86400s (24 hours) |
| `search_web` / results | 1800s (30 min) |
| `search_code` / codebase index | 300s |
| `query_db` / SELECT results | 30s |

---

## Audit Log Entry (tool_calls.jsonl)

Every tool call — hit or miss — is logged to `sessions/<id>/tool_calls.jsonl`:

```json
{
  "ts": "2026-05-24T14:00:00Z",
  "session_id": "sess_<ulid>",
  "task_id": "task_<ulid>",
  "agent": "<agent-role>",
  "tool": "<tool_name>",
  "operation": "<operation>",
  "inputs_hash": "<hash>",
  "permission_tier": 1,
  "approved_by": "auto | user",
  "cache_hit": false,
  "cache_ttl": 3600,
  "duration_ms": 1240,
  "result_status": "success | error | timeout",
  "error": null
}
```

---

## Cache Enforcement Protocol

Every agent MUST use `.agents/scripts/cache.ps1` before executing any tool call
for tools listed in the TTL table below. This is not optional.

### Before Every Tool Call (Cache Check)

```
1. Normalize inputs: JSON-stringify with keys sorted alphabetically
2. Run: powershell .agents/scripts/cache.ps1 check <tool> <operation> "<inputs_json>"
3. If exit code 0 (HIT):
   → Read returned JSON as the cached result
   → Skip the actual tool call
   → Log to tool_calls.jsonl with cache_hit: true
4. If exit code 1 (MISS or EXPIRED):
   → Execute the tool call normally
   → Capture the result
   → Run: powershell .agents/scripts/cache.ps1 write <tool> <operation> "<inputs_json>" "<result_json>" <ttl>
   → Log to tool_calls.jsonl with cache_hit: false
```

### Session Start Warmup

At the start of each session, run:
```
powershell .agents/scripts/cache.ps1 clear
```
This removes any stale entries from prior sessions so the cache starts clean.

### Guardrails

- **Never cache results containing secrets** — if the result contains any field
  matching (api_key|secret|token|password|private_key), skip the cache write
- **TTL is per-operation, not per-tool** — a `read` of a config file (TTL 120s)
  is different from a `read` of a lock file (treat as 30s)
- **Cache bypass** — if the agent knows the data has changed since the last call
  (e.g., agent just edited the file), skip the cache check entirely
- **Cache writes never fail the task** — if the write fails, log a warning and
  continue; the task must not be blocked by a cache write error

---

## Rate Limiting

Each MCP server has rate limits enforced transparently:

```json
{
  "github":    { "requests_per_minute": 60, "retry_on_429": true,  "backoff": "exponential" },
  "figma":     { "requests_per_minute": 30, "retry_on_429": true,  "backoff": "linear" },
  "sentry":    { "requests_per_minute": 100, "retry_on_429": false },
  "terraform": { "requests_per_minute": 20, "retry_on_429": true,  "backoff": "exponential" },
  "browser":   { "requests_per_minute": 60, "retry_on_429": false }
}
```

- Rate limiting is handled at the tool call lifecycle level — agents do not manage this
- If rate limit is hit: log `rate_limited: true` in tool_calls.jsonl, apply backoff, retry
- If `retry_on_429: false` and limit hit: return error to agent immediately
