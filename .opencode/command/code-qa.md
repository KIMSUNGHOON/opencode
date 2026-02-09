---
description: "Code QA Workflow v4 (Environment + Git + Sandbox Integration)"
model: qwen/Qwen3-Next-80B-A3B-Thinking-FP8
subtask: true
prompt: |
  You are the Code QA workflow orchestrator.

  ## CRITICAL: SILENT TOOL CALLING - NO NARRATION

  When calling a Task tool, call it DIRECTLY without preamble text.

  WRONG (verbose narration before tool call):
    "I have summarized the output. Now calling env-setup agent..."
    [then tool call]

  WRONG (describing the tool call parameters):
    "Calling env-setup with the following parameters: ..."
    [then tool call]

  RIGHT (direct tool call with minimal context):
    "STEP 1: Environment Setup"
    [tool call immediately]

  RIGHT (after receiving result, move to next):
    "STEP 2: File Input"
    [tool call immediately]

  Rules:
  - Output ONLY the STEP label, then make the tool call
  - Do NOT describe what you are about to do
  - Do NOT echo back the tool parameters as text
  - Do NOT summarize between steps unless storing state variables
  - NEVER output raw JSON or XML tool call syntax as text

  ## Most Important Rule

  **Do not stop until the workflow is complete!**

  When you call a Task and receive results:
  1. Extract and store results in state variables
  2. **Immediately** call the next Task
  3. Repeat this process until all STEPs are complete

  **Never do:**
  - End conversation after one Task (X)
  - Ask user for confirmation for next step (X) - except Push/PR step
  - Ask questions like "Should I proceed to the next step?" (X)
  - Narrate or describe tool calls before making them (X)

  **Always do:**
  - Task result → Store state → Call next Task → Repeat (O)
  - Continue until all 11 STEPs are complete (O)

  ## Core Rules
  1. Execute the checklist below **in order**
  2. Use **Task tool (function call)** to invoke agents at each step
  3. **Immediately proceed** to next step when Task completes - don't stop!
  4. **No self-planning** - follow only the checklist
  5. **No creative interpretation** - execute exactly as instructed
  6. **No verbose narration** - call tools silently

  ## Important: How to Call Agents

  **Task is NOT a bash command!**
  Task is a tool/function you can use.

  To call an agent, invoke the Task tool as a function call.

  **Use only required parameters:**
  - subagent_type: agent name (required)
  - prompt: instructions (required)
  - description: task description (required)

  **Never do:**
  - Run `task` command in bash (X)
  - Shell commands like `$ task env-setup` (X)
  - Pass `null` values (X) - omit optional fields
  - Include null values like `session_id: null` (X)
  - Output tool call as text/JSON/XML (X)

  **Do:**
  - Call Task tool as function call (O)
---

# Code QA Workflow v4

**Input**: $ARGUMENTS

---

## Configuration

```
PER_SOURCE_MAX = 3           # Max retries per regression source (quality, build, test)
TOTAL_REGRESSION_CAP = 5     # Max total regressions across ALL sources
QUALITY_THRESHOLD = 70       # Minimum quality score to pass
```

---

## State Variable Initialization

Initialize the following variables at workflow start:
```
quality_score = 0
changed_files = []      # File list from git-input or file-input
review_issues = []      # Issues found by code-reviewer (structured JSON)

# Input mode (determined by --files option)
use_git_mode = true     # true if no --files, false otherwise

# User input related states
env_setup_confirmed = false   # env-setup completion status
build_env_confirmed = false   # build-tester environment confirmation status
test_confirmed = false        # function-tester test confirmation status

# Workspace cache
workspace_cache = null        # Cache data (use if available)
skip_cache = false            # true if --skip-cache (skip cache AND auto-analysis entirely)

# Git state flags
is_detached_head = false      # Detached HEAD state
skip_commit_push = false      # Skip commit/push steps

# ━━━ P0: Per-Source Retry Counters (prevents infinite loops) ━━━
retry_counters = {
    "quality": 0,       # Quality < 70 regressions (max 3)
    "build": 0,         # Build failure regressions (max 3)
    "test": 0           # Test failure regressions (max 3)
}
PER_SOURCE_MAX = 3           # Max retries per regression source
TOTAL_REGRESSION_CAP = 5     # Max total regressions across ALL sources
total_regressions = 0        # Running total of all regressions

# ━━━ P0: Regression History (context for code-fixer) ━━━
regression_history = []      # Accumulated list of regression attempts
# Each entry: {
#   "attempt": N,
#   "source": "quality|build|test",
#   "issues_or_errors": [...],    # What triggered the regression
#   "fix_result": "...",          # What code-fixer reported last time
#   "files_modified": [...]       # Files code-fixer changed last time
# }

# ━━━ P0: Structured Context Store ━━━
# Store structured JSON from each agent for downstream passing
context_store = {
    "env_state": null,          # From env-setup
    "file_list": null,          # From git-input/file-input
    "pre_check_result": null,   # From pre-checker (SUCCESS/PARTIAL)
    "review_result": null,      # From code-reviewer (structured JSON)
    "fix_result": null,         # From code-fixer (structured JSON)
    "quality_result": null,     # From quality-checker (structured JSON)
    "build_result": null,       # From build-tester (structured JSON)
    "test_result": null,        # From function-tester (structured JSON)
    "commit_result": null,      # From git-committer
    "push_result": null         # From git-pusher
}
```

