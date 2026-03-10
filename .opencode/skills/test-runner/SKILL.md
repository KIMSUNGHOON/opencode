---
name: test-runner
description: Test suite execution and report generation knowledge — framework detection, test execution patterns, result parsing, coverage analysis, and structured report generation. Load this skill when running tests, analyzing test results, or generating test reports.
---

# Test Runner Knowledge Base

Rules for detecting test frameworks, executing test suites, parsing results, and generating comprehensive test reports.

## Quick Decision Tree: Test Framework Detection

```
Which files/directories exist in project root?
├─ pytest.ini / pyproject.toml [tool.pytest] / conftest.py / setup.cfg [tool:pytest]
│  └─ pytest project → python -m pytest
├─ test_*.py / *_test.py files (no pytest config)
│  └─ unittest project → python -m unittest discover
├─ jest.config.{js,ts,cjs,mjs} / package.json "jest" key
│  └─ Jest project → npx jest
├─ vitest.config.{js,ts} / package.json "vitest" in devDeps
│  └─ Vitest project → npx vitest run
├─ .mocharc.{yml,json,js} / package.json "mocha" key
│  └─ Mocha project → npx mocha
├─ karma.conf.js
│  └─ Karma project → npx karma start --single-run
├─ go.mod + *_test.go files
│  └─ Go project → go test ./...
├─ Cargo.toml + #[cfg(test)] or tests/ dir
│  └─ Rust project → cargo test
├─ pom.xml + src/test/
│  └─ Maven project → mvn test
├─ build.gradle + src/test/
│  └─ Gradle project → ./gradlew test
├─ Gemfile + spec/ or test/
│  └─ Ruby project → bundle exec rspec or rake test
├─ phpunit.xml
│  └─ PHP project → ./vendor/bin/phpunit
├─ Package.swift + Tests/
│  └─ Swift project → swift test
└─ CMakeLists.txt + enable_testing()
   └─ CTest project → cd build && ctest
```

## Test Execution Commands

### Python

| Framework | Run Command | With Coverage | Report Flags |
|-----------|-------------|---------------|--------------|
| pytest | `python -m pytest tests/ -v --tb=short` | `--cov=src --cov-report=term-missing --cov-report=html:reports/coverage` | `--junitxml=reports/test-results.xml` |
| unittest | `python -m unittest discover -s tests -v` | `coverage run -m unittest discover -s tests && coverage report -m` | (no built-in XML) |
| nose2 | `nose2 -v` | `nose2 --with-coverage` | `--plugin nose2.plugins.junitxml --junit-xml` |

**pytest markers & filtering:**
```bash
# Run specific markers
python -m pytest -m "not slow" tests/
# Run specific test file
python -m pytest tests/test_auth.py -v
# Run specific test function
python -m pytest tests/test_auth.py::test_login -v
# Run with keyword filter
python -m pytest -k "login or signup" tests/
# Parallel execution
python -m pytest -n auto tests/  # requires pytest-xdist
```

### JavaScript / TypeScript

| Framework | Run Command | With Coverage | Report Flags |
|-----------|-------------|---------------|--------------|
| Jest | `npx jest --verbose` | `npx jest --coverage` | `--json --outputFile=reports/test-results.json` |
| Vitest | `npx vitest run` | `npx vitest run --coverage` | `--reporter=json --outputFile=reports/test-results.json` |
| Mocha | `npx mocha --recursive` | `npx nyc mocha --recursive` | `--reporter mocha-junit-reporter` |

### Go

```bash
# Basic
go test -v ./...
# With coverage
go test -v -cover -coverprofile=reports/coverage.out ./...
# Coverage report
go tool cover -func=reports/coverage.out
go tool cover -html=reports/coverage.out -o reports/coverage.html
# JSON output
go test -v -json ./... > reports/test-results.json
# Race detection
go test -v -race ./...
# Specific package
go test -v ./pkg/auth/...
```

### Rust

