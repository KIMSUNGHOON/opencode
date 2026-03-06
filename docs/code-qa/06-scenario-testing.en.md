# Code QA v4 Scenario Testing & Case Review

This document provides a comprehensive review of workflow scenarios and edge case handling in the Code QA v4 system.

---

## Part 1: Workflow Scenario Matrix

### 1.1 Cache State x Option Combinations

| Scenario | Cache State | Option | Expected Behavior | Verified |
|----------|------------|--------|-------------------|----------|
| S1 | Valid cache exists | (default) | Use cache | ✅ |
| S2 | Valid cache exists | --skip-cache | Ignore cache | ✅ |
| S3 | Valid cache exists | --with-analysis | Use cache (no re-analysis) | ✅ |
| S4 | Stale cache exists | (default) | Warning + proceed without cache | ✅ |
| S5 | Stale cache exists | --with-analysis | Run re-analysis | ✅ |
| S6 | No cache | (default) | Warning + proceed without cache | ✅ |
| S7 | No cache | --with-analysis | Run analysis | ✅ |
| S8 | No cache | --skip-cache | Ignore cache (no analysis) | ✅ |

### 1.2 Input Mode x Cache Combinations

| Scenario | Input Mode | Cache State | Expected Behavior | Verified |
|----------|-----------|-------------|-------------------|----------|
| I1 | Git (--working) | Cache exists | Cache context + git diff | ✅ |
| I2 | Git (--working) | No cache | git diff only | ✅ |
| I3 | Git (--staged) | Cache exists | Cache context + staged | ✅ |
| I4 | Git (--last) | Cache exists | Cache context + last commit | ✅ |
| I5 | Git (--branch) | Cache exists | Cache context + branch diff | ✅ |
| I6 | --files | Cache exists | Cache context + specified files | ✅ |
| I7 | --files | No cache | Specified files only | ✅ |

---

### 1.3 Edge Case Review

#### File-Related Edge Cases

| Case | Current Handling | Issue | Improvement Needed | Status |
|------|-----------------|-------|-------------------|--------|
| 0 changed files | ✅ Implemented | Empty git diff | NO | ✅ RESOLVED |
| 1000+ changed files | ✅ Implemented | Too many files | NO | ✅ RESOLVED |
| Only binary files changed | ✅ Implemented | No code to analyze | NO | ✅ RESOLVED |
| Deleted files | ✅ Implemented | Cannot read | NO | ✅ RESOLVED |
| Renamed files | ✅ Implemented | Path tracking | NO | ✅ RESOLVED |

#### Git-Related Edge Cases

| Case | Current Handling | Issue | Improvement Needed | Status |
|------|-----------------|-------|-------------------|--------|
| Not a Git repo | ✅ Implemented | NO_GIT_REPO → user choice | NO | ✅ RESOLVED |
| Detached HEAD | ✅ Implemented | No branch info | NO | ✅ RESOLVED |
| Merge conflict state | ✅ Implemented | Cannot commit | NO | ✅ RESOLVED |
| Rebase in progress | ✅ Implemented | Cannot commit | NO | ✅ RESOLVED |
| Dirty working tree | ⚠️ Partial | Conflict with --last | LOW | - |
| Shallow clone | ⚠️ Partial | Insufficient history | LOW | - |

#### Environment-Related Edge Cases

| Case | Current Handling | Issue | Improvement Needed | Status |
|------|-----------------|-------|-------------------|--------|
| Docker not available | ✅ Implemented | --no-sandbox fallback | NO | ✅ RESOLVED |
| Python/Node not installed | ⚠️ Partial | Build/test fails | LOW | - |
| Dependencies not installed | ✅ Implemented | Build fails | NO | ✅ RESOLVED |
| No network | ⚠️ Partial | Push fails | LOW | - |

---

### 1.4 Issues Found and Resolved

#### CRITICAL: No Changed Files Handling (RESOLVED)

**Issue**: Workflow behavior was undefined when git diff result is empty

