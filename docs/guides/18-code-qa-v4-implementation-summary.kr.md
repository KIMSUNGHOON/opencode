# Code QA v4 구현 요약

> 이 문서는 [18-code-qa-v4-implementation-summary.md](./18-code-qa-v4-implementation-summary.md)의 한국어 번역입니다.

이 문서는 Code QA v4 워크플로우 시스템에 대해 완료된 모든 구현 작업을 요약합니다.

---

## 1. 개요

### 1.1 프로젝트 목표

1. **엣지 케이스 처리**: 워크플로우에서 식별된 모든 엣지 케이스에 대한 견고한 처리 구현
2. **영문 번역**: 모든 오케스트레이터 및 서브 에이전트 프롬프트를 영어로 번역
3. **Qwen3-Next 호환성**: Qwen3-Next 시리즈 모델에 최적화된 프롬프트 보장
4. **로컬 인프라**: 토큰 비용에 구애받지 않는 로컬 LLM 서빙을 위한 설계

### 1.2 워크플로우 아키텍처

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Code QA v4 Workflow                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  /code-qa command                                                       │
│       │                                                                 │
│       ▼                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                 │
│  │  STEP 0-2   │───▶│  STEP 3-6   │───▶│  STEP 7-8   │                 │
│  │  Env/Input  │    │ Review/Fix  │    │ Build/Test  │                 │
│  └─────────────┘    └─────────────┘    └─────────────┘                 │
│                                              │                          │
│       ┌──────────────────────────────────────┘                          │
│       ▼                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                 │
│  │  STEP 9     │───▶│  STEP 10    │───▶│  STEP 11    │                 │
│  │ Git Commit  │    │   Summary   │    │  Git Push   │                 │
│  └─────────────┘    └─────────────┘    └─────────────┘                 │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. 구현된 엣지 케이스

### 2.1 최우선 순위 (해결됨)

| 이슈 | 설명 | 해결 방법 | 결과 토큰 |
|-------|------|-----------|-----------|
| 변경된 파일 없음 | 빈 git diff | 워크플로우 정상 종료 | `GIT_INPUT_RESULT: NO_CHANGES` |
| 삭제된 파일 | 삭제된 파일을 읽을 수 없음 | 분석에서 제외하고 별도 추적 | `DELETED_FILES: file1, file2` |

### 2.2 높은 순위 (해결됨)

| 이슈 | 설명 | 해결 방법 | 결과 토큰 |
|-------|------|-----------|-----------|
| 대량 파일 수 | 100개 이상의 변경된 파일 | 경고 + 바이너리 필터링 | 경고 메시지 |
| 파일 상태 추적 | A/M/D/R 구분 | `git diff --name-status` | `FILE_LIST` (상태 포함) |

### 2.3 중간 순위 (해결됨)

| 이슈 | 설명 | 해결 방법 | 결과 토큰 |
|-------|------|-----------|-----------|
| Detached HEAD | 커밋할 브랜치 없음 | 사용자 선택: 브랜치 생성 / QA만 수행 / 종료 | `GIT_INPUT_RESULT: DETACHED_HEAD` |
| Merge conflict | 커밋 불가 | 워크플로우 차단, 가이드 제공 | `GIT_INPUT_RESULT: MERGE_CONFLICT` |
| Rebase 진행 중 | 커밋 불가 | 워크플로우 차단, 가이드 제공 | `GIT_INPUT_RESULT: REBASE_IN_PROGRESS` |
| 의존성 오류 | 누락된 의존성으로 빌드 실패 | 패턴 감지, 설치 명령 제안 | `BUILD_RESULT: FAIL_DEPS` |

### 2.4 낮은 순위 (보류)

| 이슈 | 보류 사유 |
|-------|-----------|
| Dirty working tree | 빈도 낮음, 기존 처리로 충분 |
| Shallow clone | 엣지 케이스, 필요시 `--unshallow` 사용 가능 |
| 런타임 미설치 | 범위 외 (시스템 설정 문제) |
| 네트워크 없음 | 비용 대비 효과 낮음 |

