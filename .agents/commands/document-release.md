# Command: /document-release
# .agents/commands/document-release.md
# Owner: DevOps Engineer
# Trigger: /document-release — called by /ship before version bump commit

## Purpose
Generate a structured CHANGELOG entry from git log between current and previous tag.

## Workflow
```
STEP 1 — Find previous tag
  git describe --tags --abbrev=0  → last tag
  git log <last-tag>..HEAD --oneline → commits since last release

STEP 2 — Categorize commits
  Parse commit messages:
    feat:     → Features (new capabilities)
    fix:      → Bug Fixes
    perf:     → Performance
    security: → Security
    refactor: → Internal Changes
    docs:     → Documentation
    chore:    → Maintenance

STEP 3 — Write CHANGELOG entry
  Prepend to CHANGELOG.md:

  ## v<version> — <date>

  ### Features
  - <description> (<commit-sha>)

  ### Bug Fixes
  - <description>

  ### Security
  - <description>

  [Full diff: v<prev>...v<current>]

STEP 4 — Return entry text to /ship for PR description
```