**Solution Implemented**:
- git-input returns `GIT_INPUT_RESULT: NO_CHANGES` token
- code-qa orchestrator gracefully exits with success message

#### CRITICAL: Deleted Files Handling (RESOLVED)

**Issue**: code-reviewer would try to Read deleted files

**Solution Implemented**:
- git-input uses `git diff --name-status` to track file status (A/M/D/R)
- Deleted files (D) are excluded from analysis
- Returns `DELETED_FILES` section in result
- Returns `GIT_INPUT_RESULT: DELETED_ONLY` if all files are deleted

#### HIGH: Large File Count Handling (RESOLVED)

**Issue**: No handling for hundreds/thousands of changed files

**Solution Implemented**:
- Warning when >100 files changed
- Binary file auto-filtering
- Recommendation to filter to source files only

#### MEDIUM: Detached HEAD Handling (RESOLVED)

**Issue**: Common in CI/CD environments, no handling defined

**Solution Implemented**:
- git-input detects detached HEAD state
- User options: create branch, continue QA-only, or exit
- `skip_commit_push` flag skips STEP 9 and 11

#### MEDIUM: Dependency Install Guidance (RESOLVED)

**Issue**: Build fails when dependencies not installed

**Solution Implemented**:
- build-tester detects dependency errors by error message patterns
- Returns `BUILD_RESULT: FAIL_DEPS` token
- Provides language-specific install suggestions
- User can retry or skip build

#### MEDIUM: Merge Conflict Handling (RESOLVED)

**Issue**: Cannot commit when merge conflicts exist

**Solution Implemented**:
- git-input detects merge conflict state with `git ls-files -u`
- Returns `GIT_INPUT_RESULT: MERGE_CONFLICT` token
- Provides resolution guidance

#### MEDIUM: Rebase In Progress Handling (RESOLVED)

**Issue**: Cannot commit when rebase is in progress

**Solution Implemented**:
- git-input detects rebase state by checking `.git/rebase-merge` or `.git/rebase-apply`
- Returns `GIT_INPUT_RESULT: REBASE_IN_PROGRESS` token
- Provides resolution guidance

---

### 1.5 Implemented Modifications

#### git-input Agent Modifications

```
Extended result tokens:
- GIT_INPUT_RESULT: SUCCESS (files exist)
- GIT_INPUT_RESULT: NO_CHANGES (no changes)
- GIT_INPUT_RESULT: DELETED_ONLY (only deleted files)
- GIT_INPUT_RESULT: NO_CODE_FILES (only config/docs)
- GIT_INPUT_RESULT: NO_GIT_REPO (not a Git repo)
- GIT_INPUT_RESULT: DETACHED_HEAD (detached HEAD state)
- GIT_INPUT_RESULT: MERGE_CONFLICT (merge conflict)
- GIT_INPUT_RESULT: REBASE_IN_PROGRESS (rebase in progress)
- GIT_INPUT_RESULT: ABORTED (user cancelled)

Extended FILE_LIST format:
FILE_LIST: file1.py, file2.py, ...
DELETED_FILES: deleted1.py, deleted2.py, ...
RENAMED_FILES: old→new, ...
```

#### code-qa Orchestrator Modifications

```
STEP 2 result handling:
- NO_CHANGES → End workflow (success)
- DELETED_ONLY → Skip to STEP 9
- NO_CODE_FILES → End workflow (success)
- DETACHED_HEAD → User choice, set skip_commit_push flag
- MERGE_CONFLICT → End workflow (blocked)
- REBASE_IN_PROGRESS → End workflow (blocked)

STEP 2.5 file validation:
- Binary file auto-filtering
- Large file count warning (>100)

STEP 7 build failure handling:
- FAIL_DEPS → Show dependency install guidance
```

#### build-tester Agent Modifications

```
Extended build failure tokens:
- BUILD_RESULT: FAIL (general failure)
- BUILD_RESULT: FAIL_DEPS (dependency issue)

Dependency error detection patterns:
- Python: ModuleNotFoundError, ImportError, No module named
- Node.js: Cannot find module, MODULE_NOT_FOUND
- Go: cannot find package
- Rust: can't find crate
- Java: package does not exist
```

