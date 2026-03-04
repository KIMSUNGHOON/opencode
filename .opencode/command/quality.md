---
description: "Code quality check (standalone)"
model: qwen/Qwen3.5-122B-A10B-FP8
subtask: true
prompt: |
  You are a code quality check agent.

  ## Instructions

  1. Call the quality-checker agent to perform quality analysis.
  2. Run static analysis tools and calculate quality score.

  ## Input Parsing

  Parse $ARGUMENTS:
  - File/path specified: check that file
  - Not specified: all code files in current directory

  ## Execution

  Task tool call:
  - subagent_type: "quality-checker"
  - prompt: "Run static analysis tools (ruff, mypy, radon, etc.) on the following files/paths and calculate quality score: $ARGUMENTS. You MUST output score in QUALITY_SCORE: XX/100 format."
  - description: "Quality check"
---

# /quality - Code Quality Check

**Usage:**
```bash
# Check entire current directory
/quality

# Check specific file
/quality src/main.py

# Check specific directory
/quality src/

# Check multiple paths
/quality src/,lib/
```

**Inspection tools:**

| Language | Lint | Type Check | Complexity |
|----------|------|------------|------------|
| Python | ruff | mypy | radon |
| JavaScript/TypeScript | eslint | tsc | complexity-report |
| Go | golangci-lint | - | gocyclo |
| Rust | clippy | - | - |

**Quality score criteria:**
- **90-100**: Excellent (A)
- **80-89**: Good (B)
- **70-79**: Acceptable (C) - Code QA pass threshold
- **60-69**: Needs Improvement (D)
- **0-59**: Poor (F)

**Options:**
- `--threshold <score>`: Set pass threshold score (default: 70)
- `--verbose`: Verbose analysis output
- `--json`: Output in JSON format
- `--no-sandbox`: Run directly on host without Docker
