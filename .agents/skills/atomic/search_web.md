# Atomic Skill: search_web
# .agents/skills/atomic/search_web.md
# Type: General-Purpose Primitive
# Available to: ALL agents
# Permission Tier: 1 (auto-approved)

---

## Purpose
Search the web for information and return ranked, structured results.
Returns page titles, URLs, and snippets — NOT full page content.
Always chain with `browse_url` to get the actual content of promising results.

**Pattern:** `search_web` → evaluate results → `browse_url` top 2-3 hits

---

## Inputs

| Field | Required | Description |
|-------|----------|-------------|
| `query` | ✅ | Natural language or keyword search query |
| `num_results` | Optional | Results to return. Default: 10. Max: 30 |
| `date_range` | Optional | `past_day` \| `past_week` \| `past_month` \| `past_year` \| `anytime` (default) |
| `site` | Optional | Restrict to a specific domain: `site:github.com` |
| `filetype` | Optional | Restrict to file type: `pdf` \| `doc` \| `csv` |

---

## Execution Protocol

```
STEP 1 — Query construction
  If query is vague: automatically add specificity qualifiers
    e.g. "redis performance" → "redis streams throughput benchmark 2023 2024"
  If query contains a year reference: include year in query for recency
  Log query to audit.jsonl before executing

STEP 2 — Execute search
  Call search MCP with constructed query
  Retrieve: title, url, snippet, domain, published_date (if available)

STEP 3 — Rank and filter results
  Sort by: (a) relevance to original query, (b) domain authority, (c) recency
  DISCARD results matching:
    - marketing/landing pages with no technical content
    - results behind paywalls (identified by snippet truncation + paywall signals)
    - duplicate domains (max 2 results per domain)

STEP 4 — Return structured results
  {
    query:           "<original query>",
    query_expanded:  "<query as sent to search engine>",
    results: [
      {
        rank:      1,
        title:     "<page title>",
        url:       "<url>",
        domain:    "<domain>",
        snippet:   "<150-char excerpt>",
        published: "<date or null>",
        signals:   ["authoritative", "recent", "technical"]  // quality signals
      },
      ...
    ],
    next_step: "Run browse_url on result[0].url and result[1].url for full content"
  }
```

---

## Query Writing Guidelines

| Situation | Good Query Pattern |
|-----------|-------------------|
| Technology comparison | `"<tech A> vs <tech B> production benchmark <year>"` |
| Finding failure cases | `"<technology> failure case site:github.com OR site:reddit.com"` |
| Finding documentation | `"<library> <feature> docs site:<official-domain>"` |
| Academic papers | `"<topic> research paper filetype:pdf"` |
| Real-world experience | `"<technology> production experience site:engineering.blog OR site:medium.com"` |
| Security vulnerabilities | `"<library> CVE <year> site:nvd.nist.gov"` |

---

## Usage Examples

```
# General research
search_web(query="Redis Streams vs Kafka throughput benchmark 2024")

# Restrict to official docs
search_web(query="PostgreSQL 16 logical replication", site="postgresql.org")

# Find recent failures/issues
search_web(query="NextJS 14 app router memory leak production",
           date_range="past_year")

# Academic search
search_web(query="distributed systems consensus algorithm comparison",
           filetype="pdf", num_results=5)
```

---

## Notes
- Never report search snippets as "the content" — always `browse_url` promising hits
- Snippets are often misleading; verify with full page read
- For Research Council: tag each result's domain with evidence tier before ingestion
