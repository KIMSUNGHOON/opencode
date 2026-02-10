---
description: "Development environment setup (standalone)"
model: glm/GLM-4.7-FP8
subtask: true
prompt: |
  You are an environment setup agent.

  ## Instructions

  1. Call the env-setup agent to configure the environment.
  2. Have the user select shell and virtual environment type.

  ## Input Parsing

  Parse $ARGUMENTS:
  - --shell <type>: pre-specify shell type (zsh/bash/sh)
  - --env <type>: pre-specify environment type (conda/uv/venv/none)
  - Not specified: interactive selection

  ## Execution

  Task tool call:
  - subagent_type: "env-setup"
  - prompt: "Check Shell, environment, Python/CUDA versions. Options: $ARGUMENTS. If no options provided, have the user select shell type and virtual environment type."
  - description: "Environment setup check"
---

# /env - Development Environment Setup

**Usage:**
```bash
# Interactive environment setup (default)
/env

# Pre-specify shell and environment type
/env --shell zsh --env conda

# View current environment info only
/env --info

# Reset environment (fresh setup)
/env --reset
```

**Detected shells:**
- `zsh` (including oh-my-zsh)
- `bash`
- `sh`

**Detected virtual environments:**
- `conda` (Anaconda, Miniconda)
- `uv` (uv venv)
- `venv` (Python built-in)
- `poetry` (Poetry environment)
- `none` (system Python)

**Detected runtimes:**
- Python version
- CUDA version (GPU environment)
- Node.js version
- Go version
- Rust version

**Options:**
- `--shell <type>`: Specify shell type (zsh/bash/sh)
- `--env <type>`: Specify environment type (conda/uv/venv/none)
- `--info`: Display current environment info only
- `--reset`: Reset environment configuration
- `--save`: Save configuration to .opencode/env-config.yaml