---

## Part 2: Detailed Scenario Analysis

### 2.1 Environment Setup Scenarios

#### Scenario: Active Conda Environment

```
User state: Already in "ml-dev" conda environment
Expected flow:
  1. env-setup detects $CONDA_DEFAULT_ENV = "ml-dev"
  2. Shows: "Use current environment 'ml-dev'? [Y/n/list]"
  3. User presses Enter or Y
  4. SUCCESS (1 interaction)
```

**Status**: ✅ Handled by streamlined env-setup

#### Scenario: Active venv Environment

```
User state: Already activated .venv
Expected flow:
  1. env-setup detects $VIRTUAL_ENV = "/path/to/.venv"
  2. Shows: "Use current environment '.venv'? [Y/n/list]"
  3. User presses Enter
  4. SUCCESS (1 interaction)
```

**Status**: ✅ Handled by streamlined env-setup

#### Scenario: No Active Environment

```
User state: No conda/venv activated
Expected flow:
  1. env-setup detects ACTIVE_TYPE: none
  2. Shows conda env list + options
  3. User selects environment
  4. SUCCESS (2 interactions)
```

**Status**: ✅ Handled by streamlined env-setup

#### Scenario: User Wants Different Environment

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

#### Scenario: auto_confirm Config

```
User state: .opencode/env-config.yaml has auto_confirm: true
Expected flow:
  1. env-setup reads config
  2. Verifies environment matches
  3. SUCCESS (0 interactions)
```

**Status**: ✅ Handled by streamlined env-setup

---

### 2.2 Git Input Scenarios

#### Scenario: Normal Working Directory Changes

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

#### Scenario: No Changed Files

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

#### Scenario: Only Deleted Files

```
User state: git rm file.py
Command: /code-qa --staged
Expected flow:
  1. git-input detects D status files
  2. GIT_INPUT_RESULT: DELETED_ONLY
  3. Skip to STEP 9 (Git Commit)
```

**Status**: ✅ Handled

#### Scenario: Detached HEAD

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

#### Scenario: Merge Conflict

```
User state: git merge feature (conflicts exist)
Command: /code-qa
Expected flow:
  1. git-input detects merge conflict via git ls-files -u
  2. GIT_INPUT_RESULT: MERGE_CONFLICT
  3. Workflow blocked, user guided to resolve
```

**Status**: ✅ Handled

#### Scenario: Rebase in Progress

```
User state: git rebase main (stopped mid-rebase)
Command: /code-qa
Expected flow:
  1. git-input detects .git/rebase-merge or .git/rebase-apply
  2. GIT_INPUT_RESULT: REBASE_IN_PROGRESS
  3. Workflow blocked, user guided to continue/abort
```

**Status**: ✅ Handled

#### Scenario: Not a Git Repository

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

#### Scenario: Large File Count (100+ files)

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

#### Scenario: Renamed Files

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

### 2.3 Cache Scenarios

#### Scenario: Valid Cache Exists

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

#### Scenario: Stale Cache (>24h)

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

#### Scenario: Stale Cache with --with-analysis

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

#### Scenario: No Cache

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

#### Scenario: No Cache with --with-analysis

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

#### Scenario: Skip Cache Explicitly

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

### 2.4 Build/Test Scenarios

#### Scenario: Build Success

```
Expected flow:
  1. build-tester runs build command
  2. BUILD_RESULT: SUCCESS
  3. Proceed to STEP 8
```

**Status**: ✅ Handled

#### Scenario: Build Failure (Code Issue)

```
Expected flow:
  1. build-tester runs build
  2. Compilation error
  3. BUILD_RESULT: FAIL
  4. Regress to STEP 5 (code-fixer)
  5. Max 3 retries
```

**Status**: ✅ Handled

#### Scenario: Build Failure (Dependency Missing)

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

#### Scenario: Test Failure

