# Code QA v4 Implementation Summary

This document summarizes all implementation work completed for the Code QA v4 workflow system.

---

## 1. Overview

### 1.1 Project Goals

1. **Edge Case Handling**: Implement robust handling for all identified edge cases in the workflow
2. **English Translation**: Translate all orchestrator and sub-agent prompts to English
3. **Qwen3-Next Compatibility**: Ensure prompts are optimized for Qwen3-Next series models
4. **Local Infrastructure**: Design for token-cost-agnostic local LLM serving

### 1.2 Workflow Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Code QA v4 Workflow                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  /code-qa command                                                       │
│       │                                                                 │
│       ▼                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                 │
│  │  STEP 0-2   │───▶│  STEP 3-6   │───▶│  STEP 7-8   │                 │
│  │  Env/Input  │    │ Review/Fix  │    │ Build/Test  │                 │
│  └─────────────┘    └─────────────┘    └─────────────┘                 │
│                                              │                          │
│       ┌──────────────────────────────────────┘                          │
│       ▼                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                 │
│  │  STEP 9     │───▶│  STEP 10    │───▶│  STEP 11    │                 │
│  │ Git Commit  │    │   Summary   │    │  Git Push   │                 │
│  └─────────────┘    └─────────────┘    └─────────────┘                 │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Implemented Edge Cases

### 2.1 Critical Priority (Resolved)

| Issue | Description | Solution | Result Token |
|-------|-------------|----------|--------------|
| No changed files | Empty git diff | Graceful workflow exit | `GIT_INPUT_RESULT: NO_CHANGES` |
| Deleted files | Cannot read deleted files | Exclude from analysis, track separately | `DELETED_FILES: file1, file2` |

### 2.2 High Priority (Resolved)

| Issue | Description | Solution | Result Token |
|-------|-------------|----------|--------------|
| Large file count | 100+ changed files | Warning + binary filtering | Warning message |
| File status tracking | A/M/D/R differentiation | `git diff --name-status` | `FILE_LIST` with status |

### 2.3 Medium Priority (Resolved)

| Issue | Description | Solution | Result Token |
|-------|-------------|----------|--------------|
| Detached HEAD | No branch for commit | User choice: create branch / QA-only / exit | `GIT_INPUT_RESULT: DETACHED_HEAD` |
| Merge conflict | Cannot commit | Block workflow, provide guidance | `GIT_INPUT_RESULT: MERGE_CONFLICT` |
| Rebase in progress | Cannot commit | Block workflow, provide guidance | `GIT_INPUT_RESULT: REBASE_IN_PROGRESS` |
| Dependency errors | Build fails due to missing deps | Detect pattern, suggest install command | `BUILD_RESULT: FAIL_DEPS` |

### 2.4 Low Priority (Deferred)

| Issue | Reason for Deferral |
|-------|---------------------|
| Dirty working tree | Low frequency, existing handling sufficient |
| Shallow clone | Edge case, can use `--unshallow` if needed |
| Runtime not installed | Out of scope (system setup issue) |
| No network | Low cost-benefit ratio |

---

## 3. Agent Implementation Details

### 3.1 Agent List and Status

