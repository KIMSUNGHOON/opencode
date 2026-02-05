# Code QA v4 Complete Workflow Diagram

## Overview

This document provides an integrated diagram of the complete **Code QA v4 Workflow**.

---

## 1. Pipeline Overview

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                    Code QA Workflow v4                                               │
│                            (Environment + Git + Docker Sandbox Integration)                          │
├─────────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                      │
│   ┌──────────────────────────────────────────────────────────────────────────────────────────────┐  │
│   │                                    Host Execution Zone                                        │  │
│   ├──────────────────────────────────────────────────────────────────────────────────────────────┤  │
│   │                                                                                               │  │
│   │  Phase -1        Phase 0         Phase 1         Phase 2         Phase 3         Phase 4     │  │
│   │  ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐    │  │
│   │  │   🔧    │───▶│   📂    │───▶│   ⚡    │───▶│   🔍    │───▶│   🔧    │───▶│   📋    │    │  │
│   │  │   Env   │    │   Git   │    │   Pre   │    │  Review │    │   Fix   │    │ Quality │    │  │
│   │  │  Setup  │    │  Input  │    │  Check  │    │         │    │         │    │  Check  │    │  │
│   │  └─────────┘    └─────────┘    └─────────┘    └─────────┘    └────┬────┘    └────┬────┘    │  │
│   │                                                                   │              │          │  │
│   │                                                                   │◀── Regress ◀─┤ <70%     │  │
│   │                                                                   │   (max 3x)   │          │  │
│   └───────────────────────────────────────────────────────────────────┼──────────────┼──────────┘  │
│                                                                       │              │              │
│   ┌───────────────────────────────────────────────────────────────────┼──────────────┼──────────┐  │
│   │                              Docker Sandbox Zone (default)         │              │          │  │
│   ├───────────────────────────────────────────────────────────────────┼──────────────┼──────────┤  │
│   │                                                                   │              ▼          │  │
│   │  Phase 5                                    Phase 6               │        ┌─────────┐     │  │
│   │  ┌─────────────────────┐                   ┌─────────────────────┐│        │  Build  │     │  │
│   │  │        🏗️           │                   │        🧪           ││◀───────│   🏗️    │     │  │
│   │  │   Build Tester     │──────────────────▶│  Function Tester    ││ Regress└─────────┘     │  │
│   │  │   (GPU Support)     │                   │   (GPU Support)      ││                        │  │
│   │  └─────────────────────┘                   └──────────┬──────────┘│                        │  │
│   │                                                       │           │                        │  │
│   │  ┌─────────────────────────────────────────────────────────────────────────────────────┐  │  │
│   │  │  docker run --gpus all -v $(pwd):/workspace qa-sandbox python -m pytest tests/     │  │  │
│   │  └─────────────────────────────────────────────────────────────────────────────────────┘  │  │
│   │                                                       │           │                        │  │
│   └───────────────────────────────────────────────────────┼───────────┼────────────────────────┘  │
│                                                           │           │                          │
│   ┌───────────────────────────────────────────────────────┼───────────┼────────────────────────┐  │
│   │                                    Host Execution Zone │           │                        │  │
│   ├───────────────────────────────────────────────────────┼───────────┼────────────────────────┤  │
│   │                                                       │  Regress ◀┤ Failed                 │  │
│   │                                                       │           │                        │  │
│   │                                                       ▼           │                        │  │
│   │  Phase 7              Phase 8              Phase 9                │                        │  │
│   │  ┌─────────┐         ┌─────────┐         ┌─────────────────────┐ │                        │  │
│   │  │   📝    │────────▶│   📊    │────────▶│   📤 Push   🔀 PR   │ │                        │  │
│   │  │ Commit  │         │ Summary │         │   (User Confirm Req) │ │                        │  │
│   │  │ /Amend  │         │ Report  │         └─────────────────────┘ │                        │  │
│   │  └─────────┘         └─────────┘                  │               │                        │  │
│   │                                                   ▼               │                        │  │
│   │                                              ┌─────────┐         │                        │  │
│   │                                              │   🎉    │         │                        │  │
│   │                                              │ Complete │         │                        │  │
│   │                                              └─────────┘         │                        │  │
│   └──────────────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Phase Summary Table