---

## 3. 에이전트 구현 세부사항

### 3.1 에이전트 목록 및 상태

| 에이전트 | 파일 | 언어 | 모델 | 용도 |
|----------|------|------|------|------|
| code-qa | `.opencode/mode/code-qa.md` | English | qwen-instruct/Qwen3.5-122B-A10B-FP8 | 오케스트레이터 (Instruct 모드, tool call 안정성) |
| code-reviewer | `.opencode/agent/code-reviewer.md` | English | qwen/Qwen3.5-122B-A10B-FP8 | 수동 코드 리딩으로 이슈 발견 (CoT) |
| quality-checker | `.opencode/agent/quality-checker.md` | English | qwen/Qwen3.5-122B-A10B-FP8 | 도구 기반 품질 점수 산출 (CoT) |
| summary-reporter | `.opencode/agent/summary-reporter.md` | English | qwen/Qwen3.5-122B-A10B-FP8 | 최종 요약 (CoT) |
| env-setup | `.opencode/agent/env-setup.md` | English | qwen-instruct/Qwen3.5-122B-A10B-FP8 | 환경 설정 |
| git-input | `.opencode/agent/git-input.md` | English | qwen-instruct/Qwen3.5-122B-A10B-FP8 | Git diff 수집 |
| file-input | `.opencode/agent/file-input.md` | English | qwen-instruct/Qwen3.5-122B-A10B-FP8 | 직접 파일 입력 |
| workspace-analyzer | `.opencode/agent/workspace-analyzer.md` | English | qwen-instruct/Qwen3.5-122B-A10B-FP8 | 작업공간 분석 (DEPRECATED — legacy fallback) |
| pre-checker | `.opencode/agent/pre-checker.md` | English | qwen-instruct/Qwen3.5-122B-A10B-FP8 | 사전 검사 |
| code-fixer | `.opencode/agent/code-fixer.md` | English | qwen-instruct/Qwen3.5-122B-A10B-FP8 | 자동 이슈 수정 (SWE-Bench) |
| build-tester | `.opencode/agent/build-tester.md` | English | qwen-instruct/Qwen3.5-122B-A10B-FP8 | 빌드 테스트 |
| function-tester | `.opencode/agent/function-tester.md` | English | qwen-instruct/Qwen3.5-122B-A10B-FP8 | 기능 테스트 |
| git-committer | `.opencode/agent/git-committer.md` | English | qwen-instruct/Qwen3.5-122B-A10B-FP8 | Git 커밋 |
| git-pusher | `.opencode/agent/git-pusher.md` | English | qwen-instruct/Qwen3.5-122B-A10B-FP8 | Git 푸시 |

### 3.2 결과 토큰 패턴

모든 에이전트는 결정론적 파싱을 위해 일관된 결과 토큰 패턴을 사용합니다:

```
# Environment Setup Results
ENV_SETUP_RESULT: SUCCESS
ENV_SETUP_RESULT: FAIL
ENV_SETUP_RESULT: WAITING_INPUT

# Workspace Analysis Results
WORKSPACE_ANALYSIS_RESULT: COMPLETE
WORKSPACE_ANALYSIS_RESULT: FAILED
WORKSPACE_ANALYSIS_RESULT: TIMEOUT
WORKSPACE_ANALYSIS_RESULT: EMPTY

# Git Input Results
GIT_INPUT_RESULT: SUCCESS
GIT_INPUT_RESULT: NO_CHANGES
GIT_INPUT_RESULT: DELETED_ONLY
GIT_INPUT_RESULT: NO_CODE_FILES
GIT_INPUT_RESULT: NO_GIT_REPO
GIT_INPUT_RESULT: DETACHED_HEAD
GIT_INPUT_RESULT: MERGE_CONFLICT
GIT_INPUT_RESULT: REBASE_IN_PROGRESS
GIT_INPUT_RESULT: ABORTED

# Pre-Check Results
PRE_CHECK_RESULT: SUCCESS
PRE_CHECK_RESULT: PARTIAL

# Code Review Results
REVIEW_RESULT: ISSUES_FOUND
REVIEW_RESULT: NO_ISSUES

# Fix Results
FIX_RESULT: SUCCESS
FIX_RESULT: PARTIAL

# Quality Check Results
QUALITY_SCORE: XX/100

# Build Results
BUILD_RESULT: SUCCESS
BUILD_RESULT: FAIL
BUILD_RESULT: FAIL_DEPS
BUILD_RESULT: SKIP

# Test Results
TEST_RESULT: SUCCESS
TEST_RESULT: FAIL
TEST_RESULT: SKIPPED
TEST_RESULT: NO_TESTS

# Commit Results
COMMIT_RESULT: SUCCESS
COMMIT_RESULT: NO_CHANGES
COMMIT_RESULT: SKIPPED

# Push Results
PUSH_RESULT: SUCCESS
PUSH_RESULT: SKIPPED
PUSH_RESULT: FAIL
```