| Agent | File | Language | Model | Purpose |
|-------|------|----------|-------|---------|
| code-qa | `.opencode/mode/code-qa.md` | English | qwen-coder/Qwen3-Coder-Next-FP8 | Orchestrator (Coder for tool call stability) |
| code-reviewer | `.opencode/agent/code-reviewer.md` | English | qwen/Qwen3-Next-80B-A3B-Thinking-FP8 | Code review (CoT) |
| quality-checker | `.opencode/agent/quality-checker.md` | English | qwen/Qwen3-Next-80B-A3B-Thinking-FP8 | Quality verification (CoT) |
| summary-reporter | `.opencode/agent/summary-reporter.md` | English | qwen/Qwen3-Next-80B-A3B-Thinking-FP8 | Final summary (CoT) |
| env-setup | `.opencode/agent/env-setup.md` | English | qwen-coder/Qwen3-Coder-Next-FP8 | Environment setup |
| git-input | `.opencode/agent/git-input.md` | English | qwen-coder/Qwen3-Coder-Next-FP8 | Git diff collection |
| file-input | `.opencode/agent/file-input.md` | English | qwen-coder/Qwen3-Coder-Next-FP8 | Direct file input |
| workspace-analyzer | `.opencode/agent/workspace-analyzer.md` | English | qwen-coder/Qwen3-Coder-Next-FP8 | Workspace analysis |
| pre-checker | `.opencode/agent/pre-checker.md` | English | qwen-coder/Qwen3-Coder-Next-FP8 | Pre-review checks |
| code-fixer | `.opencode/agent/code-fixer.md` | English | qwen-coder/Qwen3-Coder-Next-FP8 | Auto-fix issues (SWE-Bench) |
| build-tester | `.opencode/agent/build-tester.md` | English | qwen-coder/Qwen3-Coder-Next-FP8 | Build test |
| function-tester | `.opencode/agent/function-tester.md` | English | qwen-coder/Qwen3-Coder-Next-FP8 | Function testing |
| git-committer | `.opencode/agent/git-committer.md` | English | qwen-coder/Qwen3-Coder-Next-FP8 | Git commit |
| git-pusher | `.opencode/agent/git-pusher.md` | English | qwen-coder/Qwen3-Coder-Next-FP8 | Git push |

### 3.2 Result Token Patterns

All agents use consistent result token patterns for deterministic parsing:

```
# Environment Setup Results
ENV_SETUP_RESULT: SUCCESS
ENV_SETUP_RESULT: FAIL
ENV_SETUP_RESULT: WAITING_INPUT

# Workspace Analysis Results
WORKSPACE_ANALYSIS_RESULT: COMPLETE
WORKSPACE_ANALYSIS_RESULT: FAILED
WORKSPACE_ANALYSIS_RESULT: TIMEOUT
WORKSPACE_ANALYSIS_RESULT: EMPTY

# Git Input Results
GIT_INPUT_RESULT: SUCCESS
GIT_INPUT_RESULT: NO_CHANGES
GIT_INPUT_RESULT: DELETED_ONLY
GIT_INPUT_RESULT: NO_CODE_FILES
GIT_INPUT_RESULT: NO_GIT_REPO
GIT_INPUT_RESULT: DETACHED_HEAD
GIT_INPUT_RESULT: MERGE_CONFLICT
GIT_INPUT_RESULT: REBASE_IN_PROGRESS
GIT_INPUT_RESULT: ABORTED

# Pre-Check Results
PRE_CHECK_RESULT: SUCCESS
PRE_CHECK_RESULT: PARTIAL

# Code Review Results
REVIEW_RESULT: ISSUES_FOUND
REVIEW_RESULT: NO_ISSUES

# Fix Results
FIX_RESULT: SUCCESS
FIX_RESULT: PARTIAL

# Quality Check Results
QUALITY_SCORE: XX/100

# Build Results
BUILD_RESULT: SUCCESS
BUILD_RESULT: FAIL
BUILD_RESULT: FAIL_DEPS
BUILD_RESULT: SKIP

# Test Results
TEST_RESULT: SUCCESS
TEST_RESULT: FAIL
TEST_RESULT: SKIPPED
TEST_RESULT: NO_TESTS

# Commit Results
COMMIT_RESULT: SUCCESS
COMMIT_RESULT: NO_CHANGES
COMMIT_RESULT: SKIPPED

# Push Results
PUSH_RESULT: SUCCESS
PUSH_RESULT: SKIPPED
PUSH_RESULT: FAIL
```

---

## 4. Qwen3-Next Compatibility

### 4.1 Design Patterns for LLM Compatibility

