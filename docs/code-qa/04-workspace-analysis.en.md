# Workspace Analysis Workflow Design Document (v2)

This document describes the design of the `/analyze` command and the 3-Level Progressive Cache-based workspace analysis workflow.

## Table of Contents

1. [Overview](#1-overview)
2. [Motivation and Background](#2-motivation-and-background)
3. [Architecture (v2)](#3-architecture-v2)
4. [3-Level Cache Schema](#4-3-level-cache-schema)
5. [Agent Design](#5-agent-design)
6. [Parallel Execution Strategy](#6-parallel-execution-strategy)
7. [Directory Exclusion Rules](#7-directory-exclusion-rules)
8. [Code-QA Integration](#8-code-qa-integration)
9. [Usage Examples](#9-usage-examples)
10. [Error Handling and Fallback](#10-error-handling-and-fallback)

---

## 1. Overview

### 1.1 What is Workspace Analysis?

Workspace Analysis is a workflow that pre-analyzes a project's structure, module boundaries, dependencies, and build system, storing the results in a 3-Level Progressive Cache.

### 1.2 v1 to v2 Changes

| Item | v1 (Previous) | v2 (Current) |
|------|---------------|--------------|
| Agent | Single workspace-analyzer | workspace-scanner + N module-analyzers |
| Execution | Sequential (single agent) | Parallel (concurrent per-module analysis) |
| Cache Structure | Single analysis.json file | 3-Level (project-map + modules + dependency-graph) |
| Context Efficiency | Full load (inefficient for large projects) | L1 always loaded (~1K), L2 on-demand (~2-5K/module) |
| Analysis Speed | Serial, proportional to project size | Parallel, ~30s regardless of module count |
| Large Projects | Unsupported (timeout) | Tiered + Batched (v2.1): 3-tier analysis by module importance |
| Incremental Analysis | None (full re-analysis each time) | Incremental (v2.1): re-analyze only changed modules |

### 1.3 Design Principles

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      Core Design Principles                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  1. Progressive Disclosure                                               │
│     - L1 (~1K tokens): Always loaded, entire project map                │
│     - L2 (~2-5K/module): Loaded on demand, detailed module analysis     │
│     - L3 (source): Direct access via Read tool when needed              │
│                                                                          │
│  2. Parallel Execution                                                   │
│     - Module analysis invokes N Tasks simultaneously in a single        │
│       response                                                           │
│     - AI SDK fire-and-forget pattern for true parallel execution        │
│                                                                          │
│  3. Separation of Concerns                                               │
│     - Scanner: Fast structural scan (what modules exist)                │
│     - Analyzer: Deep module analysis (what each module does)            │
│     - Orchestrator: Result integration and cache storage                │
│                                                                          │
│  4. Legacy Compatibility                                                 │
│     - analysis.json is also generated simultaneously                    │
│     - v1 cache is utilized if available                                 │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Motivation and Background

### 2.1 Limitations of v1

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      v1 Limitations                                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  1. Single Agent Bottleneck                                              │
│     - One workspace-analyzer sequentially analyzes entire project       │
│     - Takes several minutes for large projects (100+ modules)           │
│                                                                          │
│  2. Context Inefficiency                                                 │
│     - Loading entire analysis.json → tens of thousands of tokens        │
│       for large projects                                                │
│     - Analysis data takes excessive share of 256K context               │
│                                                                          │
│  3. All-or-Nothing                                                       │
│     - Cannot re-analyze specific modules only                           │
│     - Partial failure requires full re-execution                        │
│                                                                          │
│  4. Self-Reference Problem                                               │
│     - .opencode/ directory included in analysis targets                 │
│     - Cache directories, build artifacts, etc. unnecessarily scanned   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.2 v2 Solution Strategy

| Problem | Solution |
|---------|----------|
| Single agent bottleneck | 2-Phase parallel: Scanner(1) → Analyzer(N concurrent) |
| Context inefficiency | 3-Level Cache: L1 always loaded, L2/L3 on-demand only |
| All-or-Nothing | Per-module independent cache → partial re-analysis with `--modules-only` |
| Self-reference | EXCLUDED_DIRS rules applied at 3 layers (Scanner + Analyzer + Orchestrator) |

---

## 3. Architecture (v2)

### 3.1 Component Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│              Workspace Analysis Architecture (v2)                        │
└─────────────────────────────────────────────────────────────────────────┘

                              User
                                │
                                ▼
                    ┌───────────────────┐
                    │  /analyze command  │  (Thinking Model - Orchestrator)
                    │  (analyze.md)     │
                    └─────────┬─────────┘
                              │
              ┌───────────────┘
              ▼
    ┌───────────────────┐
    │ workspace-scanner  │  Phase 1: Fast Scan (~15s)
    │   (Coder Model)   │
    │                    │
    │  Tools: Glob,      │
    │  Read, Bash        │
    └─────────┬─────────┘
              │
              │ modules[] returned
              ▼
    ┌─────────────────────────────────────────────────────┐
    │              Phase 2: Parallel Module Analysis        │
    │                                                       │
    │  ┌──────────┐ ┌──────────┐ ┌──────────┐            │
    │  │ module-  │ │ module-  │ │ module-  │  ... x N    │
    │  │ analyzer │ │ analyzer │ │ analyzer │  (concurrent)│
    │  │ (api)    │ │ (models) │ │ (utils)  │            │
    │  └────┬─────┘ └────┬─────┘ └────┬─────┘            │
    │       │             │             │                   │
    └───────┼─────────────┼─────────────┼───────────────────┘
            │             │             │
            └─────────────┼─────────────┘
                          │
                          ▼
                ┌───────────────────┐
                │  Phase 3: Merge   │  Orchestrator integrates results
                └─────────┬─────────┘
                          │
          ┌───────────────┼───────────────────────────┐
          ▼               ▼               ▼            ▼
    ┌──────────┐   ┌──────────┐   ┌──────────┐  ┌──────────┐
    │ L1:      │   │ L2:      │   │ Dep      │  │ Legacy:  │
    │ project- │   │ modules/ │   │ Graph    │  │ analysis │
    │ map.yaml │   │ *.yaml   │   │ .yaml    │  │ .json    │
    └──────────┘   └──────────┘   └──────────┘  └──────────┘
          │
          │ (always loaded)
          ▼
    ┌───────────────────┐
    │ Code-QA / general │
    │ coding tasks use  │
    │ as context        │
    └───────────────────┘
```

### 3.2 File Structure

```
.opencode/
├── command/
│   └── analyze.md              # /analyze command (Orchestrator)
├── agent/
│   ├── workspace-scanner.md    # Phase 1: Fast project scan
│   ├── module-analyzer.md      # Phase 2: Per-module deep analysis
│   └── workspace-analyzer.md   # (Legacy) v1 analysis agent
├── mode/
│   └── code-qa.md              # STEP 0 cache integration
├── config/
│   └── workflow-settings.yaml  # Agent timeout/model settings
└── workspace-cache/            # Cache storage directory
    ├── project-map.yaml        # L1: Entire project map (~1K tokens)
    ├── modules/                # L2: Per-module detailed analysis
    │   ├── api.yaml            #     (~2-5K tokens per module)
    │   ├── models.yaml
    │   └── services.yaml
    ├── dependency-graph.yaml   # Inter-module dependency graph
    ├── .cache-meta.json        # Cache metadata
    └── analysis.json           # Legacy compatibility (v1 format)
```

### 3.3 Data Flow

```
1. Analysis Execution (/analyze)

   ┌────────┐     ┌─────────────────┐     ┌───────────────────────────────┐
   │  User  │────▶│ workspace-      │────▶│ modules[] (JSON)              │
   │        │     │ scanner         │     │ [{name, path, file_count}...] │
   └────────┘     └─────────────────┘     └───────────────┬───────────────┘
                                                           │
                                           ┌───────────────┼───────────────┐
                                           ▼               ▼               ▼
                                     ┌──────────┐   ┌──────────┐   ┌──────────┐
                                     │ module-  │   │ module-  │   │ module-  │
                                     │ analyzer │   │ analyzer │   │ analyzer │
                                     └────┬─────┘   └────┬─────┘   └────┬─────┘
                                           │               │               │
                                           └───────────────┼───────────────┘
                                                           │
                                                           ▼
                                                  ┌────────────────┐
                                                  │ Merge & Save   │
                                                  │ 3-Level Cache  │
                                                  └────────────────┘

2. Cache Usage in Code-QA / General Tasks

   ┌─────────────────┐     ┌─────────────────────┐
   │ project-map.yaml│────▶│ Understand project   │  (L1: ~1K tokens, always)
   │ (L1)            │     │ structure, modules   │
   └─────────────────┘     └─────────────────────┘
                                     │
                                     │ (when working on specific module)
                                     ▼
   ┌─────────────────┐     ┌─────────────────────┐
   │ modules/api.yaml│────▶│ Understand module    │  (L2: ~2-5K tokens, on-demand)
   │ (L2)            │     │ files/functions      │
   └─────────────────┘     └─────────────────────┘
                                     │
                                     │ (when actual code is needed)
                                     ▼
   ┌─────────────────┐     ┌─────────────────────┐
   │ src/api/app.py  │────▶│ Read code directly   │  (L3: Read tool)
   │ (L3 source)     │     │                     │
   └─────────────────┘     └─────────────────────┘
```

---

## 4. 3-Level Cache Schema

### 4.1 Level 1: project-map.yaml (~500-1K tokens)

The entire project map, always included in the system prompt.

```yaml
version: "2.0"
analyzed_at: "2025-01-15T10:30:00Z"
project_root: "/home/user/myproject"

project:
  name: "myproject"
  type: "node"
  languages: ["typescript", "javascript"]
  frameworks: ["react", "express"]

build:
  build_command: "npm run build"
  test_command: "npm test"
  lint_command: "eslint src/"

modules:
  api:
    path: "src/api"
    tier: 1
    summary: "FastAPI REST endpoints with JWT auth"
    files: 12
    key_exports: ["create_app", "router", "verify_token"]
  models:
    path: "src/models"
    tier: 1
    summary: "SQLAlchemy ORM models for users, orders, products"
    files: 8
    key_exports: ["User", "Order", "Product"]
  services:
    path: "src/services"
    tier: 2
    summary: "Business logic layer with transaction support"
    files: 6
    key_exports: ["UserService", "OrderService"]

dependencies:
  api: [services, models]
  services: [models]
  models: []

entry_points:
  - "src/main.py"
  - "src/server.ts"

git:
  remote_url: "git@github.com:user/myproject.git"
  current_branch: "main"
```

### 4.2 Level 2: modules/{name}.yaml (~3-8K tokens per module)

Loaded on-demand when working on a specific module. Includes DB schema, API contracts, and type definitions.

```yaml
name: "api"
path: "src/api"
summary: "FastAPI REST endpoints with JWT auth and role-based access control. Handles user CRUD, order management, and payment processing via Stripe."
file_count: 12
test_count: 3
total_lines: 1850

files:
  - path: "src/api/app.py"
    role: "FastAPI app factory, CORS setup, exception handlers"
    exports: ["create_app"]
    lines: 85
  - path: "src/api/routes/users.py"
    role: "User CRUD endpoints - register, login, profile"
    exports: ["router"]
    lines: 120
    imports_from: ["services.UserService", "models.User"]

key_exports: ["create_app", "router", "verify_token", "require_role"]

internal_dependencies:
  - module: "services"
    imports: ["UserService", "OrderService"]
  - module: "models"
    imports: ["User", "Order", "Product"]

# --- Deep Analysis (Steps 5-8) ---

data_models:
  - name: "User"
    type: "sqlalchemy"
    file: "src/models/user.py"
    fields:
      - {name: "id", type: "Integer", primary_key: true}
      - {name: "email", type: "String(255)", unique: true, nullable: false}
      - {name: "hashed_password", type: "String(255)", nullable: false}
      - {name: "is_active", type: "Boolean", default: true}
    relationships:
      - {field: "orders", target: "Order", type: "one-to-many"}

api_endpoints:
  - {method: "POST", path: "/api/users/register", handler: "register_user", request_type: "UserCreateSchema", response_type: "UserResponse", auth: false}
  - {method: "GET", path: "/api/users/me", handler: "get_current_user", response_type: "UserResponse", auth: "verify_token"}

type_definitions:
  - name: "UserCreateSchema"
    kind: "pydantic"
    file: "src/api/schemas/user.py"
    fields: [{name: "email", type: "EmailStr"}, {name: "password", type: "str", min_length: 8}]
  - name: "UserResponse"
    kind: "pydantic"
    file: "src/api/schemas/user.py"
    fields: [{name: "id", type: "int"}, {name: "email", type: "str"}, {name: "is_active", type: "bool"}]

error_handling:
  custom_errors:
    - {name: "UserNotFoundError", file: "src/api/errors.py", http_status: 404}
    - {name: "DuplicateEmailError", file: "src/api/errors.py", http_status: 409}
  error_handlers: ["global_exception_handler in app.py"]

config:
  env_vars:
    - {name: "DATABASE_URL", file: "src/api/config.py", required: true}
    - {name: "JWT_SECRET", file: "src/api/auth.py", required: true}

patterns:
  - "All routes use Depends(verify_token) for auth"
  - "Pydantic schemas in schemas/ for request/response validation"
  - "Custom exceptions mapped to HTTP status codes via global handler"
  - "Config loaded from env vars with pydantic Settings"
```

**Deep Analysis Field Descriptions:**

| Field | Detection Target | Purpose |
|-------|-----------------|---------|
| `data_models` | SQLAlchemy, Django, Prisma, Drizzle, TypeORM, GORM, etc. | DB schema understanding, migration planning |
| `api_endpoints` | FastAPI, Express, NestJS, Gin routes, etc. | API contract identification, new endpoint consistency |
| `type_definitions` | Pydantic, Zod, TypeScript interfaces, Go structs | DTO/schema reuse, type safety |
| `error_handling` | Custom error classes, error handlers | Error handling pattern consistency |
| `config` | Environment variables, config file references | New feature configuration requirements |

### 4.3 dependency-graph.yaml

```yaml
# Inter-module dependency relationships
graph:
  api: [services, models]
  services: [models, database]
  models: [database]
  database: []
```

### 4.4 .cache-meta.json

```json
{
  "version": "2.1",
  "analyzed_at": "2025-01-15T10:30:00Z",
  "scanner_version": "1.1",
  "modules_analyzed": 5,
  "modules_skipped": 0,
  "modules_reused": 2,
  "tier_breakdown": {
    "tier1": 3,
    "tier2": 2,
    "tier3": 0
  },
  "total_analysis_time_ms": 28500
}
```

### 4.5 Cache Invalidation Strategy

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      Cache Invalidation Rules                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Automatic Invalidation:                                                 │
│    - analyzed_at is more than 24 hours old                              │
│    - /analyze --force for forced re-analysis                            │
│                                                                          │
│  Incremental Cache (v2.1):                                              │
│    - Compare per-module file modification times (find -newer)           │
│    - Re-analyze only changed modules, reuse cache for the rest         │
│    - Ignored with --force                                               │
│                                                                          │
│  Partial Update:                                                         │
│    - /analyze --modules-only: Skip scanner, re-analyze modules only    │
│    - Delete individual module yaml → only that module is re-analyzed   │
│                                                                          │
│  Legacy Fallback:                                                        │
│    - If project-map.yaml is absent but analysis.json exists,           │
│      use v1 cache                                                       │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 5. Agent Design

### 5.1 workspace-scanner (Phase 1)

Generates a module list through fast project scanning.

```yaml
# .opencode/agent/workspace-scanner.md
---
description: Fast workspace scanner
mode: subagent
model: qwen-instruct/Qwen3.5-122B-A10B-FP8
tools: [Glob, Read, Bash]
permission: read-only
---
```

**Execution Steps:**

| Step | Task | Tool | Duration |
|------|------|------|----------|
| 1 | Project root & type detection | Bash (pwd, ls) | ~1s |
| 2 | Directory structure mapping | Glob | ~2s |
| 3 | Module boundary detection | Glob | ~5s |
| 4 | Per-module file count | Bash (find) | ~3s |
| 5 | **Module importance scoring & Tier classification** | Glob | ~3s |
| 6 | Entry point & config detection | Glob | ~2s |
| 7 | Monorepo detection | Read (package.json) | ~1s |

**Tier Classification Criteria (v2.1):**

| Tier | Score Criteria | Analysis Depth | Typical Modules |
|------|---------------|----------------|-----------------|
| T1 (core) | >= 20 | Full 9-step deep analysis | Core business logic, API, data layer |
| T2 (important) | >= 8 | 4-step standard analysis | Utilities, middleware, helpers |
| T3 (peripheral) | < 8 | File list + exports only | Config, scripts, small modules |

**Output:** `WORKSPACE_SCAN_RESULT: COMPLETE` + `SCAN_DATA` JSON

**Module Boundary Detection Criteria:**

| Language | Boundary Markers |
|----------|-----------------|
| Python | `__init__.py` |
| TypeScript/JS | `index.ts`, `index.js`, `package.json` |
| Go | `.go` files in directory |
| Rust | `mod.rs`, `lib.rs`, `main.rs` |
| Java | Subdirectories under `src/main/java/` |

### 5.2 module-analyzer (Phase 2)

Deep analysis of a single module's files, exports, and dependencies.

```yaml
# .opencode/agent/module-analyzer.md
---
description: Deep module analyzer
mode: subagent
model: qwen-instruct/Qwen3.5-122B-A10B-FP8
tools: [Glob, Grep, Read]
permission: read-only
---
```

**Input:** `MODULE_PATH`, `MODULE_NAME`, `PROJECT_ROOT`, `PROJECT_TYPE`, `ANALYSIS_TIER` (optional, default: 1)

**Execution Steps:**

| Step | Task | Tool | Details |
|------|------|------|---------|
| 1 | File inventory | Glob | Classify source/test/schema/route/type files |
| 2 | Public API / export detection | Grep | Language-specific export patterns |
| 3 | Internal dependency analysis | Grep | Extract project-internal imports only |
| 4 | Per-file role summary (top 20) | Read (first 50 lines) | Prioritize schema/route/type files |
| 5 | **DB model/schema detection** | Grep + Read | SQLAlchemy, Prisma, Drizzle, TypeORM, etc. |
| 6 | **API endpoint detection** | Grep + Read | FastAPI, Express, NestJS, Gin, etc. |
| 7 | **Type/interface extraction** | Grep + Read | Pydantic, Zod, TS interfaces, Go structs |
| 8 | **Error handling & config detection** | Grep | Custom errors, env vars, config references |
| 9 | Module summary generation | - | 2-3 sentence summary based on all data |

**Output:** `MODULE_ANALYSIS_RESULT: COMPLETE` + `MODULE_DATA` JSON (includes schema, API, types, errors, config)

### 5.3 workspace-analyzer (DEPRECATED)

Legacy single-analysis agent for v1 compatibility. Used as fallback when workspace-scanner fails.
If this fallback occurs frequently, the failure cause of workspace-scanner should be investigated.

### 5.4 Timeout Settings

```yaml
# workflow-settings.yaml
timeout:
  agent:
    workspace-scanner: 30000   # 30 seconds
    module-analyzer: 90000     # 1.5 minutes (per module, deep analysis w/ schema+API+types)
```

---

## 6. Parallel Execution Strategy

### 6.1 AI SDK Parallel Execution Mechanism

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      AI SDK Parallel Execution Mechanism                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  AI SDK's runToolsTransformation() on receiving a tool-call event:      │
│                                                                          │
│    outstandingToolResults.add(toolCallId)                                │
│    executeToolCall(toolCall)  // ← fire-and-forget without await        │
│                                                                          │
│  When the model includes multiple Task calls in one response,           │
│  each Task starts immediately without await → true parallel execution   │
│                                                                          │
│  Key: Model must include N Task calls in a single response              │
│  → Prompt design is the key to parallel execution                       │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 6.2 Parallel Execution Directives in analyze.md

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      Parallel Execution Pattern                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Correct method (5 Task calls in 1 response):                           │
│                                                                          │
│    Orchestrator Response:                                                │
│    ├── Task(module-analyzer, "Analyze api")                              │
│    ├── Task(module-analyzer, "Analyze models")                           │
│    ├── Task(module-analyzer, "Analyze services")                         │
│    ├── Task(module-analyzer, "Analyze utils")                            │
│    └── Task(module-analyzer, "Analyze tests")                            │
│                                                                          │
│    → 5 agents run concurrently, ~30s completion                         │
│                                                                          │
│  Wrong method (1 Task per 5 responses):                                 │
│                                                                          │
│    Response 1: Task(module-analyzer, "Analyze api")     → 30s          │
│    Response 2: Task(module-analyzer, "Analyze models")  → 30s          │
│    Response 3: Task(module-analyzer, "Analyze services") → 30s         │
│    ...                                                                    │
│                                                                          │
│    → Sequential execution, ~150s total                                  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 6.3 Tiered Batched Execution (v2.1)

**Small project (<= 15 modules):**
- All treated as Tier 1 (full deep analysis) in a single parallel batch (same behavior as before)

**Large project (> 15 modules):**
```
Batch 1: All Tier 1 modules (parallel)  → Results saved to L2 immediately
Batch 2: Tier 2 modules 1-10 (parallel) → Results saved to L2 immediately
Batch 3: Tier 2 modules 11-20 (parallel) → Results saved to L2 immediately
...
Final:   Tier 3 modules (--all only)     → Results saved to L2 immediately
```

- Within batch: Parallel execution (N Task calls in single response)
- Between batches: Sequential (save previous batch results before starting next)
- Batch size: Default 10 (adjustable with `--batch-size N`)
- Tier 3 modules: Skipped without `--all` flag (listed in project-map.yaml only)

---

## 7. Directory Exclusion Rules

### 7.1 Exclusion Targets

```
EXCLUDED_DIRS:
  .opencode, .git, node_modules, __pycache__, .venv, venv, .env,
  target, build, dist, out, .next, .nuxt, .output,
  vendor, .cache, .gradle, .idea, .vscode,
  .mypy_cache, .ruff_cache, .pytest_cache, .tox, .nox,
  .turbo, .parcel-cache, .webpack,
  coverage, .nyc_output, htmlcov, workspace-cache
```

### 7.2 Triple-Layer Application Principle

Exclusion rules are applied at all 3 layers:

| Layer | Application Point | Method |
|-------|-------------------|--------|
| **workspace-scanner** | Glob result filtering, `-not -path` in `find` commands | Excluded at scan phase |
| **module-analyzer** | Glob/Grep result filtering | Excluded at analysis phase |
| **analyze.md (Orchestrator)** | Scanner result post-processing | Remove modules in excluded paths from analysis targets |

### 7.3 Why Exclusion is Necessary

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      Self-Reference Prevention                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Analyzing .opencode/ causes:                                            │
│    - Agent definition files (.md) analyzed as source code               │
│    - workspace-cache/ read back as analysis results                     │
│    - Potential infinite self-reference loop                              │
│                                                                          │
│  Analyzing build/dist/ causes:                                           │
│    - Transpiled code mistaken for source                                │
│    - Bundled files detected as modules                                  │
│    - Inflated analysis results (context overflow)                       │
│                                                                          │
│  Analyzing __pycache__/.mypy_cache/ causes:                             │
│    - Cache files mistaken for source code                               │
│    - changed_files list explosion → context overflow → workflow failure │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 8. Code-QA Integration

### 8.1 STEP 0 Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      Code-QA STEP 0: Workspace Cache                     │
└─────────────────────────────────────────────────────────────────────────┘

  /code-qa execution
      │
      ▼
  mkdir -p .opencode/workspace-cache/modules
      │
      ▼
  ┌─────────────────────────────────────────┐
  │ project-map.yaml exists + within 24h?  │
  └────────────┬────────────┬───────────────┘
               │            │
           YES │        NO  │
               ▼            ▼
  ┌──────────────┐   ┌─────────────────────────────┐
  │ Use L1 cache │   │ analysis.json exists + valid?│
  │ Proceed to   │   └──────────┬─────────┬────────┘
  │ STEP 1       │              │         │
  └──────────────┘          YES │     NO  │
                                ▼         ▼
                   ┌──────────────┐   ┌──────────────────────┐
                   │ Use legacy   │   │ Run analysis          │
                   │ cache        │   │ Scanner → Analyzer×N  │
                   │ Proceed to   │   │ → Merge → STEP 1     │
                   │ STEP 1       │   └──────────────────────┘
                   └──────────────┘              │
                                                 │ (if Scanner fails)
                                                 ▼
                                         ┌──────────────────────┐
                                         │ Legacy fallback       │
                                         │ workspace-analyzer   │
                                         └──────────────────────┘
```

### 8.2 Cache Usage in Code-QA

| Phase | Cache Used | Purpose |
|-------|-----------|---------|
| STEP 0 | project-map.yaml | Understand project structure |
| STEP 4 (Review) | modules/*.yaml | Context for modules under review |
| STEP 5 (Build) | project-map.yaml → build_command | Build command reference |
| STEP 6 (Test) | project-map.yaml → test_command | Test command reference |

---

## 9. Usage Examples

### 9.1 Basic Usage

```bash
# Workspace analysis (skips if cache is valid, incremental: changed modules only)
/analyze

# Force full re-analysis
/analyze --force

# Re-analyze modules only (reuse scanner results)
/analyze --modules-only

# Analyze all modules including Tier 3 (peripheral)
/analyze --all

# Force full re-analysis of all modules (large projects)
/analyze --all --force

# Adjust batch size (server load control)
/analyze --batch-size 5
```

### 9.2 Automatic Integration with Code-QA

```bash
# Method 1: Pre-analyze then QA
/analyze
/code-qa

# Method 2: code-qa automatically checks/analyzes cache
/code-qa  # Auto-analyzes if no cache
```

### 9.3 Cache Usage in General Coding Tasks

```bash
# Quickly understand project structure (read L1 only)
Read .opencode/workspace-cache/project-map.yaml

# Check specific module details (load L2)
Read .opencode/workspace-cache/modules/api.yaml

# Check inter-module dependencies
Read .opencode/workspace-cache/dependency-graph.yaml
```

---

## 10. Error Handling and Fallback

### 10.1 Error Scenarios

| Error | Handling |
|-------|----------|
| Scanner failure | → Legacy workspace-analyzer fallback |
| Individual module-analyzer failure | → Skip that module, record in cache-meta |
| All module-analyzers fail | → Create L1 from Scanner results only (no L2) |
| JSON parsing failure | → Error log, continue with available data |
| Cache file corruption | → `rm .opencode/workspace-cache/` and re-analyze |

### 10.2 Legacy Fallback Flow

```
Scanner failure
    │
    ▼
┌─────────────────────┐
│ workspace-analyzer  │  (v1 agent)
│ Single analysis run │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ analysis.json saved │  (v1 format)
│ No L2/L3 cache      │
└─────────────────────┘
```

---

## Appendix A: Supported Project Types

| Type | Detection Files | Build Tools |
|------|----------------|-------------|
| TypeScript/JavaScript | package.json, tsconfig.json | npm, yarn, pnpm, bun |
| Python | requirements.txt, pyproject.toml, setup.py | pip, poetry, pipenv |
| Go | go.mod | go modules |
| Rust | Cargo.toml | cargo |
| Java | pom.xml, build.gradle | maven, gradle |
| C/C++ | Makefile, CMakeLists.txt | make, cmake |
| Ruby | Gemfile | bundler |
| PHP | composer.json | composer |

## Appendix B: workflow-settings.yaml Configuration

```yaml
timeout:
  agent:
    workspace-scanner: 30000   # 30 seconds
    module-analyzer: 90000     # 1.5 minutes

model:
  assignment:
    coder_agents:
      - workspace-scanner      # Phase 0B: Fast project scan
      - module-analyzer        # Phase 0B: Per-module deep analysis
      - workspace-analyzer     # Phase 0B: Legacy fallback

analysis:
  tier_thresholds:
    tier1: 20                  # Score >= 20 → full deep analysis
    tier2: 8                   # Score >= 8  → standard analysis
  batch:
    size: 10                   # Max modules per parallel batch
    delay_between_ms: 1000     # Pause between batches
  incremental:
    enabled: true              # Skip unchanged modules
  limits:
    small_project_max: 15      # Single-batch mode threshold
    tier3_default: "skip"      # "skip" or "analyze"
    max_modules_total: 100     # Absolute cap
```

---

## Change History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2024-01-15 | Initial design document (v1: single workspace-analyzer) |
| 2.0 | 2025-02-12 | v2 full revision: 3-Level Cache, parallel execution, directory exclusion rules |
| 2.1 | 2026-02-12 | Tiered Priority + Batched Parallel + Incremental Cache |

---

## Related Documents

- [Architecture Diagram](./02-architecture.en.md)
- [Quick Start](./01-quick-start.en.md)
- [Implementation Summary](./05-implementation-summary.en.md)
