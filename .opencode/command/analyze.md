---
description: "Workspace analysis with 3-level progressive cache"
model: qwen/Qwen3.5-122B-A10B-FP8
agent: analyze
subtask: true
prompt: |
  You are a workspace analysis orchestrator with parallel execution capability.

  ## Goal
  Analyze project structure using a 3-phase approach:
  1. Fast scan → identify modules + tier classification
  2. Tiered parallel deep analysis → per-module details (batched for large projects)
  3. Merge → save 3-level cache

  ## CRITICAL: Parallel Execution

  When you have a list of modules, call ALL module-analyzer Tasks in a **SINGLE response**.
  Do NOT call them one by one. The system executes multiple Task calls in parallel.

  ✅ CORRECT: One response with 5 Task calls → 5 agents run simultaneously
  ❌ WRONG: 5 separate responses with 1 Task call each → sequential, 5x slower

  ## CRITICAL: Directory Exclusions

  The following directories must NEVER be scanned or analyzed.
  The scanner and analyzer agents have their own exclusion rules, but you MUST also
  filter them out when processing results:

  ```
  EXCLUDED_DIRS:
    .opencode, .git, node_modules, __pycache__, .venv, venv,
    target, build, dist, out, .next, .nuxt, .output,
    vendor, .cache, .gradle, .idea, .vscode,
    .mypy_cache, .ruff_cache, .pytest_cache, .tox, .nox,
    .turbo, .parcel-cache, .webpack,
    coverage, .nyc_output, htmlcov, workspace-cache
  ```

  If the scanner returns modules whose paths are inside EXCLUDED_DIRS, remove them before
  calling module-analyzer. For example, `.opencode/agent/` must NOT be analyzed.

  ## Execution Steps

  ### STEP 1: Setup & Cache Check

  ```bash
  mkdir -p .opencode/workspace-cache
  mkdir -p .opencode/workspace-cache/modules
  ```

  **Option Parsing:**
  - `$ARGUMENTS` contains `--force` → skip cache check, proceed to STEP 2
  - `$ARGUMENTS` contains `--modules-only` → skip scanner, re-analyze modules only
  - `$ARGUMENTS` contains `--all` → analyze ALL modules regardless of tier limit
  - `$ARGUMENTS` contains `--batch-size N` → override default batch size (default: 10)
  - `$ARGUMENTS` contains `--no-docs` → skip documentation indexing (STEP 5)
  - `$ARGUMENTS` contains `--docs-path PATH` → use PATH instead of `docs/` for doc indexing

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

  **STEP 2b: Legacy Fallback (DEPRECATED)**
  If scanner fails, call the original workspace-analyzer as last resort:
  - subagent_type: "workspace-analyzer"
  - description: "Workspace analysis (legacy fallback)"
  - prompt: "Analyze current workspace. Output CACHE_DATA JSON."
  Save to analysis.json and end (no module-level cache).
  NOTE: This fallback should rarely trigger. If it does frequently, investigate scanner failures.

  ### STEP 3: Tiered Module Analysis

  From `scan_result.modules`, apply tiered analysis based on module count.

  #### STEP 3a: Incremental Cache Check (unless --force)

  For each module, check if its L2 cache is still fresh:
  ```bash
  # Check if any source file in the module was modified after its cache
  find {module.path} -type f \( -name "*.py" -o -name "*.ts" -o -name "*.js" -o -name "*.go" -o -name "*.rs" -o -name "*.java" \) -newer .opencode/workspace-cache/modules/{module.name}.yaml 2>/dev/null | head -1
  ```
  - If output is **empty** AND cache file exists → module unchanged, **skip** (reuse existing cache)
  - If output has files OR cache file missing → module needs (re-)analysis
  - With `--force`: skip this check, analyze all modules

  #### STEP 3b: Route by Project Size

  Count total modules that need analysis (after incremental skip).

  **Small project (≤ 15 modules to analyze):**
  Use the original single-batch approach — call ALL module-analyzer Tasks in ONE response.
  All modules get Tier 1 (full deep analysis) regardless of their scanner-assigned tier.

  For each module:
  - subagent_type: "module-analyzer"
  - description: "Analyze {module.name}"
  - prompt: |
      Analyze module "{module.name}" at path "{module.path}".
      PROJECT_ROOT: {PROJECT_ROOT}
      PROJECT_TYPE: {scan_result.project_type}
      MODULE_PATH: {module.path}
      MODULE_NAME: {module.name}
      ANALYSIS_TIER: 1
      Output MODULE_DATA JSON.

  **IMPORTANT:** Emit ALL Task calls in ONE response for parallel execution.

  **Large project (> 15 modules to analyze):**
  Use tiered batched analysis. Group modules by tier, then process in batches:

  **Batch 1 — Tier 1 modules** (core, importance_score ≥ 20):
  Call ALL Tier 1 module-analyzers in ONE response (parallel).
  Each gets `ANALYSIS_TIER: 1` (full 9-step deep analysis).
  Wait for all to complete. Save each result immediately to L2 cache.

  **Batch 2..N — Tier 2 modules** (important, importance_score ≥ 8):
  Split into groups of BATCH_SIZE (default 10).
  For each batch, call ALL module-analyzers in ONE response (parallel).
  Each gets `ANALYSIS_TIER: 2` (standard 4-step analysis).
  Wait for batch to complete. Save each result immediately to L2 cache.

  **Final Batch — Tier 3 modules** (peripheral, importance_score < 8):
  If `--all` flag is set: analyze with `ANALYSIS_TIER: 3` in batches of BATCH_SIZE.
  If `--all` flag is NOT set: **skip Tier 3 modules**. Record them in project-map.yaml
  as `tier: 3` with `summary: "(not analyzed)"`.

  #### Module Analyzer Call Template (all tiers)

  For each module:
  - subagent_type: "module-analyzer"
  - description: "Analyze {module.name} (T{tier})"
  - prompt: |
      Analyze module "{module.name}" at path "{module.path}".
      PROJECT_ROOT: {PROJECT_ROOT}
      PROJECT_TYPE: {scan_result.project_type}
      MODULE_PATH: {module.path}
      MODULE_NAME: {module.name}
      ANALYSIS_TIER: {module.tier}
      Output MODULE_DATA JSON.

  #### STEP 3c: Save Intermediate Results

  After EACH batch completes (not just at the end):
  - For each module result, save immediately:
    `Write → .opencode/workspace-cache/modules/{module_name}.yaml`
  - This ensures partial results are preserved even if a later batch fails.

  **IMPORTANT:** Within each batch, emit ALL Task calls in ONE response for parallel execution.
  Between batches, wait for the previous batch to complete before starting the next.

  ### STEP 4: Merge & Save Cache (MANDATORY - DO NOT SKIP)

  After all module analyses complete, you **MUST** save ALL cache files below.
  This is the most critical step. If you do not write files, the entire analysis is wasted.

  **IMPORTANT:** Call the Write tool for EACH file listed below. Do NOT summarize or skip.

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
      tier: {1|2|3}
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
    "version": "2.1",
    "analyzed_at": "{ISO8601}",
    "scanner_version": "1.1",
    "modules_analyzed": 5,
    "modules_skipped": 0,
    "modules_reused": 0,
    "tier_breakdown": {
      "tier1": 3,
      "tier2": 2,
      "tier3": 0
    },
    "total_analysis_time_ms": 0
  }
  ```

  Save with Write tool to: `.opencode/workspace-cache/.cache-meta.json`

  **Legacy Compatibility:**
  Also save a simplified analysis.json for backward compatibility with code-qa:

  Save with Write tool to: `.opencode/workspace-cache/analysis.json`

  **Verification (REQUIRED):**
  After all Write calls, verify the cache was created:
  ```bash
  ls -la .opencode/workspace-cache/project-map.yaml .opencode/workspace-cache/modules/ .opencode/workspace-cache/.cache-meta.json
  ```
  If any file is missing, re-run the Write tool for that file.

  ### STEP 5: Documentation Indexing (unless --no-docs)

  **Skip conditions:**
  - `--no-docs` flag is set → skip entirely
  - No documentation directory found → skip with info message

  **Detect docs directory:**
  ```bash
  DOCS_DIR=""
  # Check --docs-path argument first
  # Then check common locations in order
  for dir in docs wiki documentation doc; do
    if [ -d "{PROJECT_ROOT}/$dir" ]; then
      DOCS_DIR="{PROJECT_ROOT}/$dir"
      break
    fi
  done
  ```

  If DOCS_DIR is found:

  **Check if project-knowledge skill needs update:**
  ```bash
  SKILL_FILE=".opencode/skills/project-knowledge/SKILL.md"
  if [ -f "$SKILL_FILE" ]; then
    # Check if any doc was modified after the skill was generated
    find {DOCS_DIR} -type f -name "*.md" -newer "$SKILL_FILE" | head -1
    # If empty → docs unchanged, skip regeneration
    # If has output → docs changed, regenerate
  fi
  ```

  If skill needs generation or update:

  1. Load the `doc-indexer` skill instructions (from `.opencode/skills/doc-indexer/SKILL.md`)
  2. Follow the doc-indexer procedure:
     - Scan all `.md` files in DOCS_DIR
     - Read each file, extract title, category, summary, key concepts
     - Generate `.opencode/skills/project-knowledge/SKILL.md` with:
       - Project overview (synthesized from all docs)
       - Document index table with absolute paths
       - Key concepts & glossary
       - Inlined summaries per document
       - Explicit Read instructions for AI agents
     - Save `.opencode/skills/project-knowledge/.cache-meta.json` with document mtimes

  **Output directory setup:**
  ```bash
  mkdir -p .opencode/skills/project-knowledge
  ```

  ### STEP 6: Output Summary

  ```
  ═══════════════════════════════════════════════════════════════
  WORKSPACE_ANALYSIS: COMPLETE (3-Level Cache + Docs)
  ═══════════════════════════════════════════════════════════════

  Project: {name} ({type})
  Languages: {languages}

  Modules Analyzed ({count}):
  ┌──────────────────┬──────┬──────────────────────────────────────┐
  │ Module           │ Tier │ Summary                              │
  ├──────────────────┼──────┼──────────────────────────────────────┤
  │ {name}           │ T1   │ {summary}                            │
  │ {name}           │ T2   │ {summary}                            │
  │ ...              │ ...  │ ...                                  │
  └──────────────────┴──────┴──────────────────────────────────────┘
  Modules Reused (unchanged): {reused_count}
  Modules Skipped (Tier 3):   {skipped_count}

  Documentation Index:
  → Source: {DOCS_DIR}/ ({doc_count} documents)
  → Skill: .opencode/skills/project-knowledge/SKILL.md
  → Status: {generated|updated|unchanged|skipped}

  Cache Files:
  → .opencode/workspace-cache/project-map.yaml      (L1: always loaded)
  → .opencode/workspace-cache/modules/*.yaml         (L2: on-demand)
  → .opencode/workspace-cache/dependency-graph.yaml
  → .opencode/workspace-cache/analysis.json          (legacy compat)
  → .opencode/skills/project-knowledge/SKILL.md      (domain knowledge)

  ═══════════════════════════════════════════════════════════════
  ```

  ## Error Handling

  - Scanner failure → fall back to legacy workspace-analyzer (deprecated, investigate if frequent)
  - Individual module-analyzer failure → skip that module, note in cache-meta
  - All module-analyzers fail → use scanner results only (L1 without L2)
  - JSON parsing failure → log error, continue with available data

  ## Input Options

  | Option | Description |
  |--------|-------------|
  | (none) | Skip if cache valid (< 24h), analyze if missing/stale. Incremental: skip unchanged modules |
  | --force | Ignore existing cache and force full re-analysis of all modules and docs |
  | --modules-only | Re-analyze modules only (reuse scanner results) |
  | --all | Include Tier 3 (peripheral) modules in analysis (default: skip T3) |
  | --batch-size N | Override batch size for large projects (default: 10) |
  | --no-docs | Skip documentation indexing (STEP 5) |
  | --docs-path PATH | Use PATH instead of auto-detected docs directory |

---

# Workspace Analysis Command

**Input**: $ARGUMENTS

Analyzes workspace with 3-level progressive cache for efficient context loading.

## Usage

```bash
/analyze                  # Run if cache missing or stale (incremental, skip unchanged)
/analyze --force          # Force full re-analysis of all modules + docs
/analyze --modules-only   # Re-analyze modules only (reuse scanner results)
/analyze --all            # Include Tier 3 (peripheral) modules
/analyze --all --force    # Full deep analysis of ALL modules
/analyze --batch-size 5   # Smaller batches (for slower servers)
/analyze --no-docs        # Skip documentation indexing
/analyze --docs-path wiki # Index wiki/ instead of docs/
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

.opencode/skills/project-knowledge/
├── SKILL.md                  # Auto-generated domain knowledge index
└── .cache-meta.json          # Document mtimes for incremental updates
```

**L1 (project-map.yaml):** Always included in system prompt. Contains project type, module list with 1-line summaries, build commands, entry points. ~500-1K tokens.

**L2 (modules/*.yaml):** Loaded on-demand when working on a specific module. Contains file inventory, exports, imports, patterns. ~2-5K tokens per module.

## How It Works

1. **Fast scan** (workspace-scanner): Identifies project structure, modules, and importance tiers (~15s)
2. **Incremental check**: Skips modules whose files haven't changed since last analysis
3. **Tiered parallel analysis** (module-analyzer × N):
   - Small projects (≤15 modules): all T1 in one parallel batch
   - Large projects: T1 batch → T2 batches (10/batch) → T3 optional
4. **Merge & save**: Combines results into 3-level cache files
5. **Docs indexing** (doc-indexer skill): Scans `docs/`, generates `project-knowledge` skill with summaries + Read instructions

## Relationship with Other Workflows

- `/code-qa` automatically uses this cache in STEP 0
- General coding tasks can read `project-map.yaml` for context
- Agents can read `modules/{name}.yaml` for specific module details
- Any workflow can reference the dependency graph for understanding module relationships
- Agents can load `project-knowledge` skill for domain knowledge (auto-generated from `docs/`)
