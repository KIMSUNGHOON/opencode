---
description: "Workspace analysis with 3-level progressive cache"
model: qwen/Qwen3-Next-80B-A3B-Thinking-FP8
subtask: true
prompt: |
  You are a workspace analysis orchestrator with parallel execution capability.

  ## Goal
  Analyze project structure using a 2-phase approach:
  1. Fast scan → identify modules
  2. Parallel deep analysis → per-module details
  3. Merge → save 3-level cache

  ## CRITICAL: Parallel Execution

  When you have a list of modules, call ALL module-analyzer Tasks in a **SINGLE response**.
  Do NOT call them one by one. The system executes multiple Task calls in parallel.

  ✅ CORRECT: One response with 5 Task calls → 5 agents run simultaneously
  ❌ WRONG: 5 separate responses with 1 Task call each → sequential, 5x slower

  ## Execution Steps

  ### STEP 1: Setup & Cache Check

  ```bash
  mkdir -p .opencode/workspace-cache
  mkdir -p .opencode/workspace-cache/modules
  ```

  **Option Parsing:**
  - `$ARGUMENTS` contains `--force` → skip cache check, proceed to STEP 2
  - `$ARGUMENTS` contains `--modules-only` → skip scanner, re-analyze modules only

  **Cache Validity (unless --force):**
  Read `.opencode/workspace-cache/project-map.yaml`:
  - If exists and `analyzed_at` is within 24 hours → cache valid, output summary, end
  - Otherwise → proceed to STEP 2

  ### STEP 2: Fast Project Scan

  Call workspace-scanner:
  - subagent_type: "workspace-scanner"
  - description: "Fast workspace scan"
  - prompt: "Scan the project at {PROJECT_ROOT}. Identify project type, module boundaries, entry points, and build system. Output SCAN_DATA JSON."

  Extract SCAN_DATA JSON from result. Store as `scan_result`.
  If FAILED → fall back to legacy workspace-analyzer (STEP 2b).

  **STEP 2b: Legacy Fallback**
  If scanner fails, call the original workspace-analyzer:
  - subagent_type: "workspace-analyzer"
  - description: "Workspace analysis (legacy)"
  - prompt: "Analyze current workspace. Output CACHE_DATA JSON."
  Save to analysis.json and end (no module-level cache).

  ### STEP 3: Parallel Module Analysis

  From `scan_result.modules`, call module-analyzer for EACH module **in a single response**:

  For each module in scan_result.modules:
  - subagent_type: "module-analyzer"
  - description: "Analyze {module.name}"
  - prompt: |
      Analyze module "{module.name}" at path "{module.path}".
      PROJECT_ROOT: {PROJECT_ROOT}
      PROJECT_TYPE: {scan_result.project_type}
      MODULE_PATH: {module.path}
      MODULE_NAME: {module.name}
      Output MODULE_DATA JSON.

  **IMPORTANT:** Emit ALL Task calls in ONE response for parallel execution.

  If a project has > 15 modules, analyze the 15 largest (by file_count) and note the rest as unanalyzed.

  ### STEP 4: Merge & Save Cache

  After all module analyses complete, build the 3-level cache:

  **Level 1: project-map.yaml**
  Combine scan_result + module summaries:

  ```yaml
  version: "2.0"
  analyzed_at: "{ISO8601}"
  project_root: "{absolute_path}"

  project:
    name: "{name}"
    type: "{type}"
    languages: [...]
    frameworks: [...]

  build:
    build_command: "{cmd}"
    test_command: "{cmd}"
    lint_command: "{cmd}"

  modules:
    {module_name}:
      path: "{path}"
      summary: "{1-line summary from module analysis}"
      files: {count}
      key_exports: [...]

  dependencies:
    {module_a}: [{module_b}, {module_c}]

  entry_points:
    - "{path}"

  git:
    remote_url: "{url}"
    current_branch: "{branch}"
  ```

  Save with Write tool to: `.opencode/workspace-cache/project-map.yaml`

  **Level 2: modules/{name}.yaml**
  For each module analysis result, save the MODULE_DATA as YAML:

  Save with Write tool to: `.opencode/workspace-cache/modules/{module_name}.yaml`

  **Dependency Graph:**
  Build from module internal_dependencies:

  ```yaml
  # .opencode/workspace-cache/dependency-graph.yaml
  graph:
    api: [services, models]
    services: [models, database]
    models: [database]
    database: []
  ```

  Save with Write tool to: `.opencode/workspace-cache/dependency-graph.yaml`

  **Cache Metadata:**
  ```json
  {
    "version": "2.0",
    "analyzed_at": "{ISO8601}",
    "scanner_version": "1.0",
    "modules_analyzed": 5,
    "modules_skipped": 0,
    "total_analysis_time_ms": 0
  }
  ```

  Save with Write tool to: `.opencode/workspace-cache/.cache-meta.json`

  **Legacy Compatibility:**
  Also save a simplified analysis.json for backward compatibility with code-qa:

  Save with Write tool to: `.opencode/workspace-cache/analysis.json`

  ### STEP 5: Output Summary

  ```
  ═══════════════════════════════════════════════════════════════
  WORKSPACE_ANALYSIS: COMPLETE (3-Level Cache)
  ═══════════════════════════════════════════════════════════════

  Project: {name} ({type})
  Languages: {languages}

  Modules Analyzed ({count}):
  ┌──────────────────┬──────────────────────────────────────────┐
  │ Module           │ Summary                                  │
  ├──────────────────┼──────────────────────────────────────────┤
  │ {name}           │ {summary}                                │
  │ ...              │ ...                                      │
  └──────────────────┴──────────────────────────────────────────┘

  Cache Files:
  → .opencode/workspace-cache/project-map.yaml      (L1: always loaded)
  → .opencode/workspace-cache/modules/*.yaml         (L2: on-demand)
  → .opencode/workspace-cache/dependency-graph.yaml
  → .opencode/workspace-cache/analysis.json          (legacy compat)

  ═══════════════════════════════════════════════════════════════
  ```

  ## Error Handling

  - Scanner failure → fall back to legacy workspace-analyzer
  - Individual module-analyzer failure → skip that module, note in cache-meta
  - All module-analyzers fail → use scanner results only (L1 without L2)
  - JSON parsing failure → log error, continue with available data

  ## Input Options

  | Option | Description |
  |--------|-------------|
  | (none) | Skip if cache valid (< 24h), analyze if missing/stale |
  | --force | Ignore existing cache and force full re-analysis |
  | --modules-only | Re-analyze modules only (reuse scanner results) |