| Pattern | Implementation | Benefit |
|---------|---------------|---------|
| Visual structure | Box-drawing chars (┌─┬─┐) | Clear organization |
| Result tokens | `CATEGORY: VALUE` format | Deterministic parsing |
| Step numbering | STEP 1, STEP 2, etc. | Sequential execution |
| Pseudo-code flow | IF/THEN/ELSE conditions | Explicit branching |
| Forbidden markers | ❌ with visual emphasis | Critical rule highlighting |
| Required markers | ✅ with visual emphasis | Mandatory output marking |
| No-placeholder rule | Global enforcement | Hallucination prevention |

### 4.2 Model Considerations

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Dual Model Characteristics                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Thinking Model (Qwen3-Next-80B-A3B-Thinking-FP8, SGLang port 8000):  │
│    - Self-reasoning capability (CoT)                                    │
│    - 4 agents: Orchestrator, code-reviewer, quality-checker,           │
│      summary-reporter                                                   │
│                                                                         │
│  Coder Model (Qwen3-Coder-Next-FP8, vLLM port 8001):                  │
│    - Non-thinking, fast code generation (SWE-Bench 70.6%)              │
│    - 10 agents: env-setup, git-input, file-input, workspace-analyzer,  │
│      pre-checker, code-fixer, build-tester, function-tester,           │
│      git-committer, git-pusher                                         │
│                                                                         │
│  Local Inference:                                                       │
│    - Token cost: Not relevant (local serving)                          │
│    - Latency: Proportional to context length                           │
│    - Quality/Consistency: Primary concern                               │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 4.3 Optimization Plan

1. **Dual Model Strategy (Implemented)**
   - Thinking model: Complex reasoning tasks (code review, quality check)
   - Coder model: Code generation/modification tasks (SWE-Bench optimized)

2. **Agent Rebalancing**
   - Test each agent with both models
   - Measure accuracy and latency
   - Assign optimal model per agent

3. **Workflow Optimization**
   - Parallel execution where possible
   - Caching for repeated operations

---

## 5. Workflow Scenarios

### 5.1 Scenario Matrix: Cache State × Options

| Scenario | Cache State | Option | Expected Behavior |
|----------|------------|--------|-------------------|
| S1 | Valid cache | (default) | Use cache |
| S2 | Valid cache | --skip-cache | Ignore cache |
| S3 | Valid cache | --with-analysis | Use cache (no re-analysis) |
| S4 | Stale cache | (default) | Warning + proceed without cache |
| S5 | Stale cache | --with-analysis | Run re-analysis |
| S6 | No cache | (default) | Warning + proceed without cache |
| S7 | No cache | --with-analysis | Run analysis |
| S8 | No cache | --skip-cache | Ignore cache (no analysis) |

### 5.2 Scenario Matrix: Input Mode × Cache

| Scenario | Input Mode | Cache State | Expected Behavior |
|----------|-----------|-------------|-------------------|
| I1 | --working | Cache exists | Cache context + git diff |
| I2 | --working | No cache | git diff only |
| I3 | --staged | Cache exists | Cache context + staged |
| I4 | --last | Cache exists | Cache context + last commit |
| I5 | --branch | Cache exists | Cache context + branch diff |
| I6 | --files | Cache exists | Cache context + specified files |
| I7 | --files | No cache | Specified files only |

---

## 6. File Changes Summary

### 6.1 Modified Files

| File | Changes |
|------|---------|
| `.opencode/command/code-qa.md` | Thin wrapper (refs mode/code-qa.md as single source of truth) |
| `.opencode/agent/git-input.md` | English translation, new result tokens |
| `.opencode/agent/build-tester.md` | English translation, FAIL_DEPS handling |
| `.opencode/agent/workspace-analyzer.md` | Full English translation |
| `docs/guides/16-workflow-case-review.md` | English rewrite, all issues marked resolved |

### 6.2 Commits

