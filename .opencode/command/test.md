---
description: "Function test (standalone — equivalent to /code-qa STEP 8)"
model: qwen-instruct/Qwen3.5-122B-A10B-FP8
subtask: true
prompt: |
  You are a function test agent.

  ## Instructions

  1. Call the function-tester agent to run tests.
  2. Detect test files and run tests after user confirmation.

  ## Input Parsing

  Parse $ARGUMENTS:
  - Test path specified: run only that test
  - --no-sandbox: run directly on host
  - --skip-confirm: skip test confirmation
  - --coverage: generate coverage report
  - Not specified: detect and run all tests

  ## Execution

  Task tool call:
  - subagent_type: "function-tester"
  - prompt: "Run function tests. Detect test files and proceed after user confirmation. Options: $ARGUMENTS"
  - description: "Function test"
---

# /test - Function Test

**Usage:**
```bash
# Detect and run all tests (default)
/test

# Run specific test file
/test tests/test_main.py

# Run specific test function
/test tests/test_main.py::test_function

# Run tests for specific language only
/test --lang python

# Include coverage report
/test --coverage

# Run directly on host
/test --no-sandbox
```

**Auto-detected test frameworks:**

| Language | Framework | Detection Pattern |
|----------|-----------|-------------------|
| Python | pytest | `tests/`, `test_*.py`, `*_test.py` |
| Python | unittest | `tests/`, `test_*.py` |
| JavaScript | jest | `__tests__/`, `*.test.js`, `*.spec.js` |
| TypeScript | jest | `__tests__/`, `*.test.ts`, `*.spec.ts` |
| Go | go test | `*_test.go` |
| Rust | cargo test | `tests/`, `src/**/test*.rs` |
| Java | JUnit | `src/test/`, `*Test.java` |
| Ruby | RSpec | `spec/`, `*_spec.rb` |
| PHP | PHPUnit | `tests/`, `*Test.php` |

**Options:**
- `--no-sandbox`: Run directly on host without Docker
- `--skip-confirm`: Skip test confirmation step
- `--coverage`: Generate coverage report
- `--lang <language>`: Run tests for specific language only
- `--verbose`: Verbose test log output
- `--fail-fast`: Stop at first failure
