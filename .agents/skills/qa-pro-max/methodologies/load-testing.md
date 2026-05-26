# Load & Performance Testing Methodology
# .agents/skills/qa-pro-max/methodologies/load-testing.md
#
# Used by: performance-tester
# Activated by: /benchmark command, main branch merge, pre-production deploy

---

## PHILOSOPHY

Performance tests validate BEHAVIOR under stress, not just throughput numbers.
A test that produces a low latency number without measuring under realistic,
sustained conditions is a false green.

Every load test must define:
  1. Load shape (ramp, spike, soak, saturation)
  2. Duration
  3. Assertion criteria (p50/p95/p99 thresholds)
  4. What to measure (not just HTTP latency)

---

## LATENCY THRESHOLD CONTRACTS

These are CI gate thresholds — exceeding them fails the pipeline.

```
Internal Service-to-Service APIs:
  p50:  < 50ms
  p95:  < 250ms  ← CI gate — fail if exceeded
  p99:  < 1000ms ← CI gate — fail if exceeded

External User-Facing APIs:
  p50:  < 100ms
  p95:  < 500ms  ← CI gate — fail if exceeded
  p99:  < 1000ms ← CI gate — fail if exceeded

Async Worker Job Completion (standard priority):
  Median completion: < 2 seconds
  p95 completion:   < 10 seconds

Redis Cache:
  Cache hit response: < 5ms (additional latency vs miss)
  Cache miss + DB fallback: within normal API p95 threshold

Database Queries (direct measurement):
  OLTP query (single row by primary key): < 10ms
  Paginated list query (indexed): < 50ms
  Complex aggregation (reporting): < 500ms (background, not real-time)
```

---

## WHAT TO MEASURE (every test run)

```
HTTP Metrics:
  □ p50, p95, p99 latency per endpoint
  □ Throughput (requests/second) at each load stage
  □ Error rate (must be 0% up to saturation point)
  □ Response time distribution histogram

System Metrics:
  □ PostgreSQL: active connection count over time
  □ PostgreSQL: query execution time distribution
  □ Redis: connection pool utilization over time
  □ Redis: hit ratio over time
  □ Worker queue: depth over time (enqueued - processed)
  □ Process memory (RSS) over time — detect leaks
  □ CPU utilization over time — detect saturation

Infrastructure Metrics (when available):
  □ Pod CPU/memory (Kubernetes)
  □ Load balancer connections
  □ Database read replicas lag
```

---

## REQUIRED TEST SCENARIOS

### SCENARIO 1 — Ramp Test (find the breaking point)

```
Purpose: Identify the point at which latency degrades beyond threshold

Shape:
  Start:   1 virtual user
  Ramp:    Increase to target max concurrency over 5 minutes
  Sustain: Hold target max for 10 minutes
  Ramp-down: 2 minutes

Assertions:
  □ p95 latency stays below threshold during sustain phase
  □ Error rate remains 0% up to 80% of max concurrency
  □ System recovers when load drops (latency returns to baseline)
  □ Memory growth: < 5% per 10-minute window during sustain

Output:
  → Breaking point identified (N concurrent users where p95 crosses threshold)
  → Document in /artifacts/load/<run-id>/summary.json
```

### SCENARIO 2 — Spike Test (sudden burst)

```
Purpose: Validate autoscaling response and backpressure handling

Shape:
  Phase 1: Normal load (10% of max concurrency) — 2 minutes
  Phase 2: Instant 10x spike — 2 minutes at spike level
  Phase 3: Return to normal — 2 minutes

Assertions:
  □ System does not return 5xx during spike (may return 429 for rate-limited routes)
  □ Queue depth grows during spike and drains after (not unbounded)
  □ System recovers: p95 returns to baseline within 60 seconds of spike ending
  □ No cascading failures triggered by spike
  □ Autoscaling (if enabled): new instances spin up during spike window

Output:
  → Spike handling behavior documented
  → Recovery time measured (seconds from spike end to baseline p95)
```

### SCENARIO 3 — Soak Test (long-duration stability)

