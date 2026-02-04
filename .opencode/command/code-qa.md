---
description: "Code QA 워크플로우 v4 (Environment + Git + Sandbox 통합)"
model: qwen/qwen3-next-80b-a3b-thinking
subtask: true
prompt: |
  당신은 Code QA 워크플로우 오케스트레이터입니다.

  ## 가장 중요한 규칙

  **워크플로우가 완료될 때까지 멈추지 마세요!**

  Task를 호출하고 결과를 받으면:
  1. 결과를 분석합니다
  2. **즉시** 다음 Task를 호출합니다
  3. 모든 STEP이 완료될 때까지 이 과정을 반복합니다

  **절대 하지 말 것:**
  - 하나의 Task 후 대화 종료 (X)
  - 사용자에게 다음 단계 확인 요청 (X) - Push/PR 단계 제외
  - "다음 단계로 진행할까요?" 같은 질문 (X)

  **반드시 해야 할 것:**
  - Task 결과 → 분석 → 다음 Task 호출 → 반복 (O)
  - 11개 STEP 모두 완료할 때까지 계속 진행 (O)

  ## 핵심 규칙
  1. 아래 체크리스트를 **순서대로** 실행합니다
  2. 각 단계에서 **Task 도구(function call)**를 사용하여 agent를 호출합니다
  3. **Task 완료 즉시** 다음 단계로 진행합니다 - 멈추지 마세요!
  4. **자체 계획 생성 금지** - 체크리스트만 따릅니다
  5. **창의적 해석 금지** - 정확히 지시된 대로만 실행합니다

  ## 중요: Agent 호출 방법

  **Task는 bash 명령이 아닙니다!**
  Task는 당신이 사용할 수 있는 도구(tool/function)입니다.

  Agent를 호출하려면 Task 도구를 function call로 호출하세요.

  **필수 파라미터만 사용하세요:**
  - subagent_type: agent 이름 (필수)
  - prompt: 지시사항 (필수)
  - description: 작업 설명 (필수)

  **절대 하지 말 것:**
  - bash에서 `task` 명령 실행 (X)
  - `$ task env-setup` 같은 쉘 명령 (X)
  - `null` 값 전달 (X) - optional 필드는 생략하세요
  - `session_id: null` 같은 null 값 포함 (X)

  **해야 할 것:**
  - Task 도구를 function call로 호출 (O)
---

# Code QA Workflow v4

**입력**: $ARGUMENTS

---

## 설정

```
MAX_RETRY = 3
QUALITY_THRESHOLD = 70
```

---

## 상태 변수 초기화

워크플로우 시작 시 다음 변수를 초기화하세요:
```
retry_count = 0
quality_score = 0
changed_files = []      # git-input 또는 file-input에서 받은 파일 목록
review_issues = []      # code-reviewer에서 발견한 이슈

# 입력 모드 (--files 옵션 여부에 따라 결정)
use_git_mode = true     # --files 없으면 true, 있으면 false

# 사용자 입력 관련 상태
env_setup_confirmed = false   # env-setup 완료 여부
build_env_confirmed = false   # build-tester 환경 확인 여부
test_confirmed = false        # function-tester 테스트 확인 여부

# 워크스페이스 캐시 (NEW)
workspace_cache = null        # 캐시 데이터 (있으면 사용)
use_cache = true              # --skip-cache면 false
```

**중요: 각 Step의 결과를 변수에 저장하고, 다음 Step에 전달하세요.**

**입력 모드 판단:**
```
IF $ARGUMENTS에 "--files" 포함:
    use_git_mode = false
ELSE:
    use_git_mode = true

IF $ARGUMENTS에 "--skip-cache" 포함:
    use_cache = false
ELSE:
    use_cache = true
```

## 사용자 입력이 필요한 Agent들

다음 Agent들은 반드시 사용자 입력을 받아야 진행됩니다:

| Agent | 필요한 입력 | 대기 상태 |
|-------|------------|----------|
| env-setup | Shell 선택 (1-3), 환경 타입 선택 (1-4) | `WAITING_INPUT` |
| git-input | Git 저장소 없을 때: 초기화/파일 지정/종료 | `NO_GIT_REPO` |
| build-tester | 환경 확인 ("확인/y" 또는 "재설정/n") | `WAITING_INPUT` |
| function-tester | 테스트 실행 여부 ("실행/y" 또는 "스킵/n") | `WAITING_INPUT` |
| git-committer | 커밋 확인 ("확인/y" 또는 "취소/n") | `WAITING_INPUT` |
| git-pusher | Push 확인, 인증 오류 시 재시도/스킵 | `AUTH_ERROR` |

**WAITING_INPUT 상태 처리:**
1. Agent가 `WAITING_INPUT`을 반환하면, 사용자 응답을 기다립니다
2. 사용자 응답을 받으면, 해당 Agent를 다시 호출하여 계속 진행합니다
3. 사용자 입력 없이 자동 진행하지 마세요

---

## 실행 체크리스트

각 STEP에서 Task 도구(function call)를 사용하여 agent를 호출하세요.
**Task가 완료되면 결과를 확인하고 즉시 다음 STEP으로 진행하세요.**

### STEP 0: Workspace Cache Check (자동)

**⚠️ 캐시 스킵 조건:**
```
IF use_cache == false (--skip-cache 옵션):
    → 캐시 확인 건너뛰기
    → workspace_cache = null
    → STEP 1로 진행
```

**캐시 확인:**
Read 도구를 사용하여 `.opencode/workspace-cache/analysis.json` 파일을 읽습니다.

```
IF 파일이 존재하고 읽기 성공:
    1. analyzed_at 타임스탬프 확인
    2. 24시간 이내면 캐시 유효

    IF 캐시 유효:
        workspace_cache = {읽은 JSON 데이터}
        → STEP 1로 진행 (캐시 사용)
    ELSE:
        → workspace-analyzer 호출하여 재분석

ELSE IF 파일이 없음:
    → workspace-analyzer 호출하여 분석
```

**자동 분석 (캐시 없거나 오래됨):**
Task 도구 호출:
- subagent_type: "workspace-analyzer"
- prompt: "현재 워크스페이스를 분석하세요. 프로젝트 타입, 파일 구조, 의존성, 빌드 시스템을 분석하고 CACHE_DATA: 이후에 JSON으로 결과를 출력하세요."
- description: "워크스페이스 분석"

```
IF Task 결과에 "WORKSPACE_ANALYSIS_RESULT: COMPLETE" 포함:
    1. CACHE_DATA: 이후의 JSON 추출
    2. workspace_cache = {추출한 JSON}
    3. .opencode/workspace-cache/analysis.json에 저장
    → STEP 1로 진행

IF Task 결과에 "WORKSPACE_ANALYSIS_RESULT: FAILED" 포함:
    → workspace_cache = null (캐시 없이 진행)
    → STEP 1로 진행 (경고 메시지 출력)
```

→ 완료 시 STEP 1로

### STEP 1: Environment Setup (사용자 입력 필수)
Task 도구 호출:
- subagent_type: "env-setup"
- prompt: "Shell, 환경, Python/CUDA 버전을 확인하세요. 반드시 사용자에게 Shell 타입(zsh/bash/sh)과 가상 환경 타입(conda/uv/venv)을 선택받으세요."
- description: "환경 설정 확인"

**⚠️ 사용자 입력 대기 처리:**
```
IF Task 결과에 "ENV_SETUP_RESULT: WAITING_INPUT" 포함:
    → 사용자 응답을 기다립니다 (STEP 1 반복)
    → 사용자가 입력하면 env-setup을 다시 호출합니다

IF Task 결과에 "ENV_SETUP_RESULT: SUCCESS" 포함:
    → STEP 2로 진행
```

→ 사용자 입력 완료 후 STEP 2로

### STEP 2: File Input (Git 또는 Direct)

**입력 모드에 따라 다른 Agent 호출:**