| Phase | Agent | Model | Role | Execution Environment |
|-------|-------|-------|------|----------------------|
| **-1** | `@env-setup` | Qwen3-Coder-Next | Shell/conda/venv environment detection | Host |
| **0** | `@git-input` | Qwen3-Coder-Next | Git diff extraction, changed file list | Host |
| **1** | `@pre-checker` | Qwen3-Coder-Next | Auto-fix (lint --fix, format) | Host |
| **2** | `@code-reviewer` | Qwen3-Next-Thinking | Deep code analysis, issue detection (CoT) | Host |
| **3** | `@code-fixer` | Qwen3-Coder-Next | Fix discovered issues (SWE-Bench) | Host |
| **4** | `@quality-checker` | Qwen3-Next-Thinking | Quality score check (≥70%) | Host |
| **5** | `@build-tester` | Qwen3-Coder-Next | Build test (GPU) | **Sandbox** |
| **6** | `@function-tester` | Qwen3-Coder-Next | Function test (GPU) | **Sandbox** |
| **7** | `@git-committer` | Qwen3-Coder-Next | Commit or Amend | Host |
| **8** | `@summary-reporter` | Qwen3-Next-Thinking | Markdown result report (CoT) | Host |
| **9** | `@git-pusher` | Qwen3-Coder-Next | Push & PR creation | Host |

> ⚠️ **Note**: code-reviewer has Read permission only (Glob/Grep/Bash disabled). It can only analyze files explicitly passed by the orchestrator.

### 2.1 Dual Model Strategy

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              Dual Model Strategy                                          │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                          │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │  [Thinking] Qwen3-Next-80B-A3B-Thinking-FP8 (SGLang, port 8000)               │   │
│  │  ──────────────────────────────────────────────────                             │   │
│  │  • Thinking Mode + CoT reasoning specialized (4 agents)                        │   │
│  │  • Applied: Orchestrator, code-reviewer, quality-checker, summary-reporter     │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                          │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │  [Coder] Qwen3-Coder-Next-FP8 (vLLM, port 8001)                               │   │
│  │  ──────────────────────────────────────────────────                             │   │
│  │  • Tool Calling + code generation/modification specialized (10 agents)         │   │
│  │  • Applied: env-setup, git-input, file-input, workspace-analyzer, pre-checker, │   │
│  │    code-fixer, build-tester, function-tester, git-committer, git-pusher        │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                          │
│  ═══════════════════════════════════════════════════════════════════════════════════   │
│                                                                                          │
│   Phase -1  Phase 0   Phase 1   Phase 2   Phase 3   Phase 4   Phase 5-6   Phase 7-9   │
│   ┌─────┐  ┌─────┐   ┌─────┐   ┌─────┐   ┌─────┐   ┌─────┐   ┌───────┐   ┌───────┐   │
│   │Coder│  │Coder│   │Coder│   │Think│   │Coder│   │Think│   │ Coder │   │ Mixed │   │
│   │     │→ │     │ → │     │ → │ ing │ → │     │ → │ ing │ → │       │ → │       │   │
│   └─────┘  └─────┘   └─────┘   └─────┘   └─────┘   └─────┘   └───────┘   └───────┘   │
│    env      git       pre      review     fix      quality   build/test  commit/     │
│   setup    input     check      (CoT)    (SWE)    check      (Coder)    summary     │
│                                                                                          │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Detailed Flowchart

