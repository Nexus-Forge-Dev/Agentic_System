# Atomic Skills Registry
# .agents/skills/atomic/REGISTRY.md
#
# All 14 general-purpose primitive skills available to any agent.
# These are the lowest-level building blocks — composable by any division.
# No agent needs to route through another division to use these.

---

## Quick Reference

| Skill | Tier | Purpose | Chain With |
|-------|------|---------|-----------|
| [`browse_url`](./browse_url.md) | 1 | Read full content of one URL | → `summarize` if > 2K words |
| [`crawl_site`](./crawl_site.md) | 1 | Read ALL pages of a docs site/domain | → `summarize` for site map |
| [`search_web`](./search_web.md) | 1 | Find URLs via web search | → `browse_url` top results |
| [`read_document`](./read_document.md) | 1 | Read PDF, DOCX, XLSX, CSV, JSON, YAML | → `summarize` if large |
| [`api_call`](./api_call.md) | **2** | HTTP call to external service | Always requires human approval |
| [`validate_schema`](./validate_schema.md) | 1 | Validate JSON/YAML against schema | → `api_call` after validation passes |
| [`transform_data`](./transform_data.md) | 1 | Convert/reshape/filter/aggregate data | → `validate_schema` after transform |
| [`query_db`](./query_db.md) | 1/2 | SQL query (SELECT=Tier1, writes=Tier2) | → `transform_data` on results |
| [`search_code`](./search_code.md) | 1 | Find code by name or concept | → `trace_call` for call graph |
| [`trace_call`](./trace_call.md) | 1 | Build call graph (callers / callees) | → `explain_code` for context |
| [`explain_code`](./explain_code.md) | 1 | Audience-calibrated code explanations | → `draft` for documentation |
| [`summarize`](./summarize.md) | 1 | Compress long content at configurable ratio | → inject into agent context |
| [`diff_content`](./diff_content.md) | 1 | Line or semantic diff of two versions | → `draft` for changelog |
| [`draft`](./draft.md) | 1/2 | Write issues, PRs, postmortems, ADRs | Human approves before send |

---

## Composition Patterns

### Research Pattern
```
search_web("topic")
  → browse_url(top results)
  → summarize(each page, target_length="short")
  → diff_content(old_finding, new_finding)   [if comparing sources]
  → draft(type="adr", context=findings)
```

### Investigation Pattern
```
search_code("error symptom", mode="semantic")
  → trace_call(target="suspicious_function", direction="both")
  → explain_code(target="found_function", audience="engineer", focus="risks")
  → query_db("SELECT ... WHERE related_data", purpose="verify hypothesis")
```

### Data Pipeline Pattern
```
read_document(path="input.csv")
  → validate_schema(data, schema=expected_schema)
  → transform_data(data, to_format="json", transform={...})
  → validate_schema(transformed, schema=output_schema)
  → api_call(method="POST", url=endpoint, body=transformed)  [Tier 2 gate]
```

### Deploy Validation Pattern
```
validate_schema(payload=env_config, schema=required_schema)
  → query_db("SELECT COUNT(*) FROM migrations WHERE applied = false")
  → diff_content(before=current_api, after=new_api, mode="semantic")
  → draft(type="changelog_entry", context=changes)
```

---

## Permission Summary

```
Tier 1 (auto-approved):
  browse_url, crawl_site, search_web, read_document,
  validate_schema, transform_data, search_code, trace_call,
  explain_code, summarize, diff_content
  query_db (SELECT only, local/staging)
  draft (creation only)

Tier 2 (human approval required):
  api_call (ALWAYS)
  query_db (INSERT / UPDATE / DELETE, any env)
  query_db (SELECT on production)
  draft (when programmatically sending via external channel)

Tier 3 (BLOCKED — never executes):
  query_db (DROP, TRUNCATE, ALTER)
```

---

## Cache Behavior

| Skill | Result Cached? | TTL |
|-------|---------------|-----|
| browse_url | ✅ | 1 hour |
| crawl_site | ✅ | 1 hour (each page) |
| search_web | ✅ | 30 min |
| read_document | ❌ | Files may change between reads |
| api_call | ❌ | Always live (POST/PUT/PATCH) |
| validate_schema | ❌ | Pure, fast — no need to cache |
| transform_data | ❌ | Pure, fast |
| query_db (SELECT) | ✅ | 30 seconds |
| search_code | ✅ | 5 min |
| trace_call | ✅ | 5 min |
| explain_code | ❌ | Code may change between sessions |
| summarize | ❌ | Input may change |
| diff_content | ❌ | Inputs may change |
| draft | ❌ | Always generated fresh |
