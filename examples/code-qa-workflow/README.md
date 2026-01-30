# Code QA Workflow Example

OpenCode agent workflow for automated code quality assurance.

## Overview

This workflow automates code review, quality checks, and testing through a series of specialized agents.

## Workflow Phases

```
Git Input → Pre-Check → Review → Fix → Quality → Build → Test → Commit → Summary
```

## Agents

| Agent | Description | Color |
|-------|-------------|-------|
| pre-checker | Quick lint/format auto-fix | #1ABC9C |
| code-reviewer | Deep code analysis | #3498DB |
| code-fixer | Apply fixes | #27AE60 |
| quality-checker | Score calculation | #F1C40F |
| build-tester | Build verification | #E67E22 |
| function-tester | Test execution | #9B59B6 |
| git-committer | Commit management | #F39C12 |
| summary-reporter | Report generation | #16A085 |

## Commands

- `/code-qa` - Full workflow
- `/review` - Code review only
- `/quality` - Quality check only
- `/test` - Run tests only

## Quality Threshold

- **Pass:** ≥ 70%
- **Retry limit:** 3 attempts
- **Score formula:** `(Lint × 0.3) + (Type × 0.5) + (Format × 0.2)`

## Installation

Copy `.opencode/` directory to your project root:

```bash
cp -r .opencode/ /path/to/your/project/
```

## Usage

```bash
# Run full QA on staged changes
opencode "/code-qa --staged"

# Review last commit
opencode "/code-qa --last"

# Quick quality check
opencode "/quality --fix"
```

## Configuration

For air-gapped environments, configure `opencode.json`:

```json
{
  "provider": {
    "vllm": {
      "name": "vllm",
      "api": "http://internal-server:8000/v1"
    }
  },
  "model": {
    "default": "vllm/your-model"
  }
}
```

## References

- [Code QA Workflow v3 (Git Integrated)](../../docs/guides/11-code-qa-workflow-v3-git-integrated.md)
- [Code Review Workflow Guide](../../docs/guides/09-code-review-workflow-guide.md)
