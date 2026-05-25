# Atomic Skill: extract_text
# .agents/skills/atomic/extract_text.md
# Type: Primitive — Web & Content
# Source: agents_and_skills_design.md §8.3

---

## Purpose

Downloads a URL and converts it to clean text in the specified format.
Handles multiple file types: PDF, HTML, DOCX, and plain text.

## Inputs

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `url` | string | ✅ | URL to download and convert |
| `format` | enum | ✅ | Output format: `markdown`, `plain`, or `json` |

## Output

Cleaned text string in the specified format.

```
markdown → Headers preserved as #/##/###, lists as -, code as `backticks`
plain    → All formatting stripped, raw readable text only
json     → Structured {title, sections: [{heading, content}], metadata}
```

## Behavior

- Detects file type automatically from Content-Type header or URL extension
- Supported formats:
  - `.html` / `text/html` → strips tags, preserves structure
  - `.pdf` / `application/pdf` → extracts text layer; OCRs image-heavy PDFs
  - `.docx` / `.doc` → extracts paragraphs and headings
  - `.txt` / `text/plain` → direct passthrough
  - JSON/YAML at URL → converts to readable format
- Removes: navigation elements, cookie banners, headers/footers (for HTML)

## Permission Tier

Tier 1 — Auto-approved.

## Difference from read_document

| Skill | Input | Best for |
|-------|-------|---------|
| `extract_text` | URL (downloads first) | Remote files, web-hosted PDFs |
| `read_document` | Local file path or URL | Local files, arbitrary document formats |

Both are valid — `extract_text` is the URL-first variant.
