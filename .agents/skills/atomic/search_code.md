# Atomic Skill: search_code
# .agents/skills/atomic/search_code.md
# Type: General-Purpose Primitive
# Available to: ALL agents
# Permission Tier: 1 (auto-approved — read-only)

---

## Purpose
Find functions, classes, types, variables, imports, patterns, or concepts across
the codebase. Two modes: **exact** (literal string match) and **semantic**
(conceptual match — finds related code even if the exact words differ).

**Use when:** You need to locate where something is defined, where it's used,
or find all files matching a pattern, before reading or modifying them.

---

## Inputs

| Field | Required | Description |
|-------|----------|-------------|
| `query` | ✅ | What to find: function name, concept, pattern, error message |
| `mode` | Optional | `exact` \| `semantic` (default: `exact` for identifiers, `semantic` for concepts) |
| `path` | Optional | Restrict to directory: `src/`, `tests/`, `services/auth/` |
| `extensions` | Optional | File types: `[".ts", ".tsx"]` or `[".py"]` |
| `exclude` | Optional | Paths to skip: `["node_modules/", ".git/", "dist/"]` |
| `context_lines` | Optional | Lines of context around each match. Default: 3 |
| `max_results` | Optional | Cap on results. Default: 20 |

---

## Execution Protocol

```
IF mode=exact:
  Run regex/grep across all files (respecting path/extensions/exclude filters)
  Return each match with: file path, line number, matched line, context_lines above/below

IF mode=semantic:
  1. Parse query into conceptual intent (e.g. "authentication middleware" →
     look for: middleware, auth, token, session, guard, verify, JWT)
  2. Expand to synonym set: auth|authentication|authz|authorize
  3. Run expanded search across codebase
  4. Score results by: identifier match, file path relevance, import graph distance
  5. Deduplicate: if same function referenced in 10 files, group under definition file
  6. Return ranked by relevance score

RETURN:
  {
    query:   "<original query>",
    mode:    "exact | semantic",
    matches: [
      {
        file:    "src/services/auth.service.ts",
        line:    42,
        match:   "export function verifyToken(token: string): User {",
        context: ["// line 40", "// line 41", ">>> matched line", "// line 43"],
        score:   0.95  // semantic mode only
      },
      ...
    ],
    grouped_by_file: {
      "src/services/auth.service.ts": [<match1>, <match2>]
    },
    total_matches: <N>,
    searched_files: <N>
  }
```

---

## Search Patterns Reference

```
# Find where a function is defined
search_code(query="getUserById", mode="exact")

# Find all usages of a function
search_code(query="getUserById", mode="exact", context_lines=5)

# Find all files importing a module
search_code(query="from './auth.service'", mode="exact", extensions=[".ts"])

# Semantic: find authentication-related code
search_code(query="JWT token verification middleware", mode="semantic")

# Find all TODO/FIXME comments
search_code(query="TODO|FIXME|HACK|XXX", mode="exact")

# Find environment variable usage
search_code(query="process.env.", mode="exact", path="src/")

# Find all database query calls
search_code(query="prisma.user.findMany", mode="exact")

# Semantic: find error handling patterns
search_code(query="error boundary try catch global error handler", mode="semantic", path="src/")

# Find test files for a specific module
search_code(query="auth.service", mode="exact", path="tests/", extensions=[".test.ts"])
```

---

## Recommended Workflow

```
1. search_code(query="<name>", mode="exact")
   → Locate definition file + line number

2. view_file(path=<file>, start=<line-5>, end=<line+50>)
   → Read the full implementation

3. search_code(query="<name>", mode="exact", context_lines=1)
   → Find all call sites

4. Only then → make edits (Rule 05: READ BEFORE WRITING)
```
