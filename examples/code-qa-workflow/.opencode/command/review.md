---
description: Run code review only
---

Run code review analysis without the full QA workflow.

## Usage

```
/review              # Review current changes
/review --staged     # Review staged changes only
/review --last       # Review last commit
```

## Process

1. Get target changes (diff or commit)
2. Run code-reviewer agent
3. Output review comments

## Output

Review findings with:
- Issues categorized by severity
- Suggestions for improvement
- Security concerns if any
