---
description: Run quality check only
---

Run quality checks (lint, type, format) without full workflow.

## Usage

```
/quality             # Check all files
/quality src/        # Check specific directory
/quality --fix       # Auto-fix issues
```

## Process

1. Run quality-checker agent
2. Calculate scores
3. Report results

## Output

Quality report with:
- Lint score and issues
- Type check results
- Format compliance
- Overall quality percentage
