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

Code QA v4 is an automated code quality workflow consisting of 11 phases.

### 1.2 Key Features

- **Single Model Strategy**: Qwen3-Next-80B-A3B-Thinking-FP8 (reasoning + tool calling)
- **User Confirmation Steps**: Required at env-setup, git-input, build-tester, function-tester, git-committer, git-pusher
- **Docker Sandbox**: Isolated Build/Test environment (CUDA 13.0, Python 3.12)
- **Regression Loop**: Automatic retry on quality threshold failure (max 3 times)
- **Structured State Management**: Inter-agent data passing via result token parsing
- **GitLab-CE Support**: Both GitHub and GitLab supported (gh/glab CLI)
- **Authentication Error Handling**: SSH/HTTPS/GPG/CLI auth issue detection and guidance

### 1.3 Model Specifications

| Item | Value |
|------|-------|
| **Model** | Qwen3-Next-80B-A3B-Thinking-FP8 |
| **Context Window** | 256K |
| **Output Limit** | 16K |
| **Reasoning** | Yes (thinking mode) |
| **Tool Calling** | Yes |
| **VRAM Required** | ~76GB (FP8) |
| **Recommended GPU** | 2x H100 NVL 96GB |

### 1.4 Official Sampling Parameters

```
Temperature: 0.6
TopP: 0.95
TopK: 20
MinP: 0
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

# SGLang installation
pip install sglang[all]

# Docker (for Sandbox)
docker --version
nvidia-docker --version  # For GPU usage
```

### 2.3 Model Server Launch

```bash
# Serve Qwen3-Next-80B-A3B-Thinking-FP8 with SGLang
python -m sglang.launch_server \
    --model-path Qwen/Qwen3-Next-80B-A3B-Thinking-FP8 \
    --tp 2 \
    --context-length 262144 \
    --port 30000 \
    --host 0.0.0.0
```

