# Atomic Skill: transform_data
# .agents/skills/atomic/transform_data.md
# Type: General-Purpose Primitive
# Available to: ALL agents
# Permission Tier: 1 (auto-approved — pure transformation, no I/O side effects)

---

## Purpose
Convert data between formats, reshape structures, filter/map/aggregate
datasets without any external calls. Pure in-memory transformation.
Used for: converting API responses for storage, reshaping CSV → JSON,
normalizing data before validation, preparing report inputs.

---

## Supported Transformations

| From → To | Operation |
|-----------|-----------|
| JSON → YAML | Serialization |
| YAML → JSON | Serialization |
| CSV → JSON array | Parse + structure |
| JSON array → CSV | Flatten + serialize |
| JSON → Markdown table | Visualization |
| Any → filtered subset | Field selection / projection |
| Any → reshaped | Key rename, nest/flatten |
| Any → aggregated | Group by, count, sum, avg |

---

## Inputs

| Field | Required | Description |
|-------|----------|-------------|
| `data` | ✅ | Input data: string (JSON/YAML/CSV) or object |
| `from_format` | Optional | `json` \| `yaml` \| `csv` \| `auto` (default, inferred) |
| `to_format` | ✅ | `json` \| `yaml` \| `csv` \| `markdown_table` |
| `transform` | Optional | Transformation spec (see below) |

---

## Transform Spec

```json
// Project: keep only specific fields
{ "select": ["id", "name", "email"] }

// Rename fields
{ "rename": { "user_id": "id", "user_name": "name" } }

// Filter: keep only records matching condition
{ "filter": { "field": "status", "op": "eq", "value": "active" } }

// Flatten nested structure
{ "flatten": { "path": "user.address", "prefix": "address_" } }

// Aggregate
{
  "aggregate": {
    "group_by": "department",
    "operations": [
      { "field": "salary", "op": "avg", "as": "avg_salary" },
      { "field": "id", "op": "count", "as": "headcount" }
    ]
  }
}

// Chain multiple transforms
{
  "pipeline": [
    { "filter": { "field": "active", "op": "eq", "value": true } },
    { "select": ["id", "name", "role"] },
    { "rename": { "id": "user_id" } }
  ]
}
```

---

## Execution Protocol

```
STEP 1 — Infer input format (if from_format=auto)
  Try JSON.parse → if succeeds: json
  Try YAML.parse → if succeeds: yaml
  Check for comma-separated first line → csv
  Else → FAILED: "Cannot detect format. Specify from_format explicitly."

STEP 2 — Apply transform spec (if provided)
  Execute pipeline in order
  On error at any step: report which step failed + partial result so far

STEP 3 — Serialize to target format
  json:           JSON.stringify with 2-space indent
  yaml:           YAML.dump with block style
  csv:            RFC 4180 compliant, headers on first row
  markdown_table: | header | header | rows |

STEP 4 — Return
  {
    result:           "<transformed data as string>",
    input_format:     "<detected or specified>",
    output_format:    "<to_format>",
    records_in:       <N>,  // for array data
    records_out:      <M>,  // after filter
    transforms_applied: ["<op1>", "<op2>"]
  }
```

---

## Usage Examples

```
# Convert API JSON response to YAML for config
transform_data(data=api_response, to_format="yaml")

# Extract only relevant fields from a large payload
transform_data(
  data=raw_payload,
  to_format="json",
  transform={ "select": ["id", "name", "created_at"] }
)

# Convert CSV to JSON for processing
transform_data(data="id,name,score\n1,Alice,95\n2,Bob,87", to_format="json")

# Create a markdown table for a report
transform_data(
  data=benchmark_results,
  to_format="markdown_table",
  transform={ "select": ["test", "p50_ms", "p99_ms", "rps"] }
)

# Aggregate metrics by environment
transform_data(
  data=cost_data,
  to_format="json",
  transform={
    "aggregate": {
      "group_by": "environment",
      "operations": [{ "field": "cost_usd", "op": "sum", "as": "total_cost" }]
    }
  }
)
```
