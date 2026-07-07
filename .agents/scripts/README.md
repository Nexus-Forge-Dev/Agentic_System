# Forge Nexus Validation Scripts
# .agents/scripts/

## Script Index

| Script | Purpose | Exit 0 | Exit non-0 |
|--------|---------|--------|------------|
| trace_completeness.ps1 | Validates trace entry completeness | All entries present | Missing entries |
| tdd_order.ps1 | Validates TDD phase ordering | TDD respected | TDD violated |
| qg_enforcer.ps1 | Validates quality gate score ≥ 8.0 | QG passed | Below threshold |
| checkpoint.ps1 | Runs all three validators | All pass | Any failed |

## Usage Pattern (after every task)
```powershell
powershell .agents/scripts/checkpoint.ps1 -SessionId "<id>" -TaskPath "<path>" -Phase "<phase>"
```

## Force Override
All scripts support `-Force` to bypass validation in emergencies.
Overrides are logged to `.agents/audit.jsonl`.
