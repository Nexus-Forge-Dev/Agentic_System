# Atomic Skill: browse_url
# .agents/skills/atomic/browse_url.md
# Type: General-Purpose Primitive
# Available to: ALL agents
# Permission Tier: 1 (auto-approved for read, Tier 2 if filling/submitting forms)

---

## Purpose
Retrieve the full readable content of a single URL. Returns structured text:
headings, body text, tables, code blocks, links. Used for reading documentation,
blog posts, GitHub issues, benchmark reports, any single web page.

**Not for:** Crawling multi-page sites (use `crawl_site`), searching (use `search_web` first)

---

## Inputs

| Field | Required | Description |
|-------|----------|-------------|
| `url` | ✅ | Full URL including scheme (https://) |
| `extract` | Optional | `text` (default) \| `tables` \| `code_blocks` \| `links` \| `all` |
| `timeout_ms` | Optional | Max wait in ms. Default: 10000 |

---

## Execution Protocol

```
PRE-FLIGHT:
  Check cache: .agents/cache/browser/<hash(url)>.json
    → Cache TTL: 3600 seconds (1 hour) for most pages
    → Cache TTL: 300 seconds for pages with live data (status pages, dashboards)
    → If cache hit AND not expired → return cached result, skip HTTP call
    → Log to tool_calls.jsonl: { cache_hit: true }

EXECUTE:
  1. Navigate to <url>
  2. Wait for page to settle (no pending network requests OR timeout)
  3. Extract content per <extract> mode:
     - text:        All readable text, preserving heading hierarchy
     - tables:      Markdown-formatted tables only
     - code_blocks: Fenced code blocks with language tags
     - links:       All <a href> targets with link text
     - all:         Full structured extraction (text + tables + code + links)
  4. Strip: ads, nav bars, cookie banners, footers, tracking pixels
  5. Preserve: headings (H1→H6 as # marks), inline code, numbered lists

POST-EXECUTE:
  Write result to cache:
    { key, tool: "browser", operation: "read_page", inputs, result, ts, ttl_seconds, expires_at }
  Log to tool_calls.jsonl:
    { ts, tool: "browser", operation: "read_page", url, cache_hit: false,
      duration_ms, content_length_chars, status_code }

RETURN:
  {
    url:        "<final url after redirects>",
    title:      "<page title>",
    content:    "<extracted text>",
    word_count: <number>,
    links:      ["<url1>", "<url2>", ...],   // only if extract=links|all
    tables:     ["<table-md>"],              // only if extract=tables|all
    code:       ["<code-block>"],            // only if extract=code_blocks|all
    cached:     true | false,
    fetched_at: "<ISO-8601>"
  }
```

---

## Error Handling

| Error | Action |
|-------|--------|
| HTTP 4xx (not found, forbidden) | Return FAILED: `{error: "http_4xx", status: <code>, url}` |
| HTTP 5xx (server error) | Retry once after 2s. If still failing → FAILED |
| Timeout | Return PARTIAL with whatever was loaded before timeout |
| JavaScript-heavy page (content not in HTML) | Note: content may be incomplete — flag in result |

---

## Usage Examples

```
# Read a documentation page
browse_url(url="https://nextjs.org/docs/app/building-your-application/routing")

# Extract only tables from a benchmark page
browse_url(url="https://bundlephobia.com/package/react@18", extract="tables")

# Get all links from a changelog
browse_url(url="https://github.com/org/repo/blob/main/CHANGELOG.md", extract="links")
```

---

## Notes for Research Council Use
- Moderator uses `browse_url` to ingest each `--materials` URL before debate begins
- All pages ingested this way are logged to the `evidence_manifest.json`
- Content is assigned an evidence tier by the Moderator after ingestion
- Results are cached for 1 hour — re-ingesting the same URL in the same session hits cache
