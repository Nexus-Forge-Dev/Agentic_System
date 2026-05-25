# /document-generate — Documentation Generation Skill
# Generates or updates /docs/ files from code, APIs, and comments
# Owner: Engineering Lead → delegates to Backend Architect / Frontend Developer
# Trigger: /document-generate [--scope <path>]
# Source: agents_and_skills_design.md §8.4 (Composite Skill Catalog)

---

## Preamble (runs first, always)

1. READ `.agents/MANIFEST.md` — current system state
2. READ `.agents/rules/global.md` — 12 ironclad rules
3. READ `.agents/PROJECT.md` — project stack and naming conventions
4. READ `.agents/learned.jsonl` — tag-filter: `["documentation", "docs"]`
5. CHECK `task.md` — verify task exists and is correctly scoped
6. VALIDATE permissions — all planned operations are Tier 1 (read + write to /docs/)
7. LOG `{"action":"skill-activate","skill":"/document-generate","ts":"<ISO>"}` → `audit.jsonl`

---

## Skill Flow

```
User: /document-generate [--scope <path>]
  │
  ▼
Engineering Lead activates
  │
  ├─ Phase 1: Discovery (what needs documenting)
  │   If --scope provided:
  │     → Analyze only files under <path>
  │   If no --scope:
  │     → search_code(semantic, "exported functions, classes, APIs, REST endpoints")
  │     → List all modules with missing or outdated docs
  │
  ├─ Phase 2: Code Analysis
  │   For each file to document:
  │     → read_file() → parse exports, functions, types, parameters, return types
  │     → trace_call() → identify callers/callees to document usage
  │     → explain_code(audience="engineer") → generate plain-language explanation
  │     → Check for existing JSDoc/docstrings → preserve and enrich them
  │
  ├─ Phase 3: Documentation Writing
  │   Generates or updates:
  │     → /docs/api/README.md         (API reference — endpoints, schemas)
  │     → /docs/architecture.md       (system architecture overview)
  │     → /docs/modules/<name>.md     (per-module documentation)
  │     → Code comments (JSDoc/docstrings) in-file
  │   Rules:
  │     → Never remove existing documentation without reading it first (RULE 05)
  │     → Preserve all comments unrelated to the change
  │     → Every public function must have: purpose, parameters, return value, example
  │
  ├─ Phase 4: Cross-Reference Validation
  │   → Verify all code examples in docs actually compile or run
  │   → Verify all file paths referenced in docs exist
  │   → Check for broken internal links between doc pages
  │
  └─ Phase 5: Deliver
      → Return Result Message to Orchestrator
        artifacts: [all /docs/ files created or modified]
```

---

## Output Artifacts

| Artifact | Path | Contents |
|----------|------|----------|
| API Reference | `/docs/api/README.md` | All endpoints with method, path, params, response schemas |
| Architecture | `/docs/architecture.md` | System structure, division of responsibility, key decisions |
| Module Docs | `/docs/modules/<name>.md` | One page per module with exports, usage, examples |
| In-code JSDoc | same files as source | Function-level documentation in place |

---

## Rules (Hard)

- **RULE 05: Read before writing** — always read the existing file before generating docs
- Never overwrite documentation with empty content
- Never document private/internal functions — only exported/public surfaces
- Code examples must use real types from the actual codebase, not `any`
- If a function lacks enough context to document it accurately → flag it, do not guess
