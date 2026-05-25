# PROJECT.md — Project Configuration
# .agents/PROJECT.md
#
# AUTHORITY: LAYER 4 — Cross-cutting project conventions.
# Read by: Orchestrator (always) + all agents on first task of session.
# Can override: Division defaults, agent defaults, skill defaults.
# Cannot override: Ironclad rules (global.md), security guardrails.
#
# INSTRUCTIONS: Fill in every section below for this specific project.
# Delete placeholder text and replace with real values.
# Agents will fail with BLOCKED status if required sections are empty.

---

# PROJECT: [Project Name Here]

## Stack

- Runtime:        [e.g. Node.js 20 / Python 3.12 / Go 1.22]
- Framework:      [e.g. Next.js 14 App Router / FastAPI / Gin]
- Database:       [e.g. PostgreSQL 16 / MongoDB 7 / SQLite]
- ORM:            [e.g. Prisma / SQLAlchemy / GORM / Drizzle]
- Styling:        [e.g. Tailwind CSS / CSS Modules / styled-components]
- Test Framework: [e.g. Vitest / Jest / pytest / Go test]
- CI/CD:          [e.g. GitHub Actions / GitLab CI / CircleCI]
- Cloud:          [e.g. AWS / GCP / Vercel / Railway / self-hosted]
- Package Manager:[e.g. pnpm / npm / yarn / uv / pip]

## Conventions

- Language:       [e.g. TypeScript strict / Python with type hints / Go]
- Naming:         [e.g. camelCase variables, PascalCase types, kebab-case files]
- File Structure: [describe your specific directory layout]
- Import Style:   [e.g. absolute from src/ / relative imports]
- Branch Strategy:[e.g. main + feature branches / gitflow / trunk-based]

## How to Run

```bash
# Install dependencies
[e.g. pnpm install]

# Start development server
[e.g. pnpm dev]

# Run tests
[e.g. pnpm test]

# Run linter
[e.g. pnpm lint]

# Run type checker
[e.g. pnpm typecheck]

# Build for production
[e.g. pnpm build]
```

## Environment

- Local:      .env.local (never committed)
- Staging:    [e.g. .env.staging / 1Password vault "Engineering" / AWS SSM]
- Production: [e.g. AWS Secrets Manager / Vercel env vars / GCP Secret Manager]

## Deployment

- Staging:    [e.g. Auto-deploy on merge to 'develop' branch via GitHub Actions]
- Production: [e.g. Manual approval required, deploy from 'main' only]
- Rollback:   [e.g. git revert + redeploy / Kubernetes rollout undo / Vercel instant rollback]

## Design System

- Tokens:           [e.g. /src/design-tokens/ / tailwind.config.ts]
- Component Library:[e.g. shadcn/ui + custom / Radix UI / MUI]
- Brand Colors:     [e.g. Primary: #1A2B3C, Accent: #FF6B35]
- Font:             [e.g. Geist Sans + Geist Mono / Inter + JetBrains Mono]
- Icon Library:     [e.g. Lucide / Heroicons / Phosphor]

## Hard Project Rules

> Rules that apply to this project beyond the framework defaults.
> Examples only — replace with your actual rules.

- [e.g. All API routes require authentication — no public endpoints without explicit exception]
- [e.g. Database models must have soft-delete (deleted_at column) — no hard deletes ever]
- [e.g. All external API calls must go through /src/lib/api-client.ts — no direct fetch()]
- [e.g. All forms must have client-side + server-side validation]

## Permitted Overrides

> Framework defaults this project explicitly changes.
> Leave empty if no overrides needed.

- [e.g. Bundle size limit is 200KB gzipped for this project (not the 150KB default)]
- [e.g. Dark mode variants are NOT required — this is a light-only product (with justification)]

## Known Gotchas

> Documented project-specific pitfalls for agents to know before starting.
> Leave empty if no known issues.

- [e.g. The auth module has a circular dependency — see DEBUG_REPORT.md in /docs]
- [e.g. Environment variables are snake_case in this project, not SCREAMING_SNAKE_CASE]
- [e.g. The database connection pool must be initialized before any test runs]

## MCP Configuration

> References to MCP config files for this project.

- Settings: `.agents/mcp/settings.json`
- Auth:     All credentials in `.env.agents` (gitignored)
