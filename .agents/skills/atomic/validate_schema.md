# Atomic Skill: validate_schema
# .agents/skills/atomic/validate_schema.md
# Type: General-Purpose Primitive
# Available to: ALL agents
# Permission Tier: 1 (auto-approved — read-only, no side effects)

---

## Purpose
Validate a JSON or YAML payload against a schema or set of rules. Returns
a structured validation report: pass/fail, all errors with paths, suggested fixes.
Used before any API call, config deploy, or data pipeline step.

---

## Inputs

| Field | Required | Description |
|-------|----------|-------------|
| `payload` | ✅ | The JSON/YAML data to validate (as string or object) |
| `schema` | ✅ | JSON Schema (Draft 7/2019/2020), or a file path to one |
| `format` | Optional | `json` (default) \| `yaml` |
| `strict` | Optional | If true: extra properties not in schema = error. Default: false |
| `coerce` | Optional | If true: attempt type coercion (string "42" → number 42). Default: false |

---

## Execution Protocol

```
STEP 1 — Parse payload
  If format=json: JSON.parse(<payload>)
  If format=yaml: YAML.parse(<payload>)
  If parse fails → FAILED: { error: "parse_error", detail: "<syntax error message>" }

STEP 2 — Resolve schema
  If <schema> is a file path → read_document(path=<schema>)
  If <schema> is an inline object → use directly
  If schema references $ref → resolve all $ref pointers before validating

STEP 3 — Validate
  Run JSON Schema validation against parsed payload
  Collect ALL errors (not just first):
    - path:     JSON pointer to the failing field (e.g. "/user/email")
    - rule:     which schema rule failed ("type", "required", "minLength", etc.)
    - got:      actual value
    - expected: what the schema expected

STEP 4 — Return result
  {
    valid:   true | false,
    errors:  [
      {
        path:     "/field/subfield",
        rule:     "type | required | minLength | format | ...",
        message:  "<human-readable description>",
        got:      <actual value>,
        expected: <expected>
      }
    ],
    warnings: [   // non-blocking issues
      "<extra property 'foo' not in schema>",
      ...
    ],
    suggestions: [  // actionable fixes
      "Field '/user/email' expects format 'email' — check for missing '@'",
      ...
    ]
  }
```

---

## Common Schema Patterns

```json
// Validate environment config
{
  "type": "object",
  "required": ["DATABASE_URL", "PORT", "NODE_ENV"],
  "properties": {
    "DATABASE_URL": { "type": "string", "pattern": "^postgres://" },
    "PORT":         { "type": "string", "pattern": "^[0-9]+$" },
    "NODE_ENV":     { "type": "string", "enum": ["development","staging","production"] }
  }
}

// Validate API response
{
  "type": "object",
  "required": ["id", "status", "data"],
  "properties": {
    "id":     { "type": "string", "format": "uuid" },
    "status": { "type": "string", "enum": ["success", "error"] },
    "data":   { "type": "object" }
  }
}
```

---

## Usage Examples

```
# Validate a kubernetes manifest before apply
validate_schema(
  payload="./k8s/deployment.yaml",
  schema="https://json.schemastore.org/kubernetes.json",
  format="yaml"
)

# Validate env vars before deploy
validate_schema(
  payload={ "DATABASE_URL": "postgres://...", "PORT": "3000" },
  schema={ "required": ["DATABASE_URL", "PORT"], ... }
)

# Strict validation (no extra fields allowed)
validate_schema(payload=api_response, schema=api_schema, strict=true)
```
