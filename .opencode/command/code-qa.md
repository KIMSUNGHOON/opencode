---
description: "Code QA 워크플로우 v4 (Environment + Git + Sandbox 통합)"
model: opencode/gpt-oss-120b
---

# Code QA Workflow v4

$ARGUMENTS

## 설정

```
MAX_RETRY = 3
QUALITY_THRESHOLD = 70
```

## 모델 배분

| Agent | 모델 | 근거 |
|-------|------|------|
| @env-setup | Qwen3-Coder | Tool calling |
| @git-input | Qwen3-Coder | Tool calling |
| @pre-checker | Qwen3-Coder | Tool calling |
| @code-reviewer | **GPT-OSS-120B** | CoT 분석 |
| @code-fixer | Qwen3-Coder | SWE-Bench SOTA |
| @quality-checker | Qwen3-Coder | Tool calling |
| @build-tester | Qwen3-Coder | Agentic |
| @function-tester | Qwen3-Coder | Agentic |
| @git-committer | Qwen3-Coder | Tool calling |
| @summary-reporter | **GPT-OSS-120B** | CoT 종합 |
| @git-pusher | Qwen3-Coder | Tool calling |

---

## 입력 옵션

### Git 옵션
- (기본값): `--working` (git diff)
- `--staged`: staged 변경만
- `--last`: 마지막 커밋
- `--branch`: 브랜치 전체
- `--range <a>..<b>`: 특정 범위

### Sandbox 옵션
- (기본값): Docker Sandbox에서 Build/Test 실행 (GPU 지원)
- `--no-sandbox`: 호스트에서 직접 Build/Test 실행

---

## Phase -1: Environment Setup

**먼저 @env-setup을 호출하여 실행 환경을 확인합니다.** (Qwen3-Coder)

@env-setup에게 다음을 요청:
1. Shell 확인 (zsh/bash/sh)
2. 현재 활성화된 환경 확인
3. 환경이 없으면 사용자에게 선택 요청
4. Python, CUDA, PyTorch 버전 더블 체크

환경 설정이 완료되면 다음 Phase로 진행합니다.

---

## Phase 0: Git Input

@git-input을 호출하여: (Qwen3-Coder)
1. 입력 모드 파싱 ($ARGUMENTS에서)
2. 변경 파일 추출
3. 검사 대상 목록 생성

---

## Phase 1-3: 코드 분석 및 수정

순차적으로 호출 (호스트에서 실행):

1. **@pre-checker** (Qwen3-Coder) - 자동 수정 (lint --fix, format)
2. **@code-reviewer** (GPT-OSS-120B) - 심층 코드 분석 (Chain-of-Thought)
3. **@code-fixer** (Qwen3-Coder) - 발견된 이슈 수정 (SWE-Bench SOTA)

---

## Phase 4: Quality Check

**@quality-checker** (Qwen3-Coder) - 품질 점수 검사 (≥70% 필요)

---

## Phase 5-6: Build & Test

### 기본값 (Docker Sandbox 실행)

Build와 Test는 **기본적으로 Docker Sandbox에서 실행**됩니다.

5. **@build-tester** (Qwen3-Coder) - Docker 컨테이너에서 빌드 테스트
6. **@function-tester** (Qwen3-Coder) - Docker 컨테이너에서 기능 테스트

#### Sandbox 실행 방법

```bash
# Docker 이미지 빌드 (첫 실행 시 또는 캐시 무효화 시)
docker build -t qa-sandbox -f .opencode/docker/Dockerfile.sandbox .

# 빌드 테스트 (GPU 사용)
docker run --gpus all --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  qa-sandbox \
  python -m pytest tests/ --tb=short || npm run build

# 기능 테스트 (GPU 사용)
docker run --gpus all --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  qa-sandbox \
  python -m pytest tests/ -v || npm test
```

### `--no-sandbox` 플래그가 있는 경우 (호스트 실행)

5. **@build-tester --no-sandbox** (Qwen3-Coder) - 호스트에서 빌드 테스트
6. **@function-tester --no-sandbox** (Qwen3-Coder) - 호스트에서 기능 테스트

#### Sandbox 설정 (env-config.yaml)

```yaml
sandbox:
  enabled: true                     # 기본값: Docker Sandbox 사용
  dockerfile: ".opencode/docker/Dockerfile.sandbox"
  image_name: "qa-sandbox"
  gpu: true                         # nvidia-docker 사용
  build_args:
    CUDA_VERSION: "11.8.0"
    PYTHON_VERSION: "3.11"
```

---

## 회귀 조건

- Quality Check < 70% → @code-fixer로 회귀 (최대 3회)
- Build 실패 → @code-fixer로 회귀
- Test 실패 → @code-fixer로 회귀

---

## Phase 7: Commit

@git-committer를 호출하여: (Qwen3-Coder)
1. 수정 여부 확인 (`git status --porcelain`)
2. 수정 있으면:
   - 커밋 전 모드 (`--working`/`--staged`) → 새 커밋
   - 커밋 후 모드 (`--last`/`--branch`) → amend

---

## Phase 8: Summary Report

@summary-reporter를 호출하여: (GPT-OSS-120B - Chain-of-Thought)
1. 전체 QA 결과 수집
2. Markdown 형식 리포트 생성
3. 사용자에게 출력

---

## Phase 9: Push & PR

@git-pusher를 호출하여: (Qwen3-Coder)
1. **사용자에게 Push 여부 확인** (필수)
2. Push 승인 시:
   - amend면 `--force-with-lease`
   - 일반이면 그냥 push
3. **사용자에게 PR 생성 여부 확인**
4. PR 승인 시 PR 정보 수집 및 생성

---

## 중요 규칙

1. **Phase -1은 항상 먼저 실행** - 환경 설정 없이 QA 진행 금지
2. **Phase 9의 모든 remote 작업은 사용자 확인 필수**
3. **강제 푸시 시 경고 표시**
4. **회귀 최대 3회**
5. **Build/Test는 기본적으로 Docker Sandbox에서 실행** (nvidia-docker 필요)
6. **호스트에서 실행하려면 `--no-sandbox` 플래그 사용**