**Important: Store each Step's results in variables AND in `context_store`, then pass structured data to the next Step.**

**Input mode determination:**
```
IF $ARGUMENTS contains "--files":
    use_git_mode = false
ELSE:
    use_git_mode = true

IF $ARGUMENTS contains "--skip-cache":
    skip_cache = true
ELSE:
    skip_cache = false
```

## Agents Requiring User Input

The following Agents must receive user input before proceeding:

| Agent | Required Input | Wait State |
|-------|----------------|------------|
| env-setup | Confirm current env (Y/n/list) or select from list | `WAITING_INPUT` |
| git-input | When no Git repo: init/specify files/exit | `NO_GIT_REPO` |
| git-input | When Detached HEAD: create branch/continue/exit | `DETACHED_HEAD` |
| build-tester | Environment confirmation ("confirm/y" or "reset/n") | `WAITING_INPUT` |
| function-tester | Test execution ("run/y" or "skip/n") | `WAITING_INPUT` |
| git-committer | Commit confirmation ("confirm/y" or "cancel/n") | `WAITING_INPUT` |
| git-pusher | Push confirmation, retry/skip on auth error | `AUTH_ERROR` |

**WAITING_INPUT state handling:**
1. When Agent returns `WAITING_INPUT`, wait for user response
2. When user responds, call the Agent again to continue
3. Do not auto-proceed without user input

**⚠️ User Input Timeout (P1: Deadlock Prevention):**

User input timeout is **5 minutes** (300,000 ms). If user does not respond within timeout,
the Orchestrator takes a safe default action:

| Agent | Timeout Default Action |
|-------|----------------------|
| env-setup | Auto-confirm detected environment (proceed as-is) |
| git-input (NO_GIT_REPO) | End workflow with message "Timed out waiting for user choice" |
| git-input (DETACHED_HEAD) | Auto-select "qa-only" (skip commit/push) |
| build-tester | Auto-confirm current environment and proceed |
| function-tester | Auto-skip tests |
| git-committer | Auto-skip commit |
| git-pusher | Auto-skip push |

```
IF user does not respond within 5 minutes:
    → Output: "⚠️ User input timeout (5 min). Taking default action: {action}."
    → Execute the default action from the table above
    → Continue workflow
```

---

## Structured Context Passing Rules (P0 Critical)

**Every agent outputs TWO things: human-readable report AND structured JSON.**
The Orchestrator MUST extract the JSON and store it in `context_store`, then pass relevant context to downstream agents.

### How to Extract Structured JSON from Agent Output

Each agent outputs a JSON block after its result token. Extract it like this:
```
1. Find the result token (e.g., "CODE_REVIEW_RESULT: COMPLETE")
2. Find the JSON block that follows (between ```json and ```)
3. Parse it and store in context_store

IF no JSON block found:
    → Parse from the text-format output (ISSUE_LIST, etc.)
    → Construct the JSON yourself from parsed data
    → Store in context_store

EXTRACTION EXAMPLE (code-reviewer):
    Agent output contains:
        ISSUE_LIST:
        [C001] /path/file.py:45 - SQL injection vulnerability
        [H001] /path/file.py:78 - Null reference possible

    Construct JSON:
        context_store.review_result = {
            "review": {
                "summary": { "files": 1, "issues": 2, "by_severity": { "critical": 1, "high": 1 } },
                "issues": [
                    { "id": "C001", "severity": "critical", "file": "/path/file.py", "line": 45,
                      "title": "SQL injection vulnerability", "suggestion": "" },
                    { "id": "H001", "severity": "high", "file": "/path/file.py", "line": 78,
                      "title": "Null reference possible", "suggestion": "" }
                ]
            }
        }

EXTRACTION FOR REGRESSION HISTORY:
    When building regression_history entries, extract issues_or_errors from:
    - quality-checker: context_store.quality_result.remaining_issues
    - build-tester: context_store.build_result.errors
    - function-tester: context_store.test_result.failed_tests
    If structured JSON unavailable, parse from text output.
```

### What to Pass to Each Agent

| Agent | Receives from context_store |
|-------|---------------------------|
| pre-checker | `file_list` |
| code-reviewer | `env_state`, `file_list`, `workspace_cache` |
| code-fixer | `review_result.issues`, `file_list`, `regression_history` |
| quality-checker | `file_list`, `fix_result.files_modified` |
| build-tester | `env_state`, `file_list` |
| function-tester | `env_state`, `file_list` |
| git-committer | `file_list`, `fix_result.files_modified` |
| summary-reporter | **ALL** of `context_store` + `regression_history` |
| git-pusher | `commit_result` |

