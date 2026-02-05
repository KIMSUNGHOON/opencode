---
description: "코드 리뷰 (독립 실행)"
model: qwen/Qwen3-Next-80B-A3B-Thinking-FP8
subtask: true
prompt: |
  당신은 코드 리뷰 에이전트입니다.

  ## 지시사항

  1. code-reviewer agent를 호출하여 코드 분석을 수행합니다.
  2. 보안 취약점, 버그, 성능 이슈, 코드 스타일 문제를 찾습니다.

  ## 입력 파싱

  $ARGUMENTS를 파싱하세요:
  - 파일/경로가 지정됨: 해당 파일에 대해 리뷰
  - --staged: staged 변경만 리뷰
  - --last: 마지막 커밋 리뷰
  - 지정되지 않음: working directory 변경 리뷰

  ## 실행

  Task 도구 호출:
  - subagent_type: "code-reviewer"
  - prompt: "다음 파일/경로의 코드를 분석하고 이슈를 찾으세요: $ARGUMENTS. 발견된 이슈는 파일명, 라인번호, 이슈 설명 형식으로 출력하세요."
  - description: "코드 리뷰"
---

# /review - 코드 리뷰

**사용법:**
```bash
# Working directory 변경 리뷰 (git diff)
/review

# Staged 변경만 리뷰
/review --staged

# 마지막 커밋 리뷰
/review --last

# 특정 파일 리뷰
/review src/main.py

# 특정 디렉토리 리뷰
/review src/

# 여러 파일 리뷰
/review src/main.py,src/utils.py
```

**검사 항목:**
- **보안 (Security)**: SQL Injection, XSS, 인증/인가 취약점
- **버그 (Bug)**: Null 참조, 타입 오류, 논리 오류
- **성능 (Performance)**: N+1 쿼리, 메모리 누수, 비효율적 알고리즘
- **코드 품질 (Quality)**: 중복 코드, 복잡도, 명명 규칙

**옵션:**
- `--staged`: staged 변경만 리뷰
- `--last`: 마지막 커밋만 리뷰
- `--security`: 보안 이슈만 집중
- `--verbose`: 상세 분석 결과 출력