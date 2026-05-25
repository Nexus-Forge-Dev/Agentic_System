# Atomic Skill: fetch_page
# .agents/skills/atomic/fetch_page.md
# Type: Primitive — Web & URL
# Source: agents_and_skills_design.md §8.3 (Web & URL Skills)

---

## Purpose

Lightweight page fetch (no JavaScript rendering). Faster than `browse_url` for static pages.
Use when you know the page is static HTML and don't need JS-executed content.

## Inputs

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `url` | string | ✅ | The URL to fetch |
| `selector` | string | ❌ | CSS selector to extract only a specific section |

## Output

```json
{
  "url": "https://example.com",
  "status_code": 200,
  "content": "<text content of the page or selected element>",
  "content_type": "text/html"
}
```

## Behavior

- Makes a raw HTTP GET request (no browser, no JS engine)
- If `selector` provided: extracts only the matched element's text content
- If `selector` not provided: returns full page text (HTML stripped, clean text)
- Handles: HTML, plain text, JSON, XML response types
- Does NOT handle: JavaScript-heavy SPAs, pages requiring auth, pages with cookie gates
  → For those: use `browse_url` instead

## Permission Tier

Tier 1 — Auto-approved for reads to any non-sensitive URL.

## When to Use vs. browse_url

| Situation | Use |
|-----------|-----|
| Static HTML page, no JS required | `fetch_page` (faster) |
| SPA, dynamically loaded content | `browse_url` |
| Need all outbound links from page | `browse_url` |
| Need only a specific section | `fetch_page(selector=".content")` |

## Error Cases

| Error | Action |
|-------|--------|
| HTTP 4xx | Return error status to agent, do not retry |
| HTTP 5xx | Retry once after 2s delay, then return error |
| Timeout (>10s) | Return timeout error, log to tool_calls.jsonl |
| Connection refused | Return error immediately |
