# Atomic Skill: summarize
# .agents/skills/atomic/summarize.md
# Type: General-Purpose Primitive
# Available to: ALL agents
# Permission Tier: 1 (auto-approved — read-only, no side effects)

---

## Purpose
Condense long text (crawl results, documents, session logs, reports) into
a structured summary at a configurable compression level. Preserves key
facts, decisions, numbers, and warnings while removing redundancy.

**When to use:** After `crawl_site` returns > 10 pages. After `read_document`
returns > 5,000 words. Before injecting large content into an agent's context window.

---

## Inputs

| Field | Required | Description |
|-------|----------|-------------|
| `content` | ✅ | Text to summarize (string or file path) |
| `target_length` | Optional | `brief` (5%) \| `short` (15%) \| `medium` (30%) \| `detailed` (60%). Default: `short` |
| `format` | Optional | `prose` (default) \| `bullets` \| `structured` \| `tldr` |
| `preserve` | Optional | What to always keep: `["numbers", "decisions", "warnings", "code", "urls"]` |
| `focus` | Optional | What to emphasize: free-form topic e.g. `"authentication"`, `"performance"` |
| `title` | Optional | Title for the summary document |

---

## Target Length Guide

| Level | Approx. compression | Use for |
|-------|---------------------|---------|
| `brief` | 95% reduction | Single paragraph — "headline" only |
| `short` | 85% reduction | 5-10 bullets or 2-3 paragraphs — standard default |
| `medium` | 70% reduction | Detailed summary preserving most key points |
| `detailed` | 40% reduction | Near-complete but removes duplication and filler |

---

## Preserve Rules

When `preserve` includes a tag, those elements are **never removed** even if
compression level would otherwise cut them:

| Tag | What is always kept |
|-----|---------------------|
| `numbers` | All specific numeric values, percentages, measurements |
| `decisions` | Sentences containing "decided", "chose", "selected", "rejected" |
| `warnings` | Sentences with "warning", "caution", "risk", "failure", "error", "bug" |
| `code` | All inline code and code blocks |
| `urls` | All URLs and file paths |

---

## Execution Protocol

```
STEP 1 — Resolve content
  If content is a file path → read_document(path=<content>)
  If content is a URL → browse_url(url=<content>)
  If content is a string → use directly

STEP 2 — Pre-analysis
  Word count: <N>
  Target word count: <N × compression_rate>
  Detect structure: headings, sections, lists, tables
  Extract preserve-tagged elements: save as protected set

STEP 3 — Compress
  Remove: filler phrases, repeated information, examples when principle is clear,
           lengthy transitions, marketing language
  Keep: topic sentences, conclusions, findings, data points, protected elements
  If focus specified: weight sentences containing <focus> keywords × 2 in scoring

STEP 4 — Format output
  prose:      Flowing paragraphs
  bullets:    One key point per bullet, grouped by section heading
  structured: Section headers preserved → bullets under each
  tldr:       Single sentence + 3 key takeaways max

STEP 5 — Quality check
  Verify preserved elements all appear in output
  Verify word count is within 10% of target
  Verify no hallucinated content introduced

RETURN:
  {
    title:         "<title or auto-generated>",
    format:        "<format>",
    target_length: "<level>",
    original_words: <N>,
    summary_words:  <M>,
    compression:    "<X%>",
    summary:        "<the summary text>",
    preserved:      ["<element1>", ...]  // what was force-kept
  }
```

---

## Usage Examples

```
# Summarize a large documentation crawl
summarize(
  content=crawl_result,
  target_length="short",
  format="structured",
  preserve=["numbers", "warnings"],
  focus="authentication"
)

# TL;DR of a long research paper
summarize(
  content="./evidence/kafka-benchmark.pdf",
  target_length="brief",
  format="tldr"
)

# Summarize a session audit log for /retro
summarize(
  content=".agents/audit.jsonl",
  target_length="medium",
  format="bullets",
  preserve=["decisions", "warnings"]
)

# Compress a verbose API response for context injection
summarize(
  content=api_response_text,
  target_length="short",
  format="bullets",
  preserve=["numbers", "urls"]
)
```