```mermaid
flowchart TB
    START(["code-qa --last"]) --> ENV_SETUP

    subgraph PHASE_NEG1["Phase -1: Environment Setup"]
        ENV_SETUP["env-setup"]
        SHELL["Check Shell"]
        ENV_CHECK["Check Environment"]
        ENV_SELECT{"Select Environment"}
        DOUBLE_CHECK["Double Check"]

        ENV_SETUP --> SHELL --> ENV_CHECK --> ENV_SELECT --> DOUBLE_CHECK
    end

    DOUBLE_CHECK --> GIT_INPUT

    subgraph PHASE_0["Phase 0: Git Input"]
        GIT_INPUT["git-input"]
        PARSE_MODE["Parse Mode"]
        EXTRACT_FILES["Extract Changed Files"]

        GIT_INPUT --> PARSE_MODE --> EXTRACT_FILES
    end

    EXTRACT_FILES --> PRE_CHECK

    subgraph HOST_QA["Phase 1-4: Host QA"]
        PRE_CHECK["pre-checker"]
        CODE_REVIEW["code-reviewer"]
        CODE_FIX["code-fixer"]
        QUALITY["quality-checker"]

        PRE_CHECK --> CODE_REVIEW --> CODE_FIX --> QUALITY
    end

    QUALITY --> Q_CHECK{"≥70%?"}
    Q_CHECK -->|No| RETRY_Q{"Regress <3x?"}
    RETRY_Q -->|Yes| CODE_FIX
    RETRY_Q -->|No| HUMAN["User Intervention"]
    HUMAN --> BUILD_TEST

    Q_CHECK -->|Yes| BUILD_TEST

    subgraph SANDBOX["Phase 5-6: Docker Sandbox"]
        BUILD_TEST["build-tester"]
        FUNC_TEST["function-tester"]

        BUILD_TEST --> B_CHECK{"Success?"}
        B_CHECK -->|Yes| FUNC_TEST
        FUNC_TEST --> T_CHECK{"Pass?"}
    end

    B_CHECK -->|No| CODE_FIX
    T_CHECK -->|No| CODE_FIX

    T_CHECK -->|Yes| COMMIT

    subgraph HOST_GIT["Phase 7-9: Git Operations"]
        COMMIT["git-committer"]
        SUMMARY["summary-reporter"]
        PUSH_PR["git-pusher"]

        COMMIT --> HAS_CHANGE{"Has Changes?"}
        HAS_CHANGE -->|No| SUMMARY
        HAS_CHANGE -->|Yes| COMMIT_MODE{"Input Mode?"}

        COMMIT_MODE -->|Pre-commit| NEW_COMMIT["New Commit"]
        COMMIT_MODE -->|Post-commit| AMEND["amend"]

        NEW_COMMIT --> SUMMARY
        AMEND --> SUMMARY
        SUMMARY --> PUSH_PR
    end

    PUSH_PR --> PUSH_ASK["Push?"]
    PUSH_ASK --> PUSH_CHOICE{"Choice"}
    PUSH_CHOICE -->|No| DONE_LOCAL(["Complete - Local Only"])
    PUSH_CHOICE -->|Yes| DO_PUSH["git push"]

    DO_PUSH --> PR_ASK["Create PR?"]
    PR_ASK --> PR_CHOICE{"Choice"}
    PR_CHOICE -->|No| DONE_PUSH(["Complete - Push Only"])
    PR_CHOICE -->|Yes| CREATE_PR["Create PR"]
    CREATE_PR --> DONE(["Complete!"])

    style PHASE_NEG1 fill:#95A5A622,stroke:#95A5A6
    style PHASE_0 fill:#34495E22,stroke:#34495E
    style HOST_QA fill:#3498DB22,stroke:#3498DB
    style SANDBOX fill:#E67E2222,stroke:#E67E22
    style HOST_GIT fill:#27AE6022,stroke:#27AE60
```

---

## 4. Execution Flow Sequence

```mermaid
sequenceDiagram
    autonumber

    actor User
    participant CMD as code-qa
    participant ENV as env-setup
    participant GIT as git-input
    participant QA as Host QA
    participant SANDBOX as Docker Sandbox
    participant COMMIT as git-committer
    participant REPORT as summary-reporter
    participant PUSH as git-pusher

    User->>CMD: /code-qa --last

    rect rgb(149, 165, 166, 0.2)
        Note over ENV: Phase -1
        CMD->>ENV: Request environment check
        ENV->>ENV: Detect Shell
        ENV->>ENV: Check conda env
        ENV-->>User: Confirm environment usage
        User->>ENV: Yes
        ENV->>ENV: Double check
        ENV-->>CMD: Environment report
    end

    rect rgb(52, 73, 94, 0.2)
        Note over GIT: Phase 0
        CMD->>GIT: Extract Git diff
        GIT->>GIT: git diff HEAD~1
        GIT-->>CMD: 5 changed files
    end

    rect rgb(52, 152, 219, 0.2)
        Note over QA: Phase 1-4
        CMD->>QA: Start QA
        QA->>QA: Pre-Check
        QA->>QA: Code Review
        QA->>QA: Code Fix
        QA->>QA: Quality Check
        QA-->>CMD: QA Complete
    end

    rect rgb(230, 126, 34, 0.2)
        Note over SANDBOX: Phase 5-6
        CMD->>SANDBOX: docker run --gpus all
        SANDBOX->>SANDBOX: Build Test
        SANDBOX->>SANDBOX: Function Test
        SANDBOX-->>CMD: Tests Passed
    end

    rect rgb(39, 174, 96, 0.2)
        Note over COMMIT,REPORT: Phase 7-8
        CMD->>COMMIT: Request commit
        COMMIT->>COMMIT: git commit --amend
        COMMIT-->>CMD: Commit complete
        CMD->>REPORT: Generate report
        REPORT-->>User: Summary Report
    end

    rect rgb(142, 68, 173, 0.2)
        Note over PUSH: Phase 9
        CMD->>PUSH: Request push
        PUSH-->>User: Push?
        User->>PUSH: Yes
        PUSH->>PUSH: git push
        PUSH-->>User: Create PR?
        User->>PUSH: Yes
        PUSH-->>User: PR created
    end

    CMD-->>User: Code QA Complete
```

