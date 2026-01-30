---
description: Run tests only
---

Run function/unit tests without full workflow.

## Usage

```
/test                # Run all tests
/test --coverage     # Include coverage report
/test src/auth/      # Test specific directory
```

## Process

1. Run function-tester agent
2. Collect test results
3. Report pass/fail status

## Output

Test report with:
- Pass/fail counts
- Failed test details
- Coverage percentage (if requested)
