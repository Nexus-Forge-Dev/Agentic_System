# Cache Layer Testing Checklist
# .agents/skills/qa-pro-max/checklists/cache.md
#
# Used by: sdet, qa-automation-engineer
# Activated by: /health, /e2e

---

## HIT RATIO & TTL CONSISTENCY

```
□ Cache hit ratio measurable and baseline established per endpoint
    (Project must define acceptable threshold in PROJECT.md)
□ Cache MISS on first request (cold start) → DB fallback completes within timeout
□ Cache HIT on subsequent request → response time measurably faster
□ TTL verified: cached item expires at expected time
    Set item → wait TTL duration → assert cache miss
□ Stale-while-revalidate (if used):
    Item served stale while background refresh runs
    Stale window duration matches configuration
□ TTL consistency: items from same logical set have coordinated TTLs
    (User profile cache and user permissions cache expire at same time or invalidated together)
```

---

## INVALIDATION

```
□ Write operation invalidates all affected cache keys:
    Update user email → user cache key invalidated
    Update user email → user-by-email lookup cache key also invalidated
    NOT just the primary key
□ Partial invalidation:
    Updating user profile → invalidates user-specific caches ONLY
    NOT a full cache flush
□ Multi-tenant isolation:
    Tenant A cache invalidation does NOT affect Tenant B cache keys
    Cache keys are namespaced by tenant_id
□ Cache stampede prevention (single-flight pattern):
    Concurrent cache miss on same key → exactly ONE DB query executed
    All concurrent requests receive same result (not N parallel DB queries)
□ List/collection caches:
    Adding item to list → list cache invalidated (not stale list returned)
    Deleting item → list cache invalidated
□ Pagination caches:
    Page 1 invalidated when underlying data changes
```

---

## SESSION INTEGRITY

```
□ Session ID maps to correct user data (no session fixation)
□ Session expiry enforced:
    Expired session → 401 (not stale data served)
□ Session data not leaked across tenant boundaries:
    Session for User A cannot be used to access User B data
□ Session invalidation on logout:
    Token blacklisted or session deleted
    Subsequent requests with old session → 401
□ Concurrent sessions:
    If limit configured: enforced (new session invalidates oldest)
    If no limit: multiple sessions coexist without interference
```

---

## CONNECTION POOL

```
□ Redis connection pool size tested:
    Normal load: pool utilization < 80%
    Peak load: pool does not exhaust (queue or reject gracefully)
□ Pool exhaustion behavior:
    Project must define: queue (wait) or fail fast
    Documented in PROJECT.md
    Behavior tested and matches definition
□ Connection recovery after Redis restart:
    Application reconnects automatically (no manual restart required)
    In-flight requests receive graceful error, NOT crash
    Recovery time: < 30 seconds
□ Connection leak detection:
    Long-running load test: connection count stable (not growing)
    No connections left open after request completes
```

---

## CACHE POISONING & SECURITY

```
□ Cache keys do not include user-controlled input that could collide
□ Cached responses do not include authorization headers or tokens
□ Private data not cached in shared (non-user-scoped) cache keys
□ Cache-Control headers set correctly on HTTP responses:
    Private data: Cache-Control: private, no-store
    Public static assets: Cache-Control: public, max-age=<ttl>
```

---

## ANTI-PATTERNS (HARD BLOCKS)

```
❌ Never cache authorization decisions without short TTL (< 60 seconds max)
❌ Never use user-controlled input directly as a cache key
❌ Never assume cache is consistent — always test explicit invalidation
❌ Never cache errors or empty results without a very short TTL (negative caching trap)
❌ Never share cache namespace across tenants
❌ Never rely on cache for data that must be strongly consistent
```