```
Expected flow:
  1. function-tester runs tests
  2. Some tests fail
  3. TEST_RESULT: FAIL
  4. Regress to STEP 5 (code-fixer)
  5. Max 3 retries
```

**Status**: ✅ Handled

#### Scenario: No Tests Found

```
User state: Project has no test files
Expected flow:
  1. function-tester searches for tests
  2. No test files found
  3. TEST_RESULT: NO_TESTS
  4. Proceed to STEP 9 (skip tests)
```

**Status**: ✅ Handled

#### Scenario: User Skips Tests

```
Expected flow:
  1. function-tester shows detected tests
  2. User inputs "skip/n"
  3. TEST_RESULT: SKIPPED
  4. Proceed to STEP 9
```

**Status**: ✅ Handled

---

### 2.5 Git Commit/Push Scenarios

#### Scenario: Normal Commit and Push

```
Expected flow:
  1. git-committer shows commit info
  2. User confirms
  3. COMMIT_RESULT: SUCCESS
  4. git-pusher pushes
  5. PUSH_RESULT: SUCCESS
```

**Status**: ✅ Handled

#### Scenario: User Cancels Commit

```
Expected flow:
  1. git-committer shows commit info
  2. User inputs "cancel/n"
  3. COMMIT_RESULT: SKIPPED
  4. Proceed to STEP 10 (summary)
```

**Status**: ✅ Handled

#### Scenario: Push Auth Error (SSH)

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

#### Scenario: Push Auth Error (HTTPS)

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

#### Scenario: Detached HEAD (Skip Commit/Push)

```
User state: Detached HEAD, chose "qa-only"
Expected flow:
  1. skip_commit_push = true
  2. STEP 9 skipped with message
  3. STEP 11 skipped with message
  4. Workflow ends after summary
```

**Status**: ✅ Handled

#### Scenario: Non-Git Mode (--files)

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

### 2.6 File Input Mode Scenarios

#### Scenario: Single File

```
Command: /code-qa --files src/main.py
Expected flow:
  1. use_git_mode = false
  2. file-input parses path
  3. FILE_INPUT_RESULT: SUCCESS
  4. Proceed with single file
```

**Status**: ✅ Handled

#### Scenario: Directory

```
Command: /code-qa --files src/
Expected flow:
  1. file-input finds all code files in src/
  2. FILE_INPUT_RESULT: SUCCESS
  3. Proceed with all found files
```

**Status**: ✅ Handled

#### Scenario: Glob Pattern

```
Command: /code-qa --files "src/**/*.py"
Expected flow:
  1. file-input expands glob
  2. FILE_INPUT_RESULT: SUCCESS
  3. Proceed with matched files
```

**Status**: ✅ Handled

#### Scenario: Invalid Path

```
Command: /code-qa --files nonexistent/
Expected flow:
  1. file-input cannot find path
  2. FILE_INPUT_RESULT: INVALID_PATH
  3. Workflow ends with error
```

**Status**: ✅ Handled

#### Scenario: No Code Files Found

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

### 2.7 Quality/Regression Scenarios

#### Scenario: Quality Pass First Try

```
Expected flow:
  1. quality-checker returns QUALITY_SCORE: 85/100
  2. score >= 70
  3. Proceed to STEP 7
```

**Status**: ✅ Handled

#### Scenario: Quality Fail → Fix → Pass

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

#### Scenario: Max Retries Exceeded

```
Expected flow:
  1. quality-checker fails 3 times
  2. retry_count = 3
  3. Still failing
  4. Workflow stops with "Max retry exceeded"
```

**Status**: ✅ Handled

---

### 2.8 Workspace Analysis Scenarios

#### Scenario: Normal Project

```
Command: /analyze
Expected flow:
  1. workspace-analyzer scans project
  2. WORKSPACE_ANALYSIS_RESULT: COMPLETE
  3. Cache saved
```

**Status**: ✅ Handled

#### Scenario: Large Project (10,000+ files)

