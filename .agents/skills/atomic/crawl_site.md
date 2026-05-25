# Atomic Skill: crawl_site
# .agents/skills/atomic/crawl_site.md
# Type: General-Purpose Primitive
# Available to: Research Council, UX Researcher, Engineering Lead
# Permission Tier: 1 (auto-approved — read-only)

---

## Purpose
Recursively fetch ALL relevant content from a domain or docs site, following
internal links up to a configurable depth. Returns a structured map of all pages
with their content. Essential for: reading full documentation, understanding an
entire API surface, research material ingestion.

**Not for:** Single page reads (use `browse_url`). Not for link discovery only (use `browse_url` with `extract=links`).

---

## Inputs

| Field | Required | Description |
|-------|----------|-------------|
| `url` | ✅ | Starting URL (entry point). Must be https:// |
| `depth` | Optional | How many link-hops from start. Default: 2. Max: 5 |
| `same_domain_only` | Optional | Only follow links on the same domain. Default: true |
| `include_patterns` | Optional | URL patterns to include, e.g. `["/docs/", "/api/"]` |
| `exclude_patterns` | Optional | URL patterns to skip, e.g. `["/blog/", "/pricing/"]` |
| `max_pages` | Optional | Hard cap on pages fetched. Default: 50. Max: 200 |
| `extract` | Optional | Same as `browse_url`: `text` (default) \| `all` |

---

## Execution Protocol

```
STEP 1 — Seed queue
  queue = [<url>]
  visited = {}
  results = {}
  depth_tracker = { <url>: 0 }

STEP 2 — Crawl loop (breadth-first)
  WHILE queue not empty AND len(results) < max_pages:
    current_url = queue.pop(0)
    current_depth = depth_tracker[current_url]

    IF current_url in visited → skip
    IF current_depth > depth → skip

    page = browse_url(url=current_url, extract="all")
    results[current_url] = page
    visited.add(current_url)

    IF current_depth < depth:
      for link in page.links:
        IF same_domain_only AND link not on same domain → skip
        IF include_patterns defined AND link not matches any → skip
        IF exclude_patterns defined AND link matches any → skip
        IF link not in visited → queue.append(link)
        depth_tracker[link] = current_depth + 1

    Log progress: "Crawled <N>/<max_pages>: <current_url>"

STEP 3 — Deduplicate and structure
  Remove near-duplicate pages (> 90% same content by word overlap)
  Sort by depth (shallower = more important)

STEP 4 — Return structured result
  {
    root_url:      "<start url>",
    pages_crawled: <N>,
    depth_reached: <max depth actually reached>,
    pages: [
      {
        url:        "<page url>",
        depth:      <0-N>,
        title:      "<title>",
        content:    "<extracted text>",
        word_count: <N>
      },
      ...
    ],
    skipped_urls:  ["<urls skipped and why>"]
  }
```

---

## Summarize After Crawl

For large crawls (> 10 pages), automatically:
1. Run `summarize` on each page over 2,000 words
2. Produce a `site_map.md` showing page hierarchy with one-line summaries
3. Identify the 5 most content-rich pages (by unique information density)

```
site_map.md format:
# Site Map — <domain>
Crawled: <N> pages | Depth: <D> | Total words: <W>

## [Page Title] (depth 0)
  → Summary: <one-line>
  ## [Child Page] (depth 1)
    → Summary: <one-line>
```

---

## Usage Examples

```
# Read all of Next.js docs
crawl_site(url="https://nextjs.org/docs", depth=3, include_patterns=["/docs/"])

# Read a GitHub repo's wiki
crawl_site(url="https://github.com/org/repo/wiki", depth=2)

# Deep crawl of an API reference (limited scope)
crawl_site(url="https://api.example.com/docs", depth=4,
           include_patterns=["/reference/", "/guides/"], max_pages=100)

# Research Council material ingestion
crawl_site(url="https://kafka.apache.org/documentation/", depth=2, max_pages=30)
```

---

## Rate Limiting
- Respects `robots.txt` — never crawls disallowed paths
- 500ms delay between page fetches (prevents hammering servers)
- Uses `browse_url` for each page → all results cached individually
