# Code QA v4 Quick Start Guide

이 문서는 Code QA v4 워크플로우를 바로 사용할 수 있도록 설정 파일과 사용 방법을 제공합니다.

## 목차

1. [개요](#1-개요)
2. [설치](#2-설치)
3. [글로벌 설정](#3-글로벌-설정)
4. [프로젝트 설정](#4-프로젝트-설정)
5. [Agent 파일](#5-agent-파일)
6. [사용 방법](#6-사용-방법)
7. [문제 해결](#7-문제-해결)

---

## 1. 개요

Code QA v4는 11개의 Phase로 구성된 자동화된 코드 품질 검사 워크플로우입니다.

### 주요 특징

- **Environment Setup**: 자동 환경 감지 및 설정
- **Docker Sandbox**: 격리된 Build/Test 환경
- **두 가지 모델 전략**: GPT-OSS-120B (추론) + Qwen3-Coder-30B (에이전틱)
- **회귀 루프**: 품질 기준 미달 시 자동 재시도

### 모델 배분

| 모델 | 용도 | Agent |
|------|------|-------|
| **GPT-OSS-120B** | Chain-of-Thought 추론 | code-reviewer, summary-reporter |
| **Qwen3-Coder-30B** | Tool Calling, SWE-Bench | 나머지 9개 Agent |

---

## 2. 설치

### 2.1 파일 구조

```
~/.config/opencode/
└── opencode.json              # 글로벌 설정 (Provider, Model 정의)

your-project/
├── .opencode/
│   ├── opencode.json          # 프로젝트 설정 (Agent 오버라이드)
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
│   │   └── code-qa.md         # 메인 워크플로우
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

---

## 3. 글로벌 설정

글로벌 설정 파일을 `~/.config/opencode/opencode.json`에 생성합니다.

### 3.1 글로벌 설정 파일 (복사해서 사용)

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "opencode/gpt-oss-120b",
  "small_model": "opencode/qwen3-coder-30b",
  "provider": {
    "opencode": {
      "name": "OpenCode LLM Server",
      "npm": "@ai-sdk/openai-compatible",
      "api": "http://localhost:30000/v1",
      "options": {
        "apiKey": "dummy",
        "baseURL": "http://localhost:30000/v1",
        "timeout": 300000
      },
      "models": {
        "gpt-oss-120b": {
          "name": "GPT-OSS-120B (Reasoning)",
          "id": "gpt-oss-120b",
          "tool_call": true,
          "temperature": true,
          "reasoning": true,
          "limit": {
            "context": 131072,
            "output": 8192
          }
        },
        "qwen3-coder-30b": {
          "name": "Qwen3-Coder-30B (Agentic)",
          "id": "qwen3-coder-30b-a3b-instruct",
          "tool_call": true,
          "temperature": true,
          "reasoning": false,
          "limit": {
            "context": 262144,
            "output": 8192
          }
        }
      }
    }
  }
}
```

### 3.2 설정 항목 설명

| 항목 | 설명 |
|------|------|
| `model` | 기본 모델 (메인 워크플로우용) |
| `small_model` | 보조 모델 (빠른 작업용) |
| `provider.{name}.api` | LLM 서버 API 엔드포인트 |
| `provider.{name}.options` | API 연결 옵션 |
| `provider.{name}.models` | 사용 가능한 모델 목록 |

### 3.3 모델 설정 상세

```json
"gpt-oss-120b": {
  "name": "GPT-OSS-120B (Reasoning)",  // 표시 이름
  "id": "gpt-oss-120b",                 // 서버에서 사용하는 모델 ID
  "tool_call": true,                    // Tool/Function Calling 지원
  "temperature": true,                  // Temperature 조절 지원
  "reasoning": true,                    // Chain-of-Thought 지원
  "limit": {
    "context": 131072,                  // 컨텍스트 윈도우 (128K)
    "output": 8192                      // 최대 출력 토큰
  }
}
```

---

## 4. 프로젝트 설정

프로젝트별 설정은 `.opencode/opencode.json`에 생성합니다.

### 4.1 프로젝트 설정 파일 (복사해서 사용)

```json
{
  "$schema": "https://opencode.ai/config.json",
  "extends": "~/.config/opencode/opencode.json",
  "agents": {
    "env-setup": {
      "model": "opencode/qwen3-coder-30b"
    },
    "git-input": {
      "model": "opencode/qwen3-coder-30b"
    },
    "pre-checker": {
      "model": "opencode/qwen3-coder-30b"
    },
    "code-reviewer": {
      "model": "opencode/gpt-oss-120b"
    },
    "code-fixer": {
      "model": "opencode/qwen3-coder-30b"
    },
    "quality-checker": {
      "model": "opencode/qwen3-coder-30b"
    },
    "build-tester": {
      "model": "opencode/qwen3-coder-30b"
    },
    "function-tester": {
      "model": "opencode/qwen3-coder-30b"
    },
    "git-committer": {
      "model": "opencode/qwen3-coder-30b"
    },
    "summary-reporter": {
      "model": "opencode/gpt-oss-120b"
    },
    "git-pusher": {
      "model": "opencode/qwen3-coder-30b"
    }
  }
}
```

### 4.2 환경 설정 파일 (선택)

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

| 파일 | Phase | 모델 | 역할 |
|------|-------|------|------|
| `env-setup.md` | -1 | Qwen3-Coder | 환경 감지 및 설정 |
| `git-input.md` | 0 | Qwen3-Coder | Git 변경 파일 추출 |
| `pre-checker.md` | 1 | Qwen3-Coder | Lint/Format 자동 수정 |
| `code-reviewer.md` | 2 | **GPT-OSS-120B** | 코드 심층 분석 |
| `code-fixer.md` | 3 | Qwen3-Coder | 이슈 수정 |
| `quality-checker.md` | 4 | Qwen3-Coder | 품질 점수 검사 |
| `build-tester.md` | 5 | Qwen3-Coder | 빌드 테스트 |
| `function-tester.md` | 6 | Qwen3-Coder | 기능 테스트 |
| `git-committer.md` | 7 | Qwen3-Coder | Git 커밋 |
| `summary-reporter.md` | 8 | **GPT-OSS-120B** | 결과 종합 리포트 |
| `git-pusher.md` | 9 | Qwen3-Coder | Push 및 PR |

### 5.2 Agent 파일 구조

```markdown
---
description: Agent 설명
mode: subagent
model: opencode/qwen3-coder-30b
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

### 5.3 Permission 규칙

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

### 6.1 기본 사용

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

### 6.2 Sandbox 옵션

```bash
# Docker Sandbox에서 실행 (기본값)
/code-qa

# 호스트에서 직접 실행
/code-qa --no-sandbox
```

### 6.3 조합 사용

```bash
# Staged 변경을 호스트에서 검사
/code-qa --staged --no-sandbox

# 마지막 커밋을 Sandbox에서 검사
/code-qa --last
```

### 6.4 워크플로우 진행 과정

```
Phase -1: Environment Setup
    ↓
Phase 0: Git Input
    ↓
Phase 1: Pre-Check (Lint/Format)
    ↓
Phase 2: Code Review
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
Phase 8: Summary Report
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
1. LLM 서버 상태 확인: `curl http://localhost:30000/v1/models`
2. 글로벌 설정의 `api` URL 확인
3. 방화벽 설정 확인

### 7.2 Docker Sandbox 실패

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

### 7.3 환경 감지 실패

```
Warning: No conda environment detected
```

**해결:**
1. conda 환경 활성화: `conda activate my-env`
2. `.opencode/env-config.yaml`에 환경 설정 추가

### 7.4 Permission 오류

```
Error: Command denied by permission rules
```

**해결:**
1. Agent 파일의 `permission.bash` 규칙 확인
2. 필요한 명령 패턴 추가

### 7.5 품질 점수 미달

```
Quality Score: 45/100 (FAIL)
Retrying... (attempt 2/3)
```

**정상 동작:** 자동으로 Code Fixer로 회귀하여 재시도합니다.

3회 실패 시:
- 수동 검토 필요
- 남은 이슈 확인
- 필요 시 수동 수정

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
