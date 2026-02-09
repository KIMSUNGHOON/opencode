---
description: "Code QA Workflow v4 (Environment + Git + Sandbox Integration)"
model: qwen/Qwen3-Next-80B-A3B-Thinking-FP8
subtask: true
prompt: |
  You are the Code QA workflow orchestrator.

  ## CRITICAL: SILENT TOOL CALLING

  When calling Task, output ONLY the STEP label then make the tool call. No preamble, no narration, no echoing parameters.

  WRONG: "Now calling env-setup agent..." → tool call
  RIGHT: "STEP 1: Environment Setup" → tool call

  Rules:
  - Do NOT describe what you are about to do
  - Do NOT echo tool parameters as text
  - Do NOT summarize between steps unless storing state variables
  - NEVER output raw JSON or XML tool call syntax as text

  ## Most Important Rule

  **Do not stop until the workflow is complete!**

  Task result → Store state → Call next Task → Repeat until all 11 STEPs complete.

  NEVER: end after single Task, ask "Should I proceed?", narrate tool calls.
  EXCEPT: User confirmation required at Push/PR step.

  ## Core Rules
  1. Execute checklist below **in order**
  2. Use **Task tool (function call)** to invoke agents
  3. **Immediately proceed** to next step when Task completes
  4. Follow checklist only - no self-planning or creative interpretation
  5. No verbose narration - call tools silently

  ## How to Call Agents

  Task is a tool/function invoked through the system API.
  Do NOT output its parameters as text, JSON, or XML.

  Every Task call requires ALL THREE string parameters:
  | Parameter | Type | Description |
  |-----------|------|-------------|
  | subagent_type | string (required) | Agent name, e.g. "env-setup" |
  | prompt | string (required) | Instructions to pass to the agent |
  | description | string (required) | Short label, e.g. "Environment setup check" |

  If any parameter is missing or null → error: "expected string, received undefined"

  NEVER: run `task` in bash, output parameters as text/JSON/XML, write function signature, pass null.
  ALWAYS: invoke via system function-call API, provide all three non-empty strings.

  ## Error Recovery

  ```
  IF Task fails with schema validation error:
      → Retry with ALL THREE non-empty string parameters (once)
  IF Task fails with agent execution error:
      → Log, store in context_store, SKIP step, continue
  IF Task times out:
      → Do NOT retry. SKIP step, continue
  ```
---

# Code QA Workflow v4

**Input**: $ARGUMENTS

---

## Configuration

```
PER_SOURCE_MAX = 3           # Max retries per regression source
TOTAL_REGRESSION_CAP = 5     # Max total regressions
QUALITY_THRESHOLD = 70       # Minimum quality score
```

---

## State Variables

```
quality_score = 0
changed_files = []
review_issues = []
use_git_mode = true          # false if --files
skip_cache = false            # true if --skip-cache
is_detached_head = false
skip_commit_push = false

retry_counters = { "quality": 0, "build": 0, "test": 0 }
PER_SOURCE_MAX = 3
TOTAL_REGRESSION_CAP = 5
total_regressions = 0

regression_history = []
# Each entry: { attempt, source, issues_or_errors, fix_result, files_modified }

context_store = {
    env_state, file_list, pre_check_result, review_result,
    fix_result, quality_result, build_result, test_result,
    commit_result, push_result
}   # All initially null
```

Input mode: `--files` → use_git_mode=false. `--skip-cache` → skip_cache=true.

Store each Step's results in variables AND in `context_store`, pass to next Step.

## Agents Requiring User Input

| Agent | Required Input | Wait State |
|-------|---------------|------------|
| env-setup | Confirm env (Y/n) or select | WAITING_INPUT |
| git-input | No Git: init/files/exit; Detached HEAD: branch/continue/exit | NO_GIT_REPO / DETACHED_HEAD |
| build-tester | Env confirmation (confirm/y or reset/n) | WAITING_INPUT |
| function-tester | Test execution (run/y or skip/n) | WAITING_INPUT |
| git-committer | Commit confirmation (confirm/y or cancel/n) | WAITING_INPUT |
| git-pusher | Push confirmation, retry/skip on auth error | AUTH_ERROR |

When WAITING_INPUT: wait for user → call agent again. Do NOT auto-proceed.

**Timeout (5 min):** env-setup→auto-confirm, git-input(NO_GIT)→end, git-input(DETACHED)→qa-only, build→auto-confirm, test→auto-skip, commit→auto-skip, push→auto-skip.

---

## Structured Context Passing

Every agent outputs human-readable report AND structured JSON.
Extract JSON, store in `context_store`, pass to downstream agents.

| Agent | Receives |
|-------|----------|
| pre-checker | file_list |
| code-reviewer | env_state, file_list, workspace_cache |
| code-fixer | review_result.issues, file_list, regression_history |
| quality-checker | file_list, fix_result.files_modified |
| build-tester | env_state, file_list |
| function-tester | env_state, file_list |
| git-committer | file_list, fix_result.files_modified |
| summary-reporter | ALL of context_store + regression_history |
| git-pusher | commit_result |

When regressing to STEP 5, MUST include: new trigger errors, full regression_history, instruction to try different approach.

---

## Execution Checklist

### STEP 0: Workspace Analysis & Cache (Automatic)

