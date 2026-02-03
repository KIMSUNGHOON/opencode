---
description: "기능 테스트 (독립 실행)"
model: qwen/qwen3-next-80b-a3b-thinking
subtask: true
prompt: |
  당신은 기능 테스트 에이전트입니다.

  ## 지시사항

  1. function-tester agent를 호출하여 테스트를 수행합니다.
  2. 테스트 파일을 탐지하고 사용자 확인 후 테스트를 실행합니다.

  ## 입력 파싱

  $ARGUMENTS를 파싱하세요:
  - 테스트 경로 지정: 해당 테스트만 실행
  - --no-sandbox: 호스트에서 직접 실행
  - --skip-confirm: 테스트 확인 건너뛰기
  - --coverage: 커버리지 리포트 생성
  - 지정되지 않음: 모든 테스트 탐지 후 실행

  ## 실행

  Task 도구 호출:
  - subagent_type: "function-tester"
  - prompt: "기능 테스트를 실행하세요. 테스트 파일을 탐지하고 사용자 확인 후 진행하세요. 옵션: $ARGUMENTS"
  - description: "기능 테스트"
---

# /test - 기능 테스트

**사용법:**
```bash
# 모든 테스트 탐지 및 실행 (기본)
/test

# 특정 테스트 파일 실행
/test tests/test_main.py

# 특정 테스트 함수 실행
/test tests/test_main.py::test_function

# 특정 언어 테스트만 실행
/test --lang python

# 커버리지 리포트 포함
/test --coverage

# 호스트에서 직접 실행
/test --no-sandbox
```

**자동 감지되는 테스트 프레임워크:**

| 언어 | 프레임워크 | 탐지 패턴 |
|------|-----------|----------|
| Python | pytest | `tests/`, `test_*.py`, `*_test.py` |
| Python | unittest | `tests/`, `test_*.py` |
| JavaScript | jest | `__tests__/`, `*.test.js`, `*.spec.js` |
| TypeScript | jest | `__tests__/`, `*.test.ts`, `*.spec.ts` |
| Go | go test | `*_test.go` |
| Rust | cargo test | `tests/`, `src/**/test*.rs` |
| Java | JUnit | `src/test/`, `*Test.java` |
| Ruby | RSpec | `spec/`, `*_spec.rb` |
| PHP | PHPUnit | `tests/`, `*Test.php` |

**옵션:**
- `--no-sandbox`: Docker 없이 호스트에서 직접 실행
- `--skip-confirm`: 테스트 확인 단계 건너뛰기
- `--coverage`: 커버리지 리포트 생성
- `--lang <언어>`: 특정 언어 테스트만 실행
- `--verbose`: 상세 테스트 로그 출력
- `--fail-fast`: 첫 번째 실패에서 중단