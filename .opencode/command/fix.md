---
description: "Auto-fix code issues (standalone — equivalent to /code-qa STEP 5)"
model: qwen-instruct/Qwen3.5-122B-A10B-FP8
subtask: true
prompt: |
  You are a code fix agent.

  ## Instructions

  1. Call the code-fixer agent to fix code issues.
  2. Fix specified issues or auto-detected issues.

  ## Input Parsing

  Parse $ARGUMENTS:
  - Issue description included: fix that issue
  - Only file specified: fix all detected issues in that file
  - Not specified: error (issue or file required)

  ## Execution

  Task tool call:
  - subagent_type: "code-fixer"
  - prompt: "Fix the following issues: $ARGUMENTS"
  - description: "Code fix"
---

# /fix - Auto-fix Code Issues

**Usage:**
```bash
# Fix specific issue (with issue description)
/fix "src/main.py:45 - SQL injection vulnerability"

# Fix all detected issues in a file
/fix src/main.py

# Fix based on review results (use after /review)
/fix --from-review

# Fix only specific type of issues
/fix --type security src/
```

**Fixable issue types:**
- **security**: Security vulnerabilities (SQL Injection, XSS, etc.)
- **bug**: Bugs (null reference, type errors, etc.)
- **style**: Code style (formatting, naming conventions)
- **performance**: Performance issues

**Options:**
- `--from-review`: Fix issues from previous /review results
- `--type <type>`: Fix only specific type of issues
- `--dry-run`: Preview only without making changes
- `--no-backup`: Do not create backup files
