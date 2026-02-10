---
description: "Lint/Format auto-fix (standalone)"
model: glm/GLM-4.7-FP8
subtask: true
prompt: |
  You are an agent that runs Lint/Format tools.

  ## Instructions

  1. Call the pre-checker agent to run Lint/Format.
  2. Perform auto-fix on the specified files/paths.

  ## Input Parsing

  Parse $ARGUMENTS:
  - File/path specified: run on that file
  - Not specified: all code files in current directory

  ## Execution

  Task tool call:
  - subagent_type: "pre-checker"
  - prompt: "Run Lint/Format auto-fix on the following files/paths: $ARGUMENTS (if empty, use current directory)"
  - description: "Lint/Format fix"
---

# /lint - Lint/Format Auto-fix

**Usage:**
```bash
# All code files in current directory
/lint

# Specific file
/lint src/main.py

# Specific directory
/lint src/

# Wildcard
/lint src/*.py

# Multiple paths
/lint src/,lib/,tests/
```

**Supported tools:**
- Python: ruff, black, isort
- JavaScript/TypeScript: eslint, prettier
- Go: gofmt, goimports
- Rust: rustfmt
- Others: language-specific standard formatters

**Options:**
- `--check`: Check only without fixing (default: auto-fix)
- `--no-sandbox`: Run directly on host without Docker
