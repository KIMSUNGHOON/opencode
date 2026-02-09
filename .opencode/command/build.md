---
description: "Build test (standalone)"
model: qwen-coder/Qwen3-Coder-Next-FP8
subtask: true
prompt: |
  You are a build test agent.

  ## Instructions

  1. Call the build-tester agent to run the build.
  2. Show current environment info and proceed with build after user confirmation.

  ## Input Parsing

  Parse $ARGUMENTS:
  - --no-sandbox: build directly on host
  - --skip-confirm: skip environment confirmation
  - --cmd <command>: use this as the build command (passed as BUILD_CMD to build-tester)
  - Not specified: build in Docker Sandbox with auto-detected build command

  ## Execution

  Extract the --cmd value from $ARGUMENTS if present. Include it as BUILD_CMD in the prompt.

  Task tool call:
  - subagent_type: "build-tester"
  - prompt: "Run build test. Show current environment status and proceed with build only after user confirmation. Options: $ARGUMENTS" + (if --cmd was provided: "\nBUILD_CMD: <the command value>")
  - description: "Build test"
---

# /build - Build Test

**Usage:**
```bash
# Build in Docker Sandbox (default, auto-detects build system)
/build

# Build directly on host
/build --no-sandbox

# Skip environment confirmation
/build --skip-confirm

# Run specific build command (overrides auto-detection)
/build --cmd "pip install -e ."
/build --cmd "python setup.py build"
/build --cmd "pip install ."
/build --cmd "python -m build"
/build --cmd "uv pip install -e ."
/build --cmd "poetry install"
```

**Auto-detected build systems (used when --cmd is not specified):**

| Language | Build System | Default Build Command |
|----------|-------------|----------------------|
| Python | pip/setuptools (pyproject.toml) | `pip install -e .` |
| Python | setuptools (setup.py only) | `pip install -e .` |
| Python | poetry | `poetry install` |
| Python | pdm | `pdm install` |
| JavaScript | npm | `npm install && npm run build` |
| JavaScript | yarn | `yarn install && yarn build` |
| Go | go mod | `go build ./...` |
| Rust | cargo | `cargo build` |
| Java | maven | `mvn compile` |
| Java | gradle | `./gradlew build` |
| C/C++ | cmake | `cmake . && make` |
| C/C++ | make | `make` |

**Options:**
- `--no-sandbox`: Build directly on host without Docker
- `--skip-confirm`: Skip environment confirmation step
- `--cmd <command>`: Run custom build command (overrides auto-detection)
- `--verbose`: Verbose build log output

**Project-level config (`.opencode/build-config.yaml`):**
```yaml
# Set a default build command for this project
build_command: "python setup.py build"
```
When set, this is used instead of auto-detection. `--cmd` still takes highest priority.
