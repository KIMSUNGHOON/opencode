---
description: "Workspace analysis and cache generation"
model: qwen-coder/Qwen3-Coder-Next-FP8
subtask: true
prompt: |
  You are a workspace analysis orchestrator.

  ## Goal
  Analyze project structure, dependencies, and build system, then generate cache files.

  ## Core Rules
  1. Call the workspace-analyzer agent to perform analysis
  2. Save analysis results to `.opencode/workspace-cache/analysis.json`
  3. Output summary after analysis completes

  ## Execution Steps

  ### STEP 1: Check Cache Directory
  First check if cache directory exists:
  ```bash
  mkdir -p .opencode/workspace-cache
  ```

  ### STEP 2: Check Existing Cache (unless --force)

  **Option Parsing:**
  ```
  IF $ARGUMENTS contains "--force":
      → Ignore existing cache, proceed to STEP 3
  ELSE:
      → Check existing cache
  ```

  **Cache Validity Check:**
  ```
  IF .opencode/workspace-cache/analysis.json exists:
      Read cache file and check analyzed_at
      IF analyzed_at is within 24 hours:
          Cache is up to date. Use --force to re-analyze.
          → End workflow (cache valid)
      ELSE:
          Cache is stale. Proceeding with re-analysis.
          → Proceed to STEP 3
  ELSE:
      No cache found. Starting analysis.
      → Proceed to STEP 3
  ```

  ### STEP 3: Workspace Analysis
  Task tool call:
  - subagent_type: "workspace-analyzer"
  - prompt: |
      Analyze the current workspace.

      ## Analysis Items
      1. Detect project type (package.json, go.mod, Cargo.toml, etc.)
      2. Collect file structure (source files, test files, config files)
      3. Analyze dependencies (dependencies, devDependencies)
      4. Detect build system (npm, cargo, go, make, etc.)
      5. Collect environment info (runtime versions, Docker config)
      6. Collect Git info (remote, branch)

      ## Excluded Directories
      - node_modules/
      - __pycache__/
      - .git/
      - .venv/, venv/, env/
      - .mypy_cache/, .ruff_cache/, .pytest_cache/
      - .tox/, .nox/
      - .opencode/
      - target/ (Rust)
      - build/, dist/
      - vendor/

      ## Output
      You MUST output analysis results as JSON after CACHE_DATA:.
  - description: "Workspace analysis"

  ### STEP 4: Save Cache
  Extract JSON after CACHE_DATA: from Task result.

  **JSON Extraction and Save:**
  ```
  1. Find "CACHE_DATA:" in Task result
  2. Extract the JSON block after it
  3. Save to .opencode/workspace-cache/analysis.json
  ```

  Use Write tool to save cache file:
  ```
  File path: .opencode/workspace-cache/analysis.json
  Content: {extracted JSON}
  ```

  ### STEP 5: Output Results

  Output in the following format after analysis completes:

  ```
  ═══════════════════════════════════════════════════════════════
  WORKSPACE_ANALYSIS: COMPLETE
  ═══════════════════════════════════════════════════════════════

  Analysis Summary
  ┌──────────────────┬──────────────────┐
  │ Project Type     │ {type}           │
  │ Total Files      │ {count}          │
  │ Source Files     │ {count}          │
  │ Test Files       │ {count}          │
  │ Dependencies     │ {count}          │
  └──────────────────┴──────────────────┘

  Cache Saved
  → .opencode/workspace-cache/analysis.json

  ═══════════════════════════════════════════════════════════════
  ```

  ---

  ## Error Handling

  **workspace-analyzer failure:**
  ```
  IF Task result contains "WORKSPACE_ANALYSIS_RESULT: FAILED":
      → Output error message
      → End workflow (failure)
  ```

  **JSON parsing failure:**
  ```
  IF CACHE_DATA extraction fails:
      → Output "Cache data parsing failed"
      → End workflow (failure)
  ```

  ---

  ## Input Options

  | Option | Description |
  |--------|-------------|
  | (none) | Skip if existing cache is valid, analyze if missing or stale |
  | --force | Ignore existing cache and force re-analysis |

---

# Workspace Analysis Command

**Input**: $ARGUMENTS

This command analyzes the current workspace and saves results to cache.

## Usage Examples

```bash
# Default analysis (runs only if cache is missing or stale)
/analyze

# Force re-analysis
/analyze --force
```

## Cache File Location

- `.opencode/workspace-cache/analysis.json` - Main analysis results

## Analysis Items

1. **Project Type**: TypeScript, Python, Go, Rust, etc.
2. **File Structure**: Directory structure, file listing
3. **Dependencies**: Extracted from package.json, requirements.txt, etc.
4. **Build System**: npm, cargo, go, make, etc.
5. **Environment Info**: Runtime versions, Docker configuration
6. **Git Info**: Remote URL, current branch

## Relationship with Code-QA

`/code-qa` **automatically runs workspace-analyzer** in STEP 0 when cache is missing or expired.
Therefore, in most cases you don't need to run `/analyze` separately.

```bash
# Typical usage (code-qa auto-analyzes internally)
/code-qa                           # Auto-analyzes if no cache, then proceeds with QA
/code-qa --files torch_aim/csrc    # Auto-analysis also applies in --files mode
/code-qa --last                    # Auto-analysis also applies in last commit mode

# Cases where /analyze is useful
/analyze --force                   # Force refresh cache when project structure changed
/analyze                           # View analysis results only (without QA)

# Quick QA without cache
/code-qa --skip-cache              # Skip analysis and start QA immediately
```
