---
name: build-test
description: Build testing knowledge — project type detection, build command mappings per language, Docker sandbox patterns, and dependency failure diagnosis. Load this skill when building, testing, or diagnosing build failures.
---

# Build Testing Knowledge Base

Rules for detecting project types, selecting build commands, running builds in Docker sandbox, and diagnosing failures.

## Quick Decision Tree: Project Type Detection

```
Which files exist in project root?
├─ pyproject.toml
│  ├─ [tool.poetry] section → Poetry project
│  ├─ [tool.pdm] section   → PDM project
│  └─ generic               → pip project (pip install -e .)
├─ setup.py (no pyproject.toml) → Legacy setuptools
├─ requirements.txt only → pip install -r requirements.txt
├─ package.json
│  ├─ Has "build" script → npm run build
│  ├─ yarn.lock           → yarn install && yarn build
│  ├─ pnpm-lock.yaml      → pnpm install && pnpm build
│  └─ bun.lockb            → bun install && bun run build
├─ go.mod → Go project (go build ./...)
├─ Cargo.toml → Rust project (cargo build)
├─ CMakeLists.txt → CMake project
├─ Makefile → Make project
├─ pom.xml → Maven project (mvn compile)
├─ build.gradle / build.gradle.kts → Gradle project (./gradlew build)
├─ Gemfile → Ruby project (bundle install)
├─ composer.json → PHP project (composer install)
├─ Package.swift → Swift project (swift build)
└─ *.kt files → Kotlin project
```

## Build Command Reference

| Language | Default Build Command | Verify Command |
|----------|----------------------|----------------|
| Python (pip) | `pip install -e .` | `ls dist/*.whl dist/*.tar.gz` |
| Python (poetry) | `poetry install` | `poetry build && ls dist/` |
| Python (pdm) | `pdm install` | `pdm build && ls dist/` |
| Python (uv) | `uv pip install -e .` | `uv build && ls dist/` |
| Node.js (npm) | `npm install && npm run build` | `ls dist/ build/` |
| Node.js (yarn) | `yarn install && yarn build` | `ls dist/ build/` |
| Node.js (pnpm) | `pnpm install && pnpm build` | `ls dist/ build/` |
| Node.js (bun) | `bun install && bun run build` | `ls dist/ build/` |
| Go | `go build ./...` | `file $(go list -f '{{.Target}}' ./...)` |
| Rust | `cargo build` | `ls target/debug/* target/release/*` |
| C/C++ (CMake) | `mkdir -p build && cd build && cmake .. && make` | `ls build/*.a build/*.so` |
| C/C++ (Make) | `make` | `ls *.o *.a *.so *.out` |
| Java (Maven) | `mvn compile` | `ls target/*.jar target/*.war` |
| Java (Gradle) | `./gradlew build` | `ls build/libs/*.jar` |
| Ruby | `bundle install` | `ls *.gem` |
| PHP | `composer install` | `ls vendor/autoload.php` |
| Swift | `swift build` | `ls .build/debug/* .build/release/*` |

## BUILD_CMD Priority

```
1. Explicit BUILD_CMD from user (highest priority)
   └─ Use exactly as provided
2. Project config (.opencode/build-config.yaml → build_command)
   └─ Use its value
3. Auto-detect from project files (lowest priority)
   └─ Use the table above
```

## Docker Sandbox Mode

### When to Use Sandbox
- Project has `.opencode/docker/Dockerfile.sandbox` or `.opencode/env-config.yaml`
- User explicitly requests sandboxed build
- Build requires specific system dependencies not on host

### Sandbox Commands
```bash
# Check if sandbox image exists
docker images | grep qa-sandbox

# Build sandbox image (if missing)
docker build -t qa-sandbox -f .opencode/docker/Dockerfile.sandbox .

# Run build in sandbox
docker run --rm -v $(pwd):/workspace -w /workspace qa-sandbox {BUILD_CMD}

# GPU projects (add nvidia runtime)
docker run --rm --gpus all -v $(pwd):/workspace -w /workspace qa-sandbox {BUILD_CMD}
```

### When to Skip Sandbox
- No Dockerfile.sandbox found → build on host directly
- Docker not installed → build on host directly
- Missing config is NOT an error — just fall back to host build

## Environment Activation

Always prefix build commands with the environment activation command:

```bash
{ACTIVATE_CMD} && {BUILD_CMD}
```

If ACTIVATE_CMD is missing/empty → run BUILD_CMD directly without prefix.

### Common Activation Commands
| Environment | Activation |
|-------------|-----------|
| Conda | `conda activate {env_name}` |
| Virtualenv | `source {venv_path}/bin/activate` |
| Poetry | `poetry shell` or prefix with `poetry run` |
| nvm | `nvm use {version}` |
| None | (run directly) |

## Dependency Failure Diagnosis

### Detection Patterns

| Language | Error Pattern | Classification |
|----------|-------------|---------------|
| Python | `ModuleNotFoundError`, `ImportError`, `No module named` | FAIL_DEPS |
| Node.js | `Cannot find module`, `MODULE_NOT_FOUND`, `npm ERR! missing` | FAIL_DEPS |
| Go | `cannot find package`, `no required module provides package` | FAIL_DEPS |
| Rust | `error[E0463]: can't find crate`, `failed to load manifest` | FAIL_DEPS |
| Java | `package does not exist`, `ClassNotFoundException` | FAIL_DEPS |
| Ruby | `LoadError`, `cannot load such file` | FAIL_DEPS |
| PHP | `Class not found`, `require(): Failed opening required` | FAIL_DEPS |

### Fix Commands

| Language | Fix Command |
|----------|-------------|
| Python | `pip install -r requirements.txt` or `pip install -e .` |
| Node.js | `npm install` or `yarn install` or `pnpm install` |
| Go | `go mod download` or `go mod tidy` |
| Rust | `cargo fetch` |
| Java (Maven) | `mvn dependency:resolve` |
| Java (Gradle) | `./gradlew dependencies` |
| Ruby | `bundle install` |
| PHP | `composer install` |

## Common Build Failure Patterns

| Error Pattern | Likely Cause | Fix |
|---|---|---|
| `SyntaxError` / `ParseError` | Code syntax issue | Fix the code (code-fixer) |
| `TypeError` / `AttributeError` | Type mismatch in code | Fix the code |
| `Permission denied` | File/dir permission issue | `chmod` or run with correct user |
| `ENOMEM` / `out of memory` | Insufficient memory | Increase memory / optimize build |
| `ENOSPC` / `no space left` | Disk full | Clean build artifacts / free space |
| `Connection refused` / `ETIMEDOUT` | Network issue | Check proxy/firewall, retry |
| `version not found` | Wrong runtime version | Install correct version (nvm, pyenv) |

## Build Result Schema

```json
{
  "build": {
    "status": "SUCCESS|FAIL|FAIL_DEPS",
    "exit_code": 0,
    "tool": "pip|npm|cargo|make|...",
    "duration": "45s",
    "errors": [
      {"file": "/absolute/path.ext", "line": 45, "message": "error description"}
    ]
  }
}
```

## Build Timeout
- Default: 10 minutes
- If build exceeds timeout → report FAIL with timeout message
- Do NOT retry timed-out builds automatically