| Commit | Message |
|--------|---------|
| `bdfd9fca5` | feat: implement edge case handling and translate agents to English |
| `225760dd7` | docs: translate remaining Korean text in workspace-analyzer to English |

---

## 7. Testing Checklist

### 7.1 Happy Path Tests

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

### 7.2 Edge Case Tests

```bash
# T6: No changes
git status  # clean
/code-qa    # → "No changed files" message

# T7: Only deleted files
git rm old_file.py
/code-qa --staged  # → Deleted file handling

# T8: Large file count (100+ files)
/code-qa  # → Warning and filtering

# T9: Non-Git directory
cd /tmp/non-git-project
/code-qa  # → NO_GIT_REPO handling

# T10: Detached HEAD
git checkout HEAD~1
/code-qa  # → DETACHED_HEAD handling

# T11: Merge conflict
git merge feature --no-commit  # create conflict
/code-qa  # → MERGE_CONFLICT handling

# T12: Rebase in progress
git rebase main  # create rebase state
/code-qa  # → REBASE_IN_PROGRESS handling

# T13: Dependencies not installed
rm -rf node_modules
/code-qa  # → FAIL_DEPS handling
```

---

## 8. Environment Setup Streamlining

### 8.1 Problem with Original Design

The original env-setup agent required 4 rounds of user interaction:

```
Old Flow (4 WAITING_INPUTs):
STEP 1: Shell selection → WAITING_INPUT
STEP 2: Env type selection → WAITING_INPUT
STEP 3: Env name selection → WAITING_INPUT
STEP 4: Activation confirm → WAITING_INPUT
```

Issues:
- Users already have their environment set up
- Forcing shell selection when `$SHELL` already tells us
- Asking env type when `$CONDA_DEFAULT_ENV` or `$VIRTUAL_ENV` already set
- Too much friction for every `/code-qa` run

### 8.2 Streamlined Design

New flow with minimal interaction:

```
New Flow (1-2 WAITING_INPUTs):

[Active env detected]
  → "Use current env? [Y/n/list]"
  → Y: SUCCESS (1 interaction)
  → n: Show list → Select → SUCCESS (2 interactions)

[No active env]
  → Show env list → Select → SUCCESS (2 interactions)
```

### 8.3 Key Changes

| Aspect | Old | New |
|--------|-----|-----|
| Shell selection | Explicit | Auto-detect (no selection) |
| Env type | Must choose | Auto-detect from active env |
| Env list | Always show | Only when changing |
| Happy path | 4 interactions | 1 interaction |
| Config support | Hint only | `auto_confirm: true` option |

### 8.4 Unified Detection Command

Single Bash call detects everything:
- Current shell and version
- Active environment (conda/venv)
- All conda environments (full list)
- Local .venv directories
- Other managers (uv, poetry, pipenv, pyenv)
- Language runtimes
- GPU availability

---

## 9. Architecture Decisions

### 9.1 Why Result Tokens?

Result tokens provide:
- **Deterministic parsing**: No ambiguity in state detection
- **Error resilience**: Clear success/failure indication
- **Debugging**: Easy to trace workflow state
- **Model independence**: Works across different LLM backends

### 9.2 Why English?

- Primary training language for most LLMs
- Better tokenization efficiency
- Wider community accessibility
- Consistent terminology across codebase

### 9.3 Why Visual Formatting?

- Aids model comprehension of structure
- Reduces ambiguity in complex instructions
- Provides clear section boundaries
- Compatible with markdown rendering

---

## 10. Per-Source Regression Counters

### 10.1 Overview

The regression system uses **per-source independent counters** instead of a single global retry counter:

```
retry_counters = {
    "quality": 0,       # Quality < 70 regressions (max 3 per-source)
    "build": 0,         # Build failure regressions (max 3 per-source)
    "test": 0           # Test failure regressions (max 3 per-source)
}
PER_SOURCE_MAX = 3
TOTAL_REGRESSION_CAP = 5
total_regressions = 0
```