**With NEXTN Speculative Decoding (~30% performance boost):**
```bash
python -m sglang.launch_server \
    --model-path Qwen/Qwen3-Next-80B-A3B-Thinking-FP8 \
    --tp 2 \
    --context-length 262144 \
    --speculative-algorithm NEXTN \
    --speculative-num-draft-tokens 3 \
    --port 30000 \
    --host 0.0.0.0
```

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
cp /tmp/opencode-setup/.opencode/agent/{env-setup,build-tester,function-tester,code-reviewer,code-fixer,git-input,git-committer,git-pusher,pre-checker,quality-checker,summary-reporter}.md \
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
export QWEN_BASE_URL="http://localhost:30000/v1"
```

---

## 4. Configuration File Structure

### 4.1 Global Config (Shared Across All Projects)

```
~/.config/opencode/
├── opencode.json                    # Provider, Model, Agent sampling params
└── .opencode/
    ├── agent/                       # Code QA Agents (11)
    │   ├── env-setup.md             # Phase -1: Environment setup (user input required)
    │   ├── git-input.md             # Phase 0: Git changed file extraction
    │   ├── pre-checker.md           # Phase 1: Lint/Format auto-fix
    │   ├── code-reviewer.md         # Phase 2: Deep code analysis
    │   ├── code-fixer.md            # Phase 3: Issue fixing
    │   ├── quality-checker.md       # Phase 4: Quality score check
    │   ├── build-tester.md          # Phase 5: Build test (user confirm required)
    │   ├── function-tester.md       # Phase 6: Function test (user confirm required)
    │   ├── git-committer.md         # Phase 7: Git commit
    │   ├── summary-reporter.md      # Phase 8: Summary report
    │   └── git-pusher.md            # Phase 9: Push and PR
    ├── command/
    │   └── code-qa.md               # /code-qa command
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
1. Environment variables (OPENCODE_*)    ← Highest
2. CLI flags
3. Project root opencode.json
4. Project .opencode/opencode.jsonc
5. Global ~/.config/opencode/opencode.json
6. Defaults                              ← Lowest
```

---

## 5. Global Configuration

### 5.1 Global Config File (`~/.config/opencode/opencode.json`)

Copy and use the following content:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "qwen/qwen3-next-80b-a3b-thinking",
  "provider": {
    "qwen": {
      "name": "Qwen3-Next-Thinking Server (SGLang)",
      "npm": "@ai-sdk/openai-compatible",
      "options": {
        "timeout": 600000,
        "baseURL": "{env:QWEN_BASE_URL}"
      },
      "models": {
        "qwen3-next-80b-a3b-thinking": {
          "name": "Qwen3-Next-80B-A3B-Thinking-FP8",
          "id": "Qwen/Qwen3-Next-80B-A3B-Thinking-FP8",
          "tool_call": true,
          "reasoning": true,
          "temperature": true,
          "limit": {
            "context": 262144,
            "output": 16384
          }
        }
      }
    }
  },
  "agent": {
    "code-reviewer": { "temperature": 0.6, "top_p": 0.95, "top_k": 20, "min_p": 0 },
    "code-fixer": { "temperature": 0.6, "top_p": 0.95, "top_k": 20, "min_p": 0 },
    "env-setup": { "temperature": 0.6, "top_p": 0.95, "top_k": 20, "min_p": 0 },
    "build-tester": { "temperature": 0.6, "top_p": 0.95, "top_k": 20, "min_p": 0 },
    "function-tester": { "temperature": 0.6, "top_p": 0.95, "top_k": 20, "min_p": 0 },
    "pre-checker": { "temperature": 0.6, "top_p": 0.95, "top_k": 20, "min_p": 0 },
    "quality-checker": { "temperature": 0.6, "top_p": 0.95, "top_k": 20, "min_p": 0 },
    "git-input": { "temperature": 0.6, "top_p": 0.95, "top_k": 20, "min_p": 0 },
    "git-committer": { "temperature": 0.6, "top_p": 0.95, "top_k": 20, "min_p": 0 },
    "git-pusher": { "temperature": 0.6, "top_p": 0.95, "top_k": 20, "min_p": 0 },
    "summary-reporter": { "temperature": 0.6, "top_p": 0.95, "top_k": 20, "min_p": 0 }
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
# ═══════════════════════════════════════════════════════════════
# /code-qa - Full Code QA Workflow (11 phases)
# ═══════════════════════════════════════════════════════════════

# ── Git Mode (default) ──────────────────────────────────────────
/code-qa                        # Check working directory changes
/code-qa --staged               # Check staged changes only
/code-qa --last                 # Check last commit
/code-qa --branch               # Check entire branch (vs main)
/code-qa --range a1b2c3..d4e5f6 # Check specific commit range

# ── File Direct Mode (Non-Git) ──────────────────────────────────
/code-qa --files src/main.py              # Single file
/code-qa --files src/*.py                 # Wildcard
/code-qa --files src/,lib/                # Multiple directories
/code-qa --files "src/**/*.py"            # Recursive pattern

# ── Execution Environment Options ───────────────────────────────
/code-qa --no-sandbox           # Run directly on host without Docker

# ── Combined Examples ───────────────────────────────────────────
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
# ── /env - Environment Setup ────────────────────────────────────
/env                            # Interactive environment setup
/env --shell zsh --env conda    # Pre-specify Shell/environment
/env --info                     # Check current environment info only
/env --reset                    # Reset environment settings

# ── /lint - Lint/Format Auto-fix ────────────────────────────────
/lint                           # Entire current directory
/lint src/main.py               # Specific file
/lint src/                      # Specific directory
/lint src/*.py                  # Wildcard
/lint --check                   # Check only without fixing
/lint --no-sandbox              # Run on host

# ── /review - Code Review ───────────────────────────────────────
/review                         # Review working directory changes
/review --staged                # Review staged changes only
/review --last                  # Review last commit
/review src/main.py             # Review specific file
/review --security              # Focus on security issues only
/review --verbose               # Detailed analysis

# ── /fix - Code Issue Fixing ────────────────────────────────────
/fix "src/main.py:45 - SQL injection"  # Fix specific issue
/fix src/main.py                # Fix all issues in file
/fix --from-review              # Fix based on /review results
/fix --type security src/       # Fix specific type only
/fix --dry-run                  # Preview only

# ── /quality - Quality Check ────────────────────────────────────
/quality                        # Check current directory
/quality src/                   # Check specific directory
/quality --threshold 80         # Change pass threshold
/quality --verbose              # Detailed results
/quality --json                 # JSON output
/quality --no-sandbox           # Run on host

# ── /build - Build Test ─────────────────────────────────────────
/build                          # Build in Docker Sandbox
/build --no-sandbox             # Build on host
/build --skip-confirm           # Skip environment confirmation
/build --cmd "pip install -e ." # Custom build command
/build --verbose                # Detailed logs

# ── /test - Function Test ───────────────────────────────────────
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
# Remove global Code QA Agents (12)
rm -rf ~/.config/opencode/.opencode/agent/{env-setup,build-tester,function-tester,code-reviewer,code-fixer,git-input,file-input,git-committer,git-pusher,pre-checker,quality-checker,summary-reporter}.md

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
# Check server status
curl http://localhost:30000/v1/models

# Check environment variable
echo $QWEN_BASE_URL
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

**Solution**: Provide the requested input:
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
| env-setup | Yes | Yes | No | No | Yes | Yes | Environment detection |
| git-input | Yes | Yes | No | No | Yes | No | Git parsing |
| pre-checker | Yes | Yes | No | No | Yes | Yes | Lint/Format |
| code-reviewer | Yes | Yes | No | No | Yes | Yes | Code analysis |
| code-fixer | Yes | Yes | Yes | Yes | Yes | Yes | Code modification |
| quality-checker | Yes | Yes | No | No | Yes | Yes | Quality check |
| build-tester | Yes | Yes | No | No | Yes | No | Build testing |
| function-tester | Yes | Yes | No | No | Yes | Yes | Function testing |
| git-committer | Yes | Yes | No | No | No | No | Git commit |
| summary-reporter | Yes | Yes | No | No | No | No | Report generation |
| git-pusher | Yes | Yes | No | No | No | No | Push/PR |

**Key Permission Notes:**
- **code-fixer**: Only agent with Edit/Write permissions (code modification required)
- **code-reviewer, summary-reporter**: Can analyze file contents with Bash/Read permissions
- **All Agents**: Dangerous commands blocked (rm -rf, git push --force, etc.)

---

## Appendix B: Result Tokens and State Management

### Result Token Format

Each agent outputs tokens in the following format upon completion:

| Agent | Output Token | Example |
|-------|-------------|---------|
| env-setup | `ENV_SETUP_RESULT: SUCCESS/FAIL/WAITING_INPUT` | `ENV_SETUP_RESULT: SUCCESS` |
| git-input | `FILE_LIST: {files}` | `FILE_LIST: src/app.py, src/utils.py` |
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
retry_count = 0              # Regression count (max 3)
quality_score = 0            # Quality score

env_result = ""              # Environment setup result
changed_files = []           # Changed file list
review_issues = []           # Review issue list
fix_result = ""              # Fix result
build_result = ""            # Build result
test_result = ""             # Test result
commit_result = ""           # Commit result
```

