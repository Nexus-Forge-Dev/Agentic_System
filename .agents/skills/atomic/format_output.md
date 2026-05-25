# Atomic Skill: format_output
# .agents/skills/atomic/format_output.md
# Type: Primitive — Data & Transform
# Source: agents_and_skills_design.md §8.3

---

## Purpose

Reformats any content into the requested output format.
Particularly useful for turning raw API responses or DB query results into readable reports.

## Inputs

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `content` | any | ✅ | The data to reformat (string, object, array) |
| `format` | enum | ✅ | Target format: `markdown`, `table`, `json`, `yaml`, `csv` |

## Output

Formatted string in the specified format.

## Format Behaviors

```
markdown → Renders headers, lists, code blocks, bold/italic
table    → ASCII table or markdown table (| col | col |) from array of objects
json     → Pretty-printed JSON with 2-space indent
yaml     → Clean YAML (no ---  header unless root is mapping)
csv      → Comma-separated with header row from first object's keys
```

## Examples

Input: `[{name: "auth.ts", coverage: 87}, {name: "api.ts", coverage: 62}]`
Format: `table`

Output:
```
| name    | coverage |
|---------|----------|
| auth.ts | 87       |
| api.ts  | 62       |
```

Format: `csv`
Output:
```
name,coverage
auth.ts,87
api.ts,62
```

## Permission Tier

Tier 1 — Pure transformation, no I/O. Always auto-approved.

## Use Cases

- Format DB query rows into a markdown table for a report
- Convert a JSON API response into readable YAML for human review
- Transform an array of test results into a CSV for export
- Format a structured summary into markdown for an artifact
