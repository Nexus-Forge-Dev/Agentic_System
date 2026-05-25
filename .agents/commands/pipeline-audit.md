# Command: /pipeline-audit
# .agents/commands/pipeline-audit.md
# Owner: DevOps Engineer + Security Engineer (parallel)
# Trigger: /pipeline-audit ["<pipeline-file-path>"]

---

## Purpose
Audit existing CI/CD pipeline files for security, correctness, and best practices.
Produces a severity-ranked report. All findings filed as GitHub issues.

---

## Workflow

```
INPUT: Path to pipeline YAML (default: .github/workflows/)
  Audit all files if no specific file given.

STEP 1 — Parse pipeline file(s)
  Load and parse all YAML files in target path
  Identify: trigger events, jobs, steps, env vars, secrets references

STEP 2 — Run audit checks (Security Engineer in parallel)

  SECURITY CHECKS (Critical / High):
    [C] Secrets in YAML — any hardcoded credentials, tokens, API keys
    [C] Piped remote execution — curl | bash or wget | sh patterns
    [H] Unpinned step versions — @latest, @v3, @main, @master (no SHA)
    [H] Overly broad permissions — write-all or admin where not needed
    [H] Third-party actions without SHA pinning — supply chain risk
    [H] Unverified external Docker images — pulling without digest

  STRUCTURE CHECKS (Medium):
    [M] Missing required stages — pipeline lacks lint|test|build|scan|deploy
    [M] Single-stage pipeline — build and deploy in the same job
    [M] Deploy triggered on all branches — should be main/tag only
    [M] No job timeout — unbounded jobs can consume unlimited minutes

  BEST PRACTICE CHECKS (Low):
    [L] Missing cache configuration — slow builds due to re-downloading deps
    [L] Inefficient job ordering — opportunities for parallelism not taken
    [L] No concurrency control — multiple workflow runs stepping on each other
    [L] Missing artifact retention policy — artifacts accumulating forever

STEP 3 — Score the pipeline
  Critical findings: -20 points each
  High findings: -10 points each
  Medium findings: -5 points each
  Low findings: -2 points each
  Starting score: 100

  Grade:
    90-100: EXCELLENT
    75-89:  GOOD (minor improvements)
    60-74:  NEEDS IMPROVEMENT
    < 60:   CRITICAL ISSUES — do not use in production

STEP 4 — Generate report
  Write to: .agents/reports/pipeline-audit-<ts>.md
  Format:
    # Pipeline Audit — <filename>
    Score: X/100 — <grade>

    ## Critical Findings
    [C] <finding> at line <N>: <description> | Remediation: <exact fix>

    ## High Findings
    ...

    ## Recommended Pipeline Structure
    <show what a corrected version of the trigger/permissions/steps would look like>

STEP 5 — File GitHub issues
  For each Critical and High finding: file a GitHub issue
  Labels: ["pipeline", "security", finding-severity]
  Do NOT leave findings as comments only
```

---

## Output Artifacts
- `.agents/reports/pipeline-audit-<ts>.md` — severity-ranked audit report
- GitHub issues for all Critical + High findings (via MCP)

---

## Hard Rules
- All Critical and High findings → GitHub issues filed (not optional)
- Report always includes exact remediation steps, not just descriptions of problems
