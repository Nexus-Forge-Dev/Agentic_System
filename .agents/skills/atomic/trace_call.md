# Atomic Skill: trace_call
# .agents/skills/atomic/trace_call.md
# Type: General-Purpose Primitive
# Available to: ALL agents
# Permission Tier: 1 (auto-approved — read-only, static analysis)

---

## Purpose
Build a call graph for a function: who calls it, what it calls, how deep
the chain goes. Essential for understanding impact before changes, finding
circular dependencies, and tracing the execution path of a bug.

**Two directions:**
- **Callers** (`up`): Who calls this function? (impact analysis)
- **Callees** (`down`): What does this function call? (dependency analysis)

---

## Inputs

| Field | Required | Description |
|-------|----------|-------------|
| `target` | ✅ | Function/method name or `ClassName.method` |
| `file` | Optional | If known, the file containing the target (speeds up analysis) |
| `direction` | Optional | `up` (callers) \| `down` (callees) \| `both` (default) |
| `depth` | Optional | How many hops to trace. Default: 3. Max: 8 |
| `path` | Optional | Restrict analysis to a directory |
| `exclude` | Optional | Skip directories: `["node_modules/", "tests/"]` |

---

## Execution Protocol

```
STEP 1 — Locate target definition
  search_code(query=<target>, mode="exact", context_lines=10)
  If not found → FAILED: "Cannot locate <target>. Specify 'file' for faster lookup."
  If multiple definitions found → list them, ask which to trace

STEP 2 — Build call graph (static analysis)

  IF direction=up (callers):
    Find all files calling <target>
    For each caller: find who calls THEM (recursively up to depth)
    → "Who calls getUserById?" → [controller → route handler → middleware]

  IF direction=down (callees):
    Parse the function body: find all function calls within it
    For each callee: recursively find what THEY call (up to depth)
    → "getUserById calls?" → [db.query → pool.connect → pg.Client]

  IF direction=both:
    Run both directions and merge into a unified tree

STEP 3 — Detect issues
  Circular dependencies: A calls B calls A → flag as CYCLE
  Dead code: function has no callers → flag as UNREACHABLE
  Deep chains: depth > 6 → flag as DEEP_CHAIN (complexity risk)

STEP 4 — Return call graph
  {
    target: "<function>",
    file:   "<path>:<line>",
    callers: {
      "<caller_function>": {
        file: "<path>",
        line: <N>,
        callers: { ... }  // recursive up to depth
      }
    },
    callees: {
      "<callee_function>": {
        file: "<path>",
        line: <N>,
        callees: { ... }
      }
    },
    issues: [
      { type: "CYCLE", path: ["A", "B", "A"] },
      { type: "UNREACHABLE", function: "oldHelper" },
      { type: "DEEP_CHAIN", depth: 7 }
    ],
    ascii_tree: "..."  // human-readable tree diagram
  }
```

---

## ASCII Tree Output Format

```
getUserById (src/services/user.service.ts:42)
│
├── CALLERS (who calls this?)
│   ├── UserController.getUser (src/controllers/user.ts:15)
│   │   └── called by: router.get('/user/:id') (src/routes/user.ts:8)
│   └── AdminController.viewUser (src/controllers/admin.ts:33)
│
└── CALLEES (what does this call?)
    ├── prisma.user.findUnique (node_modules/...)
    ├── cache.get (src/lib/cache.ts:12)
    │   └── redis.get (node_modules/ioredis/...)
    └── logger.info (src/lib/logger.ts:5)
```

---

## Usage Examples

```
# Impact analysis before refactoring
trace_call(target="getUserById", direction="up", depth=4)
# "If I change getUserById, who is affected?"

# Dependency audit
trace_call(target="sendEmail", direction="down", depth=5)
# "What does sendEmail ultimately depend on?"

# Find circular imports
trace_call(target="AuthService", direction="both", depth=6)
# Checks for circular dependency patterns

# Trace a bug's execution path
trace_call(target="processPayment", direction="down", depth=8)
# "Where does processPayment go? Find where it might fail."
```
