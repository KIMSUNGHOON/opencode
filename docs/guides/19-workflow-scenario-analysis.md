# Code QA v4 Workflow Scenario Analysis

This document analyzes various workflow scenarios to verify correct handling.

---

## 1. Environment Setup Scenarios

### 1.1 Scenario: Active Conda Environment

```
User state: Already in "ml-dev" conda environment
Expected flow:
  1. env-setup detects $CONDA_DEFAULT_ENV = "ml-dev"
  2. Shows: "Use current environment 'ml-dev'? [Y/n/list]"
  3. User presses Enter or Y
  4. SUCCESS (1 interaction)
```

**Status**: ✅ Handled by streamlined env-setup

### 1.2 Scenario: Active venv Environment

```
User state: Already activated .venv
Expected flow:
  1. env-setup detects $VIRTUAL_ENV = "/path/to/.venv"
  2. Shows: "Use current environment '.venv'? [Y/n/list]"
  3. User presses Enter
  4. SUCCESS (1 interaction)
```

**Status**: ✅ Handled by streamlined env-setup

### 1.3 Scenario: No Active Environment

```
User state: No conda/venv activated
Expected flow:
  1. env-setup detects ACTIVE_TYPE: none
  2. Shows conda env list + options
  3. User selects environment
  4. SUCCESS (2 interactions)
```

**Status**: ✅ Handled by streamlined env-setup

### 1.4 Scenario: User Wants Different Environment

```
User state: In "base" but wants "ml-dev"
Expected flow:
  1. env-setup shows: "Use 'base'? [Y/n/list]"
  2. User inputs "n"
  3. Shows full env list
  4. User selects "ml-dev"
  5. SUCCESS (2 interactions)
```

**Status**: ✅ Handled by streamlined env-setup

### 1.5 Scenario: auto_confirm Config

```
User state: .opencode/env-config.yaml has auto_confirm: true
Expected flow:
  1. env-setup reads config
  2. Verifies environment matches
  3. SUCCESS (0 interactions)
```

**Status**: ✅ Handled by streamlined env-setup

---

## 2. Git Input Scenarios

### 2.1 Scenario: Normal Working Directory Changes

```
User state: Has uncommitted changes in working directory
Command: /code-qa (default --working)
Expected flow:
  1. git-input runs git diff
  2. Returns FILE_LIST with changed files
  3. GIT_INPUT_RESULT: SUCCESS
  4. Proceed to STEP 3
```

**Status**: ✅ Handled

### 2.2 Scenario: No Changed Files

```
User state: Clean working directory
Command: /code-qa
Expected flow:
  1. git-input runs git diff
  2. No files returned
  3. GIT_INPUT_RESULT: NO_CHANGES
  4. Workflow ends gracefully with message
```

**Status**: ✅ Handled

### 2.3 Scenario: Only Deleted Files

```
User state: git rm file.py
Command: /code-qa --staged
Expected flow:
  1. git-input detects D status files
  2. GIT_INPUT_RESULT: DELETED_ONLY
  3. Skip to STEP 9 (Git Commit)
```

**Status**: ✅ Handled

### 2.4 Scenario: Detached HEAD

```
User state: git checkout HEAD~1 (CI/CD common)
Command: /code-qa
Expected flow:
  1. git-input detects detached HEAD
  2. GIT_INPUT_RESULT: DETACHED_HEAD
  3. User options:
     - Enter branch name → create branch, continue
     - "qa-only" → skip_commit_push=true, continue QA only
     - "exit" → end workflow
```

**Status**: ✅ Handled

### 2.5 Scenario: Merge Conflict

```
User state: git merge feature (conflicts exist)
Command: /code-qa
Expected flow:
  1. git-input detects merge conflict via git ls-files -u
  2. GIT_INPUT_RESULT: MERGE_CONFLICT
  3. Workflow blocked, user guided to resolve
```

**Status**: ✅ Handled

### 2.6 Scenario: Rebase in Progress

