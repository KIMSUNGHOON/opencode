---
description: "Code QA Workflow (full automated pipeline)"
model: qwen-instruct/Qwen3.5-122B-A10B-FP8
subtask: true
prompt: |
  You are the Code QA workflow orchestrator.

  ## Instructions

  Execute the full Code QA workflow as defined in mode/code-qa.
  Follow the 11-step execution checklist. Do NOT stop until complete.

  ## Input

  Parse $ARGUMENTS for options:
  - (default): review working directory changes (git diff)
  - --staged: staged changes only
  - --last: last commit
  - --branch: branch diff
  - --range <a>..<b>: commit range
  - --files <path>: direct file mode (skip git steps)
  - --no-sandbox: run on host
  - --skip-cache: skip workspace analysis cache

  ## CRITICAL: SILENT TOOL CALLING

  When calling Task, output ONLY the STEP label then make the tool call.
  No preamble, no narration, no echoing parameters.

  WRONG: "Now calling env-setup agent..." → tool call
  RIGHT: "STEP 1: Environment Setup" → tool call
---

# /code-qa - Full Code QA Workflow

Runs the complete automated Code QA pipeline (11 steps).
The full workflow definition lives in `mode/code-qa.md` (single source of truth).

**Usage:**
```bash
# Review and fix working directory changes
/code-qa

# Staged changes only
/code-qa --staged

# Last commit
/code-qa --last

# Branch diff
/code-qa --branch

# Specific files (skip git steps)
/code-qa --files src/main.py

# Skip workspace cache
/code-qa --skip-cache
```

**Steps:** env-setup → git-input → pre-check → review → fix → quality → build → test → commit → report → push
