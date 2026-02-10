# Agent Context Schema (P0: Structured Context Passing)

This document defines the JSON schemas used for structured data exchange between agents.
All agents MUST output their result token followed by a JSON block matching these schemas.
The Orchestrator (code-qa) parses this JSON and passes relevant portions to downstream agents.

---

## Why Structured Context Matters

1. **Prevents data loss** — Text tokens can be ambiguous; JSON is unambiguous
2. **Enables regression tracking** — The Orchestrator can store and compare across attempts
3. **Downstream agents get precise data** — No guessing or re-parsing needed

---

## Schema Definitions

### env-setup Output

```json
{
  "env_state": {
    "shell_type": "zsh",
    "env_type": "conda",
    "env_name": "ml-dev",
    "env_path": "/home/user/miniconda3/envs/ml-dev",
    "activate_cmd": "source ~/miniconda3/etc/profile.d/conda.sh && conda activate ml-dev",
    "python_path": "/home/user/miniconda3/envs/ml-dev/bin/python",
    "python_version": "3.11.5",
    "cuda_version": "12.1"
  }
}
```

**Required fields:** `shell_type`, `env_type`, `activate_cmd`
**Optional fields:** `env_name`, `env_path`, `python_path`, `python_version`, `cuda_version`

---

### workspace-analyzer Output

```json
{
  "workspace": {
    "project": {
      "name": "myproject",
      "type": "python",
      "languages": ["python", "shell"],
      "frameworks": ["fastapi", "sqlalchemy"]
    },
    "structure": {
      "root": "/home/user/myproject",
      "src_dir": "/home/user/myproject/src",
      "test_dir": "/home/user/myproject/tests",
      "total_files": 245,
      "code_files": 180
    },
    "build_system": {
      "type": "pip",
      "config_file": "pyproject.toml",
      "build_command": "pip install -e .",
      "test_command": "pytest"
    },
    "analyzed_at": "2025-01-15T10:30:00Z"
  }
}
```

**Required fields:** `project.name`, `project.type`, `structure.root`
**Optional fields:** All others (populated when detectable)

---

### git-input Output

```json
{
  "git_input": {
    "mode": "working",
    "branch": "feature/add-auth",
    "base_branch": "main",
    "files": [
      { "path": "/absolute/path/to/file.py", "status": "M" },
      { "path": "/absolute/path/to/new_file.py", "status": "A" }
    ],
    "deleted_files": [
      { "path": "/absolute/path/to/removed.py", "status": "D" }
    ],
    "total_files": 3,
    "code_files": 2
  }
}
```

**Required fields:** `mode`, `files`
**Optional fields:** `branch`, `base_branch`, `deleted_files`, `total_files`, `code_files`

---

### file-input Output

Alternative to git-input for direct file mode (`--files`). Uses same `file_list` storage slot.

```json
{
  "file_input": {
    "mode": "direct",
    "files": [
      { "path": "/absolute/path/to/file.py", "status": "F" }
    ],
    "total_files": 1,
    "code_files": 1
  }
}
```

**Required fields:** `mode`, `files`
**Note:** `status` is always `"F"` (file) for direct input since there is no git status.

---

### pre-checker Output

```json
{
  "pre_check": {
    "status": "SUCCESS",
    "tools_run": [
      { "tool": "ruff", "action": "format", "files_changed": 2 },
      { "tool": "ruff", "action": "check --fix", "issues_fixed": 5 }
    ],
    "files_modified": ["/absolute/path/file1.py", "/absolute/path/file2.py"],
    "total_fixes": 7
  }
}
```

**Required fields:** `status`
**Optional fields:** `tools_run`, `files_modified`, `total_fixes`

---

### code-reviewer Output

```json
{
  "review": {
    "summary": {
      "files": 3,
      "issues": 7,
      "by_severity": { "critical": 1, "high": 2, "medium": 3, "low": 1 }
    },
    "issues": [
      {
        "id": "C001",
        "severity": "critical",
        "category": "security",
        "file": "/absolute/path/to/file.py",
        "line": 45,
        "title": "SQL Injection Vulnerability",
        "description": "User input directly inserted into SQL query",
        "suggestion": "Use parameterized query"
      }
    ]
  }
}
```