```bash
# Basic
cargo test --verbose
# With output capture disabled (show println!)
cargo test --verbose -- --nocapture
# Specific test
cargo test test_name --verbose
# With coverage (requires cargo-tarpaulin)
cargo tarpaulin --out html --output-dir reports/
# JSON output (unstable)
cargo test --verbose -- -Z unstable-options --format json
```

### Java

| Build Tool | Run Command | Report Location |
|------------|-------------|-----------------|
| Maven | `mvn test -Dmaven.test.failure.ignore=true` | `target/surefire-reports/` |
| Gradle | `./gradlew test --continue` | `build/reports/tests/test/index.html` |

### Ruby

```bash
# RSpec
bundle exec rspec --format documentation --format json --out reports/test-results.json
# minitest
rake test TESTOPTS="-v"
```

### PHP

```bash
./vendor/bin/phpunit --coverage-text --coverage-html reports/coverage --log-junit reports/test-results.xml
```

### Swift

```bash
swift test --verbose 2>&1 | tee reports/test-output.txt
```

## Test Result Parsing Patterns

### pytest Output Parsing

```
Pattern: "(\d+) passed" → passed count
Pattern: "(\d+) failed" → failed count
Pattern: "(\d+) error"  → error count
Pattern: "(\d+) skipped" → skipped count
Pattern: "(\d+) warning" → warning count
Pattern: "TOTAL\s+\d+\s+\d+\s+(\d+)%" → coverage %

Failure block:
"FAILED {test_file}::{test_class}::{test_name} - {error_type}: {message}"
```

### Jest Output Parsing

```
Pattern: "Tests:\s+(\d+) failed" → failed count
Pattern: "Tests:\s+.*(\d+) passed" → passed count
Pattern: "Tests:\s+(\d+) total" → total count
Pattern: "Test Suites:\s+(\d+) failed" → failed suites
Pattern: "Stmts\s*\|\s*.*\|\s*([\d.]+)%" → statement coverage

Failure block:
"● {test_suite} › {test_name}"
```

### Go Test Output Parsing

```
Pattern: "^ok\s+" → passed package
Pattern: "^FAIL\s+" → failed package
Pattern: "^---\s+FAIL:\s+(\w+)" → failed test name
Pattern: "coverage:\s+([\d.]+)%" → coverage %
```

### Generic Exit Code

```
exit_code == 0 → all tests passed
exit_code != 0 → some tests failed (parse output for details)
```

## Coverage Thresholds

| Level | Coverage % | Assessment |
|-------|-----------|------------|
| Excellent | ≥ 80% | Well-tested codebase |
| Good | 60-79% | Adequate coverage, room for improvement |
| Fair | 40-59% | Significant gaps in test coverage |
| Poor | < 40% | Critical lack of test coverage |

## Report Generation

### Report Structure (Markdown)

```markdown
# Test Report — {project_name}

**Date**: {YYYY-MM-DD HH:MM}
**Framework**: {framework_name} {version}
**Duration**: {total_time}

## Summary

| Metric | Value |
|--------|-------|
| Total Tests | {total} |
| Passed | {passed} ✅ |
| Failed | {failed} ❌ |
| Skipped | {skipped} ⏭️ |
| Errors | {errors} 💥 |
| Coverage | {coverage}% |
| Status | **{PASS/FAIL}** |

## Coverage Breakdown

| Module/File | Stmts | Miss | Cover |
|-------------|-------|------|-------|
| {file_path} | {stmts} | {miss} | {cover}% |
| ... | ... | ... | ... |
| **TOTAL** | **{total_stmts}** | **{total_miss}** | **{total_cover}%** |

## Failed Tests

### {test_name}
- **File**: `{file_path}:{line}`
- **Error**: {error_type}
- **Message**:
  ```
  {error_message}
  ```
- **Suggested Fix**: {brief suggestion based on error pattern}

## Warnings

- {warning_1}
- {warning_2}

## Recommendations

- {recommendation based on coverage gaps}
- {recommendation based on failure patterns}
```

### Report Output Location