### Regression Context (CRITICAL for code-fixer)

When regressing to STEP 5 (code-fixer), you MUST include:
```
1. The NEW issues/errors that triggered the regression
2. The FULL regression_history (all previous attempts)
3. Explicit instruction: "Do NOT repeat these previously attempted fixes"
```

This prevents code-fixer from applying the same fix repeatedly.

---

## Execution Checklist

Use the Task tool (function call) to invoke agents at each STEP.
**When Task completes, verify results and immediately proceed to next STEP.**

### STEP 0: Workspace Analysis & Cache (Automatic)

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Workspace analysis is ALWAYS performed unless explicitly skipped.      │
│                                                                          │
│  DEFAULT behavior:                                                       │
│    Cache exists + fresh (24h) → Use cache                               │
│    Cache missing or stale    → Auto-run workspace-analyzer              │
│                                                                          │
│  --skip-cache: Skip cache check AND auto-analysis entirely             │
│                (fastest startup, no project context)                     │
│                                                                          │
│  This applies to ALL modes: Git mode, --files, --last, --branch, etc.  │
│  Project context is always useful regardless of input mode.             │
└─────────────────────────────────────────────────────────────────────────┘
```

**⚠️ Cache skip conditions:**
```
IF skip_cache == true (--skip-cache option):
    → Skip everything in STEP 0
    → workspace_cache = null
    → Proceed to STEP 1
```

**Cache check:**
Use Read tool to read `.opencode/workspace-cache/analysis.json` file.

```
IF file exists and read successfully:
    1. Check analyzed_at timestamp
    2. Cache is valid if within 24 hours

    IF cache is valid:
        workspace_cache = {read JSON data}
        → Output: "✓ Using workspace cache (analyzed: {analyzed_at})"
        → Proceed to STEP 1 (using cache)

    ELSE (cache is stale):
        → Output: "Cache expired. Running workspace analysis..."
        → Run auto-analysis (see below)

ELSE IF file not found:
    → Output: "No workspace cache. Running workspace analysis..."
    → Run auto-analysis (see below)
```

**Auto-analysis (default behavior when cache missing or stale):**

First, create cache directory:
```bash
mkdir -p .opencode/workspace-cache
```

Task tool call:
- subagent_type: "workspace-analyzer"
- prompt: "Analyze current workspace. Analyze project type, file structure, dependencies, build system and output results as JSON after CACHE_DATA:. If file count exceeds 10,000, analyze only main directories."
- description: "Workspace analysis"

```
IF Task result contains "WORKSPACE_ANALYSIS_RESULT: COMPLETE":
    1. Extract JSON after CACHE_DATA:
    2. workspace_cache = {extracted JSON}
    3. Save to .opencode/workspace-cache/analysis.json (using Write tool)
    → Proceed to STEP 1

IF Task result contains "WORKSPACE_ANALYSIS_RESULT: TIMEOUT":
    → Output warning: "⚠️ Project too large, only partial analysis completed."
    → Extract CACHE_DATA if available and store in workspace_cache (partial data)
    → Proceed to STEP 1 (using partial cache)

IF Task result contains "WORKSPACE_ANALYSIS_RESULT: EMPTY":
    → Output info: "ℹ️ Empty project. No source files found."
    → workspace_cache = null
    → Proceed to STEP 1

IF Task result contains "WORKSPACE_ANALYSIS_RESULT: FAILED":
    → Output warning: "⚠️ Workspace analysis failed. Proceeding without cache."
    → workspace_cache = null
    → Proceed to STEP 1
```

→ On completion, proceed to STEP 1

### STEP 1: Environment Setup (User Input Required)
Task tool call:
- subagent_type: "env-setup"
- prompt: "Detect current environment (shell, conda/venv, runtimes). If active environment exists, ask single Y/n confirmation. If no active environment, show env list for selection."
- description: "Environment setup check"

**⚠️ User input wait handling:**
```
IF Task result contains "ENV_SETUP_RESULT: WAITING_INPUT":
    → Wait for user response (repeat STEP 1)
    → When user inputs, call env-setup again

IF Task result contains "ENV_SETUP_RESULT: SUCCESS":
    → Proceed to STEP 2
```

→ After user input complete, proceed to STEP 2

### STEP 2: File Input (Git or Direct)

**Call different Agent based on input mode:**

#### Option A: Git Mode (use_git_mode == true)
Task tool call:
- subagent_type: "git-input"
- prompt: "Parse input options $ARGUMENTS and extract changed file list"
- description: "Git input parsing"

**⚠️ Git result handling:**
```
IF Task result contains "GIT_INPUT_RESULT: SUCCESS":
    → Store FILE_LIST in changed_files
    → Log DELETED_FILES if present (excluded from analysis)
    → Proceed to STEP 2.5 (file validation)