**Required fields per issue:** `id`, `severity`, `file`, `line`, `title`, `suggestion`
**Optional fields:** `category`, `description`

---

### code-fixer Output

```json
{
  "fix": {
    "summary": { "total": 7, "fixed": 6, "skipped": 1, "failed": 0 },
    "fixed_issues": ["C001", "H001", "H002"],
    "skipped_issues": [
      { "id": "L001", "reason": "Low priority, no functional impact" }
    ],
    "failed_issues": [
      { "id": "M003", "reason": "Cannot determine correct fix without more context" }
    ],
    "files_modified": ["/absolute/path/file1.py", "/absolute/path/file2.py"],
    "changes_applied": [
      {
        "issue_id": "C001",
        "file": "/absolute/path/file1.py",
        "line": 45,
        "description": "Changed to parameterized query"
      }
    ]
  }
}
```

**Required fields:** `summary`, `fixed_issues`, `files_modified`
**Optional fields:** `skipped_issues`, `failed_issues`, `changes_applied`

---

### quality-checker Output

```json
{
  "quality": {
    "score": 85,
    "status": "PASS",
    "by_severity": { "critical": 0, "high": 1, "medium": 3, "low": 2 },
    "tool_results": [
      { "tool": "ruff", "issues": 3, "available": true },
      { "tool": "mypy", "issues": 1, "available": true }
    ],
    "remaining_issues": [
      {
        "severity": "high",
        "tool": "mypy",
        "file": "/absolute/path.py",
        "line": 10,
        "message": "Incompatible return value type"
      }
    ]
  }
}
```

**Required fields:** `score`, `status`
**Critical on FAIL:** `remaining_issues` (used for regression context)

---

### build-tester Output

```json
{
  "build": {
    "status": "SUCCESS",
    "exit_code": 0,
    "tool": "npm",
    "duration": "12.5s",
    "errors": []
  }
}
```

**On failure:**
```json
{
  "build": {
    "status": "FAIL",
    "exit_code": 1,
    "tool": "tsc",
    "errors": [
      {
        "file": "/absolute/path/calculator.ts",
        "line": 45,
        "message": "TS2345: Argument of type 'string' is not assignable"
      }
    ]
  }
}
```

**Required fields:** `status`, `exit_code`
**Critical on FAIL:** `errors` (used for regression context)

---

### function-tester Output

```json
{
  "test": {
    "status": "SUCCESS",
    "total": 45,
    "passed": 45,
    "failed": 0,
    "skipped": 0,
    "coverage": 87,
    "failed_tests": []
  }
}
```

**On failure:**
```json
{
  "test": {
    "status": "FAIL",
    "total": 45,
    "passed": 42,
    "failed": 3,
    "skipped": 0,
    "coverage": 82,
    "failed_tests": [
      {
        "name": "test_auth_login",
        "file": "/absolute/path/test_auth.py",
        "line": 23,
        "error": "AssertionError: expected 200 but got 401"
      }
    ]
  }
}
```

**Required fields:** `status`, `total`, `passed`, `failed`
**Critical on FAIL:** `failed_tests` (used for regression context)

---

### git-committer Output

```json
{
  "commit": {
    "status": "SUCCESS",
    "hash": "a1b2c3d",
    "message": "fix: resolve SQL injection vulnerability",
    "files_committed": ["/absolute/path/file1.py", "/absolute/path/file2.py"],
    "branch": "feature/add-auth"
  }
}
```

**Required fields:** `status`
**On SUCCESS:** `hash`, `message`, `files_committed`
**On SKIPPED/NO_CHANGES:** only `status` required

---

### git-pusher Output

```json
{
  "push": {
    "status": "SUCCESS",
    "remote": "origin",
    "branch": "feature/add-auth",
    "pr_url": "https://github.com/user/repo/pull/42",
    "pr_created": true
  }
}
```

**Required fields:** `status`
**On SUCCESS:** `remote`, `branch`
**Optional fields:** `pr_url`, `pr_created`

---

## Regression History Entry Schema

Each entry in `regression_history`:

```json
{
  "attempt": 1,
  "source": "quality",
  "issues_or_errors": [
    { "severity": "high", "file": "/path.py", "line": 10, "message": "..." }
  ],
  "fix_result": {
    "summary": { "total": 3, "fixed": 3, "skipped": 0, "failed": 0 },
    "files_modified": ["/path.py"],
    "changes_applied": [...]
  },
  "files_modified": ["/path.py"]
}
```

