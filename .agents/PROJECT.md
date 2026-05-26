# PROJECT.md — DevPlatform Monorepo Configuration
# .agents/PROJECT.md
#
# AUTHORITY: LAYER 4 — Cross-cutting project conventions.
# Read by: Orchestrator (always) + all agents on first task of session.
# Can override: Division defaults, agent defaults, skill defaults.
# Cannot override: Ironclad rules (global.md), security guardrails.

---

# PROJECT: DevPlatform — Forge Nexus Monorepo

> A multi-product developer platform housing three products:
> 1. **Auth** — Multi-tenant authentication-as-a-service (like Clerk/Auth0, but owned)
> 2. **Forge IDE** — AI-native full-stack development platform (like Figma + VS Code + Vercel in one)
> 3. **Nexus** — Developer intelligence platform (monitoring, AI agents, vector search, code intelligence)

---

## Monorepo Structure

```
devplatform/                       ← pnpm workspace root (Turborepo)
├── apps/
│   ├── auth-dashboard/            ← Auth Admin UI (Next.js 16 + React 19 + Tailwind 4)
│   └── playground/                ← Internal sandbox / testing app
├── services/
│   ├── auth-api/                  ← Core auth REST API (Express + TypeScript + Prisma)
│   ├── auth-gateway/              ← Reverse proxy, tenant resolution, rate limiting (Express)
│   ├── auth-identity/             ← OIDC IdP, JWKS, authorization code flow (Express + jose)
│   ├── auth-worker/               ← Async job processor, email sending (BullMQ + node-cron)
│   └── kms-proxy/                 ← AWS KMS encrypt/decrypt wrapper (Express + @aws-sdk/client-kms)
├── packages/
│   ├── shared-auth/               ← Core auth library: Prisma schema, adapters, UI, SDK (@devplatform/auth)
│   ├── shared-auth-express/       ← Express middleware adapter
│   ├── shared-auth-fastify/       ← Fastify middleware adapter
│   ├── shared-auth-nextjs/        ← Next.js middleware + RSC adapter
│   ├── shared-auth-react/         ← React hooks + context provider
│   └── shared-auth-ui/            ← Headless auth UI components (React)
├── docs/
│   ├── forge/                     ← Forge IDE design documents (7 parts)
│   └── nexus/                     ← Nexus design documents (6 parts)
├── infra/                         ← Terraform / Kubernetes / Helm
├── e2e-tests/                     ← Playwright E2E test suite
├── scripts/                       ← Database init, observability configs, pgAdmin setup
└── .agents/                       ← Forge Nexus Agentic System (this directory)
```

---

## Stack

### Auth (Current — active development)

| Layer          | Technology                                          |
|----------------|-----------------------------------------------------|
| Runtime        | Node.js 20 (LTS)                                    |
| Language       | TypeScript 5 (strict mode)                          |
| REST Framework | Express 4 (all services)                            |
| Auth Library   | `@devplatform/auth` (workspace package)             |
| ORM            | Prisma 5 (`@devplatform/auth` package)              |
| Database       | PostgreSQL 16 (database: `devplatform_auth`)        |
| Cache / Queue  | Redis 7 (sessions, rate limiting, BullMQ jobs)      |
| Job Queue      | BullMQ 5 (auth-api + auth-worker)                   |
| Crypto / JWT   | `jose` 5, `@node-rs/argon2`, `@aws-sdk/client-kms` |
| WebAuthn       | `@simplewebauthn/server` + `@simplewebauthn/browser`|
| OAuth          | `arctic` 3 (social provider flows)                  |
| Email          | `resend` (auth-worker + nodemailer fallback)        |
| Validation     | `zod` 4                                             |
| Observability  | `prom-client` (metrics), OpenTelemetry (planned)   |
| Test Framework | Vitest 4 + Supertest                                |
| Admin UI       | Next.js 16.2 + React 19 + Tailwind CSS 4            |
| Package Mgr    | pnpm 10 + Turborepo                                 |

### Forge IDE (Design phase — see docs/forge/)

| Layer          | Technology                                          |
|----------------|-----------------------------------------------------|
| Frontend       | Next.js 15, React 19, Monaco Editor, Yjs CRDT      |
| Canvas         | Konva.js + custom React renderer (GPU-accelerated)  |
| Backend Svc    | Go (Gin/gRPC), Python (FastAPI) — microservices     |
| AI/ML          | ONNX Runtime, vLLM, Claude 3.5 / Gemini 1.5        |
| Vector DB      | Qdrant (local: port 6333)                           |
| Streaming      | Apache Kafka + Confluent (local: port 9092)         |
| Storage        | AWS S3 + Cloudflare R2                              |
| Infra          | Kubernetes (EKS), Helm, Terraform, ArgoCD           |

