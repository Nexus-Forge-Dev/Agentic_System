# Load Test Report Template
# .agents/skills/qa-pro-max/templates/load-test-report.md
#
# Use this template for every benchmark/performance test run.
# Machine-readable equivalent: /artifacts/load/<run-id>/summary.json

---

# Load Test Report

**Run ID:** [YYYY-MM-DDThh-mm-ssZ]  
**Scenario:** [ ] Ramp  [ ] Spike  [ ] Soak  [ ] Saturation  [ ] Queue Stress  
**Git SHA:** [short commit hash]  
**Date:** [YYYY-MM-DD]  
**Environment:** [ ] CI  [ ] Staging  [ ] Production (Tier 3)  
**Triggered by:** [agent-role or /benchmark command]

---

## Steady State Baseline (measured pre-test)

| Metric | Value |
|---|---|
| p95 latency (baseline) | Xms |
| Error rate | 0% |
| Memory RSS | XMB |
| PG connections (active) | N |
| Queue depth | N |

---

## Test Configuration

```
Scenario: Ramp
  Start: 1 VU → Target: 200 VU → Duration: 900s
  Ramp time: 300s | Sustain: 600s

Endpoints tested:
  - POST /api/v1/auth/login
  - GET /api/v1/users/:id
  - POST /api/v1/orders
  [list all endpoints included]
```

---

## Latency Results

| Endpoint | p50 (ms) | p95 (ms) | p99 (ms) | Threshold p95 | Threshold p99 | Gate |
|---|---|---|---|---|---|---|
| POST /api/v1/auth/login | X | X | X | 250ms | 1000ms | ✅ PASS / ❌ FAIL |
| GET /api/v1/users/:id | X | X | X | 250ms | 1000ms | ✅ PASS / ❌ FAIL |
| POST /api/v1/orders | X | X | X | 250ms | 1000ms | ✅ PASS / ❌ FAIL |
| **Overall** | | | | | | ✅ PASS / ❌ FAIL |

---

## Throughput

| Phase | VUs | RPS (achieved) | Error Rate |
|---|---|---|---|
| Ramp start | 1 | X | 0% |
| Ramp peak | 200 | X | X% |
| Sustain phase | 200 | X | X% |

---

## System Resource Metrics

| Metric | Start | Peak | End | Trend | Gate |
|---|---|---|---|---|---|
| Memory RSS (MB) | X | X | X | +X% | ✅ PASS / ❌ FAIL |
| CPU % | X% | X% | X% | — | (informational) |
| PG connections (active) | X | X | X | — | ✅ PASS / ❌ FAIL |
| PG connections (% of max) | X% | X% | X% | — | ✅ PASS / ❌ FAIL |
| Redis connections | X | X | X | — | ✅ PASS / ❌ FAIL |
| Queue depth | X | X | X | — | ✅ PASS / ❌ FAIL |
| DLQ rate | — | — | X% | — | ✅ PASS / ❌ FAIL |

---

## Baseline Comparison

| Metric | Baseline | This Run | Delta | Regression? |
|---|---|---|---|---|
| p95 latency (critical endpoint) | Xms | Xms | +X% | ✅ No / ❌ Yes |
| Memory RSS growth | X% | X% | +X% | ✅ No / ❌ Yes |
| Overall | | | | ✅ No regression / ❌ REGRESSION DETECTED |

---

## Findings

### Bottlenecks Identified

[If any — describe the specific endpoint, metric, or resource that showed degradation]

Example:
"POST /api/v1/orders p95 latency increased to 340ms during peak (threshold: 250ms).
Root cause: orders_items INSERT is missing an index on order_id — sequential scan observed
in EXPLAIN ANALYZE during test run. Query time: 280ms at load."

### Memory Leak Assessment (Soak only)

[For soak tests — describe memory trend]

Example:
"Memory grew from 256MB to 261MB over 30 minutes (+1.9%). Within acceptable threshold (<5% per 10 min).
No memory leak detected."

---

## Verdict

```
OVERALL RESULT: ✅ PASS / ❌ FAIL

Blocking issues:
  ❌ [endpoint] p95 exceeded threshold (Xms vs Xms threshold)
  ❌ Memory growth exceeded threshold (+X% vs +5% limit)

Non-blocking observations:
  ⚠️  [endpoint] p99 approaching threshold (Xms vs Xms threshold) — monitor next run

Recommended actions:
  1. [action]
  2. [action]
```

---

## Artifacts

| File | Location |
|---|---|
| summary.json | /artifacts/load/[run-id]/summary.json |
| report.html | /artifacts/load/[run-id]/report.html |
| metrics.csv | /artifacts/load/[run-id]/metrics.csv |
| baseline-diff.json | /artifacts/load/[run-id]/baseline-diff.json |
| Baseline updated? | [ ] Yes (run passed, baseline updated) [ ] No |
