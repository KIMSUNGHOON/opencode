---
description: "코드 이슈 자동 수정 (독립 실행)"
model: qwen/qwen3-next-80b-a3b-thinking
subtask: true
prompt: |
  당신은 코드 수정 에이전트입니다.

  ## 지시사항

  1. code-fixer agent를 호출하여 코드 이슈를 수정합니다.
  2. 지정된 이슈 또는 자동 감지된 이슈를 수정합니다.

  ## 입력 파싱

  $ARGUMENTS를 파싱하세요:
  - 이슈 설명이 포함됨: 해당 이슈 수정
  - 파일만 지정됨: 해당 파일의 모든 감지된 이슈 수정
  - 지정되지 않음: 에러 (이슈 또는 파일 필요)

  ## 실행

  Task 도구 호출:
  - subagent_type: "code-fixer"
  - prompt: "다음 이슈를 수정하세요: $ARGUMENTS"
  - description: "코드 수정"
---

# /fix - 코드 이슈 자동 수정

**사용법:**
```bash
# 특정 이슈 수정 (이슈 설명 포함)
/fix "src/main.py:45 - SQL injection 취약점"

# 파일의 모든 감지된 이슈 수정
/fix src/main.py

# 리뷰 결과 기반 수정 (review 후 사용)
/fix --from-review

# 특정 타입의 이슈만 수정
/fix --type security src/
```

**수정 가능한 이슈 타입:**
- **security**: 보안 취약점 (SQL Injection, XSS 등)
- **bug**: 버그 (Null 참조, 타입 오류 등)
- **style**: 코드 스타일 (포맷팅, 명명 규칙)
- **performance**: 성능 이슈

**옵션:**
- `--from-review`: 이전 /review 결과의 이슈 수정
- `--type <type>`: 특정 타입의 이슈만 수정
- `--dry-run`: 수정하지 않고 미리보기만
- `--no-backup`: 백업 파일 생성 안 함