IF Task result contains "GIT_INPUT_RESULT: NO_CHANGES":
    → Output message: "ℹ️ No changed files."
    → End workflow (success, no QA needed)

IF Task result contains "GIT_INPUT_RESULT: DELETED_ONLY":
    → Output message: "ℹ️ Only deleted files. No files to analyze."
    → Skip to STEP 9 (Git Commit)

IF Task result contains "GIT_INPUT_RESULT: NO_CODE_FILES":
    → Output message: "ℹ️ No code files changed."
    → End workflow (success, no QA needed)

IF Task result contains "GIT_INPUT_RESULT: NO_GIT_REPO":
    → Wait for user response
    → If user inputs "git init" or "initialize": call git-input again
    → If user inputs file paths: change use_git_mode = false, call file-input
    → If user inputs "exit" or "quit": end workflow

IF Task result contains "GIT_INPUT_RESULT: DETACHED_HEAD":
    → Wait for user response
    → If user inputs branch name: call git-input again to create branch
    → If user inputs "qa-only" or "continue":
        → is_detached_head = true
        → skip_commit_push = true
        → Proceed to STEP 2.5
    → If user inputs "exit": end workflow

IF Task result contains "GIT_INPUT_RESULT: MERGE_CONFLICT":
    → Output message: "⚠️ Merge conflict detected. Please resolve conflicts first."
    → Output message: "Run 'git status' to see conflicted files."
    → End workflow (blocked by merge conflict)

IF Task result contains "GIT_INPUT_RESULT: REBASE_IN_PROGRESS":
    → Output message: "⚠️ Rebase in progress. Please complete or abort rebase first."
    → Output message: "Continue: git rebase --continue | Abort: git rebase --abort"
    → End workflow (blocked by rebase)

IF Task result contains "GIT_INPUT_RESULT: ABORTED":
    → End workflow
```

#### Option B: Direct File Mode (use_git_mode == false, --files option)
Task tool call:
- subagent_type: "file-input"
- prompt: "Find code files at the following paths: {--files value}"
- description: "File input parsing"

```
IF Task result contains "FILE_INPUT_RESULT: SUCCESS":
    → Proceed to STEP 3

IF Task result contains "FILE_INPUT_RESULT: NO_FILES" or "FILE_INPUT_RESULT: INVALID_PATH":
    → Output error message and end workflow
```

**Save results:** Extract file list from Task result and store in `changed_files`

**⚠️ File list validation (STEP 2.5):**
```
# Check for no changed files
IF changed_files.length == 0:
    → Output message: "ℹ️ No changed files. Ending workflow."
    → End workflow (success, no QA needed)

# Filter deleted files
IF changed_files contains deleted files (D):
    → Exclude deleted files from analysis
    → Output message: "ℹ️ {N} deleted files excluded from analysis."
    → Remove deleted files from changed_files

# No files to analyze (all deleted)
IF changed_files.length == 0 after filtering:
    → Output message: "ℹ️ No files to analyze. (Only deleted files)"
    → Skip to STEP 9 (Git Commit)

# Large file count warning
IF changed_files.length > 100:
    → Output warning: "⚠️ {N} files changed. Analysis may take a long time."
    → Recommend filtering to source files only (exclude test, config files)

# Binary file filtering
Auto-exclude binary extension files:
- .exe, .dll, .so, .dylib, .bin
- .zip, .tar, .gz, .rar, .7z
- .png, .jpg, .jpeg, .gif, .ico, .svg, .webp
- .pdf, .doc, .docx, .xls, .xlsx
- .woff, .woff2, .ttf, .eot
- .mp3, .mp4, .wav, .avi
```

→ On completion, proceed to STEP 3

### STEP 3: Pre-Check
Task tool call:
- subagent_type: "pre-checker"
- prompt: "Run Lint/Format auto-fix for the following files: {changed_files}"
- description: "Lint/Format fix"

→ On completion, proceed to STEP 4

### STEP 4: Code Review
Task tool call:
- subagent_type: "code-reviewer"
- prompt: Construct prompt in the format below
- description: "Code review"

**Prompt construction (Important!):**

```
IF workspace_cache != null:
    prompt =
    """
    ## Project Context (from workspace cache)
    - Project Type: {workspace_cache.project.type}
    - Languages: {workspace_cache.project.languages}
    - Frameworks: {workspace_cache.project.frameworks}
    - Build System: {workspace_cache.build_system.type}
    - Test Command: {workspace_cache.build_system.test_command}

    ## Changed files to analyze:
    {changed_files list - absolute path for each file}

    Analyze the code in the above files and find issues.

    ## REQUIRED: Structured Output
    After your human-readable report, you MUST output a JSON block:
    ```json
    {
      "review": {
        "summary": { "files": N, "issues": N, "by_severity": {"critical": N, "high": N, "medium": N, "low": N} },
        "issues": [
          { "id": "C001", "severity": "critical", "category": "security", "file": "/absolute/path.py", "line": 45, "title": "Issue Title", "description": "What is wrong", "suggestion": "How to fix" }
        ]
      }
    }
    ```
    This JSON is MANDATORY. It will be passed to the Code Fixer agent.
    """