---

## 4. Qwen3-Next 호환성

### 4.1 LLM 호환성을 위한 설계 패턴

| 패턴 | 구현 방식 | 이점 |
|------|-----------|------|
| 시각적 구조 | Box-drawing 문자 (┌─┬─┐) | 명확한 구조화 |
| 결과 토큰 | `CATEGORY: VALUE` 형식 | 결정론적 파싱 |
| 단계 번호 매기기 | STEP 1, STEP 2 등 | 순차적 실행 |
| 의사 코드 흐름 | IF/THEN/ELSE 조건문 | 명시적 분기 |
| 금지 표시 | 시각적 강조와 함께 사용 | 중요 규칙 강조 |
| 필수 표시 | 시각적 강조와 함께 사용 | 필수 출력 표시 |
| 플레이스홀더 금지 규칙 | 전역 적용 | 할루시네이션 방지 |

### 4.2 모델 고려사항

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Dual Model Characteristics                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Qwen3.5-122B-A10B-FP8 (SGLang port 8000, 단일 서버)                  │
│  요청별 thinking 제어 via chat_template_kwargs                          │
│                                                                         │
│  Thinking Mode (enable_thinking=true):                                 │
│    - 자기 추론 능력 (CoT)                                                │
│    - 3개 에이전트: code-reviewer, quality-checker, summary-reporter     │
│                                                                         │
│  Instruct Mode (enable_thinking=false):                                │
│    - Non-thinking, 빠른 코드 생성                                       │
│    - 11개 에이전트: Orchestrator, env-setup, git-input, file-input,     │
│      pre-checker, code-fixer, build-tester, function-tester,           │
│      git-committer, git-pusher                                         │
│                                                                         │
│  로컬 추론:                                                              │
│    - 토큰 비용: 해당 없음 (로컬 서빙)                                     │
│    - 지연 시간: 컨텍스트 길이에 비례                                       │
│    - 품질/일관성: 주요 관심사                                              │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### 4.3 최적화 계획

1. **듀얼 모델 전략 (구현 완료)**
   - Thinking 모델: 복잡한 추론 작업 (코드 리뷰, 품질 검사)
   - Coder 모델: 코드 생성/수정 작업 (SWE-Bench 최적화)

2. **에이전트 재배치**
   - 각 에이전트를 두 모델 모두로 테스트
   - 정확도 및 지연 시간 측정
   - 에이전트별 최적 모델 할당

3. **워크플로우 최적화**
   - 가능한 경우 병렬 실행
   - 반복 작업에 대한 캐싱

---

## 5. 워크플로우 시나리오

### 5.1 시나리오 매트릭스: 캐시 상태 x 옵션

