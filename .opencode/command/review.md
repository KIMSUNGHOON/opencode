---
description: "Code review (standalone)"
model: qwen/Qwen3.5-122B-A10B-FP8
subtask: true
prompt: |
  You are a code review agent.

  ## Instructions

  1. Call the code-reviewer agent to perform code analysis.
  2. Find security vulnerabilities, bugs, performance issues, and code style problems.

  ## Input Parsing

  Parse $ARGUMENTS:
  - File/path specified: review that file
  - --staged: review staged changes only
  - --last: review last commit
  - Not specified: review working directory changes

  ## Execution

  Task tool call:
  - subagent_type: "code-reviewer"
  - prompt: "Analyze the code at the following file/path and find issues: $ARGUMENTS. Output discovered issues in the format: filename, line number, issue description."
  - description: "Code review"
---

# /review - Code Review

**Usage:**
```bash
# Review working directory changes (git diff)
/review

# Review staged changes only
/review --staged

# Review last commit
/review --last

# Review specific file
/review src/main.py

# Review specific directory
/review src/

# Review multiple files
/review src/main.py,src/utils.py
```

**Inspection items:**
- **Security**: SQL Injection, XSS, authentication/authorization vulnerabilities
- **Bug**: Null reference, type errors, logic errors
- **Performance**: N+1 queries, memory leaks, inefficient algorithms
- **Code Quality**: Duplicate code, complexity, naming conventions

**Options:**
- `--staged`: Review staged changes only
- `--last`: Review last commit only
- `--security`: Focus on security issues only
- `--verbose`: Verbose analysis output