```
User state: git rebase main (stopped mid-rebase)
Command: /code-qa
Expected flow:
  1. git-input detects .git/rebase-merge or .git/rebase-apply
  2. GIT_INPUT_RESULT: REBASE_IN_PROGRESS
  3. Workflow blocked, user guided to continue/abort
```

**Status**: ✅ Handled

### 2.7 Scenario: Not a Git Repository

```
User state: In non-git directory
Command: /code-qa
Expected flow:
  1. git-input detects not a git repo
  2. GIT_INPUT_RESULT: NO_GIT_REPO
  3. User options:
     - "git init" → initialize repo
     - file paths → switch to file-input mode
     - "exit" → end workflow
```

**Status**: ✅ Handled

### 2.8 Scenario: Large File Count (100+ files)

```
User state: Major refactoring with 200 changed files
Command: /code-qa
Expected flow:
  1. git-input returns FILE_LIST with 200 files
  2. STEP 2.5 validation shows warning
  3. Binary files auto-filtered
  4. Recommendation to filter to source files
```

**Status**: ✅ Handled

### 2.9 Scenario: Renamed Files

```
User state: git mv old.py new.py
Command: /code-qa --staged
Expected flow:
  1. git-input detects R status
  2. FILE_LIST includes new.py (not old.py)
  3. RENAMED_FILES: old.py→new.py logged
```

**Status**: ✅ Handled

---

## 3. Cache Scenarios

### 3.1 Scenario: Valid Cache Exists

```
User state: /analyze ran recently (within 24h)
Command: /code-qa
Expected flow:
  1. STEP 0 reads .opencode/workspace-cache/analysis.json
  2. Timestamp within 24h
  3. workspace_cache = loaded data
  4. Proceed with cache context
```

**Status**: ✅ Handled

### 3.2 Scenario: Stale Cache (>24h)

```
User state: /analyze ran 3 days ago
Command: /code-qa
Expected flow:
  1. STEP 0 reads cache, checks timestamp
  2. Cache is stale (>24h)
  3. Warning: "Cache is stale. Run /analyze first."
  4. workspace_cache = null
  5. Proceed without cache
```

**Status**: ✅ Handled

### 3.3 Scenario: Stale Cache with --with-analysis

```
User state: /analyze ran 3 days ago
Command: /code-qa --with-analysis
Expected flow:
  1. STEP 0 detects stale cache
  2. auto_analyze = true
  3. Call workspace-analyzer to re-analyze
  4. workspace_cache = new data
  5. Proceed with fresh cache
```

**Status**: ✅ Handled

### 3.4 Scenario: No Cache

```
User state: Never ran /analyze
Command: /code-qa
Expected flow:
  1. STEP 0 tries to read cache
  2. File not found
  3. Info: "No workspace cache. Proceeding without."
  4. workspace_cache = null
  5. Proceed without cache
```

**Status**: ✅ Handled

### 3.5 Scenario: No Cache with --with-analysis

```
User state: Never ran /analyze
Command: /code-qa --with-analysis
Expected flow:
  1. STEP 0 detects no cache
  2. auto_analyze = true
  3. Call workspace-analyzer
  4. workspace_cache = new data
  5. Proceed with cache
```

**Status**: ✅ Handled

### 3.6 Scenario: Skip Cache Explicitly

```
User state: Has valid cache
Command: /code-qa --skip-cache
Expected flow:
  1. use_cache = false
  2. Skip STEP 0 cache check entirely
  3. workspace_cache = null
  4. Proceed without cache
```

**Status**: ✅ Handled

---

## 4. Build/Test Scenarios

### 4.1 Scenario: Build Success

```
Expected flow:
  1. build-tester runs build command
  2. BUILD_RESULT: SUCCESS
  3. Proceed to STEP 8
```

**Status**: ✅ Handled

### 4.2 Scenario: Build Failure (Code Issue)

```
Expected flow:
  1. build-tester runs build
  2. Compilation error
  3. BUILD_RESULT: FAIL
  4. Regress to STEP 5 (code-fixer)
  5. Max 3 retries
```

**Status**: ✅ Handled

### 4.3 Scenario: Build Failure (Dependency Missing)

