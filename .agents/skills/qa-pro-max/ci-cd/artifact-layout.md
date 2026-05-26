# Artifact Directory Layout
# .agents/skills/qa-pro-max/ci-cd/artifact-layout.md
#
# All generated artifacts stored under /artifacts/<category>

---

## FULL DIRECTORY LAYOUT

```
/artifacts/
│
├── tests/
│   ├── junit.xml                     ← All test results (unit + integration + E2E combined)
│   ├── unit-junit.xml                ← Unit test results only (if split)
│   ├── integration-junit.xml         ← Integration test results only
│   ├── e2e-junit.xml                 ← E2E test results only
│   └── playwright-report/
│       ├── index.html                ← HTML report (passed/failed, screenshots, traces)
│       ├── screenshots/              ← Screenshots of failed tests
│       │   └── <test-name>-<ts>.png
│       ├── videos/                   ← Video recordings of failed E2E flows
│       │   └── <test-name>-<ts>.webm
│       └── traces/                   ← Playwright trace files for debugging
│           └── <test-name>-<ts>.zip
│
├── coverage/
│   ├── lcov.info                     ← Machine-readable LCOV coverage data
│   ├── index.html                    ← Human-readable coverage summary
│   └── per-file/                     ← Per-file coverage breakdown
│       └── <file>.html
│
├── load/
│   ├── baseline.json                 ← Reference baseline for regression comparison
│   └── <run-id>/                     ← Each run gets its own subdirectory
│       ├── summary.json              ← Machine-readable: p50/p95/p99, gates, pass/fail
│       ├── report.html               ← Human-readable: charts, threshold comparison
│       ├── metrics.csv               ← Raw time-series: timestamp,endpoint,latency,rps
│       └── baseline-diff.json        ← Comparison against baseline (regression delta)
│
├── security/
│   ├── <tool>-results.sarif          ← SARIF output per tool (one file per scanner)
│   ├── audit.json                    ← npm/pnpm audit JSON output
│   ├── container-scan.json           ← Container image scan results (if applicable)
│   └── report.html                   ← Human-readable security summary
│
├── screenshots/
│   └── <commit>-<component>-<ts>.png ← Visual regression screenshots
│
└── reports/                          ← Agent-generated markdown reports (agent reports system)
    ├── e2e-<ts>.md
    ├── health-<ts>.md
    ├── dataaudit-<ts>.md
    └── benchmark-<ts>.md
```

---

## NAMING CONVENTIONS

```
Run IDs:
  Format: <YYYY-MM-DD>T<HH-MM-SS>Z
  Example: 2026-05-26T15-00-00Z
  Used in: /artifacts/load/<run-id>/

Test Screenshots:
  Format: <git-short-sha>-<component-name>-<timestamp>.png
  Example: a1b2c3d-user-profile-card-2026-05-26T15-00-00Z.png

SARIF files:
  Format: <tool-name>-results.sarif
  Examples: semgrep-results.sarif, codeql-results.sarif, trivy-results.sarif

Agent reports:
  Format: <command>-<ISO-timestamp>.md
  Examples: e2e-2026-05-26T15-00-00Z.md, health-2026-05-26T15-00-00Z.md
```

---

## RETENTION POLICY

```
PR builds:
  → All /artifacts/* retained for 7 days
  → Playwright traces and screenshots: 7 days
  → SARIF results: 7 days

Main branch builds:
  → All /artifacts/* retained for 90 days
  → Load test results: 90 days
  → SARIF results: 90 days (compliance)

Production deploy builds:
  → All /artifacts/* retained for 1 year
  → Security scan SARIF: 1 year (compliance/audit trail)
  → Load test results: 1 year (performance history)

Baseline files:
  → /artifacts/load/baseline.json: retained indefinitely
  → Updated only with explicit approval (version-controlled in repo)
```

---

## UPLOAD RULES

```
Always upload (even if tests fail):
  → All /artifacts/* after every run
  → CRITICAL: failure artifacts are the most important to preserve (debugging)

Conditional upload (on failure only):
  → Playwright screenshots, videos, traces (large — only when needed)

Never upload:
  → Secrets or credentials in any artifact
  → Raw application logs containing PII
  → .env files or configuration with secret values
```