| 시나리오 | 캐시 상태 | 옵션 | 예상 동작 |
|----------|-----------|------|-----------|
| S1 | 유효한 캐시 | (기본값) | 캐시 사용 |
| S2 | 유효한 캐시 | --skip-cache | 캐시 무시 |
| S3 | 유효한 캐시 | --with-analysis | 캐시 사용 (재분석 없음) |
| S4 | 만료된 캐시 | (기본값) | 경고 + 캐시 없이 진행 |
| S5 | 만료된 캐시 | --with-analysis | 재분석 실행 |
| S6 | 캐시 없음 | (기본값) | 경고 + 캐시 없이 진행 |
| S7 | 캐시 없음 | --with-analysis | 분석 실행 |
| S8 | 캐시 없음 | --skip-cache | 캐시 무시 (분석 없음) |

### 5.2 시나리오 매트릭스: 입력 모드 x 캐시

| 시나리오 | 입력 모드 | 캐시 상태 | 예상 동작 |
|----------|-----------|-----------|-----------|
| I1 | --working | 캐시 있음 | 캐시 컨텍스트 + git diff |
| I2 | --working | 캐시 없음 | git diff만 |
| I3 | --staged | 캐시 있음 | 캐시 컨텍스트 + staged |
| I4 | --last | 캐시 있음 | 캐시 컨텍스트 + 마지막 커밋 |
| I5 | --branch | 캐시 있음 | 캐시 컨텍스트 + 브랜치 diff |
| I6 | --files | 캐시 있음 | 캐시 컨텍스트 + 지정된 파일 |
| I7 | --files | 캐시 없음 | 지정된 파일만 |

---

## 6. 파일 변경 요약

### 6.1 수정된 파일

| 파일 | 변경 내용 |
|------|-----------|
| `.opencode/command/code-qa.md` | 경량 래퍼 (mode/code-qa.md를 단일 소스로 참조) |
| `.opencode/agent/git-input.md` | 영문 번역, 새로운 결과 토큰 |
| `.opencode/agent/build-tester.md` | 영문 번역, FAIL_DEPS 처리 |
| `.opencode/agent/workspace-analyzer.md` | 전체 영문 번역 |
| `docs/guides/16-workflow-case-review.md` | 영문 재작성, 모든 이슈 해결 완료 표시 |

### 6.2 커밋 이력

| 커밋 | 메시지 |
|------|--------|
| `bdfd9fca5` | feat: implement edge case handling and translate agents to English |
| `225760dd7` | docs: translate remaining Korean text in workspace-analyzer to English |

---

## 7. 테스트 체크리스트

### 7.1 정상 경로 테스트

```bash
# T1: 기본 Git 모드
/code-qa

# T2: Staged 변경사항만
git add src/app.py
/code-qa --staged

# T3: 직접 파일 지정
/code-qa --files src/

# T4: 캐시 활용
/analyze
/code-qa

# T5: 캐시 + 분석 동시 실행
/code-qa --with-analysis
```

### 7.2 엣지 케이스 테스트

```bash
# T6: 변경사항 없음
git status  # clean
/code-qa    # → "No changed files" 메시지

# T7: 삭제된 파일만 존재
git rm old_file.py
/code-qa --staged  # → 삭제된 파일 처리

# T8: 대량 파일 수 (100개 이상)
/code-qa  # → 경고 및 필터링

# T9: Git이 아닌 디렉토리
cd /tmp/non-git-project
/code-qa  # → NO_GIT_REPO 처리

# T10: Detached HEAD
git checkout HEAD~1
/code-qa  # → DETACHED_HEAD 처리

# T11: Merge conflict
git merge feature --no-commit  # 충돌 생성
/code-qa  # → MERGE_CONFLICT 처리

# T12: Rebase 진행 중
git rebase main  # rebase 상태 생성
/code-qa  # → REBASE_IN_PROGRESS 처리

# T13: 의존성 미설치
rm -rf node_modules
/code-qa  # → FAIL_DEPS 처리
```

---

## 8. 환경 설정 간소화

### 8.1 기존 설계의 문제점

기존 env-setup 에이전트는 4회의 사용자 상호작용이 필요했습니다:

```
기존 흐름 (4회 WAITING_INPUT):
STEP 1: 셸 선택 → WAITING_INPUT
STEP 2: 환경 유형 선택 → WAITING_INPUT
STEP 3: 환경 이름 선택 → WAITING_INPUT
STEP 4: 활성화 확인 → WAITING_INPUT
```

문제점:
- 사용자는 이미 환경이 설정되어 있음
- `$SHELL`이 이미 알려주는데 셸 선택을 강제
- `$CONDA_DEFAULT_ENV` 또는 `$VIRTUAL_ENV`가 이미 설정되어 있는데 환경 유형을 질문
- `/code-qa` 실행마다 너무 많은 마찰 발생

### 8.2 간소화된 설계

최소한의 상호작용으로 구성된 새로운 흐름:

```
새로운 흐름 (1-2회 WAITING_INPUT):

[활성 환경 감지됨]
  → "현재 환경을 사용하시겠습니까? [Y/n/list]"
  → Y: SUCCESS (1회 상호작용)
  → n: 목록 표시 → 선택 → SUCCESS (2회 상호작용)

[활성 환경 없음]
  → 환경 목록 표시 → 선택 → SUCCESS (2회 상호작용)
```

### 8.3 주요 변경사항

| 항목 | 기존 | 변경 후 |
|------|------|---------|
| 셸 선택 | 명시적 선택 | 자동 감지 (선택 없음) |
| 환경 유형 | 반드시 선택 | 활성 환경에서 자동 감지 |
| 환경 목록 | 항상 표시 | 변경 시에만 표시 |
| 정상 경로 | 4회 상호작용 | 1회 상호작용 |
| 설정 지원 | 힌트만 제공 | `auto_confirm: true` 옵션 |

### 8.4 통합 감지 명령

단일 Bash 호출로 모든 항목을 감지합니다:
- 현재 셸 및 버전
- 활성 환경 (conda/venv)
- 모든 conda 환경 (전체 목록)
- 로컬 .venv 디렉토리
- 기타 관리자 (uv, poetry, pipenv, pyenv)
- 언어 런타임
- GPU 가용성

---

## 9. 아키텍처 결정

### 9.1 결과 토큰을 사용하는 이유

결과 토큰이 제공하는 이점:
- **결정론적 파싱**: 상태 감지에 모호함 없음
- **오류 복원력**: 명확한 성공/실패 표시
- **디버깅**: 워크플로우 상태 추적 용이
- **모델 독립성**: 다양한 LLM 백엔드에서 작동

### 9.2 영어를 사용하는 이유

- 대부분의 LLM에서 주요 학습 언어
- 더 나은 토큰화 효율성
- 더 넓은 커뮤니티 접근성
- 코드베이스 전반에 걸친 일관된 용어 사용

### 9.3 시각적 포맷팅을 사용하는 이유

- 모델의 구조 이해를 돕음
- 복잡한 지시사항의 모호함 감소
- 명확한 섹션 경계 제공
- 마크다운 렌더링과 호환

---

## 10. 관련 문서

| 문서 | 설명 |
|------|------|
| `13-code-qa-v4-complete-diagram.md` | 전체 워크플로우 다이어그램 |
| `14-code-qa-v4-quick-start.md` | 빠른 시작 가이드 (EN) |
| `14-code-qa-v4-quick-start.kr.md` | 빠른 시작 가이드 (KR) |
| `15-workspace-analysis-workflow.md` | 작업공간 분석 상세 |
| `16-workflow-case-review.md` | 케이스 리뷰 및 엣지 케이스 |
| `20-dual-model-strategy-report.md` | 듀얼 모델 전략 보고서 |

---

## 변경 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|-----------|
| 1.0 | 2025-02-04 | 초기 구현 요약 |
| 1.1 | 2025-02-04 | env-setup 간소화 (4단계 → 1-2단계) |
| 1.2 | 2026-02-05 | 전체 결과 토큰 목록, 단계 다이어그램 수정, 전체 13개 에이전트 추가 |