```
User state: node_modules deleted or deps not installed
Expected flow:
  1. build-tester runs build
  2. "Cannot find module" error detected
  3. BUILD_RESULT: FAIL_DEPS
  4. Show dependency install guidance
  5. User retries after install or skips
```

**Status**: ✅ Handled

### 4.4 Scenario: Test Failure

```
Expected flow:
  1. function-tester runs tests
  2. Some tests fail
  3. TEST_RESULT: FAIL
  4. Regress to STEP 5 (code-fixer)
  5. Max 3 retries
```

**Status**: ✅ Handled

### 4.5 Scenario: No Tests Found

```
User state: Project has no test files
Expected flow:
  1. function-tester searches for tests
  2. No test files found
  3. TEST_RESULT: NO_TESTS
  4. Proceed to STEP 9 (skip tests)
```

**Status**: ✅ Handled

### 4.6 Scenario: User Skips Tests

```
Expected flow:
  1. function-tester shows detected tests
  2. User inputs "skip/n"
  3. TEST_RESULT: SKIPPED
  4. Proceed to STEP 9
```

**Status**: ✅ Handled

---

## 5. Git Commit/Push Scenarios

### 5.1 Scenario: Normal Commit and Push

```
Expected flow:
  1. git-committer shows commit info
  2. User confirms
  3. COMMIT_RESULT: SUCCESS
  4. git-pusher pushes
  5. PUSH_RESULT: SUCCESS
```

**Status**: ✅ Handled

### 5.2 Scenario: User Cancels Commit

```
Expected flow:
  1. git-committer shows commit info
  2. User inputs "cancel/n"
  3. COMMIT_RESULT: SKIPPED
  4. Proceed to STEP 10 (summary)
```

**Status**: ✅ Handled

### 5.3 Scenario: Push Auth Error (SSH)

```
User state: SSH key not configured
Expected flow:
  1. git-pusher attempts push
  2. SSH auth error
  3. PUSH_RESULT: AUTH_ERROR
  4. Guide SSH key setup
  5. User retries or skips
```

**Status**: ✅ Handled

### 5.4 Scenario: Push Auth Error (HTTPS)

```
User state: Token expired or wrong credentials
Expected flow:
  1. git-pusher attempts push
  2. HTTPS auth error
  3. PUSH_RESULT: AUTH_ERROR
  4. Guide credential refresh
  5. User retries or skips
```

**Status**: ✅ Handled

### 5.5 Scenario: Detached HEAD (Skip Commit/Push)

```
User state: Detached HEAD, chose "qa-only"
Expected flow:
  1. skip_commit_push = true
  2. STEP 9 skipped with message
  3. STEP 11 skipped with message
  4. Workflow ends after summary
```

**Status**: ✅ Handled

### 5.6 Scenario: Non-Git Mode (--files)

```
Command: /code-qa --files src/
Expected flow:
  1. use_git_mode = false
  2. STEP 9 skipped (no Git)
  3. STEP 11 skipped (no Git)
  4. Workflow ends after summary
```

**Status**: ✅ Handled

---

## 6. File Input Mode Scenarios

### 6.1 Scenario: Single File

```
Command: /code-qa --files src/main.py
Expected flow:
  1. use_git_mode = false
  2. file-input parses path
  3. FILE_INPUT_RESULT: SUCCESS
  4. Proceed with single file
```

**Status**: ✅ Handled

### 6.2 Scenario: Directory

```
Command: /code-qa --files src/
Expected flow:
  1. file-input finds all code files in src/
  2. FILE_INPUT_RESULT: SUCCESS
  3. Proceed with all found files
```

**Status**: ✅ Handled

### 6.3 Scenario: Glob Pattern

```
Command: /code-qa --files "src/**/*.py"
Expected flow:
  1. file-input expands glob
  2. FILE_INPUT_RESULT: SUCCESS
  3. Proceed with matched files
```

**Status**: ✅ Handled

### 6.4 Scenario: Invalid Path

```
Command: /code-qa --files nonexistent/
Expected flow:
  1. file-input cannot find path
  2. FILE_INPUT_RESULT: INVALID_PATH
  3. Workflow ends with error
```