---

## Orchestrator Context Store

The Orchestrator maintains a `context_store` dict that accumulates all agent outputs:

```json
{
  "workspace_cache": { "workspace": { ... } },
  "env_state": { "env_state": { ... } },
  "file_list": { "git_input": { ... } },
  "pre_check_result": { "pre_check": { ... } },
  "review_result": { "review": { ... } },
  "fix_result": { "fix": { ... } },
  "quality_result": { "quality": { ... } },
  "build_result": { "build": { ... } },
  "test_result": { "test": { ... } },
  "commit_result": { "commit": { ... } },
  "push_result": { "push": { ... } }
}
```

**Single Source of Truth:** All agents use a single model `glm/GLM-4.7-FP8`, defined in `workflow-settings.yaml` under `model.assignment`. The `model:` field in each agent's YAML frontmatter MUST be set to `glm/GLM-4.7-FP8` and match the assignment in `workflow-settings.yaml`. If they differ, `workflow-settings.yaml` is authoritative for documentation/validation purposes. There is no distinction between "Thinking" and "Coder" models — every agent runs on the same `glm/GLM-4.7-FP8` model.

**Note:** At runtime, OpenCode reads the `model:` field from each agent's YAML frontmatter directly — it does NOT read `workflow-settings.yaml`. Therefore, both files must be kept in sync. The test script (`test-workflow.sh`) validates this consistency.

When passing context to downstream agents, the Orchestrator includes relevant portions of this store in the prompt.

---

## Explicit Error Format (P2-2: No Silent Failures)

All failures MUST produce an explicit error block instead of failing silently.
When an agent encounters an error, it MUST output the following JSON format:

```json
{
  "error": {
    "code": "E004",
    "type": "PARSE",
    "agent": "quality-checker",
    "phase": 4,
    "message": "Failed to parse quality score from tool output",
    "details": "ruff returned exit code 2: config file not found",
    "recovery": "retry_with_defaults"
  }
}
```

**Required fields:** `code`, `type`, `agent`, `message`
**Optional fields:** `phase`, `details`, `recovery`

### Error Types and Orchestrator Responses

| Error Code | Type | Orchestrator Action |
|------------|------|-------------------|
| `E001` | TIMEOUT | Retry (max 3x), then abort |
| `E002` | NETWORK | Retry with backoff, then abort |
| `E003` | OOM | Reduce context by 50%, retry 1x |
| `E004` | PARSE | Re-call agent (max 2x), then use default |
| `E005` | TOOL_DENIED | Log error, ask user for permission |
| `E010` | AGENT_ERROR | Retry (max 2x), then abort |

### Cache Validation Errors (STEP 0)

When workspace cache read fails, the Orchestrator MUST handle explicitly:

```
IF cache file exists but JSON is corrupt:
    → Output: "⚠️ WARNING [E004]: Workspace cache is corrupt. Re-running analysis."
    → Delete corrupt cache, run workspace-analyzer

IF cache timestamp cannot be parsed:
    → Output: "⚠️ WARNING [E004]: Cache timestamp invalid. Re-running analysis."
    → Treat as stale, run workspace-analyzer

IF cache read returns permission error:
    → Output: "⚠️ WARNING [E005]: Cannot read cache file. Proceeding without cache."
    → workspace_cache = null, continue workflow
```

### Permission Template Lookup Errors

When an agent's permission template is not found:

```
IF agent references undefined template:
    → Output: "❌ ERROR [E010]: Permission template '{name}' not found for agent '{agent}'."
    → Do NOT silently default to empty permissions
    → Abort the agent call, log the error

IF template extends a non-existent base:
    → Output: "❌ ERROR [E010]: Base template '{base}' not found in extends chain."
    → Use only the templates that DO exist, warn about missing ones
```

### Model Routing Errors

When model server is unreachable during workflow:

```
IF agent call fails with connection error:
    → Output: "⚠️ WARNING [E002]: Model server unreachable for agent '{agent}'."
    → Check fallback server availability
    → IF fallback available: retry with fallback, log degraded mode
    → IF no fallback: output "❌ ERROR [E002]: No model servers available." and abort
```
