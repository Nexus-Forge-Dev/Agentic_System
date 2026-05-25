# Command: /benchmark
# .agents/commands/benchmark.md
# Owner: Performance Tester
# Trigger: /benchmark ["<service>" | "<endpoint>"]

## Purpose
Run performance benchmarks and compare against stored baseline.
MUST run before AND after any performance-related change.

## Workflow
```
STEP 1 — Load baseline
  Read: .agents/reports/baseline-<service>-latest.json
  If no baseline exists: this run creates it (no comparison possible yet)

STEP 2 — Run benchmark suite
  Run load test for 60 seconds at realistic concurrency (from PROJECT.md or default 50 VUs)
  Collect: p50, p95, p99 latency (ms) and requests/second
  Run 3 times, take median result

STEP 3 — Compare
  Calculate delta vs baseline:
    delta_p95 = ((current_p95 - baseline_p95) / baseline_p95) * 100
  Verdict:
    delta_p95 <= +10%: PASS
    delta_p95 > +10%: REGRESSION (requires documented acceptance or block)

STEP 4 — Save results
  Append to: .agents/reports/baseline-<service>-<ts>.json
  Symlink: .agents/reports/baseline-<service>-latest.json → new file

STEP 5 — Report
  Print benchmark table with baseline, current, delta, verdict
  If REGRESSION: surface to Orchestrator for documented acceptance or rollback
```