### 10.2 Behavior

| Condition | Source | Action |
|-----------|--------|--------|
| `QUALITY_SCORE < 70` | `quality` | Increment `retry_counters.quality`, regress to code-fixer |
| `BUILD_RESULT: FAIL` | `build` | Increment `retry_counters.build`, regress to code-fixer |
| `TEST_RESULT: FAIL` | `test` | Increment `retry_counters.test`, regress to code-fixer |
| `retry_counters.{source} >= 3` | any | Stop retrying that source |
| `total_regressions >= 5` | all | Stop workflow, request manual review |

### 10.3 Safety Guards

- **Timeout Guard**: Skip regression if elapsed > 85% of workflow timeout
- **Duplicate Fix Detection**: Track `regression_history` to detect repeated identical fixes
- **Context Accumulation**: Each regression passes previous attempt history to code-fixer

---

## 11. Structured JSON Output

All agents output both human-readable reports AND structured JSON for the orchestrator's `context_store`:

### 11.1 Context Store Schema

```
context_store = {
    "env_state": null,          # Environment setup (JSON)
    "file_list": null,          # Changed file list
    "pre_check_result": null,   # Pre-check results (JSON)
    "review_result": null,      # Code review issues (JSON)
    "fix_result": null,         # Code fix results (JSON)
    "quality_result": null,     # Quality score + tool results (JSON)
    "build_result": null,       # Build test results (JSON)
    "test_result": null,        # Function test results (JSON)
    "commit_result": null,      # Git commit info (JSON)
    "push_result": null         # Git push/PR info (JSON)
}
```

### 11.2 Key Agent JSON Schemas

- **git-committer**: `{ "commit": { "status", "hash", "message", "files_committed", "branch" } }`
- **git-pusher**: `{ "push": { "status", "remote", "branch", "pr_url", "pr_created" } }`
- **quality-checker**: `{ "quality": { "score", "issues_by_severity", "tool_results" } }`
- **build-tester**: `{ "build": { "status", "command", "exit_code", "error_summary" } }`
- **function-tester**: `{ "test": { "status", "total", "passed", "failed", "skipped" } }`

Full schemas defined in `.opencode/config/context-schema.md`.

---

## 12. STEP 2.5: File List Validation

After STEP 2 (git-input/file-input), the orchestrator performs file list validation:

1. **Binary File Filtering**: Exclude non-code files (.png, .jpg, .pdf, etc.)
2. **Deleted File Exclusion**: Remove files with status `D` from analysis list
3. **Large Count Warning**: Warn if >100 files changed, suggest `--staged` or `--files`
4. **Empty List Check**: If no valid files remain after filtering, exit gracefully

This step prevents the pipeline from processing files that cannot be meaningfully analyzed.

---

## 13. Related Documentation

| Document | Description |
|----------|-------------|
| `13-code-qa-v4-complete-diagram.md` | Full workflow diagram |
| `14-code-qa-v4-quick-start.md` | Quick start guide (EN) |
| `14-code-qa-v4-quick-start.kr.md` | Quick start guide (KR) |
| `15-workspace-analysis-workflow.md` | Workspace analysis details |
| `16-workflow-case-review.md` | Case review and edge cases |
| `20-dual-model-strategy-report.md` | Dual model strategy report |
| `.opencode/config/workflow-settings.yaml` | Authoritative config (timeouts, retry, model assignments) |
| `.opencode/config/context-schema.md` | JSON schemas for structured context passing |

---

## Change History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-02-04 | Initial implementation summary |
| 1.1 | 2025-02-04 | env-setup streamlining (4 steps → 1-2 steps) |
| 1.2 | 2026-02-05 | Complete result token list, fix step diagram, add all 13 agents |
| 1.3 | 2026-02-06 | Add per-source regression counters, structured JSON output, STEP 2.5 file validation, config file references |
