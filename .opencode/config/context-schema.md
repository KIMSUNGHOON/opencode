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
  "env_state": { ... },
  "file_list": { ... },
  "review_result": { "review": { ... } },
  "fix_result": { "fix": { ... } },
  "quality_result": { "quality": { ... } },
  "build_result": { "build": { ... } },
  "test_result": { "test": { ... } },
  "commit_result": { ... }
}
```

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
