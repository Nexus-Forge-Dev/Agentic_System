# Command: /deploy
# .agents/commands/deploy.md
# Owner: Platform Lead → Cloud Architect + DevOps Engineer
# Trigger: /deploy ["<environment>"] — default: staging

---

## Purpose
Full deployment pipeline: infra plan → approval → apply → service deploy →
health check → smoke test. Produces a deployment receipt.

---

## Workflow

```
INPUT: Target environment (staging | production)

GATE: Has /ship completed? (PR merged?) → If NO: BLOCKED

STEP 1 — Pre-deploy checklist
  Read .agents/PROJECT.md — Deployment section
  Record current git HEAD SHA in audit.jsonl (rollback anchor)
  Verify: all CI checks passed on this commit
  If environment = production: require explicit human confirmation (Tier 2)

STEP 2 — Infrastructure (Cloud Architect)
  Run: terraform plan --var-file=<env>.tfvars
  Output: plan summary (resources to add/change/destroy)
  If plan shows DESTROY → escalate to human, NEVER auto-apply destructive changes
  Present plan to user for approval (Tier 2 gate)
  If approved: terraform apply

STEP 3 — Service deployment (DevOps Engineer)
  Build Docker image (if applicable)
  Run CVE scan → zero critical allowed
  Push to registry
  Apply Kubernetes deployment (kubectl apply / helm upgrade)
  Monitor rollout: kubectl rollout status deployment/<name>

STEP 4 — Health check (Platform Lead)
  Ping /health endpoint on new deployment
  Check K8s pod status: all pods Running?
  Verify DB connectivity from new pods
  If any check fails → IMMEDIATE ROLLBACK, do not wait

STEP 5 — Smoke test (QA Automation Engineer)
  Run /smoke against live URL
  Must pass within 5 minutes of deploy
  If /smoke fails → IMMEDIATE ROLLBACK

STEP 6 — Deployment receipt
  Write to: .agents/sessions/<id>/deploy-receipt-<ts>.md
  Contents:
    - Environment
    - Version deployed (git SHA + version tag)
    - Infra changes applied
    - Health check results
    - Smoke test results
    - Rollback command (exact command to undo this deployment)
```

---

## Output Artifacts
- `.agents/sessions/<session-id>/deploy-receipt-<ts>.md`

---

## Hard Rules
- Production deployments: Tier 2 gate (explicit human confirmation required)
- Terraform DESTROY operations: always escalate, never auto-apply
- Smoke test failure → automatic rollback (no manual decision needed)
- Deployment receipt always includes the exact rollback command
