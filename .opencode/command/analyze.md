---
description: "워크스페이스 분석 및 캐시 생성"
model: qwen-coder/Qwen3-Coder-Next-FP8
subtask: true
prompt: |
  당신은 워크스페이스 분석 오케스트레이터입니다.

  ## 목표
  프로젝트 구조, 의존성, 빌드 시스템을 분석하고 캐시 파일을 생성합니다.

  ## 핵심 규칙
  1. workspace-analyzer 에이전트를 호출하여 분석을 수행합니다
  2. 분석 결과를 `.opencode/workspace-cache/analysis.json`에 저장합니다
  3. 분석 완료 후 요약을 출력합니다

  ## 실행 단계

  ### STEP 1: 캐시 디렉토리 확인
  먼저 캐시 디렉토리가 존재하는지 확인합니다:
  ```bash
  mkdir -p .opencode/workspace-cache
  ```

  ### STEP 2: 기존 캐시 확인 (--force가 아닌 경우)

  **옵션 파싱:**
  ```
  IF $ARGUMENTS에 "--force" 포함:
      → 기존 캐시 무시, STEP 3으로 진행
  ELSE:
      → 기존 캐시 확인
  ```

  **캐시 유효성 검사:**
  ```
  IF .opencode/workspace-cache/analysis.json 존재:
      캐시 파일을 읽어서 analyzed_at 확인
      IF analyzed_at가 24시간 이내:
          캐시가 최신입니다. 재분석이 필요하면 --force 옵션을 사용하세요.
          → 워크플로우 종료 (캐시 유효)
      ELSE:
          캐시가 오래되었습니다. 재분석을 진행합니다.
          → STEP 3으로 진행
  ELSE:
      캐시가 없습니다. 분석을 시작합니다.
      → STEP 3으로 진행
  ```

  ### STEP 3: 워크스페이스 분석
  Task 도구 호출:
  - subagent_type: "workspace-analyzer"
  - prompt: |
      현재 워크스페이스를 분석하세요.

      ## 분석 항목
      1. 프로젝트 타입 감지 (package.json, go.mod, Cargo.toml 등)
      2. 파일 구조 수집 (소스 파일, 테스트 파일, 설정 파일)
      3. 의존성 분석 (dependencies, devDependencies)
      4. 빌드 시스템 감지 (npm, cargo, go, make 등)
      5. 환경 정보 수집 (런타임 버전, Docker 설정)
      6. Git 정보 수집 (remote, branch)

      ## 제외 디렉토리
      - node_modules/
      - __pycache__/
      - .git/
      - .venv/, venv/, env/
      - target/ (Rust)
      - build/, dist/
      - vendor/

      ## 출력
      반드시 CACHE_DATA: 이후에 JSON 형식으로 분석 결과를 출력하세요.
  - description: "워크스페이스 분석"

  ### STEP 4: 캐시 저장
  Task 결과에서 CACHE_DATA: 이후의 JSON을 추출합니다.

  **JSON 추출 및 저장:**
  ```
  1. Task 결과에서 "CACHE_DATA:" 찾기
  2. 그 이후의 JSON 블록 추출
  3. .opencode/workspace-cache/analysis.json에 저장
  ```

  Write 도구를 사용하여 캐시 파일 저장:
  ```
  파일 경로: .opencode/workspace-cache/analysis.json
  내용: {추출한 JSON}
  ```

  ### STEP 5: 결과 출력

  분석 완료 후 다음 형식으로 출력:

  ```
  ═══════════════════════════════════════════════════════════════
  WORKSPACE_ANALYSIS: COMPLETE
  ═══════════════════════════════════════════════════════════════

  📊 분석 요약
  ┌──────────────────┬──────────────────┐
  │ 프로젝트 타입     │ {type}           │
  │ 총 파일 수       │ {count}          │
  │ 소스 파일        │ {count}          │
  │ 테스트 파일      │ {count}          │
  │ 의존성           │ {count}          │
  └──────────────────┴──────────────────┘

  💾 캐시 저장됨
  → .opencode/workspace-cache/analysis.json

  ═══════════════════════════════════════════════════════════════
  ```

  ---

  ## 오류 처리

  **workspace-analyzer 실패 시:**
  ```
  IF Task 결과에 "WORKSPACE_ANALYSIS_RESULT: FAILED" 포함:
      → 오류 메시지 출력
      → 워크플로우 종료 (실패)
  ```

  **JSON 파싱 실패 시:**
  ```
  IF CACHE_DATA 추출 실패:
      → "캐시 데이터 파싱 실패" 출력
      → 워크플로우 종료 (실패)
  ```

  ---

  ## 입력 옵션

  | 옵션 | 설명 |
  |------|------|
  | (없음) | 기존 캐시가 유효하면 스킵, 없거나 오래되면 분석 |
  | --force | 기존 캐시 무시하고 강제 재분석 |

---

# Workspace Analysis Command

**입력**: $ARGUMENTS

이 명령어는 현재 워크스페이스를 분석하고 결과를 캐시에 저장합니다.

## 사용 예시

```bash
# 기본 분석 (캐시가 없거나 오래된 경우만 실행)
/analyze

# 강제 재분석
/analyze --force
```

## 캐시 파일 위치

- `.opencode/workspace-cache/analysis.json` - 메인 분석 결과

## 분석 항목

1. **프로젝트 타입**: TypeScript, Python, Go, Rust 등
2. **파일 구조**: 디렉토리 구조, 파일 목록
3. **의존성**: package.json, requirements.txt 등에서 추출
4. **빌드 시스템**: npm, cargo, go, make 등
5. **환경 정보**: 런타임 버전, Docker 설정
6. **Git 정보**: remote URL, 현재 브랜치

## Code-QA와의 관계

`/code-qa`는 기본적으로 STEP 0에서 캐시가 없거나 만료되면 **자동으로 workspace-analyzer를 실행**합니다.
따라서 대부분의 경우 `/analyze`를 별도로 실행할 필요가 없습니다.

```bash
# 일반적인 사용 (code-qa가 내부에서 자동 분석)
/code-qa                           # 캐시 없으면 자동 분석 후 QA 진행
/code-qa --files torch_aim/csrc    # --files 모드에서도 자동 분석 적용
/code-qa --last                    # 마지막 커밋 모드에서도 자동 분석 적용

# /analyze가 유용한 경우
/analyze --force                   # 프로젝트 구조가 변경되었을 때 캐시 강제 갱신
/analyze                           # 분석 결과만 확인하고 싶을 때 (QA 없이)

# 캐시 없이 빠르게 QA만 하고 싶을 때
/code-qa --skip-cache              # 분석 건너뛰고 바로 QA 시작
```
