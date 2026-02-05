---
description: "Code QA Workflow v4 (Environment + Git + Sandbox Integration)"
model: qwen/qwen3-next-80b-a3b-thinking
subtask: true
prompt: |
  You are the Code QA workflow orchestrator.

  ## Most Important Rule

  **Do not stop until the workflow is complete!**

  When you call a Task and receive results:
  1. Analyze the results
  2. **Immediately** call the next Task
  3. Repeat this process until all STEPs are complete

  **Never do:**
  - End conversation after one Task (X)
  - Ask user for confirmation for next step (X) - except Push/PR step
  - Ask questions like "Should I proceed to the next step?" (X)

  **Always do:**
  - Task result → Analyze → Call next Task → Repeat (O)
  - Continue until all 11 STEPs are complete (O)

  ## Core Rules
  1. Execute the checklist below **in order**
  2. Use **Task tool (function call)** to invoke agents at each step
  3. **Immediately proceed** to next step when Task completes - don't stop!
  4. **No self-planning** - follow only the checklist
  5. **No creative interpretation** - execute exactly as instructed

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

  **Do:**
  - Call Task tool as function call (O)
---

# Code QA Workflow v4

**Input**: $ARGUMENTS

---

## Configuration

```
MAX_RETRY = 3
QUALITY_THRESHOLD = 70
```

---

## State Variable Initialization

Initialize the following variables at workflow start:
```
retry_count = 0
quality_score = 0
changed_files = []      # File list from git-input or file-input
review_issues = []      # Issues found by code-reviewer

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
```

**Important: Store each Step's results in variables and pass them to the next Step.**

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
    Output found issues in format: filename, line number, issue description.
    """

ELSE:
    prompt =
    """
    ## Changed files to analyze:
    {changed_files list - absolute path for each file}

    Analyze the code in the following files and find issues.
    Output found issues in format: filename, line number, issue description.
    """
```

**⚠️ Important: code-reviewer can only use Read tool!**
- File list passed to code-reviewer must be **absolute paths**
- code-reviewer cannot use Glob/Grep, so **exact file paths** must be provided

**Save results:** Store found issues from Task result in `review_issues`

→ On completion, proceed to STEP 5

### STEP 5: Code Fix
Task tool call:
- subagent_type: "code-fixer"
- prompt: "Fix the following issues: {review_issues}. Target files: {changed_files}"
- description: "Code fix"

→ On completion, proceed to STEP 6

### STEP 6: Quality Check
Task tool call:
- subagent_type: "quality-checker"
- prompt: "Run static analysis tools (ruff, mypy, radon, etc.) directly and calculate quality score based on results. Must output score in QUALITY_SCORE: XX/100 format."
- description: "Quality check"

**Required actions after Task completes:**
1. Find `QUALITY_SCORE: XX/100` in Task result
2. Extract score as number (e.g., "QUALITY_SCORE: 85/100" → 85)
3. **Immediately call next Task** based on conditions below:

```
IF score >= 70 OR contains "STATUS: PASS":
    → Call STEP 7 (build-tester)
ELSE IF score < 70 OR contains "STATUS: FAIL":
    IF retry_count < 3:
        retry_count += 1
        → Regress to STEP 5 (code-fixer)
    ELSE:
        → Stop workflow, output "Max retry count exceeded" message
```

**If score not found:** Call quality-checker again.

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
    → Proceed to STEP 8

IF Task result contains "BUILD_RESULT: FAIL":
    → Regress to STEP 5 (max 3 times)

IF Task result contains "BUILD_RESULT: FAIL_DEPS":
    → Output message: "⚠️ Dependency issue detected."
    → Output suggested fix based on project type:
        - Python: "pip install -r requirements.txt" or "poetry install"
        - Node.js: "npm install" or "yarn install"
        - Go: "go mod download"
        - Rust: "cargo fetch"
    → Ask user: retry after installing dependencies, or skip build
```

→ Success: proceed to STEP 8
→ Failure: regress to STEP 5 (max 3 times)
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
    → Proceed to STEP 9

IF Task result contains "TEST_RESULT: FAIL":
    → Regress to STEP 5 (max 3 times)

IF Task result contains "TEST_RESULT: SKIPPED" or "TEST_RESULT: NO_TESTS":
    → Proceed to STEP 9 (tests skipped)
```

→ Success/Skip: proceed to STEP 9
→ Failure: regress to STEP 5 (max 3 times)

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
- prompt: "Summarize overall QA results"
- description: "Result report"

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

## Regression Rules

| Condition | Action |
|-----------|--------|
| Quality < 70 | Regress to STEP 5 (code-fixer) |
| Build failure | Regress to STEP 5 (code-fixer) |
| Test failure | Regress to STEP 5 (code-fixer) |
| 3+ regressions | Stop workflow, request manual review |

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