---

## 5. Input Options Behavior

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                Input Options Behavior                                     │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                          │
│  ┌────────────────────────────────────────┐  ┌────────────────────────────────────────┐ │
│  │         Git Options                    │  │         Sandbox Options                │ │
│  ├────────────────────────────────────────┤  ├────────────────────────────────────────┤ │
│  │                                        │  │                                        │ │
│  │  --working (default)                   │  │  (default)                             │ │
│  │  └─ git diff                           │  │  └─ Run Build/Test in                  │ │
│  │  └─ Pre-commit → New commit            │  │     Docker Sandbox                     │ │
│  │                                        │  │  └─ GPU support (nvidia-docker)        │ │
│  │  --staged                              │  │                                        │ │
│  │  └─ git diff --staged                  │  │  --no-sandbox                          │ │
│  │  └─ Pre-commit → New commit            │  │  └─ Run Build/Test                     │ │
│  │                                        │  │     directly on host                   │ │
│  │  --last                                │  │                                        │ │
│  │  └─ git diff HEAD~1                    │  │                                        │ │
│  │  └─ Post-commit → amend                │  │                                        │ │
│  │                                        │  │                                        │ │
│  │  --branch                              │  │                                        │ │
│  │  └─ git diff main...HEAD               │  │                                        │ │
│  │  └─ Post-commit → amend                │  │                                        │ │
│  │                                        │  │                                        │ │
│  │  --range a..b                          │  │                                        │ │
│  │  └─ git diff a..b                      │  │                                        │ │
│  │  └─ Post-commit → amend                │  │                                        │ │
│  │                                        │  │                                        │ │
│  └────────────────────────────────────────┘  └────────────────────────────────────────┘ │
│                                                                                          │
│  Usage Examples:                                                                         │
│  ┌──────────────────────────────────────────────────────────────────────────────────┐   │
│  │  /code-qa                         # working + Sandbox (default)                  │   │
│  │  /code-qa --staged                # staged + Sandbox                             │   │
│  │  /code-qa --last                  # last commit + Sandbox (amend)                │   │
│  │  /code-qa --last --no-sandbox     # last commit + Host (amend)                   │   │
│  │  /code-qa --branch                # entire branch + Sandbox                      │   │
│  └──────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                          │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 6. Regression Loop Details

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                    Regression Loop System                                 │
├─────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                          │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │  Regression Triggers                                                             │   │
│  │                                                                                  │   │
│  │  1. Quality Check < 70%                                                          │   │
│  │     └─ Regress to @code-fixer (max 3x)                                           │   │
│  │     └─ Request user intervention after 3x                                        │   │
│  │                                                                                  │   │
│  │  2. Build Failed                                                                 │   │
│  │     └─ Regress to @code-fixer                                                    │   │
│  │     └─ Pass build error log                                                      │   │
│  │                                                                                  │   │
│  │  3. Test Failed                                                                  │   │
│  │     └─ Regress to @code-fixer                                                    │   │
│  │     └─ Pass failed test cases                                                    │   │
│  │                                                                                  │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                          │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │  Regression Flow                                                                 │   │
│  │                                                                                  │   │
│  │   @quality-checker ──(< 70%)──▶ @code-fixer ──▶ @quality-checker ──▶ ...        │   │
│  │         │                            ▲                                           │   │
│  │         │                            │                                           │   │
│  │   @build-tester ──(failed)───────────┤                                           │   │
│  │         │                            │                                           │   │
│  │         │                            │                                           │   │
│  │   @function-tester ──(failed)────────┘                                           │   │
│  │                                                                                  │   │
│  └─────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                          │
│  MAX_RETRY = 3                                                                          │
│  QUALITY_THRESHOLD = 70                                                                 │
│                                                                                          │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 7. File Structure

```
project-root/
├── .opencode/
│   ├── agent/
│   │   ├── env-setup.md           # Phase -1: Environment setup
│   │   ├── git-input.md           # Phase 0: Git input
│   │   ├── pre-checker.md         # Phase 1: Auto-fix
│   │   ├── code-reviewer.md       # Phase 2: Code review
│   │   ├── code-fixer.md          # Phase 3: Issue fixing
│   │   ├── quality-checker.md     # Phase 4: Quality check
│   │   ├── build-tester.md        # Phase 5: Build test
│   │   ├── function-tester.md     # Phase 6: Function test
│   │   ├── git-committer.md       # Phase 7: Commit
│   │   ├── summary-reporter.md    # Phase 8: Report
│   │   └── git-pusher.md          # Phase 9: Push & PR
│   │
│   ├── command/
│   │   └── code-qa.md             # /code-qa command
│   │
│   ├── docker/
│   │   └── Dockerfile.sandbox     # Docker Sandbox image
│   │
│   └── env-config.yaml            # Environment config file
│
└── src/
    └── ...
```

