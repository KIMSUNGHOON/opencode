# Code QA v4 Quick Start Guide

This document provides installation, configuration, and usage instructions for the Code QA v4 workflow.

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Installation](#3-installation)
4. [Configuration File Structure](#4-configuration-file-structure)
5. [Global Configuration](#5-global-configuration)
6. [Usage](#6-usage)
7. [Uninstallation](#7-uninstallation)
8. [Troubleshooting](#8-troubleshooting)
9. [Appendix A: Agent Tool Permission Matrix](#appendix-a-agent-tool-permission-matrix)
10. [Appendix B: Result Tokens and State Management](#appendix-b-result-tokens-and-state-management)
11. [Appendix C: File Checklist](#appendix-c-file-checklist)

---

## 1. Overview

### 1.1 What is Code QA v4?

Code QA v4 is an automated code quality workflow with 24 specialized agents (13 Code QA pipeline + 4 workspace analysis + 2 DeepWiki + 5 utility) orchestrated by a central coordinator.

### 1.2 Key Features

- **Dual Model Strategy** (Single Server + Per-Request Thinking Control):
  - **Thinking Mode**: Qwen3.5-122B-A10B-FP8 (`enable_thinking: true`) — code-reviewer, quality-checker, summary-reporter
  - **Instruct Mode**: Qwen3.5-122B-A10B-FP8 (`enable_thinking: false`) — Orchestrator (code-qa), env-setup, git-input, file-input, pre-checker, code-fixer, build-tester, function-tester, git-committer, git-pusher
  - Note: Same model served from one SGLang server (port 8000). Thinking/Instruct controlled per-request via `chat_template_kwargs`. workspace-analyzer is deprecated (legacy fallback only).
- **User Confirmation Steps**: Required at env-setup, git-input, build-tester, function-tester, git-committer, git-pusher
- **Docker Sandbox**: Isolated Build/Test environment (CUDA 13.0, Python 3.12)
- **Regression Loop**: Per-source independent retry counters (quality/build/test: max 3 each, total cap: 5)
- **Structured Context Passing**: Inter-agent JSON data exchange via `context_store` and `regression_history`
- **User Input Timeout**: 5-minute timeout with safe default actions to prevent deadlock
- **GitLab-CE Support**: Both GitHub and GitLab supported (gh/glab CLI)
- **Authentication Error Handling**: SSH/HTTPS/GPG/CLI auth issue detection and guidance

### 1.3 Model Specifications

| Item | Thinking Mode | Instruct Mode |
|------|---------------|---------------|
| **Model** | Qwen3.5-122B-A10B-FP8 | Qwen3.5-122B-A10B-FP8 (same model) |
| **Serving Engine** | SGLang (port 8000) | SGLang (port 8000, same server) |
| **Per-Request Control** | `chat_template_kwargs: {"enable_thinking": true}` | `chat_template_kwargs: {"enable_thinking": false}` |
| **Context Window** | 256K | 256K |
| **Output Limit** | 32K | 32K |
| **Reasoning** | Yes (thinking mode) | No |
| **Tool Calling** | Yes | Yes |
| **Agents** | code-reviewer, quality-checker, summary-reporter | Orchestrator (code-qa), env-setup, git-input, file-input, pre-checker, code-fixer, build-tester, function-tester, git-committer, git-pusher |

### 1.4 Official Sampling Parameters (Qwen3.5)

```
Thinking Mode (qwen/Qwen3.5-122B-A10B-FP8):
  Temperature: 0.6, TopP: 0.95, TopK: 20, MinP: 0

Instruct Mode (qwen-instruct/Qwen3.5-122B-A10B-FP8):
  Temperature: 0.7, TopP: 0.8, TopK: 20, MinP: 0
```

---

## 2. Prerequisites

### 2.1 Hardware

- GPU: 2x H100 NVL 96GB (or equivalent)
- VRAM: Minimum 160GB (model + KV cache)

### 2.2 Software

```bash
# Python 3.10+
python --version

# SGLang installation (for Thinking Model)
pip install sglang[all]

# SGLang is used for both models
# pip install sglang[all]  (already installed above)

# Docker (for Sandbox)
docker --version
nvidia-docker --version  # For GPU usage
```

### 2.3 Model Server Launch

**Single Server — SGLang (port 8000), both Thinking and Instruct via per-request control:**

```bash
# Serve Qwen3.5-122B-A10B-FP8 with SGLang (single server, hybrid mode)
python -m sglang.launch_server \
    --model-path Qwen/Qwen3.5-122B-A10B-FP8 \
    --tp-size 8 \
    --mem-fraction-static 0.8 \
    --context-length 262144 \
    --reasoning-parser qwen3 \
    --tool-call-parser qwen3_coder \
    --port 8000 \
    --host 0.0.0.0
```

> **Note**: Thinking/Instruct mode is controlled per-request via `chat_template_kwargs` in the request body (`enable_thinking: true/false`), configured in `opencode.jsonc` provider options. No need for a second server.

---

## 3. Installation

### 3.1 Create Global Config Directory

```bash
mkdir -p ~/.config/opencode/.opencode/{agent,command,mode}
```

### 3.2 Copy Global Config Files

**Method 1: Copy from Repository (Recommended)**

```bash
# Clone opencode repository
git clone https://github.com/your-org/opencode.git /tmp/opencode-setup

# Copy global config files
cp /tmp/opencode-setup/.opencode/agent/{env-setup,workspace-analyzer,git-input,file-input,pre-checker,code-reviewer,code-fixer,quality-checker,build-tester,function-tester,git-committer,summary-reporter,git-pusher}.md \
   ~/.config/opencode/.opencode/agent/

cp /tmp/opencode-setup/.opencode/command/code-qa.md \
   ~/.config/opencode/.opencode/command/

cp /tmp/opencode-setup/.opencode/mode/code-qa.md \
   ~/.config/opencode/.opencode/mode/

# Cleanup
rm -rf /tmp/opencode-setup
```

**Method 2: Manual Creation**

Create the config files manually as described in Section 5.

### 3.3 Set Environment Variables

```bash
# Add to ~/.bashrc or ~/.zshrc
export QWEN_BASE_URL="http://localhost:8000/v1"
export QWEN_CODER_BASE_URL="http://localhost:8001/v1"
```

---

## 4. Configuration File Structure

### 4.1 Global Config (Shared Across All Projects)

```
~/.config/opencode/
├── opencode.json                    # Provider, Model, Agent sampling params
└── .opencode/
    ├── agent/                       # 24 Agents (13 pipeline + 4 analysis + 2 wiki + 5 utility)
    │   ├── ── Code QA Pipeline (13) ──
    │   ├── env-setup.md             # STEP 1: Environment setup
    │   ├── git-input.md             # STEP 2: Git changed file extraction
    │   ├── file-input.md            # STEP 2 alt: File input parser (non-Git)
    │   ├── pre-checker.md           # STEP 3: Lint/Format auto-fix
    │   ├── code-reviewer.md         # STEP 4: Code review (domain-aware)
    │   ├── code-fixer.md            # STEP 5: Issue fixing
    │   ├── quality-checker.md       # STEP 6: Quality score check
    │   ├── build-tester.md          # STEP 7: Build test
    │   ├── function-tester.md       # STEP 8: Function test
    │   ├── git-committer.md         # STEP 9: Git commit
    │   ├── summary-reporter.md      # STEP 10: Summary report
    │   ├── git-pusher.md            # STEP 11: Push and PR
    │   ├── ── Workspace Analysis (4) ──
    │   ├── analyze.md               # /analyze orchestrator
    │   ├── workspace-scanner.md     # Fast project scan
    │   ├── module-analyzer.md       # Per-module deep analysis
    │   ├── workspace-analyzer.md    # Legacy fallback (DEPRECATED)
    │   ├── ── DeepWiki (2) ──
    │   ├── deepwiki.md              # /deepwiki orchestrator
    │   ├── wiki-page-generator.md   # Wiki page generation
    │   ├── ── Utility (5) ──
    │   ├── docs.md, translator.md, duplicate-pr.md, triage.md
    │   ├── test-runner.md           # Standalone test suite runner & report generator
    │   └── session-checkpoint.md    # Session context preservation & resumption
    ├── command/                     # 15 Commands
    │   ├── code-qa.md               # Full QA pipeline
    │   ├── analyze.md, deepwiki.md  # Analysis & wiki
    │   ├── env.md .. test.md        # 7 standalone agents
    │   └── commit.md, issues.md, ai-deps.md, rmslop.md, spellcheck.md
    ├── skills/                      # 8 Skills (knowledge bases)
    │   ├── code-review/, code-quality/, build-test/
    │   ├── wiki-generation/, translation/
    │   ├── doc-indexer/             # Docs → project-knowledge
    │   ├── test-runner/             # Test execution & report generation
    │   └── session-checkpoint/      # Context preservation & resumption
    └── mode/
        └── code-qa.md               # Code QA orchestrator mode

```

### 4.2 Project-Specific Config (Override)

```
your-project/
├── .opencode/
│   ├── opencode.jsonc               # Project override (optional)
│   ├── env-config.yaml              # Environment config (optional)
│   ├── agent/                       # Project-specific agents only
│   │   └── custom-agent.md
│   └── docker/
│       └── Dockerfile.sandbox       # Sandbox image (optional)
└── ...
```

### 4.3 Configuration Priority

```
1. Environment variables (OPENCODE_*)    <- Highest
2. CLI flags
3. Project root opencode.json
4. Project .opencode/opencode.jsonc
5. Global ~/.config/opencode/opencode.json
6. Defaults                              <- Lowest
```

---

## 5. Global Configuration

### 5.1 Global Config File (`~/.config/opencode/opencode.json`)

Copy and use the following content:

```json
{
  "$schema": "https://opencode.ai/config.json",
  // Single SGLang server (port 8000), per-request thinking control
  "provider": {
    "qwen": {
      "name": "Qwen3.5-122B-A10B Thinking",
      "npm": "@ai-sdk/openai-compatible",
      "api": "http://localhost:8000/v1",
      "env": [],
      "options": {
        "apiKey": "dummy",
        "baseURL": "http://localhost:8000/v1"
      },
      "models": {
        "Qwen3.5-122B-A10B-FP8": {
          "name": "Qwen3.5-122B-A10B-FP8",
          "id": "Qwen3.5-122B-A10B-FP8",
          "tool_call": true,
          "temperature": true,
          "reasoning": true,
          "attachment": false,
          "modalities": { "input": ["text"], "output": ["text"] },
          "limit": { "context": 262144, "output": 32768 },
          "options": {
            "temperature": 0.6, "top_p": 0.95, "top_k": 20,
            "chat_template_kwargs": { "enable_thinking": true }
          },
          "cost": { "input": 0, "output": 0 }
        }
      }
    },
    "qwen-instruct": {
      "name": "Qwen3.5-122B-A10B Instruct",
      "npm": "@ai-sdk/openai-compatible",
      "api": "http://localhost:8000/v1",
      "env": [],
      "options": {
        "apiKey": "dummy",
        "baseURL": "http://localhost:8000/v1"
      },
      "models": {
        "Qwen3.5-122B-A10B-FP8": {
          "name": "Qwen3.5-122B-A10B-FP8",
          "id": "Qwen3.5-122B-A10B-FP8",
          "tool_call": true,
          "temperature": true,
          "reasoning": false,
          "attachment": false,
          "modalities": { "input": ["text"], "output": ["text"] },
          "limit": { "context": 262144, "output": 32768 },
          "options": {
            "temperature": 0.7, "top_p": 0.8, "top_k": 20,
            "chat_template_kwargs": { "enable_thinking": false }
          },
          "cost": { "input": 0, "output": 0 }
        }
      }
    }
  },
  "agent": {
    // Thinking Mode agents (temp=0.6, top_p=0.95, top_k=20)
    "code-reviewer": { "temperature": 0.6, "top_p": 0.95, "top_k": 20, "min_p": 0 },
    "quality-checker": { "temperature": 0.6, "top_p": 0.95, "top_k": 20, "min_p": 0 },
    "summary-reporter": { "temperature": 0.6, "top_p": 0.95, "top_k": 20, "min_p": 0 },
    // Instruct Mode agents (temp=0.7, top_p=0.8, top_k=20)
    "env-setup": { "temperature": 0.7, "top_p": 0.8, "top_k": 20 },
    "workspace-analyzer": { "temperature": 0.7, "top_p": 0.8, "top_k": 20 },
    "git-input": { "temperature": 0.7, "top_p": 0.8, "top_k": 20 },
    "file-input": { "temperature": 0.7, "top_p": 0.8, "top_k": 20 },
    "pre-checker": { "temperature": 0.7, "top_p": 0.8, "top_k": 20 },
    "code-fixer": { "temperature": 0.7, "top_p": 0.8, "top_k": 20 },
    "build-tester": { "temperature": 0.7, "top_p": 0.8, "top_k": 20 },
    "function-tester": { "temperature": 0.7, "top_p": 0.8, "top_k": 20 },
    "git-committer": { "temperature": 0.7, "top_p": 0.8, "top_k": 20 },
    "git-pusher": { "temperature": 0.7, "top_p": 0.8, "top_k": 20 }
  },
  "experimental": {
    "chatMaxRetries": 5
  }
}
```

---

## 6. Usage

### 6.1 Verify Installation

```bash
# Run opencode
opencode

# Check model connection
> Hello. What model are you currently using?
```

### 6.2 Using as Mode

Select "code-qa" in the mode selector:

```
# Ctrl+X -> m (or configured keybind)
> code-qa (Code QA Workflow)
```

### 6.3 Full Workflow (/code-qa)

```bash
# ===============================================================
# /code-qa - Full Code QA Workflow (13 agents)
# ===============================================================

# -- Git Mode (default) ----------------------------------------
/code-qa                        # Check working directory changes
/code-qa --staged               # Check staged changes only
/code-qa --last                 # Check last commit
/code-qa --branch               # Check entire branch (vs main)
/code-qa --range a1b2c3..d4e5f6 # Check specific commit range

# -- File Direct Mode (Non-Git) --------------------------------
/code-qa --files src/main.py              # Single file
/code-qa --files src/*.py                 # Wildcard
/code-qa --files src/,lib/                # Multiple directories
/code-qa --files "src/**/*.py"            # Recursive pattern

# -- Execution Environment Options -----------------------------
/code-qa --no-sandbox           # Run directly on host without Docker

# -- Combined Examples -----------------------------------------
/code-qa --staged --no-sandbox            # Staged + Host
/code-qa --files src/ --no-sandbox        # File mode + Host
/code-qa --last --no-sandbox              # Last commit + Host
```

**Git Mode vs File Mode:**

| Mode | Input Source | Git Steps | Use Case |
|------|-------------|-----------|----------|
| **Git Mode** | git diff | Included | Git repository projects |
| **File Mode** | --files | Excluded | Non-Git projects, specific file checks |

### 6.4 Standalone Commands

Each sub-agent can be executed independently:

```bash
# -- /env - Environment Setup ----------------------------------
/env                            # Interactive environment setup
/env --shell zsh --env conda    # Pre-specify Shell/environment
/env --info                     # Check current environment info only
/env --reset                    # Reset environment settings

# -- /lint - Lint/Format Auto-fix ------------------------------
/lint                           # Entire current directory
/lint src/main.py               # Specific file
/lint src/                      # Specific directory
/lint src/*.py                  # Wildcard
/lint --check                   # Check only without fixing
/lint --no-sandbox              # Run on host

# -- /review - Code Review -------------------------------------
/review                         # Review working directory changes
/review --staged                # Review staged changes only
/review --last                  # Review last commit
/review src/main.py             # Review specific file
/review --security              # Focus on security issues only
/review --verbose               # Detailed analysis

# -- /fix - Code Issue Fixing ----------------------------------
/fix "src/main.py:45 - SQL injection"  # Fix specific issue
/fix src/main.py                # Fix all issues in file
/fix --from-review              # Fix based on /review results
/fix --type security src/       # Fix specific type only
/fix --dry-run                  # Preview only

# -- /quality - Quality Check ----------------------------------
/quality                        # Check current directory
/quality src/                   # Check specific directory
/quality --threshold 80         # Change pass threshold
/quality --verbose              # Detailed results
/quality --json                 # JSON output
/quality --no-sandbox           # Run on host

# -- /build - Build Test ---------------------------------------
/build                          # Build in Docker Sandbox
/build --no-sandbox             # Build on host
/build --skip-confirm           # Skip environment confirmation
/build --cmd "pip install -e ." # Custom build command
/build --verbose                # Detailed logs

# -- /test - Function Test -------------------------------------
/test                           # Detect and run all tests
/test tests/test_main.py        # Specific test file
/test tests/::test_function     # Specific test function
/test --lang python             # Specific language only
/test --coverage                # Include coverage
/test --no-sandbox              # Run on host
/test --fail-fast               # Stop on first failure
```

### 6.5 User Confirmation Steps

The following agents require user input:

| Agent | Required Input | Description |
|-------|---------------|-------------|
| **env-setup** | Shell selection (1-3), Environment type (1-4) | Select which Shell and virtual environment to use |
| **git-input** | "init/git init", file path, or "exit" | Choose how to handle non-Git repositories |
| **file-input** | (automatic) | File discovery when using --files option |
| **build-tester** | "y/confirm" or "n/reset" | Confirm environment settings before build |
| **function-tester** | "y/run", specific language, or "n/skip" | Show all language tests at once, decide execution |
| **git-committer** | "y/confirm", new message, or "n/cancel" | Confirm commit info before execution (Git mode only) |
| **git-pusher** | "y/confirm", "retry", or "n/skip" | Push confirmation and auth error handling (Git mode only) |

---

## 7. Uninstallation

### 7.1 Remove Global Config

```bash
# Remove global Code QA Agents (13)
rm -rf ~/.config/opencode/.opencode/agent/{env-setup,workspace-analyzer,git-input,file-input,pre-checker,code-reviewer,code-fixer,quality-checker,build-tester,function-tester,git-committer,summary-reporter,git-pusher}.md

# Remove global Code QA Commands (8)
rm -rf ~/.config/opencode/.opencode/command/{code-qa,env,lint,review,fix,quality,build,test}.md

# Remove global Code QA Mode
rm -rf ~/.config/opencode/.opencode/mode/code-qa.md
```

### 7.2 Remove All Global Config

```bash
# Remove all global config (caution!)
rm -rf ~/.config/opencode/
```

---

## 8. Troubleshooting

### 8.1 Config Error: "Unrecognized key"

```
Error: Configuration is invalid
Unrecognized key: "agents"
```

**Cause**: Use `agent` (singular) instead of `agents` (plural).

**Solution**:
```bash
sed -i 's/"agents":/"agent":/' ~/.config/opencode/opencode.json
```

### 8.2 Model Connection Failed

```
Error: Failed to connect to model server
```

**Solution**:
```bash
# Check Thinking Model server status (SGLang, port 8000)
curl http://localhost:8000/v1/models

# Check Coder Model server status (vLLM, port 8001)
curl http://localhost:8001/v1/models

# Check environment variables
echo $QWEN_BASE_URL
echo $QWEN_CODER_BASE_URL
```

### 8.3 Docker Sandbox Failed

```
Error: Docker image not found
```

**Solution**:
```bash
# Check Dockerfile
ls .opencode/docker/Dockerfile.sandbox

# Build image
docker build -t qa-sandbox -f .opencode/docker/Dockerfile.sandbox .
```

### 8.4 Agent Not Found

```
Error: Agent 'env-setup' not found
```

**Cause**: Agent file missing from global or project config.

**Solution**:
```bash
# Check global agents
ls ~/.config/opencode/.opencode/agent/

# Check project agents
ls .opencode/agent/
```

### 8.5 Stuck in WAITING_INPUT State

env-setup, git-input, build-tester, function-tester, git-committer are waiting for user input.

**Auto-timeout**: If no input is provided within **5 minutes**, the orchestrator takes a safe default action:

| Agent | Default Action on Timeout |
|-------|--------------------------|
| env-setup | Auto-confirm detected environment |
| git-input | Auto-abort (exit workflow gracefully) |
| build-tester | Auto-confirm current environment |
| function-tester | Auto-skip tests |
| git-committer | Auto-skip commit |
| git-pusher | Auto-skip push |

**Manual Solution**: Provide the requested input:
- Shell selection: `1`, `2`, or `3`
- Environment type: `1`, `2`, `3`, or `4`
- Confirm: `y` or `confirm`
- Skip: `n` or `skip`
- Git init: `git init` or `init`
- Edit commit message: Enter new message directly

### 8.6 Not a Git Repository (NO_GIT_REPO)

```
GIT_INPUT_RESULT: NO_GIT_REPO
```

**Solution**:
- Initialize as Git repo: Enter `git init` or `init`
- QA specific files only: Enter file path (e.g., `src/main.py`)
- Exit QA: Enter `exit`

### 8.7 Authentication Error (AUTH_ERROR)

```
PUSH_RESULT: AUTH_ERROR
AUTH_TYPE: SSH
```

**Solution**: Run commands based on auth type

| Error Type | Solution Command |
|-----------|-----------------|
| No SSH key | `ssh-keygen -t ed25519` |
| SSH agent inactive | `eval "$(ssh-agent -s)"` |
| SSH key not added | `ssh-add ~/.ssh/id_ed25519` |
| GitHub CLI not authenticated | `gh auth login` |
| GitLab CLI not authenticated | `glab auth login` |
| GPG signing failed | `gpg --list-secret-keys` |

---

## Appendix A: Agent Tool Permission Matrix

List of tools available to each agent:

| Agent | Bash | Read | Edit | Write | Glob | Grep | Primary Role |
|-------|:----:|:----:|:----:|:-----:|:----:|:----:|-------------|
| **workspace-analyzer** | Yes | Yes | No | No | Yes | Yes | Workspace analysis (DEPRECATED) |
| env-setup | Yes | Yes | No | No | Yes | Yes | Environment detection |
| git-input | Yes | Yes | No | No | Yes | No | Git parsing |
| pre-checker | Yes | Yes | No | No | Yes | Yes | Lint/Format (edit:deny intentional) |
| **code-reviewer** | **No** | Yes | No | No | **No** | **No** | Issue discovery (manual reading) |
| code-fixer | Yes | Yes | Yes | Yes | Yes | Yes | Code modification |
| quality-checker | Yes | Yes | No | No | Yes | Yes | Tool-based quality scoring |
| build-tester | Yes | Yes | No | No | Yes | No | Build testing |
| function-tester | Yes | Yes | No | No | Yes | Yes | Function testing |
| git-committer | Yes | Yes | No | No | No | No | Git commit |
| summary-reporter | Yes | Yes | No | No | No | No | Report generation |
| git-pusher | Yes | Yes | No | No | No | No | Push/PR |

**Key Permission Notes:**
- **code-fixer**: Only agent with Edit/Write permissions (code modification required)
- **code-reviewer**: Read permission only (Glob/Grep/Bash disabled). Can only analyze files explicitly passed by the orchestrator.
- **All Agents**: Dangerous commands blocked (rm -rf, git push --force, etc.)

---

## Appendix B: Result Tokens and State Management

### Result Token Format

Each agent outputs tokens in the following format upon completion:

| Agent | Output Token | Example |
|-------|-------------|---------|
| workspace-analyzer | `WORKSPACE_ANALYSIS_RESULT: COMPLETE/TIMEOUT/EMPTY/FAILED` | `WORKSPACE_ANALYSIS_RESULT: COMPLETE` |
| env-setup | `ENV_SETUP_RESULT: SUCCESS/FAIL/WAITING_INPUT` | `ENV_SETUP_RESULT: SUCCESS` |
| git-input | `FILE_LIST: {files}` | `FILE_LIST: src/app.py, src/utils.py` |
| file-input | `FILE_LIST: {files}` | `FILE_LIST: /home/user/project/src/app.py` |
| pre-checker | `PRE_CHECK_RESULT: SUCCESS/PARTIAL` | `PRE_CHECK_RESULT: SUCCESS` |
| code-reviewer | `ISSUE_LIST: {issues}` | `ISSUE_LIST: [H001] Null ref...` |
| code-fixer | `FIX_RESULT: SUCCESS/PARTIAL` | `FIX_RESULT: SUCCESS` |
| quality-checker | `QUALITY_SCORE: XX/100` | `QUALITY_SCORE: 85/100` |
| build-tester | `BUILD_RESULT: SUCCESS/FAIL/WAITING_INPUT` | `BUILD_RESULT: SUCCESS` |
| function-tester | `TEST_RESULT: SUCCESS/FAIL/SKIPPED/NO_TESTS` | `TEST_RESULT: SUCCESS` |
| git-committer | `COMMIT_RESULT: SUCCESS/NO_CHANGES` | `COMMIT_RESULT: SUCCESS` |
| git-pusher | `PUSH_RESULT: SUCCESS/SKIPPED/FAIL` | `PUSH_RESULT: SUCCESS` |

### Orchestrator State Variables

State variables tracked by the orchestrator (mode/code-qa.md):

```
# --- Per-Source Retry Counters (prevents infinite loops) ---
retry_counters = {
    "quality": 0,       # Quality < 70 regressions (max 3)
    "build": 0,         # Build failure regressions (max 3)
    "test": 0           # Test failure regressions (max 3)
}
PER_SOURCE_MAX = 3
TOTAL_REGRESSION_CAP = 5
total_regressions = 0

# --- Regression History (context for code-fixer) ---
regression_history = []     # Array of previous fix attempt records

# --- Structured Context Store ---
context_store = {
    "env_state": null,          # Environment setup result (JSON)
    "file_list": null,          # Changed file list
    "pre_check_result": null,   # Pre-check lint/format results (JSON)
    "review_result": null,      # Code review issues (structured JSON)
    "fix_result": null,         # Code fix results (structured JSON)
    "quality_result": null,     # Quality score + tool results (JSON)
    "build_result": null,       # Build test results (structured JSON)
    "test_result": null,        # Function test results (structured JSON)
    "commit_result": null,      # Git commit info (structured JSON)
    "push_result": null         # Git push/PR info (structured JSON)
}
```

### Regression Conditions (Per-Source Independent)

| Condition | Source | Action |
|-----------|--------|--------|
| `QUALITY_SCORE < 70` | `quality` | Increment `retry_counters.quality`, regress to STEP 5 |
| `BUILD_RESULT: FAIL` | `build` | Increment `retry_counters.build`, regress to STEP 5 |
| `TEST_RESULT: FAIL` | `test` | Increment `retry_counters.test`, regress to STEP 5 |
| `retry_counters.{source} >= 3` | any | Stop retrying that source, fail workflow |
| `total_regressions >= 5` | all | Stop workflow entirely, request manual review |

Each regression records the attempt in `regression_history` and passes it to the code-fixer
so it can choose a **different** fix strategy (see `context-schema.md` for JSON schemas).

---

## Appendix C: File Checklist

### Global Config Files (Required)

```
~/.config/opencode/
├── opencode.json                           Provider, Agent settings
└── .opencode/
    ├── agent/                              (22 Agents)
    │   ├── ── Code QA Pipeline (13) ──
    │   ├── env-setup.md                    Environment setup
    │   ├── git-input.md                    Git changed file extraction
    │   ├── file-input.md                   File input parser (Non-Git)
    │   ├── pre-checker.md                  Lint/Format auto-fix
    │   ├── code-reviewer.md                Code review (domain-aware)
    │   ├── code-fixer.md                   Code fixing
    │   ├── quality-checker.md              Quality check
    │   ├── build-tester.md                 Build testing
    │   ├── function-tester.md              Function testing
    │   ├── git-committer.md                Git commit
    │   ├── summary-reporter.md             Result report
    │   ├── git-pusher.md                   Push/PR
    │   ├── ── Workspace Analysis (4) ──
    │   ├── analyze.md                      /analyze orchestrator
    │   ├── workspace-scanner.md            Fast project scan
    │   ├── module-analyzer.md              Per-module deep analysis
    │   ├── workspace-analyzer.md           Legacy fallback (DEPRECATED)
    │   ├── ── DeepWiki (2) ──
    │   ├── deepwiki.md                     /deepwiki orchestrator
    │   ├── wiki-page-generator.md          Wiki page generation
    │   ├── ── Utility (3) ──
    │   ├── docs.md                         Documentation writing
    │   ├── translator.md                   Translation
    │   ├── duplicate-pr.md                 Duplicate PR detection
    │   └── triage.md                       GitHub issue triage
    ├── command/                            (15 Commands)
    │   ├── code-qa.md                      Full QA pipeline
    │   ├── analyze.md                      Workspace analysis + doc indexing
    │   ├── deepwiki.md                     Wiki generation
    │   ├── env.md                          /env - Environment
    │   ├── lint.md                         /lint - Lint/Format
    │   ├── review.md                       /review - Code review
    │   ├── fix.md                          /fix - Code fixing
    │   ├── quality.md                      /quality - Quality check
    │   ├── build.md                        /build - Build test
    │   ├── test.md                         /test - Function test
    │   ├── commit.md                       /commit - Git commit & push
    │   ├── issues.md                       /issues - GitHub issue search
    │   ├── ai-deps.md                      /ai-deps - AI SDK dep bumps
    │   ├── rmslop.md                       /rmslop - AI slop removal
    │   └── spellcheck.md                   /spellcheck - Markdown spellcheck
    ├── skills/                             (8 Knowledge Bases)
    │   ├── code-review/                    Review checklists per language
    │   ├── code-quality/                   Scoring rules & lint mappings
    │   ├── build-test/                     Build patterns per project type
    │   ├── wiki-generation/                Wiki page templates & diagrams
    │   ├── translation/                    Locale glossary & preserve rules
    │   ├── doc-indexer/                    Docs → project-knowledge generator
    │   ├── test-runner/                    Test execution & report generation
    │   └── session-checkpoint/             Context preservation & resumption
    ├── config/                             (Configuration)
    │   ├── workflow-settings.yaml          Timeout, retry, quality, model settings
    │   ├── context-schema.md               JSON schemas for structured context passing
    │   ├── permission-templates.yaml       Agent permission templates
    │   └── logging-format.md               Unified log format
    └── mode/
        └── code-qa.md                      QA orchestrator
```

### Environment Variables (Required)

```bash
QWEN_BASE_URL="http://localhost:8000/v1"
QWEN_CODER_BASE_URL="http://localhost:8001/v1"
```

### Command Summary

| Command | Purpose | Git Required |
|---------|---------|--------------|
| `/code-qa` | Full workflow | Optional |
| `/code-qa --files <path>` | Full workflow (Non-Git) | No |
| `/env` | Environment setup only | No |
| `/lint` | Lint/Format only | No |
| `/review` | Code review only | Optional |
| `/fix` | Code fixing only | No |
| `/quality` | Quality check only | No |
| `/build` | Build test only | No |
| `/test` | Function test only | No |

---

## Related Documents

- [Architecture](./02-architecture.en.md) - Full workflow diagram
- [Environment Setup](./03-environment-setup.en.md) - Environment setup details
- [Implementation Summary](./05-implementation-summary.en.md) - Implementation summary