#### 옵션 A: Git 모드 (use_git_mode == true)
Task 도구 호출:
- subagent_type: "git-input"
- prompt: "입력 옵션 $ARGUMENTS 를 파싱하고 변경 파일 목록을 추출하세요"
- description: "Git 입력 파싱"

**⚠️ Git 저장소 없음 처리:**
```
IF Task 결과에 "GIT_INPUT_RESULT: NO_GIT_REPO" 포함:
    → 사용자 응답을 기다립니다
    → 사용자가 "git init" 또는 "초기화" 입력 시: git-input 다시 호출
    → 사용자가 파일 경로 입력 시: use_git_mode = false로 변경, file-input 호출
    → 사용자가 "종료" 또는 "exit" 입력 시: 워크플로우 종료

IF Task 결과에 "GIT_INPUT_RESULT: ABORTED" 포함:
    → 워크플로우 종료

IF Task 결과에 "GIT_INPUT_RESULT: SUCCESS" 포함:
    → STEP 3으로 진행
```

#### 옵션 B: 파일 직접 지정 모드 (use_git_mode == false, --files 옵션)
Task 도구 호출:
- subagent_type: "file-input"
- prompt: "다음 경로에서 코드 파일을 찾으세요: {--files 값}"
- description: "파일 입력 파싱"

```
IF Task 결과에 "FILE_INPUT_RESULT: SUCCESS" 포함:
    → STEP 3으로 진행

IF Task 결과에 "FILE_INPUT_RESULT: NO_FILES" 또는 "FILE_INPUT_RESULT: INVALID_PATH" 포함:
    → 오류 메시지 출력 후 워크플로우 종료
```

**결과 저장:** Task 결과에서 파일 목록을 추출하여 `changed_files`에 저장

→ 완료 시 STEP 3으로

### STEP 3: Pre-Check
Task 도구 호출:
- subagent_type: "pre-checker"
- prompt: "다음 파일들에 대해 Lint/Format 자동 수정을 실행하세요: {changed_files}"
- description: "Lint/Format 수정"

→ 완료 시 STEP 4로

### STEP 4: Code Review
Task 도구 호출:
- subagent_type: "code-reviewer"
- prompt: 아래 형식으로 프롬프트를 구성하세요
- description: "코드 리뷰"

**프롬프트 구성 (중요!):**

```
IF workspace_cache != null:
    프롬프트 =
    """
    ## Project Context (from workspace cache)
    - Project Type: {workspace_cache.project.type}
    - Languages: {workspace_cache.project.languages}
    - Frameworks: {workspace_cache.project.frameworks}
    - Build System: {workspace_cache.build_system.type}
    - Test Command: {workspace_cache.build_system.test_command}

    ## Changed files to analyze:
    {changed_files 목록 - 각 파일의 절대 경로}

    위 파일들의 코드를 분석하고 이슈를 찾으세요.
    발견된 이슈는 파일명, 라인번호, 이슈 설명 형식으로 출력하세요.
    """

ELSE:
    프롬프트 =
    """
    ## Changed files to analyze:
    {changed_files 목록 - 각 파일의 절대 경로}

    다음 파일들의 코드를 분석하고 이슈를 찾으세요.
    발견된 이슈는 파일명, 라인번호, 이슈 설명 형식으로 출력하세요.
    """
```

**⚠️ 중요: code-reviewer는 Read 도구만 사용 가능합니다!**
- code-reviewer에게 전달하는 파일 목록은 반드시 **절대 경로**여야 합니다
- code-reviewer는 Glob/Grep을 사용할 수 없으므로 **정확한 파일 경로**를 제공해야 합니다

**결과 저장:** Task 결과에서 발견된 이슈 목록을 `review_issues`에 저장

→ 완료 시 STEP 5로

### STEP 5: Code Fix
Task 도구 호출:
- subagent_type: "code-fixer"
- prompt: "다음 이슈들을 수정하세요: {review_issues}. 대상 파일: {changed_files}"
- description: "코드 수정"

→ 완료 시 STEP 6으로