**Status**: ✅ Handled

### 6.5 Scenario: No Code Files Found

```
Command: /code-qa --files images/
Expected flow:
  1. file-input finds only .png, .jpg files
  2. Binary files filtered
  3. FILE_INPUT_RESULT: NO_FILES
  4. Workflow ends with message
```

**Status**: ✅ Handled

---

## 7. Quality/Regression Scenarios

### 7.1 Scenario: Quality Pass First Try

```
Expected flow:
  1. quality-checker returns QUALITY_SCORE: 85/100
  2. score >= 70
  3. Proceed to STEP 7
```

**Status**: ✅ Handled

### 7.2 Scenario: Quality Fail → Fix → Pass

```
Expected flow:
  1. quality-checker: QUALITY_SCORE: 55/100
  2. Regress to STEP 5 (code-fixer)
  3. retry_count = 1
  4. code-fixer fixes issues
  5. quality-checker: QUALITY_SCORE: 78/100
  6. Pass, proceed to STEP 7
```

**Status**: ✅ Handled

### 7.3 Scenario: Max Retries Exceeded

```
Expected flow:
  1. quality-checker fails 3 times
  2. retry_count = 3
  3. Still failing
  4. Workflow stops with "Max retry exceeded"
```

**Status**: ✅ Handled

---

## 8. Workspace Analysis Scenarios

### 8.1 Scenario: Normal Project

```
Command: /analyze
Expected flow:
  1. workspace-analyzer scans project
  2. WORKSPACE_ANALYSIS_RESULT: COMPLETE
  3. Cache saved
```

**Status**: ✅ Handled

### 8.2 Scenario: Large Project (10,000+ files)

```
Expected flow:
  1. workspace-analyzer hits file limit
  2. Truncated analysis
  3. WORKSPACE_ANALYSIS_RESULT: TIMEOUT
  4. Partial cache saved with truncated: true
```

**Status**: ✅ Handled

### 8.3 Scenario: Empty Project

```
Expected flow:
  1. workspace-analyzer finds no source files
  2. WORKSPACE_ANALYSIS_RESULT: EMPTY
  3. workspace_cache = null
```

**Status**: ✅ Handled

### 8.4 Scenario: Unknown Project Type

```
Expected flow:
  1. workspace-analyzer finds no manifest files
  2. project.type = "unknown"
  3. Languages inferred from extensions
  4. WORKSPACE_ANALYSIS_RESULT: COMPLETE
```

**Status**: ✅ Handled

---

## 9. Identified Issues

### 9.1 Issue: env-setup Prompt in Orchestrator Not Updated

**Location**: code-qa.md STEP 1

**Current**:
```
- prompt: "Check Shell, environment, Python/CUDA versions. Must ask user to select Shell type (zsh/bash/sh) and virtual environment type (conda/uv/venv)."
```

**Problem**: Prompt still mentions "Must ask user to select Shell type" but streamlined env-setup auto-detects shell.

**Fix Required**: Update prompt to match new streamlined behavior.

### 9.2 Issue: Env Table in Orchestrator Not Updated

**Location**: code-qa.md "Agents Requiring User Input" table

**Current**:
```
| env-setup | Shell selection (1-3), Environment type (1-4) | `WAITING_INPUT` |
```

**Problem**: Table still shows old 4-step interaction model.

**Fix Required**: Update to reflect 1-2 step model.

---

## 10. Summary

### Scenarios Verified: 40+
### Issues Found: 2 (minor documentation mismatches)

All major workflow scenarios are properly handled:
- ✅ Environment setup (all 5 scenarios)
- ✅ Git input (all 9 scenarios)
- ✅ Cache handling (all 6 scenarios)
- ✅ Build/Test (all 6 scenarios)
- ✅ Git commit/push (all 6 scenarios)
- ✅ File input mode (all 5 scenarios)
- ✅ Quality/Regression (all 3 scenarios)
- ✅ Workspace analysis (all 4 scenarios)

---

## Change History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-02-04 | Initial scenario analysis |
