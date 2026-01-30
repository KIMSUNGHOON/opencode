---
description: Run full Code QA workflow
---

Run the complete Code QA workflow on the current changes.

## Input modes

Analyze based on user request:
- `--working` - Unstaged changes (git diff)
- `--staged` - Staged changes (git diff --cached)
- `--last` - Last commit (git show HEAD)
- `--branch <base>` - Branch diff (git diff base...HEAD)

Default: `--staged` if staged changes exist, else `--working`

## Workflow phases

Execute in order:

1. **Pre-Check** (pre-checker agent)
   - Quick lint/format check
   - Auto-fix simple issues
   - If issues remain → Code Review

2. **Code Review** (code-reviewer agent)
   - Deep analysis of changes
   - Identify issues and improvements
   - Generate review comments

3. **Code Fix** (code-fixer agent)
   - Apply review suggestions
   - Fix identified issues

4. **Quality Check** (quality-checker agent)
   - Run lint, type check, format
   - Calculate quality score
   - If score < 70% and retry < 3 → Code Review
   - If score < 70% and retry >= 3 → Report to user

5. **Build Test** (build-tester agent)
   - Run build command
   - If fail and retry < 3 → Code Fix
   - If fail and retry >= 3 → Report to user

6. **Function Test** (function-tester agent)
   - Run test suite
   - If fail and retry < 3 → Code Fix
   - If fail and retry >= 3 → Report to user

7. **Git Commit** (git-committer agent)
   - Create or amend commit
   - New commit for pre-commit QA
   - Amend for post-commit QA

8. **Summary Report** (summary-reporter agent)
   - Generate Markdown report
   - Show all phase results
   - Display quality metrics

## Usage

```
/code-qa              # Auto-detect changes
/code-qa --staged     # Only staged changes
/code-qa --last       # Review last commit
/code-qa --branch main # Compare to main
```

## Output

Final summary report with:
- All phase results
- Quality metrics
- Changed files
- Retry history
- Next steps (Push/PR options)