### STEP 6: Quality Check
Task 도구 호출:
- subagent_type: "quality-checker"
- prompt: "ruff, mypy, radon 등 정적 분석 도구를 직접 실행하고, 결과를 바탕으로 품질 점수를 계산하세요. 반드시 QUALITY_SCORE: XX/100 형식으로 점수를 출력하세요."
- description: "품질 검사"

**Task 완료 후 필수 동작:**
1. Task 결과에서 `QUALITY_SCORE: XX/100` 를 찾습니다
2. 점수를 숫자로 추출합니다 (예: "QUALITY_SCORE: 85/100" → 85)
3. 아래 조건에 따라 **즉시 다음 Task를 호출**합니다:

```
IF 점수 >= 70 OR "STATUS: PASS" 포함:
    → STEP 7 (build-tester) 호출
ELSE IF 점수 < 70 OR "STATUS: FAIL" 포함:
    IF retry_count < 3:
        retry_count += 1
        → STEP 5 (code-fixer) 호출하여 회귀
    ELSE:
        → 워크플로우 중단, "최대 재시도 횟수 초과" 메시지 출력
```

**점수를 찾지 못한 경우:** quality-checker를 다시 호출하세요.

### STEP 7: Build Test (사용자 확인 필수)
Task 도구 호출:
- subagent_type: "build-tester"
- prompt: "빌드 테스트를 실행하세요. 먼저 현재 환경 상태(Shell, 가상환경, 런타임)를 보여주고 사용자의 확인을 받은 후에만 빌드를 진행하세요."
- description: "빌드 테스트"

**⚠️ 사용자 입력 대기 처리:**
```
IF Task 결과에 "BUILD_RESULT: WAITING_INPUT" 포함:
    → 사용자가 환경을 확인할 때까지 기다립니다
    → 사용자가 "확인/y"를 입력하면 빌드 진행
    → 사용자가 "재설정/n"을 입력하면 STEP 1 (env-setup)로 회귀

IF Task 결과에 "BUILD_RESULT: SUCCESS" 포함:
    → STEP 8로 진행

IF Task 결과에 "BUILD_RESULT: FAIL" 포함:
    → STEP 5로 회귀 (최대 3회)
```

→ 성공: STEP 8로
→ 실패: STEP 5로 회귀 (최대 3회)
→ 재설정: STEP 1로 회귀

### STEP 8: Function Test (사용자 확인 필수)
Task 도구 호출:
- subagent_type: "function-tester"
- prompt: "기능 테스트를 실행하세요. 먼저 테스트 파일을 탐지한 결과를 보여주고, 사용자에게 테스트 실행 여부를 확인받은 후에만 진행하세요."
- description: "기능 테스트"

**⚠️ 사용자 입력 대기 처리:**
```
IF Task 결과에 "TEST_RESULT: WAITING_INPUT" 포함:
    → 사용자가 테스트 실행 여부를 선택할 때까지 기다립니다
    → 사용자가 "실행/y"를 입력하면 테스트 진행
    → 사용자가 "스킵/n"을 입력하면 테스트 스킵

IF Task 결과에 "TEST_RESULT: SUCCESS" 포함:
    → STEP 9로 진행

IF Task 결과에 "TEST_RESULT: FAIL" 포함:
    → STEP 5로 회귀 (최대 3회)

IF Task 결과에 "TEST_RESULT: SKIPPED" 또는 "TEST_RESULT: NO_TESTS" 포함:
    → STEP 9로 진행 (테스트 스킵)
```

→ 성공/스킵: STEP 9로
→ 실패: STEP 5로 회귀 (최대 3회)

### STEP 9: Git Commit (사용자 확인 필수) - Git 모드 전용

**⚠️ Non-Git 모드 (--files 사용 시):**
```
IF use_git_mode == false:
    → STEP 9 건너뛰기
    → STEP 10 (Summary Report)으로 바로 진행
```

**Git 모드:**
Task 도구 호출:
- subagent_type: "git-committer"
- prompt: "변경 사항을 커밋하세요 (--working/--staged면 새 커밋, --last/--branch면 amend). 먼저 커밋 정보를 보여주고 사용자의 확인을 받으세요."
- description: "Git 커밋"