### Regression Conditions

| Condition | Action |
|-----------|--------|
| `QUALITY_SCORE < 70` | Regress to STEP 5 (code-fixer) |
| `BUILD_RESULT: FAIL` | Regress to STEP 5 (code-fixer) |
| `TEST_RESULT: FAIL` | Regress to STEP 5 (code-fixer) |
| `retry_count >= 3` | Stop workflow, request manual review |

---

## Appendix C: File Checklist

### Global Config Files (Required)

```
~/.config/opencode/
├── opencode.json                           Provider, Agent settings
└── .opencode/
    ├── agent/                              (12 Agents)
    │   ├── env-setup.md                    Environment setup
    │   ├── git-input.md                    Git input parser
    │   ├── file-input.md                   File input parser (Non-Git)
    │   ├── pre-checker.md                  Lint/Format
    │   ├── code-reviewer.md                Code review
    │   ├── code-fixer.md                   Code fixing
    │   ├── quality-checker.md              Quality check
    │   ├── build-tester.md                 Build testing
    │   ├── function-tester.md              Function testing
    │   ├── git-committer.md                Git commit
    │   ├── summary-reporter.md             Result report
    │   └── git-pusher.md                   Push/PR
    ├── command/                            (8 Commands)
    │   ├── code-qa.md                      Full workflow
    │   ├── env.md                          /env - Environment
    │   ├── lint.md                         /lint - Lint/Format
    │   ├── review.md                       /review - Code review
    │   ├── fix.md                          /fix - Code fixing
    │   ├── quality.md                      /quality - Quality check
    │   ├── build.md                        /build - Build test
    │   └── test.md                         /test - Function test
    └── mode/
        └── code-qa.md                      QA orchestrator
```

### Environment Variables (Required)

```bash
QWEN_BASE_URL="http://localhost:30000/v1"
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

- [05-integrated-configuration.md](./05-integrated-configuration.md) - Complete configuration guide
- [12-environment-setup-workflow.md](./12-environment-setup-workflow.md) - Environment setup details
- [13-code-qa-v4-complete-diagram.md](./13-code-qa-v4-complete-diagram.md) - Full workflow diagram