### Nexus (Design phase — see docs/nexus/)

| Layer          | Technology                                          |
|----------------|-----------------------------------------------------|
| Core           | Go microservices + Python AI workers                |
| Vector Search  | Qdrant                                              |
| Event Bus      | Kafka (topic: `platform.nexus.events`)              |
| Observability  | Prometheus + Grafana + Loki + Tempo (LGTM stack)    |

---

## Local Infrastructure (docker-compose.yml)

| Service      | Port     | Purpose                                         |
|--------------|----------|-------------------------------------------------|
| PostgreSQL 16| 5432     | Primary DB (devplatform_auth, forge_db, nexus_db)|
| Redis 7      | 6379     | Sessions, rate limiting, BullMQ queues          |
| MailHog      | 8025 UI, 1025 SMTP | Local email catch-all                |
| pgAdmin 4    | 5050     | DB management GUI                               |
| Kafka        | 9092     | Event streaming (profile: `kafka`)              |
| Qdrant       | 6333     | Vector DB (profile: `nexus`)                    |
| OTel Collector| 4317/4318| Telemetry (profile: `observability`)           |
| Prometheus   | 9090     | Metrics (profile: `observability`)              |
| Grafana      | 3000     | Dashboards (profile: `observability`)           |
| auth-gateway | 8088     | Reverse proxy → auth-api                        |
| auth-api     | 8081     | Core auth REST API                              |
| auth-identity| 8082     | OIDC identity provider                          |
| kms-proxy    | 8083     | AWS KMS proxy                                   |

---

## How to Run

```bash
# Install all dependencies (from monorepo root)
pnpm install

# Start core local infra (PostgreSQL, Redis, MailHog, pgAdmin)
docker compose up -d

# Start Kafka (optional — for event streaming)
docker compose --profile kafka up -d

# Start Qdrant (optional — for Nexus vector features)
docker compose --profile nexus up -d

# Start observability stack (optional)
docker compose --profile observability up -d

# Run all services in dev mode (Turborepo)
pnpm dev

# Run a specific service
pnpm --filter @devplatform/auth-api dev
pnpm --filter auth-dashboard dev

# Run all tests
pnpm test

# Run E2E tests
pnpm test:e2e

# Run linter across all packages
pnpm lint

# Run type checker across all packages
pnpm type-check

# Build all packages (respects Turborepo dep graph)
pnpm build

# Prisma: push schema to local DB
pnpm --filter @devplatform/auth db:push

# Prisma: open Prisma Studio
pnpm --filter @devplatform/auth db:studio
```

---

## Environment Variables

- **Local:**      `.env.local` (never committed — use `.env.example` as template)
- **Staging:**    Injected via GitHub Actions secrets (`DATABASE_AUTH_URL`, `REDIS_URL`, etc.)
- **Production:** AWS Secrets Manager + injected into K8s pods via External Secrets Operator

### Required env vars per service

| Service        | Key Vars                                                         |
|----------------|------------------------------------------------------------------|
| auth-api       | `DATABASE_AUTH_URL`, `DATABASE_URL`, `REDIS_URL`, `KMS_KEY_ID`  |
| auth-gateway   | `AUTH_API_URL`                                                   |
| auth-identity  | `AUTH_URL`, `REDIS_URL`                                          |
| auth-worker    | `REDIS_URL`, `RESEND_API_KEY`, `SMTP_HOST`                       |
| kms-proxy      | `AWS_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`       |
| auth-dashboard | `NEXT_PUBLIC_AUTH_API_URL`, `NEXT_PUBLIC_IDENTITY_URL`          |

All credentials live in `.env.agents` (gitignored). Never inline secrets.

---

## Conventions

- **Language:**       TypeScript 5 strict — all services, all packages
- **Naming:**         camelCase variables, PascalCase types/classes, kebab-case file names
- **File Structure:** Feature-by-feature within `src/` — no flat index files except for barrel exports
- **Import Style:**   Relative imports within a package; `@devplatform/*` workspace imports across packages
- **Branch Strategy:** `main` (production) ← `develop` (integration) ← `feature/<name>` branches
- **PR Policy:**      All PRs require: lint ✅ + type-check ✅ + tests ✅ + /review score ≥ 8.0
- **Commits:**        Conventional commits — `feat:`, `fix:`, `chore:`, `refactor:`, `test:`

