# Command: /seed
# .agents/commands/seed.md
# Owner: QA Automation Engineer
# Trigger: /seed "<scenario-name>"

## Purpose
Seed test data for a specific test scenario using the project's seeding mechanism.
Always uses project's own seeder/factory — never raw SQL inserts.

## Workflow
```
STEP 1 — Identify seeding mechanism
  Check PROJECT.md for: seed script, factory library, fixture files
  Examples: prisma db seed | python manage.py seed | node scripts/seed.js

STEP 2 — Seed for scenario
  Run seeder with scenario name
  Verify seed success by querying expected record counts from DB

STEP 3 — Record seed state
  Log to audit.jsonl: which records were created (counts + table names)
  This is the teardown target for /teardown

STEP 4 — Return seed manifest
  { scenario: "<name>", records_created: { users: 3, orders: 5, ... } }
```

## Guardrails
- Never seed production — only staging/test environments
- Always verify seed succeeded (count check) — never assume it worked
- Seed state logged so /teardown can clean up precisely
