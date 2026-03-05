---
name: code-quality
description: Code quality scoring rules — lint tool mappings per language, type-check commands, complexity metrics, and the scoring formula. Load this skill when measuring or improving code quality.
---

# Code Quality Scoring Knowledge Base

Rules and tool mappings for calculating code quality scores. Use the decision tree to select the right tools, then apply the scoring formula.

## Quick Decision Tree: Which Tools to Run

```
Language detected?
├─ Python
│  ├─ Lint:       ruff check <FILES> --output-format=full
│  ├─ Type check: mypy <FILES> --ignore-missing-imports
│  └─ Complexity: radon cc <FILES> -a && radon mi <FILES>
├─ JavaScript
│  ├─ Lint:       npx eslint <FILES> --format=stylish
│  └─ Type check: (N/A unless TypeScript)
├─ TypeScript
│  ├─ Lint:       npx eslint <FILES> --format=stylish
│  └─ Type check: npx tsc --noEmit 2>&1 | grep -F -e "file1" -e "file2"
├─ C/C++
│  ├─ Lint:       cppcheck --enable=all --error-exitcode=1 <FILES>
│  └─ Alt:        clang-tidy <FILES>
├─ Java
│  ├─ Lint:       checkstyle -c /google_checks.xml <FILES>
│  └─ Alt:        pmd check -d <FILES> -R rulesets/java/quickstart.xml
├─ Go
│  ├─ Lint:       go vet <DIRS> && staticcheck <DIRS>
│  └─ Alt:        golangci-lint run <DIRS>
├─ Rust
│  └─ Lint:       cargo clippy 2>&1 | grep -E "<FILES_PATTERN>"
├─ Ruby
│  └─ Lint:       rubocop --format simple <FILES>
├─ PHP
│  ├─ Lint:       phpcs --standard=PSR12 <FILES>
│  └─ Alt:        phpstan analyse <FILES>
├─ Swift
│  └─ Lint:       swiftlint lint <FILES>
└─ Kotlin
   ├─ Lint:       ktlint <FILES>
   └─ Alt:        detekt --input <FILES>
```

## Scope Rules

- ONLY check target files, NEVER the entire project
- Always specify file paths in tool commands
- If a tool is not installed, skip it (don't fail the whole check)
- Max 8 tool calls per quality check session

## Scoring Formula

```
Score = 100 - (Critical × 20) - (High × 10) - (Medium × 5) - (Low × 1)

Minimum score: 0
Maximum score: 100
Pass threshold: 70 (configurable)
```

### Severity Mapping from Tool Output

| Severity | What Counts |
|----------|-------------|
| Critical | Security vulnerabilities, type errors causing crashes |
| High | Potential bugs, severe lint errors (undefined vars, unreachable code) |
| Medium | General lint errors (unused imports, missing return types) |
| Low | Style warnings (line length, naming convention) |

### Tool-Specific Severity Mapping

#### ruff (Python)
```
E1xx-E4xx (syntax/indentation) → Medium
E5xx-E7xx (statement errors)   → High
F4xx (import errors)           → High
F8xx (undefined names)         → High
S1xx-S7xx (security)           → Critical
C9xx (complexity)              → Medium
W (warnings)                   → Low
```

#### eslint (JS/TS)
```
error   → High (or Critical if security-related rule)
warning → Medium
```

#### mypy (Python)
```
error → High
note  → Low
```

#### tsc (TypeScript)
```
TS2xxx (type errors)    → High
TS6xxx (config errors)  → Medium
TS7xxx (strict checks)  → Medium
```

#### cppcheck (C/C++)
```
error       → Critical
warning     → High
style       → Medium
performance → Medium
information → Low
```

#### clippy (Rust)
```
error              → High
warning (deny)     → High
warning (warn)     → Medium
note/help          → Low
```

## Complexity Thresholds (Python radon)

| Metric | Good | Acceptable | Poor |
|--------|------|-----------|------|
| Cyclomatic Complexity (CC) | A-B (1-10) | C (11-20) | D-F (21+) |
| Maintainability Index (MI) | A (20+) | B (10-19) | C (0-9) |

Complexity issues map to severity:
- CC grade D+ → Medium issue per function
- CC grade F → High issue per function
- MI grade C → Medium issue per module

## Output Schema

```json
{
  "quality": {
    "score": 85,
    "status": "PASS",
    "threshold": 70,
    "by_severity": {"critical": 0, "high": 1, "medium": 3, "low": 2},
    "tool_results": [
      {"tool": "ruff", "issues": 3, "available": true},
      {"tool": "mypy", "issues": 1, "available": true},
      {"tool": "radon", "issues": 0, "available": true}
    ],
    "remaining_issues": [
      {
        "severity": "high",
        "tool": "mypy",
        "file": "/absolute/path.py",
        "line": 10,
        "message": "Incompatible type in assignment"
      }
    ]
  }
}
```

## Common Quality Improvement Patterns

| Score Range | Typical Action |
|-------------|---------------|
| 90-100 | Ship it — minor style tweaks optional |
| 70-89 | Fix high-severity items, ship with medium as tech debt |
| 50-69 | Fix critical+high, address worst medium items |
| 0-49 | Significant rework needed — prioritize critical/security |