---

# Workspace Analysis Command

**Input**: $ARGUMENTS

Analyzes workspace with 3-level progressive cache for efficient context loading.

## Usage

```bash
/analyze              # Run if cache missing or stale
/analyze --force      # Force full re-analysis
/analyze --modules-only  # Re-analyze modules only
```

## Cache Structure (3 Levels)

```
.opencode/workspace-cache/
├── project-map.yaml          # L1: Project overview (~1K tokens, always loaded)
├── modules/                  # L2: Module details (on-demand per task)
│   ├── api.yaml
│   ├── models.yaml
│   └── services.yaml
├── dependency-graph.yaml     # Module dependency graph
├── .cache-meta.json          # Cache metadata
└── analysis.json             # Legacy compatibility
```

**L1 (project-map.yaml):** Always included in system prompt. Contains project type, module list with 1-line summaries, build commands, entry points. ~500-1K tokens.

**L2 (modules/*.yaml):** Loaded on-demand when working on a specific module. Contains file inventory, exports, imports, patterns. ~2-5K tokens per module.

## How It Works

1. **Fast scan** (workspace-scanner): Identifies project structure and modules (~10s)
2. **Parallel deep analysis** (module-analyzer × N): Analyzes each module simultaneously (~20s total)
3. **Merge & save**: Combines results into 3-level cache files

## Relationship with Other Workflows

- `/code-qa` automatically uses this cache in STEP 0
- General coding tasks can read `project-map.yaml` for context
- Agents can read `modules/{name}.yaml` for specific module details
- Any workflow can reference the dependency graph for understanding module relationships
