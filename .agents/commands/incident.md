# Command: /incident
# .agents/commands/incident.md
# Owner: Incident Commander
# Trigger: /incident "<description or Sentry alert link>"

---

## Purpose
Emergency production recovery. Protocol: ISOLATE → ROLLBACK → STABILIZE → DEBUG.
Order is never violated, even if root cause seems obvious.

---

## Workflow

```
INPUT: Incident description OR Sentry P0/P1 alert link

STEP 1 — Assess (< 3 minutes)
  If Sentry link: fetch error rate, affected users, first occurrence, deployment history
  Classify severity:
    P0: Full outage / data loss / security breach
    P1: Major feature broken, > 20% users affected
    P2: Minor feature broken, < 20% users affected

  If P0: IMMEDIATELY notify user before taking any action (Tier 2 gate)
  If P1: BLOCKED for /investigate until STABILIZE complete
  If P2: File GitHub issue, no emergency protocol needed

STEP 2 — ISOLATE (stop the bleeding)
  Options (pick the fastest applicable):
    - Toggle feature flag OFF (fastest — seconds)
    - Route traffic to maintenance page
    - Kill the problematic service instance
    - Revoke compromised credentials (if security breach)
  LOG isolation action to audit.jsonl

STEP 3 — ROLLBACK (revert to last known good state)
  Identify last known good deployment (from deployment history in Sentry/CI)
  Execute rollback:
    Kubernetes: kubectl rollout undo deployment/<name>
    Vercel: rollback to prior deployment
    Terraform: revert state to prior version
  Verify rollback completed (pod status / health check)
  Maximum rollback time: 5 minutes. If longer → escalate to human.

STEP 4 — STABILIZE (confirm recovery)
  Run /smoke against live URL — must PASS before declaring stable
  Check Sentry error rate → must drop to < pre-incident baseline
  Monitor for 10 minutes — no new error spikes
  Declare STABLE only after monitoring window passes

STEP 5 — DEBUG (root cause — only after stable)
  Activate Engineering Lead → /investigate
  Use Sentry trace + deployment diff as starting evidence
  DO NOT touch production during debug phase

STEP 6 — Postmortem
  File at: .agents/reports/postmortem-<ts>.md
  GitHub issue filed linking to postmortem (labeled: incident, postmortem)
  Contents:
    - Timeline (incident start, detection, isolation, rollback, stabilization)
    - Root cause (from /investigate output)
    - Impact (users affected, duration, data affected)
    - Fix applied
    - Prevention measures (specific code/process changes)
```

---

## Output Artifacts
- `.agents/reports/postmortem-<ts>.md` — structured postmortem
- GitHub issue (via MCP) — incident log + postmortem link

---

## Guardrails
- P0: Human notification BEFORE action (Tier 2) — always
- NEVER debug in production before STABILIZE — always rollback first
- Postmortem is mandatory within 24 hours of every P0/P1
- Rollback must complete in < 5 minutes or escalate to human
