# Platform / Infrastructure Division Rules
# .agents/rules/divisions/platform.md
# AUTHORITY: LAYER 3 — Division-level constraints.
# Read by: Platform Lead + all Platform specialists at session start.

---

## IaC & Cloud Defaults (override in PROJECT.md if different)

- **IaC:** Terraform (default) / Pulumi
- **Cloud:** AWS (default) / GCP / Azure / Vercel
- **Container Runtime:** Docker + Kubernetes (default)
- **CI/CD:** GitHub Actions (default) / GitLab CI
- **Container Registry:** AWS ECR / Docker Hub / GCR
- **Secret Management:** AWS Secrets Manager / 1Password / Vault

---

## Hard Platform Rules (cannot be overridden by PROJECT.md)

### Terraform / IaC
- All Terraform modules must declare `required_providers` with exact version constraints
- `terraform apply` ALWAYS requires a prior approved `terraform plan` output — never apply without plan
- All cloud resources must be tagged: `environment`, `owner`, `service` — missing tags block apply
- Least-privilege IAM: start with zero permissions, add only what is explicitly required
- State files are never stored locally — always in remote backend (S3 + DynamoDB locking or equivalent)

### Deployments
- No deployment without a rollback plan documented in `task.md` before execution begins
- All deployments use rolling or blue-green strategy — never replace-all (risk of full outage)
- All infra changes run a dry-run/plan first — never blind apply
- Zero-downtime deployments are required for any service with active users

### Containers & Images
- All GitHub Action/pipeline step versions pinned to exact SHA — no floating `@latest` tags
- Secrets sourced from environment/secrets manager only — never in Dockerfile layers, pipeline YAML, or logs
- Every Docker image must pass a CVE scan before being pushed to any registry
- Zero critical CVEs allowed in production images — high CVEs must have accepted risk documented

### CI/CD Pipelines
- Generated pipelines must always include: lint → test → build → CVE scan → deploy stages
- Single-stage pipelines are not allowed (no "build and deploy in one step")
- Pipeline audit findings are filed as GitHub issues — not left as inline suggestions
- All pipeline jobs must have explicit timeout values — no unbounded jobs

---

## Platform Division Guardrails (Tier 2)

Enforced by Platform Lead before accepting output from specialists:
- No `terraform apply` without approved plan
- No deployment without rollback plan
- All secrets sourced from env refs only — scan pipeline YAML for inline secrets before accepting

---

## Incident Priority Protocol

When an incident occurs, priority order is always:
1. **ISOLATE** — stop the bleeding (circuit breaker, traffic reroute)
2. **ROLLBACK** — revert to last known good state
3. **STABILIZE** — verify system is stable post-rollback
4. **DEBUG** — only after system is stable

Never debug in production before stabilizing. Violation of order is never acceptable.
