---
name: code-review
description: Code review knowledge base — security checklists, bug patterns, performance anti-patterns, and language-specific rules. Load this skill when performing code analysis or review tasks.
---

# Code Review Knowledge Base

Consolidated knowledge for code analysis. Use the decision trees and checklists below to systematically review code.

## Quick Decision Tree: What to Check First

```
Code change type?
├─ New API endpoint → Security checklist (auth, input validation, rate limiting)
├─ Database query → SQL injection, N+1, missing index
├─ File I/O → Path traversal, resource leak, encoding
├─ User input handling → XSS, injection, sanitization
├─ Authentication/Authorization → Token handling, privilege escalation
├─ Concurrency code → Race condition, deadlock, resource contention
├─ Memory management (C/C++/Rust) → Use-after-free, buffer overflow, leak
├─ Error handling → Swallowed exceptions, missing cleanup, partial state
└─ Configuration change → Secret exposure, default values, env-specific
```

## Security Checklist

### CRITICAL (must block merge)
- [ ] SQL queries use parameterized statements (never string concatenation)
- [ ] User input is sanitized before rendering (XSS prevention)
- [ ] No hardcoded secrets, API keys, or credentials in source
- [ ] File paths are validated against traversal (`../`)
- [ ] Deserialization of untrusted data uses safe methods
- [ ] Command execution does not interpolate user input
- [ ] CSRF tokens present on state-changing endpoints
- [ ] Authentication checks on all protected routes

### HIGH (should fix before merge)
- [ ] Sensitive data not logged or exposed in error messages
- [ ] HTTP headers set correctly (CORS, CSP, X-Frame-Options)
- [ ] Cryptographic functions use current standards (no MD5/SHA1 for security)
- [ ] Session management follows best practices (secure, httpOnly, sameSite)
- [ ] File uploads validated (type, size, content)

## Bug Pattern Checklist

### Null/Undefined Reference
- [ ] Nullable values checked before access
- [ ] Optional chaining used where appropriate
- [ ] Default values for missing configuration

### Resource Management
- [ ] Files/connections/streams properly closed (try-with-resources, `with`, defer)
- [ ] Timeout set on external calls (HTTP, DB, queue)
- [ ] Retry logic has backoff and max attempts

### Concurrency
- [ ] Shared mutable state protected by locks or atomics
- [ ] No lock ordering violations (deadlock risk)
- [ ] Goroutines/threads have cancellation mechanism
- [ ] Channel/queue consumers handle shutdown gracefully

### Edge Cases
- [ ] Empty collections handled (not just null check)
- [ ] Integer overflow/underflow considered
- [ ] Unicode and multi-byte strings handled correctly
- [ ] Time zone and DST edge cases considered

## Performance Anti-Patterns

| Anti-Pattern | Detection Signal | Fix |
|---|---|---|
| N+1 Query | Loop containing DB query | Batch query / JOIN / eager load |
| Unbounded Collection | `SELECT *` without LIMIT | Add pagination / streaming |
| Repeated Computation | Same calculation in loop body | Memoize / precompute |
| Unnecessary Copy | Large struct passed by value | Pass by reference/pointer |
| Missing Index | Slow query on filtered column | Add DB index |
| Sync I/O in async path | Blocking call in event loop | Use async alternative |
| String Concatenation in Loop | `+=` on strings in loop | Use StringBuilder/join |
| Excessive Logging | Log inside hot path | Move to debug level / sample |

## Language-Specific Rules

### Python
| Rule | Bad | Good |
|---|---|---|
| Bare except | `except:` | `except Exception as e:` |
| Mutable default | `def f(x=[]):` | `def f(x=None): x = x or []` |
| Resource mgmt | `f = open(...)` | `with open(...) as f:` |
| String format | `"hello %s" % name` | `f"hello {name}"` |
| Type hints | `def calc(x, y):` | `def calc(x: int, y: int) -> int:` |

### JavaScript / TypeScript
| Rule | Bad | Good |
|---|---|---|
| Variable declaration | `var x = 1` | `const x = 1` or `let x = 1` |
| Equality | `x == null` | `x === null \|\| x === undefined` |
| Promise handling | `.then()` without `.catch()` | `try/await` or `.catch()` |
| Type safety (TS) | `any` everywhere | Specific types or generics |
| Nullish | `x \|\| default` (for 0/empty) | `x ?? default` |

### Go
| Rule | Bad | Good |
|---|---|---|
| Error handling | `result, _ := fn()` | `result, err := fn(); if err != nil { }` |
| Goroutine leak | `go fn()` without cancel | Use `context.Context` for cancellation |
| Channel close | Reader doesn't check close | `val, ok := <-ch` |
| Defer in loop | `defer` inside for loop | Close explicitly in loop body |
| Context | Missing context propagation | Pass `ctx` through call chain |

### Rust
| Rule | Bad | Good |
|---|---|---|
| Unwrap abuse | `.unwrap()` in production | `?` operator or `.unwrap_or()` |
| Unsafe overuse | `unsafe {}` for convenience | Find safe alternative first |
| Clone overhead | `.clone()` to satisfy borrow | Restructure ownership / use references |
| Error handling | `panic!()` in library code | Return `Result<T, E>` |

### C/C++
| Rule | Bad | Good |
|---|---|---|
| Memory | Raw `malloc`/`new` | Smart pointers (`unique_ptr`, `shared_ptr`) |
| Buffer | `strcpy`, `sprintf` | `strncpy`, `snprintf` with size bounds |
| Null check | Dereference without check | Check pointer before use |
| RAII | Manual resource cleanup | Constructor/destructor pattern |
| Const | Mutable parameter that shouldn't change | `const` qualifier |

### Java
| Rule | Bad | Good |
|---|---|---|
| Resource | Manual `close()` | try-with-resources |
| Null safety | Direct access without check | Optional or null check |
| Equality | `str == "abc"` | `"abc".equals(str)` |
| Logging | `e.printStackTrace()` | Logger with proper level |
| Immutability | Mutable public fields | Private fields + getters |

## Severity Classification

```
Severity Decision:
├─ Can it cause data loss, security breach, or system crash?
│  └─ YES → CRITICAL
├─ Is it a bug that will manifest in production?
│  └─ YES → HIGH
├─ Does it degrade maintainability or performance noticeably?
│  └─ YES → MEDIUM
└─ Is it a style/convention/documentation issue?
   └─ YES → LOW
```

## Output Schema

Issues should follow this structure for downstream consumption (e.g., code-fixer agent):

```json
{
  "id": "C001",
  "severity": "critical|high|medium|low",
  "category": "security|bug|performance|maintainability|best-practice",
  "file": "/absolute/path/to/file.ext",
  "line": 42,
  "title": "Short issue title",
  "description": "What the problem is and why it matters",
  "suggestion": "Specific, actionable fix recommendation"
}
```

ID format: `C` = Critical, `H` = High, `M` = Medium, `L` = Low + 3-digit number.