Skip if --skip-cache. Otherwise: read `.opencode/workspace-cache/analysis.json`.
- Valid cache (< 24h) → use it
- Stale/missing → run workspace-analyzer

If stale/missing, call Task:
- subagent_type = workspace-analyzer
- description = Workspace analysis
- prompt = include PROJECT_ROOT; agent will scan and output CACHE_DATA JSON per its own instructions

Handle: COMPLETE→save, TIMEOUT→partial, EMPTY/FAILED→null. Proceed to STEP 1.

### STEP 1: Environment Setup (User Input Required)
- subagent_type = env-setup
- description = Environment setup check
- prompt = include PROJECT_ROOT; agent will auto-detect shell/env/runtimes

WAITING_INPUT → wait, call again. SUCCESS → proceed to STEP 2.

### STEP 2: File Input (Git or Direct)

**Option A: Git Mode** (use_git_mode == true)
- subagent_type = git-input
- description = Git input parsing
- prompt = include $ARGUMENTS value; agent will parse git mode and extract file list

Result: SUCCESS→store files→STEP 2.5. NO_CHANGES→end. DELETED_ONLY→STEP 9. NO_GIT_REPO→wait user. DETACHED_HEAD→wait user. MERGE_CONFLICT/REBASE→end. ABORTED→end.

**Option B: Direct File Mode** (--files)
- subagent_type = file-input
- description = File input parsing
- prompt = include --files value, PROJECT_ROOT, PROJECT_NAME

SUCCESS→STEP 3. NO_FILES/INVALID_PATH→end.

**STEP 2.5 Validation:** empty→end, filter deleted, >100 files→warn, exclude binaries.

### STEP 3: Pre-Check
- subagent_type = pre-checker
- description = Lint/Format fix
- prompt = list changed_files (absolute paths, one per line)

### STEP 4: Code Review
- subagent_type = code-reviewer
- description = Code review
- prompt = build dynamically: list changed_files as absolute paths; include workspace_cache if available; request structured JSON output

code-reviewer has ONLY Read tool. All paths must be absolute.

### STEP 5: Code Fix
- subagent_type = code-fixer
- description = Code fix
- prompt = build dynamically based on mode:

First run: include review_result issues, changed_files, request structured JSON.
Regression: include attempt #, trigger source, regression_history, instruction for different approach.

### STEP 6: Quality Check
- subagent_type = quality-checker
- description = Quality check
- prompt = include changed_files and fix_result.files_modified as absolute paths

score >= 70 → STEP 7. score < 70 → regress to STEP 5 (if under limits). Score not found → retry (max 2).

### STEP 7: Build Test (User Confirmation Required)
- subagent_type = build-tester
- description = Build test
- prompt = include PROJECT_ROOT and ENV_STATE (ACTIVATE_CMD, PYTHON_PATH, ENV_TYPE)

WAITING_INPUT→wait. SUCCESS→STEP 8. FAIL→regress STEP 5. FAIL_DEPS→wait user (no regression count).

### STEP 8: Function Test (User Confirmation Required)
- subagent_type = function-tester
- description = Function test
- prompt = include PROJECT_ROOT and ENV_STATE (ACTIVATE_CMD, PYTHON_PATH, ENV_TYPE)

WAITING_INPUT→wait. SUCCESS→STEP 9. FAIL→regress STEP 5. SKIPPED/NO_TESTS→STEP 9.

### STEP 9: Git Commit (Git Mode Only)

Skip if use_git_mode==false or skip_commit_push==true.

- subagent_type = git-committer
- description = Git commit
- prompt = include changed_files and fix_result.files_modified

### STEP 10: Summary Report
- subagent_type = summary-reporter
- description = Result report
- prompt = include ALL of context_store JSON, regression_history, changed_files

### STEP 11: Push & PR/MR (Git Mode Only)

Skip if use_git_mode==false or skip_commit_push==true.

- subagent_type = git-pusher
- description = Push and PR/MR
- prompt = include commit_result

---

## Regression Rules

Per-source limit: 3. Total cap: 5.

| Source | Condition | Check | Action |
|--------|-----------|-------|--------|
| Quality | score < 70 | quality < 3 AND total < 5 | Regress STEP 5 |
| Build | BUILD_FAIL | build < 3 AND total < 5 | Regress STEP 5 |
| Test | TEST_FAIL | test < 3 AND total < 5 | Regress STEP 5 |
| Any | per-source maxed | source >= 3 | Stop |
| Any | total cap hit | total >= 5 | Stop |

Post-fix validation: if same fix as previous attempt → stop loop.
Timeout guard: if >85% elapsed → skip regression.

---

## Input Options Reference

**Git Mode:** (default)--working, --staged, --last, --branch, --range \<a\>..\<b\>
**Direct File Mode:** --files \<path\> (Git not required)
**Options:** --no-sandbox, --skip-cache

| Option | STEP 0 | STEP 2 | STEP 9/11 | Notes |
|--------|--------|--------|-----------|-------|
| (default) | Auto-analyze | git-input | Commit+Push | Full workflow |
| --staged | Auto-analyze | git-input | Commit+Push | Staged only |
| --last | Auto-analyze | git-input | Amend | Amend last |
| --branch | Auto-analyze | git-input | Commit+Push | Branch diff |
| --files | Auto-analyze | file-input | SKIP | No Git ops |
| --skip-cache | SKIP | (any) | (any) | No context |
