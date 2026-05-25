# Atomic Skill: diff_content
# .agents/skills/atomic/diff_content.md
# Type: General-Purpose Primitive
# Available to: ALL agents
# Permission Tier: 1 (auto-approved — read-only, no side effects)

---

## Purpose
Compare two versions of text, files, APIs, or specs and return a structured
diff. Two modes: **line** (exact text diff) and **semantic** (meaning diff —
detects intent changes even if wording differs).

**Use when:** Reviewing what changed between two API responses, comparing
old vs new spec, understanding what a PR changed in plain English.

---

## Inputs

| Field | Required | Description |
|-------|----------|-------------|
| `before` | ✅ | Original version: file path, URL, or string |
| `after` | ✅ | New version: file path, URL, or string |
| `mode` | Optional | `line` (default for code) \| `semantic` (for prose/specs) |
| `format` | Optional | `unified` (default) \| `side_by_side` \| `summary` \| `plain_english` |
| `focus` | Optional | Which sections/fields to compare. Default: everything |
| `ignore` | Optional | Patterns to ignore: `["whitespace", "comments", "timestamps"]` |
| `context_lines` | Optional | Lines of context in unified diff. Default: 3 |

---

## Mode Details

### `line` mode (exact diff)
- Standard unified diff (like `git diff`)
- Identifies: added lines (+), removed lines (-), changed lines (change pair)
- Best for: code files, configuration, structured data

### `semantic` mode (meaning diff)
- Groups changes by concept, not by line
- Identifies: new requirements added, requirements removed, scope changes,
  tone shifts, constraint changes
- Best for: API specs, design docs, requirements, changelogs, prose documents
- Example: "Section 2 now requires HTTPS where HTTP was previously acceptable"

---

## Execution Protocol

```
STEP 1 — Resolve inputs
  For each of <before> and <after>:
    If file path → read_document(path=<...>)
    If URL → browse_url(url=<...>)
    If string → use directly

STEP 2 — Apply ignore filters
  whitespace: normalize all whitespace before comparing
  comments:   strip comment lines (// # /* */ --)
  timestamps: remove ISO-8601, Unix timestamps, date strings

STEP 3 — Compute diff

  IF mode=line:
    Run unified diff algorithm
    Apply context_lines
    Group consecutive changes into hunks

  IF mode=semantic:
    Split both texts into semantic units (sentences/paragraphs/sections)
    Align units by meaning (not position)
    For each unit: UNCHANGED | ADDED | REMOVED | CHANGED
    For CHANGED: describe the nature of the change in plain English

STEP 4 — Format output

  unified:       Standard +/- diff format
  side_by_side:  | Before | After | in table
  summary:       Bullet list of what changed at high level
  plain_english: "Section X changed from Y to Z. New requirement: ..."

RETURN:
  {
    mode:           "line | semantic",
    format:         "<format>",
    before_source:  "<path or url or 'inline'>",
    after_source:   "<path or url or 'inline'>",
    changes: {
      added:    <N>,    // lines or semantic units added
      removed:  <N>,
      modified: <N>,
      unchanged: <N>
    },
    diff:     "<formatted diff output>",
    summary:  "<one-line summary: 'X lines changed: N added, M removed'>",
    notable:  ["<key change 1>", "<key change 2>"]  // semantic mode
  }
```

---

## Usage Examples

```
# Compare two config files
diff_content(
  before="./config/old-env.yaml",
  after="./config/new-env.yaml",
  mode="line",
  ignore=["comments", "whitespace"]
)

# Compare API response before and after a refactor
diff_content(
  before=old_api_response,
  after=new_api_response,
  mode="semantic",
  format="plain_english"
)

# Understand what changed in a PR's main file
diff_content(
  before="https://github.com/org/repo/blob/main/src/auth.ts",
  after="https://github.com/org/repo/blob/pr-branch/src/auth.ts",
  mode="line",
  format="unified"
)

# Design spec comparison
diff_content(
  before="./docs/api-spec-v1.md",
  after="./docs/api-spec-v2.md",
  mode="semantic",
  format="summary"
)
# Output:
# - 3 new endpoints added: POST /users/bulk, GET /users/export, DELETE /users/:id/sessions
# - Authentication now required on all endpoints (was optional on GET routes)
# - Rate limiting changed from 100 req/min to 60 req/min
```
