---
description: "빌드 테스트 (독립 실행)"
model: devstral/Devstral-2-123B
subtask: true
prompt: |
  당신은 빌드 테스트 에이전트입니다.

  ## 지시사항

  1. build-tester agent를 호출하여 빌드를 수행합니다.
  2. 현재 환경 정보를 보여주고 사용자 확인 후 빌드를 진행합니다.

  ## 입력 파싱

  $ARGUMENTS를 파싱하세요:
  - --no-sandbox: 호스트에서 직접 빌드
  - --skip-confirm: 환경 확인 건너뛰기
  - 지정되지 않음: Docker Sandbox에서 빌드

  ## 실행

  Task 도구 호출:
  - subagent_type: "build-tester"
  - prompt: "빌드 테스트를 실행하세요. 현재 환경 상태를 보여주고 사용자의 확인을 받은 후에만 빌드를 진행하세요. 옵션: $ARGUMENTS"
  - description: "빌드 테스트"
---

# /build - 빌드 테스트

**사용법:**
```bash
# Docker Sandbox에서 빌드 (기본)
/build

# 호스트에서 직접 빌드
/build --no-sandbox

# 환경 확인 건너뛰기
/build --skip-confirm

# 특정 빌드 명령 실행
/build --cmd "pip install -e ."
```

**자동 감지되는 빌드 시스템:**

| 언어 | 빌드 시스템 | 빌드 명령 |
|------|------------|----------|
| Python | pip/setuptools | `pip install -e .` |
| Python | poetry | `poetry install` |
| JavaScript | npm | `npm install && npm run build` |
| JavaScript | yarn | `yarn install && yarn build` |
| Go | go mod | `go build ./...` |
| Rust | cargo | `cargo build` |
| Java | maven | `mvn compile` |
| Java | gradle | `./gradlew build` |
| C/C++ | cmake | `cmake . && make` |
| C/C++ | make | `make` |

**옵션:**
- `--no-sandbox`: Docker 없이 호스트에서 직접 빌드
- `--skip-confirm`: 환경 확인 단계 건너뛰기
- `--cmd <명령>`: 커스텀 빌드 명령 실행
- `--verbose`: 상세 빌드 로그 출력