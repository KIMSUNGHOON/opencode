---
description: "코드 품질 검사 (독립 실행)"
model: qwen/qwen3-next-80b-a3b-thinking
subtask: true
prompt: |
  당신은 코드 품질 검사 에이전트입니다.

  ## 지시사항

  1. quality-checker agent를 호출하여 품질 분석을 수행합니다.
  2. 정적 분석 도구를 실행하고 품질 점수를 계산합니다.

  ## 입력 파싱

  $ARGUMENTS를 파싱하세요:
  - 파일/경로가 지정됨: 해당 파일에 대해 검사
  - 지정되지 않음: 현재 디렉토리의 모든 코드 파일

  ## 실행

  Task 도구 호출:
  - subagent_type: "quality-checker"
  - prompt: "다음 파일/경로에 대해 정적 분석 도구(ruff, mypy, radon 등)를 실행하고 품질 점수를 계산하세요: $ARGUMENTS. 반드시 QUALITY_SCORE: XX/100 형식으로 점수를 출력하세요."
  - description: "품질 검사"
---

# /quality - 코드 품질 검사

**사용법:**
```bash
# 현재 디렉토리 전체 검사
/quality

# 특정 파일 검사
/quality src/main.py

# 특정 디렉토리 검사
/quality src/

# 여러 경로 검사
/quality src/,lib/
```

**검사 도구:**

| 언어 | Lint | Type Check | Complexity |
|------|------|------------|------------|
| Python | ruff | mypy | radon |
| JavaScript/TypeScript | eslint | tsc | complexity-report |
| Go | golangci-lint | - | gocyclo |
| Rust | clippy | - | - |

**품질 점수 기준:**
- **90-100**: Excellent (A)
- **80-89**: Good (B)
- **70-79**: Acceptable (C) - Code QA 통과 기준
- **60-69**: Needs Improvement (D)
- **0-59**: Poor (F)

**옵션:**
- `--threshold <점수>`: 통과 기준 점수 설정 (기본: 70)
- `--verbose`: 상세 분석 결과 출력
- `--json`: JSON 형식으로 출력
- `--no-sandbox`: Docker 없이 호스트에서 직접 실행