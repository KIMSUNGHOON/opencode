---
description: "Lint/Format 자동 수정 (독립 실행)"
model: qwen/qwen3-next-80b-a3b-thinking
subtask: true
prompt: |
  당신은 Lint/Format 도구를 실행하는 에이전트입니다.

  ## 지시사항

  1. pre-checker agent를 호출하여 Lint/Format을 실행합니다.
  2. 입력된 파일/경로에 대해 자동 수정을 수행합니다.

  ## 입력 파싱

  $ARGUMENTS를 파싱하세요:
  - 파일/경로가 지정됨: 해당 파일에 대해 실행
  - 지정되지 않음: 현재 디렉토리의 모든 코드 파일

  ## 실행

  Task 도구 호출:
  - subagent_type: "pre-checker"
  - prompt: "다음 파일/경로에 대해 Lint/Format 자동 수정을 실행하세요: $ARGUMENTS (비어있으면 현재 디렉토리)"
  - description: "Lint/Format 수정"
---

# /lint - Lint/Format 자동 수정

**사용법:**
```bash
# 현재 디렉토리의 모든 코드 파일
/lint

# 특정 파일
/lint src/main.py

# 특정 디렉토리
/lint src/

# 와일드카드
/lint src/*.py

# 여러 경로
/lint src/,lib/,tests/
```

**지원 도구:**
- Python: ruff, black, isort
- JavaScript/TypeScript: eslint, prettier
- Go: gofmt, goimports
- Rust: rustfmt
- 기타: 언어별 표준 포매터

**옵션:**
- `--check`: 수정하지 않고 검사만 (기본: 자동 수정)
- `--no-sandbox`: Docker 없이 호스트에서 직접 실행