---

## 8. Permission Matrix

```
┌──────────────────────────────────────────────────────────────────────────────────────────────┐
│                                      Agent Permission Matrix                                   │
├───────────────────┬───────┬───────┬────────────────┬────────────────┬───────────────────────┤
│ Agent             │ read  │ edit  │ bash (git)     │ bash (other)   │ User Confirm          │
├───────────────────┼───────┼───────┼────────────────┼────────────────┼───────────────────────┤
│ @env-setup        │  ✅   │  ❌   │ ❌             │ echo, conda,   │ On env selection      │
│                   │       │       │                │ python, nvidia │                       │
├───────────────────┼───────┼───────┼────────────────┼────────────────┼───────────────────────┤
│ @git-input        │  ✅   │  ❌   │ diff, status,  │ ❌             │ ❌                    │
│                   │       │       │ log, branch    │                │                       │
├───────────────────┼───────┼───────┼────────────────┼────────────────┼───────────────────────┤
│ @pre-checker      │  ✅   │  ❌   │ diff           │ lint --fix,    │ ❌                    │
│                   │       │       │                │ format         │                       │
├───────────────────┼───────┼───────┼────────────────┼────────────────┼───────────────────────┤
│ @code-reviewer    │  ✅   │  ❌   │ ❌ (Read only!)│ ❌             │ ❌                    │
│ ⚠️ Read only     │       │       │                │                │                       │
├───────────────────┼───────┼───────┼────────────────┼────────────────┼───────────────────────┤
│ @code-fixer       │  ✅   │  ✅   │ diff, status   │ ❌             │ ❌                    │
├───────────────────┼───────┼───────┼────────────────┼────────────────┼───────────────────────┤
│ @quality-checker  │  ✅   │  ❌   │ ❌             │ lint, tsc,     │ ❌                    │
│                   │       │       │                │ format         │                       │
├───────────────────┼───────┼───────┼────────────────┼────────────────┼───────────────────────┤
│ @build-tester     │  ✅   │  ❌   │ ❌             │ build,         │ ✅ Env confirm req    │
│                   │       │       │                │ docker run     │                       │
├───────────────────┼───────┼───────┼────────────────┼────────────────┼───────────────────────┤
│ @function-tester  │  ✅   │  ❌   │ diff           │ test,          │ ✅ Test run confirm   │
│                   │       │       │                │ docker run     │                       │
├───────────────────┼───────┼───────┼────────────────┼────────────────┼───────────────────────┤
│ @git-committer    │  ✅   │  ❌   │ add, commit,   │ ❌             │ ❌                    │
│                   │       │       │ status         │                │                       │
├───────────────────┼───────┼───────┼────────────────┼────────────────┼───────────────────────┤
│ @summary-reporter │  ✅   │  ❌   │ log, diff      │ ❌             │ ❌                    │
├───────────────────┼───────┼───────┼────────────────┼────────────────┼───────────────────────┤
│ @git-pusher       │  ✅   │  ❌   │ push (ask),    │ ❌             │ ✅ Push/PR required   │
│                   │       │       │ branch, remote │                │                       │
└───────────────────┴───────┴───────┴────────────────┴────────────────┴───────────────────────┘
```

---

## 9. Quick Reference

### 9.1 Commonly Used Commands

| Command | Description |
|---------|-------------|
| `/code-qa` | Check working changes (Sandbox default) |
| `/code-qa --staged` | Check staged changes only |
| `/code-qa --last` | Check last commit → amend |
| `/code-qa --branch` | Check entire branch |
| `/code-qa --last --no-sandbox` | Build/Test on host |

### 9.2 Environment Requirements

| Requirement | Description |
|-------------|-------------|
| Docker | Docker Engine installed |
| nvidia-docker | NVIDIA Container Toolkit for GPU |
| CUDA Driver | NVIDIA driver installed on host |

### 9.3 Configuration Files

| File | Location | Purpose |
|------|----------|---------|
| `env-config.yaml` | `.opencode/` | Shell, environment, requirements, Sandbox settings |
| `Dockerfile.sandbox` | `.opencode/docker/` | Sandbox image definition |
| `code-qa.md` | `.opencode/command/` | /code-qa command definition |

---

## Related Documents

- [Environment Setup Details](./12-environment-setup-workflow.md)
- [Code QA v4 Quick Start](./14-code-qa-v4-quick-start.md)
- [Custom Agent Guide](./02-custom-agent-guide.md)
