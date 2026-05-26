# Report Format Standards
# .agents/skills/qa-pro-max/ci-cd/report-formats.md
#
# All test output formats used across CI runs.

---

## FORMAT: JUnit XML

```
Used for: unit, integration, E2E test results
Location: /artifacts/tests/junit.xml

Purpose:
  → GitHub Actions reads JUnit XML and annotates PR with failed test names inline
  → Jenkins, CircleCI, GitLab CI all support JUnit XML natively
  → Failed test names visible in PR review without opening the full log

Schema:
  <testsuites>
    <testsuite name="Auth Tests" tests="12" failures="1" errors="0" time="4.2">
      <testcase name="should return 201 when user registers with valid email"
                classname="auth.register"
                time="0.34" />
      <testcase name="should return 400 when email exceeds 255 characters"
                classname="auth.register"
                time="0.21">
        <failure message="Expected 400 but received 201">
          Full failure output here
        </failure>
      </testcase>
    </testsuite>
  </testsuites>

Rules:
  → Test name must be the full describe + it description
  → classname must be the file path or feature group
  → time must be in seconds (decimal)
  → failures attribute must match actual failure count
```

---

## FORMAT: LCOV

```
Used for: code coverage reports
Location: /artifacts/coverage/lcov.info (machine) + /artifacts/coverage/index.html (human)

Purpose:
  → Machine-readable: CI gate reads lcov.info to enforce coverage thresholds
  → Human-readable: HTML report shows line-by-line coverage for PR review
  → GitHub PR decoration: coverage badge + diff coverage annotation

lcov.info format excerpt:
  SF:src/services/auth.service.ts
  DA:1,1
  DA:2,0  ← line 2 not covered
  DA:3,1
  LH:2    ← lines hit
  LF:3    ← lines found
  end_of_record

HTML report requirements:
  → File-level coverage percentages visible
  → Line-by-line highlighting (covered=green, uncovered=red, branch=yellow)
  → Sorted by coverage % ascending (lowest coverage files at top)
  → Threshold line visible in report (e.g., "threshold: 80% — current: 84%")
```

---

## FORMAT: HTML (Human-Readable Summaries)

```
Used for: all test categories (additional to machine-readable formats)
Location: /artifacts/tests/playwright-report/index.html (E2E)
          /artifacts/coverage/index.html (coverage)
          /artifacts/load/<run-id>/report.html (performance)
          /artifacts/security/report.html (security)

Purpose:
  → Human review of test run without reading raw logs
  → Failed Playwright tests: screenshots and video embedded in HTML
  → Performance runs: latency charts, memory trend, threshold comparison

Playwright HTML report requirements:
  → Failed tests show: error message, screenshot, DOM snapshot, network log
  → Passed tests: show execution trace (not expanded by default)
  → Filter by: passed, failed, skipped — one click
  → Search by test name
  → Artifacts retained per artifact-layout.md retention policy
```

---

## FORMAT: SARIF (Security / Static Analysis)

```
Used for: SAST, SCA, container scans, dependency audits
Location: /artifacts/security/<tool>-results.sarif

Purpose:
  → GitHub Advanced Security: findings annotated inline on PR diff
  → Severity levels determine blocking behavior (see ci-cd/gates.md)
  → Machine-readable: CI gate reads SARIF to enforce security gates

SARIF 2.1 schema (key fields):
  {
    "$schema": "https://raw.githubusercontent.com/oasis-tcs/sarif-spec/master/Schemata/sarif-schema-2.1.0.json",
    "version": "2.1.0",
    "runs": [{
      "tool": { "driver": { "name": "tool-name", "version": "1.0.0" } },
      "results": [{
        "ruleId": "CWE-89",
        "level": "error",    ← "error" = critical/high, "warning" = medium, "note" = low
        "message": { "text": "SQL injection risk at line 42" },
        "locations": [{
          "physicalLocation": {
            "artifactLocation": { "uri": "src/repositories/user.repo.ts" },
            "region": { "startLine": 42 }
          }
        }]
      }]
    }]
  }

Rules:
  → "error" level findings block the merge (CI gate)
  → "warning" level findings produce PR annotations (non-blocking)
  → "note" level findings logged but not annotated
  → Each SARIF file uploaded as a GitHub Code Scanning result
```

---

## FORMAT: JSON (Machine-Readable Benchmarks)

```
Used for: performance test results, regression comparison
Location: /artifacts/load/<run-id>/summary.json

Purpose:
  → CI gate reads JSON to compare against thresholds and baseline
  → Baseline stored separately as /artifacts/load/baseline.json

Schema:
  {
    "run_id": "<ISO-8601 timestamp>",
    "scenario": "ramp | spike | soak | saturation | queue-stress",
    "git_sha": "<commit hash>",
    "duration_seconds": 900,
    "results": [
      {
        "endpoint": "POST /api/v1/auth/login",
        "method": "POST",
        "p50_ms": 45,
        "p95_ms": 187,
        "p99_ms": 423,
        "rps_peak": 342,
        "error_rate_pct": 0.0,
        "threshold_p95_ms": 250,
        "threshold_p99_ms": 1000,
        "gate": "PASS | FAIL"
      }
    ],
    "system": {
      "memory_rss_start_mb": 256,
      "memory_rss_end_mb": 261,
      "memory_growth_pct": 1.9,
      "memory_gate": "PASS | FAIL",
      "pg_connections_peak": 42,
      "pg_connections_max_configured": 100,
      "redis_connections_peak": 18
    },
    "baseline_comparison": {
      "p95_regression_pct": -2.1,
      "memory_regression_pct": 0.5,
      "regression_detected": false
    },
    "overall": "PASS | FAIL"
  }
```

---

## FORMAT: npm/pnpm Audit JSON

```
Used for: dependency vulnerability reports
Location: /artifacts/security/audit.json

Command: pnpm audit --json > /artifacts/security/audit.json

CI gate reads:
  → vulnerabilities.critical > 0 → exit 1
  → vulnerabilities.high > 0 → exit 1
  → vulnerabilities.moderate — warning only (non-blocking)
```