```
reports/
├── test-report.md          # Human-readable markdown report
├── test-results.xml        # JUnit XML (for CI integration)
├── test-results.json       # JSON (for programmatic consumption)
└── coverage/
    ├── index.html          # HTML coverage report
    └── coverage.out        # Raw coverage data
```

### JSON Report Schema

```json
{
  "report": {
    "project": "{project_name}",
    "timestamp": "{ISO-8601}",
    "framework": "{name}",
    "duration_seconds": 0,
    "summary": {
      "total": 0,
      "passed": 0,
      "failed": 0,
      "skipped": 0,
      "errors": 0,
      "coverage_percent": 0,
      "status": "PASS|FAIL"
    },
    "failed_tests": [
      {
        "name": "test_name",
        "file": "relative/path/to/test.py",
        "line": 0,
        "error_type": "AssertionError",
        "message": "expected X got Y",
        "suggestion": "Check the return value of ..."
      }
    ],
    "coverage": {
      "total_statements": 0,
      "total_missed": 0,
      "percent": 0,
      "files": [
        {"file": "relative/path.py", "stmts": 0, "miss": 0, "cover": 0}
      ]
    },
    "warnings": [],
    "recommendations": []
  }
}
```

## CI Integration Patterns

### GitHub Actions

```yaml
- name: Run tests
  run: python -m pytest tests/ -v --junitxml=reports/test-results.xml --cov=src --cov-report=xml:reports/coverage.xml

- name: Upload test results
  uses: actions/upload-artifact@v4
  with:
    name: test-results
    path: reports/
```

### GitLab CI

```yaml
test:
  script:
    - python -m pytest tests/ -v --junitxml=reports/test-results.xml --cov=src
  artifacts:
    reports:
      junit: reports/test-results.xml
    paths:
      - reports/
```

## Multi-Language Project Handling

For projects with multiple languages:

1. **Detect all languages** — scan for all config files and test directories
2. **Run sequentially** — execute each language's test suite one at a time
3. **Aggregate results** — combine counts and coverage into unified report
4. **Per-language sections** — include language-specific breakdowns in report

```markdown
## Results by Language

### Python (pytest)
- Tests: 45/45 passed, Coverage: 87%

### TypeScript (Jest)
- Tests: 23/25 passed (2 failed), Coverage: 72%

### Go
- Tests: 12/12 passed, Coverage: 65%
```

## Common Test Failure Patterns

| Error Pattern | Likely Cause | Suggested Action |
|---------------|--------------|------------------|
| `ImportError` / `ModuleNotFoundError` | Missing dependency | `pip install -r requirements.txt` |
| `fixture not found` | Missing pytest fixture | Check conftest.py scope |
| `ConnectionRefusedError` | Service not running | Start required services (DB, Redis) |
| `TimeoutError` | Test too slow or deadlock | Increase timeout or check for blocking calls |
| `PermissionError` | File/directory access issue | Check file permissions |
| `AssertionError` | Test expectation mismatch | Review test logic vs implementation |
| `FileNotFoundError` | Missing test fixture/data | Check test data files exist |
| `ENOMEM` / `MemoryError` | Resource exhaustion | Run fewer tests in parallel |

## Timeout Configuration

| Framework | Default Timeout | Override |
|-----------|----------------|----------|
| pytest | None | `--timeout=300` (requires pytest-timeout) |
| Jest | 5s per test | `--testTimeout=30000` |
| Go | 10m per package | `-timeout 30m` |
| Cargo | None | `-- --test-threads=1` (sequential for stability) |
| Maven | None | `-Dsurefire.timeout=300` |

## Environment Activation

Always prefix test commands with the environment activation command:

```bash
{ACTIVATE_CMD} && {TEST_CMD}
```

If ACTIVATE_CMD is missing/empty → run TEST_CMD directly without prefix.

Priority for test command:
1. User-provided TEST_CMD (highest)
2. `.opencode/test-config.yaml` → `test_command` (if exists)
3. Auto-detect from project files (this decision tree)
