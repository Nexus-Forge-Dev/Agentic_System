# Atomic Skill: draft
# .agents/skills/atomic/draft.md
# Type: General-Purpose Primitive
# Available to: ALL agents
# Permission Tier: 1 (drafting) | 2 (sending — always requires human approval)

---

## Purpose
Generate a well-structured draft of any written artifact: GitHub issues, PRs,
Slack messages, email, postmortems, changelogs, release notes, meeting summaries,
technical specs, ADRs. The draft is ALWAYS shown to the human before sending —
agents never send communications autonomously.

**Rule: Draft is Tier 1. Send is Tier 2. Human approves every send.**

---

## Inputs

| Field | Required | Description |
|-------|----------|-------------|
| `type` | ✅ | What to draft (see Artifact Types below) |
| `context` | ✅ | What the draft is about — key facts, decisions, outcomes |
| `audience` | Optional | Who will read this: `engineering` \| `product` \| `management` \| `public` \| `customer` |
| `tone` | Optional | `formal` \| `professional` (default) \| `casual` \| `urgent` \| `reassuring` |
| `template` | Optional | Override default template for this type |
| `max_length` | Optional | Rough target length: `brief` \| `normal` (default) \| `detailed` |

---

## Artifact Types & Templates

### `github_issue`
```markdown
## Summary
<1-2 sentences: what is the problem or request>

## Details
<technical context, repro steps or feature justification>

## Acceptance Criteria
- [ ] <clear, testable condition 1>
- [ ] <clear, testable condition 2>

## Additional Context
<links, screenshots, related issues>
```

### `github_pr`
```markdown
## What This PR Does
<clear description of the change>

## Why
<motivation — what problem does this solve>

## Changes Made
- `<file>`: <what changed and why>

## Testing
- [ ] Unit tests added/updated
- [ ] Manual testing done: <what was tested>
- [ ] No breaking changes / Breaking change: <migration notes>

## Screenshots (if UI)
<before/after>
```

### `postmortem`
```markdown
# Incident Postmortem — <service> — <date>

## Summary
**Duration:** <start> to <end> | **Severity:** P<N> | **Impact:** <N users affected>

## Timeline
- HH:MM — <what happened>

## Root Cause
<technical explanation>

## Resolution
<what fixed it>

## Action Items
| Action | Owner | Due |
|--------|-------|-----|

## What Went Well
## What Went Wrong
## Lessons Learned
```

### `changelog_entry`
```markdown
## [<version>] — <date>

### Added
- <new feature or capability>

### Changed
- <change to existing behavior>

### Fixed
- <bug fix>

### Deprecated / Removed
- <what's going away>
```

### `adr` (Architecture Decision Record)
```markdown
# ADR <N>: <short title>

**Status:** Proposed | Accepted | Deprecated | Superseded by ADR-<N>
**Date:** <date>

## Context
<why this decision was needed>

## Decision
<what was decided>

## Consequences
### Positive
### Negative
### Risks
```

### `slack_message` / `email` / `meeting_summary`
Free-form but calibrated to audience and tone.

---

## Execution Protocol

```
STEP 1 — Select template
  Match <type> to template above
  If template override provided → use that instead

STEP 2 — Generate draft
  Fill template with content derived from <context>
  Apply <audience> calibration (vocabulary, depth)
  Apply <tone> (formal: no contractions; casual: conversational; urgent: direct)
  Apply <max_length> compression/expansion

STEP 3 — Present draft to human
  Display full draft
  Ask: "Ready to use this draft, or would you like changes? [use/edit/cancel]"

STEP 4 — If "use" → return the final draft (do NOT send autonomously)
  Inform agent: "Draft ready. Route to appropriate sending channel."
  Agent presents the content for the user to send manually,
  OR agent requests Tier 2 approval before any programmatic send.

RETURN:
  {
    type:     "<artifact type>",
    draft:    "<full draft text>",
    audience: "<audience>",
    tone:     "<tone>",
    word_count: <N>,
    ready_to_send: false  // always false — human decides to send
  }
```

---

## Usage Examples

```
# Draft a GitHub issue for a bug
draft(
  type="github_issue",
  context="Login form doesn't validate email format. Users can submit without @.
           Found in production. Affects all browsers. No error shown to user.",
  audience="engineering",
  tone="professional"
)

# Draft a PR description
draft(
  type="github_pr",
  context="Added email validation to signup form. Wrote 4 unit tests.
           Closes #142. No breaking changes.",
  audience="engineering"
)

# Draft a postmortem
draft(
  type="postmortem",
  context="API was down for 45 min due to OOM on pod. Fixed by increasing memory
           limit from 512MB to 1GB. 340 users affected.",
  audience="management",
  tone="formal"
)

# Draft a Slack message about a deploy
draft(
  type="slack_message",
  context="Deployed v2.4.1 to production. New feature: bulk user import.
           No issues during deploy.",
  audience="product",
  tone="casual"
)
```