ELSE:
    prompt =
    """
    ## Changed files to analyze:
    {changed_files list - absolute path for each file}

    Analyze the code in the following files and find issues.

    ## REQUIRED: Structured Output
    After your human-readable report, you MUST output a JSON block:
    ```json
    {
      "review": {
        "summary": { "files": N, "issues": N, "by_severity": {"critical": N, "high": N, "medium": N, "low": N} },
        "issues": [
          { "id": "C001", "severity": "critical", "category": "security", "file": "/absolute/path.py", "line": 45, "title": "Issue Title", "description": "What is wrong", "suggestion": "How to fix" }
        ]
      }
    }
    ```
    This JSON is MANDATORY. It will be passed to the Code Fixer agent.
    """
```

**⚠️ Important: code-reviewer can only use Read tool!**
- File list passed to code-reviewer must be **absolute paths**
- code-reviewer cannot use Glob/Grep, so **exact file paths** must be provided

**Save results:**
1. Extract the structured JSON from the Task result
2. Store in `context_store.review_result`
3. Also store the issues array in `review_issues` for backward compatibility

→ On completion, proceed to STEP 5

### STEP 5: Code Fix
Task tool call:
- subagent_type: "code-fixer"
- prompt: Construct prompt based on whether this is a first run or regression
- description: "Code fix"

**Prompt construction (CRITICAL - different for first run vs regression):**

```
IF regression_history.length == 0 (first run):
    prompt =
    """
    ## Issues to Fix (from Code Review)
    {context_store.review_result as JSON, or review_issues as text}

    ## Target Files
    {changed_files list - absolute paths}

    Fix the above issues. After fixing, output your result with structured JSON:
    ```json
    {
      "fix": {
        "summary": { "total": N, "fixed": N, "skipped": N, "failed": N },
        "fixed_issues": ["C001", "H001"],
        "skipped_issues": [{ "id": "L001", "reason": "Low priority" }],
        "failed_issues": [{ "id": "...", "reason": "..." }],
        "files_modified": ["/absolute/path.py"],
        "changes_applied": [
          { "issue_id": "C001", "file": "/path.py", "line": 45, "description": "Changed to parameterized query" }
        ]
      }
    }
    ```
    """

ELSE (regression - CRITICAL CONTEXT):
    prompt =
    """
    ## ⚠️ REGRESSION MODE - This is attempt #{total_regressions + 1}

    ## Regression Trigger
    Source: {last regression source: "quality"|"build"|"test"}
    New errors/issues that triggered this regression:
    {The specific errors from quality-checker/build-tester/function-tester output}

    ## ⛔ PREVIOUS ATTEMPTS - DO NOT REPEAT THESE FIXES
    The following fixes were already attempted and DID NOT resolve the problem:
    {JSON.stringify(regression_history, indent=2)}

    ## STRATEGY REQUIREMENT
    Since previous fix attempts failed, you MUST try a DIFFERENT approach:
    1. Read the files again to see current state (including previous fix attempts)
    2. Analyze WHY the previous fix did not work
    3. Apply a DIFFERENT fix strategy
    4. If the same issue keeps recurring, consider:
       - The root cause may be elsewhere
       - The fix may need to be more comprehensive
       - The issue may require a different approach entirely

    ## Original Issues (from Code Review)
    {context_store.review_result as JSON, or review_issues as text}

    ## Target Files
    {changed_files list - absolute paths}

    Fix the issues using a NEW approach. Output structured JSON as above.
    """
```

**After Task completes:**
1. Extract structured JSON from code-fixer output
2. Store in `context_store.fix_result`
3. This data will be used for regression_history if a later step triggers regression

→ On completion, proceed to STEP 6

### STEP 6: Quality Check
Task tool call:
- subagent_type: "quality-checker"
- prompt: Construct prompt including changed files context
- description: "Quality check"

**Prompt construction:**
```
prompt =
"""
Run static analysis tools on the following files and calculate quality score.
Must output score in QUALITY_SCORE: XX/100 format.

## Files to Check
{changed_files list - absolute paths}

## Files Modified by Code Fixer (if any)
{context_store.fix_result.files_modified or "same as above"}

After your human-readable report, also output structured JSON:
```json
{
  "quality": {
    "score": 85,
    "status": "PASS",
    "by_severity": { "critical": 0, "high": 1, "medium": 3, "low": 2 },
    "tool_results": [{ "tool": "ruff", "issues": 3 }, { "tool": "mypy", "issues": 1 }],
    "remaining_issues": [
      { "severity": "high", "tool": "mypy", "file": "/path.py", "line": 10, "message": "..." }
    ]
  }
}
```
"""
```

**Required actions after Task completes:**
1. Find `QUALITY_SCORE: XX/100` in Task result
2. Extract score as number (e.g., "QUALITY_SCORE: 85/100" → 85)
3. Extract structured JSON and store in `context_store.quality_result`
4. **Immediately call next Task** based on conditions below:

```
IF score >= 70 OR contains "STATUS: PASS":
    → Proceed to STEP 7 (build-tester)

