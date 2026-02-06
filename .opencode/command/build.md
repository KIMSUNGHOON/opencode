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
  - Not specified: build in Docker Sandbox

  ## Execution

  Task tool call:
  - subagent_type: "build-tester"
  - prompt: "Run build test. Show current environment status and proceed with build only after user confirmation. Options: $ARGUMENTS"
  - description: "Build test"
---

# /build - Build Test

**Usage:**
```bash
# Build in Docker Sandbox (default)
/build

# Build directly on host
/build --no-sandbox

# Skip environment confirmation
/build --skip-confirm

# Run specific build command
/build --cmd "pip install -e ."
```

**Auto-detected build systems:**

| Language | Build System | Build Command |
|----------|-------------|---------------|
| Python | pip/setuptools | `pip install -e .` |
| Python | poetry | `poetry install` |
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
- `--cmd <command>`: Run custom build command
- `--verbose`: Verbose build log output
