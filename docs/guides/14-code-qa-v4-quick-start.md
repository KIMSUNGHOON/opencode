# Code QA v4 Quick Start Guide

이 문서는 Code QA v4 워크플로우를 바로 사용할 수 있도록 설정 파일과 사용 방법을 제공합니다.

## 목차

1. [개요](#1-개요)
2. [설치](#2-설치)
3. [글로벌 설정](#3-글로벌-설정)
4. [환경 설정](#4-환경-설정-선택)
5. [Agent 파일](#5-agent-파일)
6. [사용 방법](#6-사용-방법)
7. [문제 해결](#7-문제-해결)

---

## 1. 개요

Code QA v4는 11개의 Phase로 구성된 자동화된 코드 품질 검사 워크플로우입니다.

### 주요 특징

- **Environment Setup**: 자동 환경 감지 및 설정
- **Docker Sandbox**: 격리된 Build/Test 환경
- **단일 모델 전략**: Qwen3-Next-80B-A3B-Thinking (Reasoning + Tool Calling)
- **회귀 루프**: 품질 기준 미달 시 자동 재시도
- **256K Context Window**: 긴 코드 파일 처리 가능

### 단일 모델 전략

| 모델 | 용도 | 역할 |
|------|------|-------|
| **Qwen3-Next-80B-A3B-Thinking** | Reasoning + Tool Calling | 오케스트레이터 + 모든 Sub-Agent |

> **왜 단일 모델인가?**
> - **256K Context Window**: 긴 코드 파일도 한 번에 처리 가능
> - **Thinking + Tool Calling**: 추론과 도구 호출 모두 단일 모델로 지원
> - **단순한 인프라**: 하나의 모델 서버만 운영
> - **일관된 성능**: 모델 전환 없이 낮은 지연시간

### 하드웨어 요구사항

```
권장: 2x H100 NVL 96GB (Tensor Parallel)
- 모델 가중치 (FP8): ~76GB
- KV Cache (256K): ~50GB
- 여유: ~66GB

최소: 1x H100 NVL 96GB
- Context 128K 제한
```

---

## 2. 설치

### 2.1 파일 구조

```
~/.config/opencode/
└── opencode.json              # 글로벌 설정 (Provider, Model 포함)

your-project/
├── .opencode/
│   ├── env-config.yaml        # 환경 설정 (선택)
│   ├── agent/
│   │   ├── env-setup.md       # Phase -1
│   │   ├── git-input.md       # Phase 0
│   │   ├── pre-checker.md     # Phase 1
│   │   ├── code-reviewer.md   # Phase 2
│   │   ├── code-fixer.md      # Phase 3
│   │   ├── quality-checker.md # Phase 4
│   │   ├── build-tester.md    # Phase 5
│   │   ├── function-tester.md # Phase 6
│   │   ├── git-committer.md   # Phase 7
│   │   ├── summary-reporter.md# Phase 8
│   │   └── git-pusher.md      # Phase 9
│   ├── command/
│   │   └── code-qa.md         # Command 워크플로우
│   ├── mode/
│   │   └── code-qa.md         # Mode 워크플로우
│   └── docker/
│       └── Dockerfile.sandbox # Sandbox 이미지 (선택)
└── ...
```

### 2.2 필수 도구

```bash
# Python 프로젝트
pip install ruff mypy pytest pytest-cov radon

# Node.js 프로젝트
npm install -D eslint prettier jest

# Docker Sandbox (선택)
docker --version
nvidia-docker --version  # GPU 사용 시
```

### 2.3 모델 서버 배포 (SGLang)

SGLang을 사용하여 모델 서버를 배포합니다.

#### SGLang vs vLLM

| 항목 | SGLang | vLLM |
|------|--------|------|
| **처리량** | 16,215 tok/s | 12,553 tok/s (+29%) |
| **동시 요청** | 안정적 (75-78 tok/s) | 감소 (37→35 tok/s) |
| **Multi-turn** | RadixAttention (~10% 향상) | 기본 |
| **Qwen3-Next 최적화** | MambaRadixCache, NEXTN | - |

> **권장: SGLang** - Multi-turn 대화, 긴 컨텍스트, 안정적 성능

#### 설치

```bash
# SGLang 설치
pip install "sglang[all]>=0.4.6"

# FlashInfer 설치 (성능 향상)
pip install flashinfer -i https://flashinfer.ai/whl/cu124/torch2.5/
```

#### 기본 배포

```bash
# 2x H100 NVL - 256K context
python3 -m sglang.launch_server \
  --model Qwen/Qwen3-Next-80B-A3B-Thinking-FP8 \
  --tp 2 \
  --context-length 262144 \
  --port 8000 \
  --host 0.0.0.0

# 1x H100 NVL - 128K context (최소 구성)
python3 -m sglang.launch_server \
  --model Qwen/Qwen3-Next-80B-A3B-Thinking-FP8 \
  --context-length 131072 \
  --port 8000 \
  --host 0.0.0.0
```

#### 고성능 배포 (Speculative Decoding)

단일 사용자 추론 시 ~30% 성능 향상:

```bash
# NEXTN Speculative Decoding (2x H100 NVL)
python3 -m sglang.launch_server \
  --model Qwen/Qwen3-Next-80B-A3B-Thinking-FP8 \
  --tp 2 \
  --context-length 262144 \
  --speculative-algo NEXTN \
  --speculative-num-steps 3 \
  --speculative-eagle-topk 1 \
  --speculative-num-draft-tokens 4 \
  --port 8000 \
  --host 0.0.0.0
```

#### 서버 상태 확인

```bash
curl http://localhost:8000/v1/models
```

---

## 3. 글로벌 설정

글로벌 설정 파일을 `~/.config/opencode/opencode.json`에 생성합니다.

### 3.1 글로벌 설정 파일 (복사해서 사용)

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "qwen/qwen3-next-80b-a3b-thinking",
  "provider": {
    "qwen": {
      "name": "Qwen3-Next-Thinking Server",
      "npm": "@ai-sdk/openai-compatible",
      "api": "http://localhost:8000/v1",
      "options": {
        "apiKey": "dummy",
        "baseURL": "http://localhost:8000/v1",
        "timeout": 600000
      },
      "models": {
        "qwen3-next-80b-a3b-thinking": {
          "name": "Qwen3-Next-80B-A3B-Thinking (Unified)",
          "id": "Qwen/Qwen3-Next-80B-A3B-Thinking-FP8",
          "tool_call": true,
          "temperature": true,
          "reasoning": true,
          "limit": {
            "context": 262144,
            "output": 16384
          }
        }
      }
    }
  },
  "agents": {
    "env-setup": {
      "model": "qwen/qwen3-next-80b-a3b-thinking",
      "temperature": 0.3,
      "top_p": 0.9
    },
    "git-input": {
      "model": "qwen/qwen3-next-80b-a3b-thinking",
      "temperature": 0.1,
      "top_p": 0.9
    },
    "pre-checker": {
      "model": "qwen/qwen3-next-80b-a3b-thinking",
      "temperature": 0.2,
      "top_p": 0.9
    },
    "code-reviewer": {
      "model": "qwen/qwen3-next-80b-a3b-thinking",
      "temperature": 0.7,
      "top_p": 0.95,
      "top_k": 40,
      "min_p": 0.05
    },
    "code-fixer": {
      "model": "qwen/qwen3-next-80b-a3b-thinking",
      "temperature": 0.3,
      "top_p": 0.9,
      "top_k": 20
    },
    "quality-checker": {
      "model": "qwen/qwen3-next-80b-a3b-thinking",
      "temperature": 0.2,
      "top_p": 0.9
    },
    "build-tester": {
      "model": "qwen/qwen3-next-80b-a3b-thinking",
      "temperature": 0.1,
      "top_p": 0.9
    },
    "function-tester": {
      "model": "qwen/qwen3-next-80b-a3b-thinking",
      "temperature": 0.1,
      "top_p": 0.9
    },
    "git-committer": {
      "model": "qwen/qwen3-next-80b-a3b-thinking",
      "temperature": 0.3,
      "top_p": 0.9
    },
    "summary-reporter": {
      "model": "qwen/qwen3-next-80b-a3b-thinking",
      "temperature": 0.6,
      "top_p": 0.95,
      "top_k": 40,
      "min_p": 0.05
    },
    "git-pusher": {
      "model": "qwen/qwen3-next-80b-a3b-thinking",
      "temperature": 0.1,
      "top_p": 0.9
    }
  }
}
```

### 3.2 설정 항목 설명

| 항목 | 설명 |
|------|------|
| `model` | 기본 모델 (오케스트레이터 + Sub-Agent) |
| `provider.qwen.api` | SGLang 서버 API 엔드포인트 |
| `provider.qwen.options.timeout` | 요청 타임아웃 (ms) - 긴 추론 고려 |
| `limit.context` | 컨텍스트 윈도우 (256K) |
| `limit.output` | 최대 출력 토큰 (16K) |
| `agents.{name}` | Agent별 모델 및 샘플링 파라미터 오버라이드 |

> **Note**: SGLang은 OpenAI compatible API (`/v1/*`)를 제공하므로 `@ai-sdk/openai-compatible` 패키지를 그대로 사용합니다. vLLM에서 SGLang으로 전환해도 설정 변경이 필요 없습니다.

### 3.3 Agent별 샘플링 파라미터

각 Agent의 역할에 맞게 샘플링 파라미터를 조정합니다:

| Agent | Temperature | Top-P | Top-K | Min-P | 설명 |
|-------|-------------|-------|-------|-------|------|
| **code-reviewer** | 0.7 | 0.95 | 40 | 0.05 | 창의적 분석, 다양한 이슈 탐지 |
| **summary-reporter** | 0.6 | 0.95 | 40 | 0.05 | 종합적 리포트 생성 |
| **code-fixer** | 0.3 | 0.9 | 20 | - | 정확한 코드 수정 |
| **git-committer** | 0.3 | 0.9 | - | - | 일관된 커밋 메시지 |
| **env-setup** | 0.3 | 0.9 | - | - | 안정적 환경 감지 |
| **pre-checker** | 0.2 | 0.9 | - | - | 정확한 Lint 수정 |
| **quality-checker** | 0.2 | 0.9 | - | - | 일관된 점수 계산 |
| **git-input** | 0.1 | 0.9 | - | - | 정확한 파일 파싱 |
| **build-tester** | 0.1 | 0.9 | - | - | 정확한 빌드 명령 |
| **function-tester** | 0.1 | 0.9 | - | - | 정확한 테스트 실행 |
| **git-pusher** | 0.1 | 0.9 | - | - | 안전한 Push 처리 |

#### 샘플링 파라미터 설명

| 파라미터 | 범위 | 설명 |
|----------|------|------|
| `temperature` | 0.0-2.0 | 높을수록 창의적, 낮을수록 결정적 |
| `top_p` | 0.0-1.0 | 누적 확률 기반 토큰 필터링 |
| `top_k` | 1-100 | 상위 K개 토큰만 고려 |
| `min_p` | 0.0-1.0 | 최소 확률 임계값 (낮은 확률 토큰 제거) |

> **팁**: Reasoning 작업(code-reviewer, summary-reporter)은 높은 temperature로 다양한 관점 탐색, Tool Calling 작업(build-tester, git-pusher)은 낮은 temperature로 정확성 확보

### 3.4 모델 설정 상세

```json
"qwen3-next-80b-a3b-thinking": {
  "name": "Qwen3-Next-80B-A3B-Thinking (Unified)",
  "id": "Qwen/Qwen3-Next-80B-A3B-Thinking-FP8",  // SGLang 서버의 모델 ID
  "tool_call": true,         // Tool/Function Calling 지원
  "temperature": true,       // Temperature 조절 지원
  "reasoning": true,         // Thinking mode 지원
  "limit": {
    "context": 262144,       // 256K 컨텍스트
    "output": 16384          // 16K 출력
  }
}
```

### 3.5 단일 모델의 장점

| 기존 (Dual Model) | 현재 (Single Model) |
|-------------------|---------------------|
| GPT-OSS-120B (128K, 불안정) + Qwen3-Coder-30B | Qwen3-Next-80B-A3B-Thinking |
| 두 개의 모델 서버 운영 | 하나의 모델 서버 |
| 모델 간 전환 지연 | 전환 없음 |
| 16K 실질 context 제한 | 256K context |

---

## 4. 환경 설정 (선택)

`.opencode/env-config.yaml`:

```yaml
# Shell 설정
shell:
  type: "zsh"
  rc_file: "~/.zshrc"

# 환경 설정
environment:
  name: "my-project-env"
  type: "conda"

# 요구 사항 (더블 체크용)
requirements:
  python: ">=3.10"
  cuda: ">=11.8"
  torch: ">=2.0"

# Sandbox 설정
sandbox:
  enabled: true
  dockerfile: ".opencode/docker/Dockerfile.sandbox"
  image_name: "qa-sandbox"
  gpu: true
  build_args:
    CUDA_VERSION: "11.8.0"
    PYTHON_VERSION: "3.11"
```

---

## 5. Agent 파일

Agent 파일들은 `.opencode/agent/` 디렉토리에 위치합니다.

### 5.1 Agent 파일 목록

모든 Agent가 동일한 모델(Qwen3-Next-80B-A3B-Thinking)을 사용합니다.

| 파일 | Phase | 역할 |
|------|-------|------|
| `env-setup.md` | -1 | 환경 감지 및 설정 |
| `git-input.md` | 0 | Git 변경 파일 추출 |
| `pre-checker.md` | 1 | Lint/Format 자동 수정 |
| `code-reviewer.md` | 2 | 코드 심층 분석 (Thinking mode) |
| `code-fixer.md` | 3 | 이슈 수정 |
| `quality-checker.md` | 4 | 품질 점수 검사 |
| `build-tester.md` | 5 | 빌드 테스트 |
| `function-tester.md` | 6 | 기능 테스트 |
| `git-committer.md` | 7 | Git 커밋 |
| `summary-reporter.md` | 8 | 결과 종합 리포트 (Thinking mode) |
| `git-pusher.md` | 9 | Push 및 PR |

### 5.2 Mode 파일 (오케스트레이터)

오케스트레이터는 `.opencode/mode/code-qa.md`에 정의됩니다.

```markdown
---
description: "Code QA 워크플로우 - 자동화된 코드 품질 검사"
model: qwen/qwen3-next-80b-a3b-thinking
mode: all
color: "#E74C3C"
---
```

> **단일 모델의 이점**: Qwen3-Next-Thinking은 Thinking mode로 복잡한 추론을, Tool Calling으로 도구 실행을 모두 수행합니다. 별도의 모델 전환 없이 오케스트레이터와 Sub-Agent 역할을 모두 담당합니다.

### 5.3 Sub-Agent 파일 구조

```markdown
---
description: Agent 설명
mode: subagent
model: qwen/qwen3-next-80b-a3b-thinking  # 동일 모델 사용
color: "#3498DB"
tools:
  "*": false
  "Bash": true
  "Read": true
permission:
  bash:
    "git status *": allow
    "rm *": deny
    "*": deny
  read: allow
  edit: deny
---

# Agent Name

역할 및 실행 단계 설명...
```

### 5.4 Permission 규칙

```yaml
permission:
  bash:
    "exact command": allow      # 정확히 일치
    "pattern *": allow          # 와일드카드 매칭
    "dangerous *": deny         # 차단
    "*": deny                   # 기본 차단 (권장)
  read: allow                   # 파일 읽기
  edit: allow | deny            # 파일 수정
  glob: allow                   # 파일 탐색
  grep: allow                   # 코드 검색
```

---

## 6. 사용 방법

### 6.1 Mode vs Command

Code QA는 두 가지 방식으로 사용할 수 있습니다:

| 방식 | 위치 | 사용법 | 용도 |
|------|------|--------|------|
| **Mode** | `.opencode/mode/code-qa.md` | 모드 선택기에서 "code-qa" 선택 | 지속적인 QA 세션 |
| **Command** | `.opencode/command/code-qa.md` | `/code-qa [options]` | 일회성 QA 실행 |

#### Mode로 사용하기

opencode의 build, plan 등과 같이 모드 선택기에서 "code-qa"를 선택하면 Code QA 워크플로우 오케스트레이터 모드로 전환됩니다.

```
# opencode 실행 후 모드 선택기에서:
> code-qa (Code QA 워크플로우 - 자동화된 코드 품질 검사)
```

Mode를 선택하면 대화 전체가 Code QA 워크플로우 컨텍스트에서 진행됩니다.

#### Command로 사용하기

특정 옵션과 함께 일회성으로 QA를 실행할 때 사용합니다.

### 6.2 기본 사용

```bash
# Working directory 변경 검사 (기본값)
/code-qa

# Staged 변경만 검사
/code-qa --staged

# 마지막 커밋 검사
/code-qa --last

# 브랜치 전체 검사
/code-qa --branch

# 특정 커밋 범위 검사
/code-qa --range abc123..def456
```

### 6.3 Sandbox 옵션

```bash
# Docker Sandbox에서 실행 (기본값)
/code-qa

# 호스트에서 직접 실행
/code-qa --no-sandbox
```

### 6.4 조합 사용

```bash
# Staged 변경을 호스트에서 검사
/code-qa --staged --no-sandbox

# 마지막 커밋을 Sandbox에서 검사
/code-qa --last
```

### 6.5 워크플로우 진행 과정

```
Phase -1: Environment Setup
    ↓
Phase 0: Git Input
    ↓
Phase 1: Pre-Check (Lint/Format)
    ↓
Phase 2: Code Review (Thinking mode)
    ↓
Phase 3: Code Fix
    ↓
Phase 4: Quality Check ──┐
    │                    │
    ↓ (>=70점)          │ (<70점)
    │                    │
Phase 5: Build Test     │
    │                    │
    ↓ (성공)             │
    │                    │
Phase 6: Function Test  │
    │                    │
    └──→ 실패 시 ────────┘
                        ↓
                   Code Fixer로 회귀
                   (최대 3회)
    ↓
Phase 7: Git Commit
    ↓
Phase 8: Summary Report (Thinking mode)
    ↓
Phase 9: Push & PR (사용자 확인)
```

---

## 7. 문제 해결

### 7.1 모델 연결 실패

```
Error: Failed to connect to model server
```

**해결:**
```bash
# SGLang 서버 상태 확인
curl http://localhost:8000/v1/models

# 서버 health check
curl http://localhost:8000/health

# 서버 로그 확인
# (SGLang은 stdout으로 로그 출력)
```
- 글로벌 설정의 `api` URL 확인
- 방화벽 설정 확인
- SGLang 서버 재시작

### 7.2 OOM (Out of Memory) 오류

```
Error: CUDA out of memory
```

**해결:**
```bash
# Context 길이 줄이기
python3 -m sglang.launch_server \
  --model Qwen/Qwen3-Next-80B-A3B-Thinking-FP8 \
  --tp 2 \
  --context-length 131072 \  # 256K → 128K
  --port 8000

# 또는 chunked prefill 사용
python3 -m sglang.launch_server \
  --model Qwen/Qwen3-Next-80B-A3B-Thinking-FP8 \
  --tp 2 \
  --chunked-prefill-size 4096 \
  --port 8000
```

### 7.3 Docker Sandbox 실패

```
Error: Docker image not found
```

**해결:**
```bash
# Dockerfile 확인
ls .opencode/docker/Dockerfile.sandbox

# 이미지 빌드
docker build -t qa-sandbox -f .opencode/docker/Dockerfile.sandbox .
```

### 7.4 환경 감지 실패

```
Warning: No conda environment detected
```

**해결:**
1. conda 환경 활성화: `conda activate my-env`
2. `.opencode/env-config.yaml`에 환경 설정 추가

### 7.5 Permission 오류

```
Error: Command denied by permission rules
```

**해결:**
1. Agent 파일의 `permission.bash` 규칙 확인
2. 필요한 명령 패턴 추가

### 7.6 품질 점수 미달

```
Quality Score: 45/100 (FAIL)
Retrying... (attempt 2/3)
```

**정상 동작:** 자동으로 Code Fixer로 회귀하여 재시도합니다.

3회 실패 시:
- 수동 검토 필요
- 남은 이슈 확인
- 필요 시 수동 수정

### 7.7 긴 응답 시간

```
Warning: Response taking longer than expected
```

**해결:**
- Thinking mode는 복잡한 추론에 시간이 걸림
- `timeout` 설정 확인 (기본 600000ms = 10분)
- 정상적인 동작임

---

## 부록: Docker Sandbox Dockerfile 예시

`.opencode/docker/Dockerfile.sandbox`:

```dockerfile
# Multi-stage build for smaller image
FROM nvidia/cuda:11.8.0-devel-ubuntu22.04 AS builder

ARG PYTHON_VERSION=3.11

# Install Python
RUN apt-get update && apt-get install -y \
    python${PYTHON_VERSION} \
    python${PYTHON_VERSION}-venv \
    python${PYTHON_VERSION}-dev \
    && rm -rf /var/lib/apt/lists/*

# Create venv
RUN python${PYTHON_VERSION} -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install common tools
RUN pip install --no-cache-dir \
    pytest pytest-cov \
    ruff mypy \
    build twine

# Runtime image
FROM nvidia/cuda:11.8.0-runtime-ubuntu22.04

ARG PYTHON_VERSION=3.11

RUN apt-get update && apt-get install -y \
    python${PYTHON_VERSION} \
    git \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

WORKDIR /workspace

CMD ["bash"]
```

---

## 관련 문서

- [12-environment-setup-workflow.md](./12-environment-setup-workflow.md) - 환경 설정 상세
- [13-code-qa-v4-complete-diagram.md](./13-code-qa-v4-complete-diagram.md) - 전체 워크플로우 다이어그램
- [11-code-qa-workflow-v3-git-integrated.md](./11-code-qa-workflow-v3-git-integrated.md) - v3 워크플로우 (레거시)