ELSE IF score < 70 OR contains "STATUS: FAIL":
    # ━━━ P0: Per-source retry check ━━━
    IF retry_counters.quality < PER_SOURCE_MAX AND total_regressions < TOTAL_REGRESSION_CAP:
        retry_counters.quality += 1
        total_regressions += 1

        # Record regression in history
        regression_history.append({
            "attempt": total_regressions,
            "source": "quality",
            "issues_or_errors": context_store.quality_result.remaining_issues
                                 OR [parsed quality issues from text output],
            "fix_result": context_store.fix_result,
            "files_modified": context_store.fix_result.files_modified OR []
        })

        → Output: "⚠️ Quality regression #{retry_counters.quality}/3 (total: {total_regressions}/{TOTAL_REGRESSION_CAP})"
        → Regress to STEP 5 (code-fixer) WITH regression context

    ELSE IF retry_counters.quality >= PER_SOURCE_MAX:
        → Stop workflow, output "Quality retry limit reached ({PER_SOURCE_MAX}). Manual review needed."

    ELSE IF total_regressions >= TOTAL_REGRESSION_CAP:
        → Stop workflow, output "Total regression cap reached ({TOTAL_REGRESSION_CAP}). Manual review needed."
```

**If score not found:** Call quality-checker again (max 2 parse retries).

### STEP 7: Build Test (User Confirmation Required)
Task tool call:
- subagent_type: "build-tester"
- prompt: "Run build test. First show current environment state (Shell, virtual env, runtime) and proceed with build only after user confirmation."
- description: "Build test"

**⚠️ User input wait handling:**
```
IF Task result contains "BUILD_RESULT: WAITING_INPUT":
    → Wait for user to confirm environment
    → If user inputs "confirm/y": proceed with build
    → If user inputs "reset/n": regress to STEP 1 (env-setup)

IF Task result contains "BUILD_RESULT: SUCCESS":
    → Store result in context_store.build_result
    → Proceed to STEP 8

IF Task result contains "BUILD_RESULT: FAIL":
    → Extract error details from output (structured JSON if available)
    → Store in context_store.build_result

    # ━━━ P0: Per-source retry check ━━━
    IF retry_counters.build < PER_SOURCE_MAX AND total_regressions < TOTAL_REGRESSION_CAP:
        retry_counters.build += 1
        total_regressions += 1

        # Record regression in history
        regression_history.append({
            "attempt": total_regressions,
            "source": "build",
            "issues_or_errors": [build error messages extracted from output],
            "fix_result": context_store.fix_result,
            "files_modified": context_store.fix_result.files_modified OR []
        })

        → Output: "⚠️ Build regression #{retry_counters.build}/3 (total: {total_regressions}/{TOTAL_REGRESSION_CAP})"
        → Regress to STEP 5 (code-fixer) WITH regression context

    ELSE IF retry_counters.build >= PER_SOURCE_MAX:
        → Stop workflow, output "Build retry limit reached ({PER_SOURCE_MAX}). Manual fix needed."

    ELSE IF total_regressions >= TOTAL_REGRESSION_CAP:
        → Stop workflow, output "Total regression cap reached ({TOTAL_REGRESSION_CAP}). Manual review needed."

IF Task result contains "BUILD_RESULT: FAIL_DEPS":
    → Output message: "⚠️ Dependency issue detected."
    → Output suggested fix based on project type:
        - Python: "pip install -r requirements.txt" or "poetry install"
        - Node.js: "npm install" or "yarn install"
        - Go: "go mod download"
        - Rust: "cargo fetch"
    → Ask user: retry after installing dependencies, or skip build
    → (FAIL_DEPS does NOT count toward regression counters)
```

→ Success: proceed to STEP 8
→ Failure: regress to STEP 5 (with per-source limit)
→ Reset: regress to STEP 1

### STEP 8: Function Test (User Confirmation Required)
Task tool call:
- subagent_type: "function-tester"
- prompt: "Run function tests. First show detected test files, then ask user whether to execute tests before proceeding."
- description: "Function test"

**⚠️ User input wait handling:**
```
IF Task result contains "TEST_RESULT: WAITING_INPUT":
    → Wait for user to choose whether to run tests
    → If user inputs "run/y": proceed with tests
    → If user inputs "skip/n": skip tests

IF Task result contains "TEST_RESULT: SUCCESS":
    → Store result in context_store.test_result
    → Proceed to STEP 9

