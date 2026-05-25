# Tool Result Cache
# .agents/cache/README.md
#
# This directory stores TTL-based cached results from MCP tool calls.
# Purpose: Eliminate redundant API calls within a session.
#
# Cache key: hash(tool_name + operation + inputs)
# Default TTLs:
#   - Volatile results (pod status, error rates):  5 minutes
#   - Semi-stable results (GitHub PR status):       30 minutes
#   - Stable results (Figma frames, docs pages):    24 hours
#
# Structure:
#   .agents/cache/
#   ├── github/
#   │   └── <hash>.json          { result: {...}, ts: "<ISO>", ttl_seconds: 1800 }
#   ├── figma/
#   │   └── <hash>.json
#   ├── sentry/
#   │   └── <hash>.json
#   └── browser/
#       └── <hash>.json
#
# Cache entry schema:
# {
#   "key":        "<hash>",
#   "tool":       "<tool-name>",
#   "operation":  "<operation-name>",
#   "inputs":     { ... },
#   "result":     { ... },
#   "ts":         "<ISO-8601>",
#   "ttl_seconds": <number>,
#   "expires_at": "<ISO-8601>",
#   "hit_count":  <number>
# }
#
# Rules:
# - Agents CHECK the cache before making any MCP call
# - On CACHE HIT: return cached result, increment hit_count, log to tool_calls.jsonl (cache_hit: true)
# - On CACHE MISS: execute MCP call, write result to cache, log to tool_calls.jsonl (cache_hit: false)
# - Expired entries (expires_at < now): treat as cache miss, overwrite
# - Cache is NEVER used for write operations (only idempotent reads)
# - Cache entries are NOT shared across sessions (session-scoped)