---

## Deployment

| Environment  | Trigger                                          | Approval  |
|--------------|--------------------------------------------------|-----------|
| **Local**    | `docker compose up` + `pnpm dev`                 | Automatic |
| **Staging**  | Push/merge to `develop` → GitHub Actions         | Automatic (after CI passes) |
| **Production** | Manual trigger from `main` after PR approval   | Tier 2 — explicit human confirmation required |
| **Rollback** | `kubectl rollout undo deployment/<name>` or Vercel instant rollback | Immediate, no approval needed |

- Zero-downtime deployments required (rolling strategy, never replace-all)
- Every production deploy records git SHA + rollback command in deploy receipt
- `/canary` monitors production for 30 minutes post-deploy (6 checks every 5 min)

---

## Database

- **ORM:** Prisma 5 (source of truth: `packages/shared-auth/prisma/schema.prisma`)
- **Migrations:** `prisma migrate dev` locally, `prisma migrate deploy` in CI
- **RLS:** Row-Level Security policies applied via raw SQL in migrations (NOT via Prisma models)
- **Databases:**
  - `devplatform_auth` — Auth service (tenants, users, sessions, MFA, OAuth, RBAC, audit logs)
  - `forge_db` — Forge IDE (projects, canvas state, components — planned)
  - `nexus_db` — Nexus intelligence (code graph, vector metadata — planned)
- **Soft deletes:** Users have `deleted_at` column — no hard deletes of user records
- **Audit logs:** Append-only, RLS enforced per tenant, integrity hash on every row

---

## Design System (auth-dashboard)

- **Styling:**          Tailwind CSS 4 (PostCSS plugin mode)
- **Component Library:** Custom (headless — `shared-auth-ui` package)
- **Font:**             System default (to be specified in Forge design system)
- **Icon Library:**     To be decided (Lucide preferred)

---

## Hard Project Rules

> These apply across ALL services and packages.

- All API routes behind auth-gateway require tenant resolution — no unauthenticated routes without explicit `@public` annotation
- Database models use `snake_case` column names mapped to `camelCase` in Prisma (`@map`)
- All external API calls from auth-worker must go through retry logic (BullMQ job retry, max 3)
- No secrets in logs, error messages, or API responses — ever (Rule 01 applies)
- OAuth tokens (access/refresh) stored AES-256-GCM encrypted in DB — never plaintext
- TOTP secrets stored AES-256-GCM encrypted via KMS proxy — never raw in DB
- All RLS policies enforced at the database level — Prisma is NOT the security boundary
- Zero critical CVEs in any Docker image before push to registry
- All BullMQ jobs must be idempotent — jobs may be retried without side effects

---

## Known Gotchas

- `shared-auth` uses ESM (`"type": "module"`) — all imports must use `.js` extensions in TypeScript source
- Prisma RLS: migrations must be run as a superuser; app-level DB user has row-level access only
- `auth-api` and `shared-auth` both depend on `@prisma/client` — ensure the same version across both
- Redis connection string format for BullMQ is `host:port` NOT `redis://host:port` in some configs — check `REDIS_URL` format per service
- MailHog is catch-all in local dev — all emails (including password resets) appear at `http://localhost:8025`
- Kafka and Qdrant are NOT started by default — use `--profile kafka` and `--profile nexus` flags
- `sessions/checkpoints/` and `sessions/templates/` in `.agents/` are for the agentic system — NOT application sessions

---

## MCP Configuration

- Settings: `.agents/mcp/settings.json`
- Auth:     All credentials in `.env.agents` (gitignored)

---

## Product Roadmap Context

| Product  | Status           | Source of Truth                                |
|----------|------------------|------------------------------------------------|
| Auth     | Active development | `services/`, `packages/shared-auth/`, `apps/auth-dashboard/` |
| Forge IDE | Design complete   | `docs/forge/` (7-part design doc)              |
| Nexus    | Design complete   | `docs/nexus/` (6-part design doc)              |

Agents working on Forge or Nexus features should read the relevant design docs
in `docs/forge/` or `docs/nexus/` before starting any task. These are the
authoritative source — treat them as the specification.