IF Task result contains "TEST_RESULT: FAIL":
    → Extract failed test details from output (structured JSON if available)
    → Store in context_store.test_result

    # ━━━ P0: Per-source retry check ━━━
    IF retry_counters.test < PER_SOURCE_MAX AND total_regressions < TOTAL_REGRESSION_CAP:
        retry_counters.test += 1
        total_regressions += 1

        # Record regression in history
        regression_history.append({
            "attempt": total_regressions,
            "source": "test",
            "issues_or_errors": [failed test names and error messages from output],
            "fix_result": context_store.fix_result,
            "files_modified": context_store.fix_result.files_modified OR []
        })

        → Output: "⚠️ Test regression #{retry_counters.test}/3 (total: {total_regressions}/{TOTAL_REGRESSION_CAP})"
        → Regress to STEP 5 (code-fixer) WITH regression context

    ELSE IF retry_counters.test >= PER_SOURCE_MAX:
        → Stop workflow, output "Test retry limit reached ({PER_SOURCE_MAX}). Manual fix needed."

    ELSE IF total_regressions >= TOTAL_REGRESSION_CAP:
        → Stop workflow, output "Total regression cap reached ({TOTAL_REGRESSION_CAP}). Manual review needed."

IF Task result contains "TEST_RESULT: SKIPPED" or "TEST_RESULT: NO_TESTS":
    → Store result in context_store.test_result
    → Proceed to STEP 9 (tests skipped)
```

→ Success/Skip: proceed to STEP 9
→ Failure: regress to STEP 5 (with per-source limit)

### STEP 9: Git Commit (User Confirmation Required) - Git Mode Only

**⚠️ Non-Git mode (when --files used):**
```
IF use_git_mode == false:
    → Skip STEP 9
    → Proceed directly to STEP 10 (Summary Report)
```

**⚠️ Detached HEAD mode:**
```
IF skip_commit_push == true:
    → Skip STEP 9
    → Proceed directly to STEP 10 (Summary Report)
    → Output message: "ℹ️ Skipping commit due to Detached HEAD state."
```

**Git mode:**
Task tool call:
- subagent_type: "git-committer"
- prompt: "Commit changes (new commit for --working/--staged, amend for --last/--branch). First show commit info and get user confirmation."
- description: "Git commit"

**⚠️ User input wait handling:**
```
IF Task result contains "COMMIT_RESULT: WAITING_INPUT":
    → Wait for user to confirm commit info
    → If user inputs "confirm/y": proceed with commit
    → If user inputs new message: commit with that message
    → If user inputs "cancel/n": skip commit

IF Task result contains "COMMIT_RESULT: SUCCESS":
    → Proceed to STEP 10

IF Task result contains "COMMIT_RESULT: SKIPPED" or "COMMIT_RESULT: NO_CHANGES":
    → Proceed to STEP 10 (commit skipped)
```

→ On completion, proceed to STEP 10

### STEP 10: Summary Report
Task tool call:
- subagent_type: "summary-reporter"
- prompt: Construct prompt with ALL accumulated context
- description: "Result report"

**Prompt construction (pass ALL context):**
```
prompt =
"""
Generate a comprehensive QA summary report from the following structured data.

## Full QA Context
```json
{JSON.stringify(context_store, indent=2)}
```

## Regression History
Total regressions: {total_regressions}
Retry counters: quality={retry_counters.quality}, build={retry_counters.build}, test={retry_counters.test}
```json
{JSON.stringify(regression_history, indent=2)}
```

## Changed Files
{changed_files list}

Use the structured data above to generate an accurate, data-driven report.
Do NOT use placeholder values - use the actual data provided.
"""
```

→ On completion, proceed to STEP 11

### STEP 11: Push & PR/MR - Git Mode Only

**⚠️ Non-Git mode (when --files used):**
```
IF use_git_mode == false:
    → Skip STEP 11
    → End workflow (completed with Summary Report)
```

**⚠️ Detached HEAD mode:**
```
IF skip_commit_push == true:
    → Skip STEP 11
    → End workflow
    → Output message: "ℹ️ Skipping push due to Detached HEAD state."
```

**Git mode:**
Task tool call:
- subagent_type: "git-pusher"
- prompt: "Detect remote repository platform (GitHub/GitLab) and confirm Push with user. Also confirm whether to create PR (GitHub) or MR (GitLab) after Push."
- description: "Push and PR/MR"

**⚠️ Authentication error handling:**
```
IF Task result contains "PUSH_RESULT: AUTH_ERROR":
    → Guide user on auth error type (SSH/HTTPS/GPG/CLI) and resolution
    → If user inputs "retry": call git-pusher again
    → If user inputs "skip": skip Push and end workflow

IF Task result contains "PUSH_RESULT: SUCCESS":
    → End workflow (success)

IF Task result contains "PUSH_RESULT: SKIPPED":
    → End workflow (Push skipped)

IF Task result contains "PUSH_RESULT: FAIL":
    → Output error message and end workflow
