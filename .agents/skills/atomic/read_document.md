# Atomic Skill: read_document
# .agents/skills/atomic/read_document.md
# Type: General-Purpose Primitive
# Available to: ALL agents
# Permission Tier: 1 (auto-approved — read-only)

---

## Purpose
Read and extract structured content from local files: PDF, DOCX, XLSX, CSV,
Markdown, plain text, JSON, YAML. Returns parsed, human-readable text with
structure preserved.

**Not for:** Web URLs (use `browse_url`). Not for code analysis (use `search_code`).

---

## Supported Formats

| Format | What Is Extracted |
|--------|-----------------|
| **PDF** | All text, tables (as markdown), headings, page numbers |
| **DOCX** | Body text, headings, tables, comments, tracked changes |
| **XLSX / CSV** | Data as markdown tables; sheet names; cell formulas (XLSX) |
| **MD / TXT** | Raw content, optionally structured by headings |
| **JSON** | Pretty-printed with path annotations |
| **YAML** | Pretty-printed with comments preserved |
| **HTML** (local) | Rendered text (same as browse_url but for local files) |

---

## Inputs

| Field | Required | Description |
|-------|----------|-------------|
| `path` | ✅ | Absolute or workspace-relative file path |
| `pages` | Optional | For PDFs: page range. `"1-5"`, `"1,3,7"`, `"all"` (default) |
| `sheet` | Optional | For XLSX: sheet name or index. Default: all sheets |
| `extract` | Optional | `text` (default) \| `tables` \| `structure` \| `all` |
| `max_chars` | Optional | Truncate output at N chars. Default: 50000 |

---

## Execution Protocol

```
PRE-FLIGHT:
  Verify file exists at <path>
  Check file size — if > 20MB: warn and confirm before proceeding
  Detect format from file extension (not file name)
  Check read permission tier → Tier 1 (always auto-approved for reads)

EXECUTE:
  Parse file per format rules
  Apply <extract> mode filter
  Apply <max_chars> truncation if needed
    → If truncated: note "Content truncated at <N> chars. File has <total> chars."
    → Suggest: pages= or sheet= to narrow scope

RETURN:
  {
    path:          "<file path>",
    format:        "pdf | docx | xlsx | csv | md | txt | json | yaml",
    extract_mode:  "<mode>",
    pages_read:    "<range or 'all'>",
    content:       "<extracted text>",
    tables:        ["<table-md>"],     // if extract=tables|all
    word_count:    <N>,
    truncated:     true | false,
    char_limit:    <N>
  }
```

---

## Usage Examples

```
# Read a PDF research paper
read_document(path="./docs/kafka-streams-benchmark.pdf")

# Read only pages 1-3 of a PDF
read_document(path="./docs/system-design.pdf", pages="1-3")

# Extract only tables from an Excel file
read_document(path="./data/performance-results.xlsx", extract="tables")

# Read a specific CSV sheet
read_document(path="./data/metrics.xlsx", sheet="Q1 Results", extract="tables")

# Read a YAML config
read_document(path="./.env.example", extract="all")

# Council: ingest a PDF research paper as evidence
read_document(path="./evidence/database-benchmark.pdf", extract="all")
```

---

## Evidence Tier Assignment (for Research Council)
After `read_document`, Moderator assigns tier based on source:
- Peer-reviewed papers, official benchmarks → Tier 1
- Conference slides/talks → Tier 2
- Internal documents, team estimates → Tier 2-3