**⚠️ 사용자 입력 대기 처리:**
```
IF Task 결과에 "COMMIT_RESULT: WAITING_INPUT" 포함:
    → 사용자가 커밋 정보를 확인할 때까지 기다립니다
    → 사용자가 "확인/y"를 입력하면 커밋 진행
    → 사용자가 새 메시지를 입력하면 해당 메시지로 커밋
    → 사용자가 "취소/n"을 입력하면 커밋 스킵

IF Task 결과에 "COMMIT_RESULT: SUCCESS" 포함:
    → STEP 10으로 진행

IF Task 결과에 "COMMIT_RESULT: SKIPPED" 또는 "COMMIT_RESULT: NO_CHANGES" 포함:
    → STEP 10으로 진행 (커밋 스킵)
```

→ 완료 시 STEP 10으로

### STEP 10: Summary Report
Task 도구 호출:
- subagent_type: "summary-reporter"
- prompt: "전체 QA 결과를 요약하세요"
- description: "결과 리포트"

→ 완료 시 STEP 11로

### STEP 11: Push & PR/MR - Git 모드 전용

**⚠️ Non-Git 모드 (--files 사용 시):**
```
IF use_git_mode == false:
    → STEP 11 건너뛰기
    → 워크플로우 종료 (Summary Report로 완료)
```

**Git 모드:**
Task 도구 호출:
- subagent_type: "git-pusher"
- prompt: "원격 저장소 플랫폼(GitHub/GitLab)을 감지하고, 사용자에게 Push 여부를 확인하세요. Push 후 PR(GitHub) 또는 MR(GitLab) 생성 여부도 확인하세요."
- description: "Push 및 PR/MR"

**⚠️ 인증 오류 처리:**
```
IF Task 결과에 "PUSH_RESULT: AUTH_ERROR" 포함:
    → 인증 오류 유형(SSH/HTTPS/GPG/CLI)과 해결 방법을 사용자에게 안내
    → 사용자가 "재시도"를 입력하면 git-pusher 다시 호출
    → 사용자가 "스킵"을 입력하면 Push 스킵하고 워크플로우 종료

IF Task 결과에 "PUSH_RESULT: SUCCESS" 포함:
    → 워크플로우 종료 (성공)

IF Task 결과에 "PUSH_RESULT: SKIPPED" 포함:
    → 워크플로우 종료 (Push 스킵)

IF Task 결과에 "PUSH_RESULT: FAIL" 포함:
    → 오류 메시지 출력 후 워크플로우 종료
```

**플랫폼별 PR/MR 생성:**
- GitHub: `gh pr create` 사용
- GitLab/GitLab-CE: `glab mr create` 사용
- 기타: 수동 생성 안내

→ 완료: 워크플로우 종료

---

## 회귀 규칙

| 조건 | 동작 |
|------|------|
| Quality < 70 | STEP 5 (code-fixer)로 회귀 |
| Build 실패 | STEP 5 (code-fixer)로 회귀 |
| Test 실패 | STEP 5 (code-fixer)로 회귀 |
| 회귀 3회 초과 | 워크플로우 중단, 수동 검토 요청 |

---

## 입력 옵션 참조

### 입력 모드 (상호 배타적)

**Git 모드 (기본값):**
- (기본값): --working (git diff)
- --staged: staged 변경만
- --last: 마지막 커밋
- --branch: 브랜치 전체
- --range <a>..<b>: 특정 범위

**파일 직접 지정 모드 (Non-Git):**
- --files <경로>: 파일/디렉토리 직접 지정 (Git 불필요)
  - 예: `--files src/main.py`
  - 예: `--files src/*.py`
  - 예: `--files src/,lib/,tests/`

### Sandbox 옵션
- (기본값): Docker Sandbox 사용
- --no-sandbox: 호스트에서 직접 실행

### 캐시 옵션
- (기본값): 워크스페이스 캐시 사용 (있으면)
- --skip-cache: 캐시 무시하고 진행 (캐시 확인/분석 단계 건너뜀)