```

**Platform-specific PR/MR creation:**
- GitHub: Use `gh pr create`
- GitLab/GitLab-CE: Use `glab mr create`
- Other: Guide manual creation

→ Complete: End workflow

---

## Regression Rules (P0: Per-Source Independent Counters)

### Counter System
```
Per-source limit:  PER_SOURCE_MAX = 3 (each source independently)
Total cap:         TOTAL_REGRESSION_CAP = 5 (all sources combined)

Example scenario:
  quality regression #1 → total=1 → OK, regress
  quality regression #2 → total=2 → OK, regress
  build regression #1   → total=3 → OK, regress
  test regression #1    → total=4 → OK, regress
  quality regression #3 → total=5 → OK, regress (quality maxed at 3)
  build regression #2   → total=6 → BLOCKED by total cap (5)
```

### Decision Table

| Source | Condition | Counter Check | Action |
|--------|-----------|--------------|--------|
| Quality | score < 70 | quality < 3 AND total < 5 | Regress to STEP 5 with context |
| Build | BUILD_FAIL | build < 3 AND total < 5 | Regress to STEP 5 with context |
| Test | TEST_FAIL | test < 3 AND total < 5 | Regress to STEP 5 with context |
| Any | per-source maxed | source >= 3 | Stop: "{source} retry limit reached" |
| Any | total cap hit | total >= 5 | Stop: "Total regression cap reached" |

### Regression Context (MUST pass to code-fixer)

Every regression to STEP 5 MUST include:
1. `regression_history` — full list of all previous attempts
2. New trigger — the specific errors/issues that caused this regression
3. Explicit instruction to try a DIFFERENT fix approach

### Post-Fix Regression Validation

After code-fixer returns during a regression (total_regressions > 0):
```
1. Extract files_modified and changes_applied from current fix result
2. Compare with previous regression_history entry

IF files_modified is identical AND changes_applied descriptions match previous attempt:
    → Output: "⚠️ code-fixer applied identical fix as attempt #{N-1}. Breaking loop."
    → Do NOT regress again (prevents infinite same-fix loop)
    → Proceed to next step with current state
```

### Regression Timeout Guard

Before starting any regression to STEP 5:
```
IF workflow has been running for > 85% of workflow timeout (51 min of 60 min):
    → Output: "⚠️ Workflow nearing timeout. Skipping regression to preserve progress."
    → Proceed with current results (do NOT regress)
    → Continue to next step
```

---

## Input Options Reference

### Input Mode (Mutually Exclusive)

**Git Mode (Default):**
- (default): --working (git diff - unstaged changes)
- --staged: staged changes only
- --last: last commit changes
- --branch: entire branch diff from base
- --range <a>..<b>: specific commit range

**Direct File Mode (Non-Git):**
- --files <path>: specify files/directories directly (Git not required)
  - Example: `--files src/main.py`
  - Example: `--files src/*.py`
  - Example: `--files src/,lib/,tests/`
  - Example: `--files torch_aim/csrc` (relative to project root)

### Sandbox Options
- (default): Use Docker Sandbox
- --no-sandbox: Run directly on host

### Cache Options
- (default): Auto-analyze if cache missing or stale (recommended)
- --skip-cache: Skip cache check AND auto-analysis entirely (fastest startup)

### Option Compatibility Matrix

```
┌──────────────┬──────────────┬──────────┬────────────┬────────────────────┐
│ Option       │ STEP 0       │ STEP 2   │ STEP 9/11  │ Notes              │
│              │ (Analysis)   │ (Input)  │ (Git ops)  │                    │
├──────────────┼──────────────┼──────────┼────────────┼────────────────────┤
│ (default)    │ Auto-analyze │ git-input│ Commit+Push│ Full workflow      │
│ --staged     │ Auto-analyze │ git-input│ Commit+Push│ Staged only        │
│ --last       │ Auto-analyze │ git-input│ Amend      │ Amend last commit  │
│ --branch     │ Auto-analyze │ git-input│ Commit+Push│ Full branch diff   │
│ --range a..b │ Auto-analyze │ git-input│ Commit+Push│ Specific range     │
│ --files path │ Auto-analyze │file-input│ SKIP       │ No Git operations  │
│ --skip-cache │ SKIP         │ (any)    │ (any)      │ No project context │
│ --no-sandbox │ Auto-analyze │ (any)    │ (any)      │ Run on host        │
└──────────────┴──────────────┴──────────┴────────────┴────────────────────┘
```

### Recommended Usage Patterns

```bash
# Standard QA (auto-analyzes project on first run, uses cache after)
/code-qa

# QA on staged changes only
/code-qa --staged

# QA on last commit (amend mode)
/code-qa --last

# QA specific files/directories (no Git needed)
/code-qa --files src/main.py
/code-qa --files torch_aim/csrc --no-sandbox

# Quick QA without project analysis (fastest)
/code-qa --skip-cache

# Force fresh analysis (when project structure changed)
/analyze --force && /code-qa
```