```
Purpose: Detect memory leaks, connection pool exhaustion, gradual state accumulation

Shape:
  Load:     50% of maximum capacity (sustained, steady)
  Duration: 30 minutes minimum (60 minutes preferred)

Assertions:
  □ Memory usage: stable (< 5% growth per 10 minutes of run)
  □ PostgreSQL connections: stable count, not growing
  □ Redis connections: stable, no leak
  □ p95 latency: no drift upward over the soak duration
  □ Error rate: 0% throughout
  □ Worker queue: depth remains bounded (not accumulating indefinitely)

Output:
  → Memory trend graph (time vs RSS)
  → Connection count trend graph
  → Any memory growth quantified and flagged
```

### SCENARIO 4 — Saturation Test (connection pool limits)

```
Purpose: Verify graceful degradation when DB connection pool is exhausted

Shape:
  Load: Increase until PostgreSQL connection pool is fully consumed

Assertions:
  □ Application queues requests (does not cascade to 500)
  □ Queued requests complete once connections free (no data loss)
  □ 503 returned only after queue timeout — not immediately
  □ Connection pool metrics observable in Prometheus/metrics endpoint
  □ No connection leak after saturation (pool recovers to normal size)

Output:
  → Max safe concurrency documented
  → Queue behavior under saturation documented
```

### SCENARIO 5 — Worker Queue Stress Test

```
Purpose: Validate queue behavior under 10x normal job volume

Shape:
  Enqueue: 10x normal job volume simultaneously
  Monitor: queue depth, worker throughput, DLQ rate

Assertions:
  □ Queue depth peaks and then drains (not unbounded growth)
  □ Worker concurrency limit respected
  □ Dead-letter queue rate: < 1% of total enqueued jobs
  □ No job duplication (idempotency holds under stress)
  □ All enqueued jobs eventually processed (no silent loss)

Output:
  → Peak queue depth recorded
  → Drain time measured
  → DLQ rate under stress documented
```

---

## BASELINE MANAGEMENT

```
Baseline: The reference point for regression detection.
  → After first successful performance run: save as baseline.json
  → Stored at: /artifacts/load/baseline.json
  → Updated only on intentional performance improvement (with approval)

Regression detection:
  → Compare current run against baseline
  → REGRESSION: p95 increased by > 10% from baseline → CI fails
  → IMPROVEMENT: p95 decreased → update baseline with confirmation

If baseline missing:
  → Gate is skipped with warning (cannot detect regression without reference)
  → First run always succeeds (establishes baseline)
  → Warning: "Baseline not found — this run will establish the baseline"
```

---

## REPORTING REQUIREMENTS

Every performance run produces:

```
/artifacts/load/<run-id>/
├── summary.json       → machine-readable: p50/p95/p99 per endpoint, thresholds, pass/fail
├── report.html        → human-readable: charts, trends, threshold comparison
├── metrics.csv        → raw time-series data for all measured metrics
└── baseline-diff.json → comparison against previous baseline (if exists)
```

summary.json format:
```json
{
  "run_id": "2026-05-26T15:00:00Z",
  "scenario": "ramp",
  "duration_seconds": 900,
  "results": [
    {
      "endpoint": "POST /api/v1/auth/login",
      "p50_ms": 45,
      "p95_ms": 187,
      "p99_ms": 423,
      "rps_peak": 342,
      "error_rate_pct": 0,
      "threshold_p95_ms": 250,
      "threshold_p99_ms": 1000,
      "gate": "PASS"
    }
  ],
  "system": {
    "memory_rss_start_mb": 256,
    "memory_rss_end_mb": 261,
    "memory_growth_pct": 1.9,
    "pg_connections_peak": 42,
    "redis_connections_peak": 18
  },
  "overall": "PASS"
}
```

---

## ANTI-PATTERNS (HARD BLOCKS)

```
❌ Never run load tests against production without explicit human approval (Tier 3 operation)
❌ Never set thresholds based on a single run — baseline over 3 runs minimum
❌ Never ignore p99 because p95 looks good — tail latency affects real users
❌ Never cancel soak tests early — memory leaks surface only over time
❌ Never set thresholds higher than current performance just to make tests pass
❌ Never measure latency without also measuring memory and connection pools
❌ Never run performance tests in the same pipeline stage as unit tests (separate job)
```
