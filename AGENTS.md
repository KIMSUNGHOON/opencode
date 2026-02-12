- To regenerate the JavaScript SDK, run `./packages/sdk/js/script/build.ts`.
- ALWAYS USE PARALLEL TOOLS WHEN APPLICABLE.
- The default branch in this repo is `dev`.
- Local `main` ref may not exist; use `dev` or `origin/dev` for diffs.
- Prefer automation: execute requested actions without confirmation unless blocked by missing info or safety/irreversibility.

## Style Guide

### General Principles

- Keep things in one function unless composable or reusable
- Avoid `try`/`catch` where possible
- Avoid using the `any` type
- Prefer single word variable names where possible
- Use Bun APIs when possible, like `Bun.file()`
- Rely on type inference when possible; avoid explicit type annotations or interfaces unless necessary for exports or clarity
- Prefer functional array methods (flatMap, filter, map) over for loops; use type guards on filter to maintain type inference downstream

### Naming

Prefer single word names for variables and functions. Only use multiple words if necessary.

### Naming Enforcement (Read This)

THIS RULE IS MANDATORY FOR AGENT WRITTEN CODE.

- Use single word names by default for new locals, params, and helper functions.
- Multi-word names are allowed only when a single word would be unclear or ambiguous.
- Do not introduce new camelCase compounds when a short single-word alternative is clear.
- Before finishing edits, review touched lines and shorten newly introduced identifiers where possible.
- Good short names to prefer: `pid`, `cfg`, `err`, `opts`, `dir`, `root`, `child`, `state`, `timeout`.
- Examples to avoid unless truly required: `inputPID`, `existingClient`, `connectTimeout`, `workerPath`.

```ts
// Good
const foo = 1
function journal(dir: string) {}

// Bad
const fooBar = 1
function prepareJournal(dir: string) {}
```

Reduce total variable count by inlining when a value is only used once.

```ts
// Good
const journal = await Bun.file(path.join(dir, "journal.json")).json()

// Bad
const journalPath = path.join(dir, "journal.json")
const journal = await Bun.file(journalPath).json()
```

### Destructuring

Avoid unnecessary destructuring. Use dot notation to preserve context.

```ts
// Good
obj.a
obj.b

// Bad
const { a, b } = obj
```

### Variables

Prefer `const` over `let`. Use ternaries or early returns instead of reassignment.

```ts
// Good
const foo = condition ? 1 : 2

// Bad
let foo
if (condition) foo = 1
else foo = 2
```

### Control Flow

Avoid `else` statements. Prefer early returns.

```ts
// Good
function foo() {
  if (condition) return 1
  return 2
}

// Bad
function foo() {
  if (condition) return 1
  else return 2
}
```

### Schema Definitions (Drizzle)

Use snake_case for field names so column names don't need to be redefined as strings.

```ts
// Good
const table = sqliteTable("session", {
  id: text().primaryKey(),
  project_id: text().notNull(),
  created_at: integer().notNull(),
})

// Bad
const table = sqliteTable("session", {
  id: text("id").primaryKey(),
  projectID: text("project_id").notNull(),
  createdAt: integer("created_at").notNull(),
})
```

## Testing

- Avoid mocks as much as possible
- Test actual implementation, do not duplicate logic into tests
- Tests cannot run from repo root (guard: `do-not-run-tests-from-root`); run from package dirs like `packages/opencode`.

---

## Workspace Context (Plan / Build Mode)

OpenCode maintains a 3-level workspace cache under `.opencode/workspace-cache/`.
This cache provides pre-analyzed project structure, module maps, and dependency graphs
that dramatically improve planning accuracy and implementation consistency.

### Cache Levels

| Level | File | Size | When to Use |
|-------|------|------|-------------|
| L1 | `project-map.yaml` | ~1K tokens | Always read first. Project overview, module list, build commands |
| L2 | `modules/{name}.yaml` | ~2-5K/module | When working on a specific module. Files, exports, dependencies |
| L3 | Source files | Varies | When you need actual code. Use Read tool directly |

### On First User Request (HITL)

When a user enters Plan or Build mode with a task, **before starting work**, check the
workspace cache and inform the user:

**Step 1:** Read `.opencode/workspace-cache/project-map.yaml`

**Step 2:** Based on result, ask the user using the question tool:

**If cache exists and is recent (< 24h):**
> "Workspace cache found (analyzed {timestamp}). {project_type} project with {N} modules."
- Option 1: "Use existing cache" → Read L1, proceed with context
- Option 2: "Regenerate cache" → (Plan: note in plan as Step 0) (Build: run `/analyze --force`)
- Option 3: "Skip" → Proceed without cache

**If cache exists but is stale (> 24h):**
> "Workspace cache found but stale ({age}). Recommend refreshing."
- Option 1: "Refresh cache" → (Plan: note in plan as Step 0) (Build: run `/analyze`)
- Option 2: "Use stale cache" → Read L1, proceed with context
- Option 3: "Skip" → Proceed without cache

**If no cache exists:**
> "No workspace cache found. Analysis improves planning accuracy and code consistency."
- Option 1: "Generate cache" → (Plan: note in plan as Step 0) (Build: run `/analyze`)
- Option 2: "Skip" → Proceed without cache

### Plan Mode Behavior

Plan mode is **read-only**. It cannot run `/analyze` directly.

- If user chooses "Generate" or "Refresh": include as **Step 0** in the plan file:
  ```
  ## Step 0: Workspace Analysis (prerequisite)
  Run `/analyze` to generate workspace cache before implementation.
  ```
- If cache is available: read L1 during Phase 1 (exploration). Use module list to
  guide explore agent searches. Read relevant L2 modules for deeper context.
- When writing the plan: reference specific modules and their patterns from cache data.

### Build Mode Behavior

Build mode has **full access**. It can run `/analyze` directly.

- If user chooses "Generate" or "Refresh": run the analysis immediately:
  ```bash
  mkdir -p .opencode/workspace-cache/modules
  ```
  Then invoke `/analyze` or call workspace-scanner + module-analyzer agents.
- If cache is available: read L1 first. Before modifying a module, read its L2 cache
  to understand existing patterns, exports, and dependencies.
- After significant structural changes (new modules, moved files): suggest cache refresh.

### During Work (Both Modes)

- **Cross-module changes**: Read `dependency-graph.yaml` to understand impact
- **New file creation**: Follow patterns from L2 cache (naming, exports, structure)
- **Import decisions**: Check L2 `key_exports` to use correct import paths

### Model Recommendations

| Mode | Recommended Model | Rationale |
|------|-------------------|-----------|
| **Plan** | Thinking model (`qwen/Qwen3.5-122B-A10B-FP8`) | Planning requires deep reasoning (CoT): architecture decisions, dependency analysis, tradeoff evaluation |
| **Build** | Instruct model (`qwen-instruct/Qwen3.5-122B-A10B-FP8`) | Implementation requires fast, accurate code generation and tool calling stability |

When switching from Plan → Build, consider switching models if the current model
is not optimal for the next phase.