```
Expected flow:
  1. workspace-analyzer hits file limit
  2. Truncated analysis
  3. WORKSPACE_ANALYSIS_RESULT: TIMEOUT
  4. Partial cache saved with truncated: true
```

**Status**: ✅ Handled

#### Scenario: Empty Project

```
Expected flow:
  1. workspace-analyzer finds no source files
  2. WORKSPACE_ANALYSIS_RESULT: EMPTY
  3. workspace_cache = null
```

**Status**: ✅ Handled

#### Scenario: Unknown Project Type

```
Expected flow:
  1. workspace-analyzer finds no manifest files
  2. project.type = "unknown"
  3. Languages inferred from extensions
  4. WORKSPACE_ANALYSIS_RESULT: COMPLETE
```

**Status**: ✅ Handled

---

## 3. Test Scenarios

### 3.1 Happy Path Tests

```bash
# T1: Default Git mode
/code-qa

# T2: Staged changes only
git add src/app.py
/code-qa --staged

# T3: Direct file specification
/code-qa --files src/

# T4: With cache
/analyze
/code-qa

# T5: Cache + analysis at once
/code-qa --with-analysis
```

### 3.2 Edge Case Tests

```bash
# T6: No changes
git status  # clean
/code-qa    # → "No changed files" message expected

# T7: Only deleted files
git rm old_file.py
/code-qa --staged  # → Deleted file handling confirmed

# T8: Large file count
# After changing 100+ files
/code-qa  # → Warning and filtering confirmed

# T9: Non-Git directory
cd /tmp/non-git-project
/code-qa  # → NO_GIT_REPO handling confirmed

# T10: Empty project
/analyze  # → EMPTY result confirmed

# T11: Detached HEAD
git checkout HEAD~1
/code-qa  # → DETACHED_HEAD handling confirmed

# T12: Merge conflict
git merge feature --no-commit  # create conflict
/code-qa  # → MERGE_CONFLICT handling confirmed
```

### 3.3 Error Scenario Tests

```bash
# T13: Dependencies not installed
rm -rf node_modules
/code-qa  # → Build failure + guidance message

# T14: Docker not available
# After stopping Docker
/code-qa  # → --no-sandbox fallback guidance

# T15: No network
# In offline state
/code-qa  # → Appropriate error handling at Push step
```

---

## 4. Summary

### Scenarios Verified: 40+

All major workflow scenarios are properly handled:
- ✅ Environment setup (all 5 scenarios)
- ✅ Git input (all 9 scenarios)
- ✅ Cache handling (all 6 scenarios)
- ✅ Build/Test (all 6 scenarios)
- ✅ Git commit/push (all 6 scenarios)
- ✅ File input mode (all 5 scenarios)
- ✅ Quality/Regression (all 3 scenarios)
- ✅ Workspace analysis (all 4 scenarios)

### Resolved Critical Issues

1. **No changed files handling** - Graceful workflow exit
2. **Deleted file handling** - Proper exclusion from analysis

### Resolved High Priority Issues

3. **Large file count handling** - Warning and filtering
4. **File status differentiation** - A/M/D/R status tracking

### Resolved Medium Priority Issues

5. **Detached HEAD handling** - User options provided
6. **Dependency install guidance** - FAIL_DEPS token and suggestions
7. **Merge conflict handling** - Detection and blocking
8. **Rebase in progress handling** - Detection and blocking

### Remaining Low Priority Issues

- Dirty working tree handling (partial)
- Shallow clone handling (partial)
- Python/Node not installed (partial)
- No network (partial)

---

## Change History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2024-01-15 | Initial case review document |
| 2.0 | 2025-02-04 | All critical/high/medium issues resolved, translated to English |
| 3.0 | 2025-02-04 | Merged scenario analysis with case review into unified document |

---

## Related Documents

- [Architecture Diagram](./02-architecture.en.md)
- [Quick Start](./01-quick-start.en.md)
- [Environment Setup](./03-environment-setup.en.md)
- [Implementation Summary](./05-implementation-summary.en.md)
