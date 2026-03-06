# 환경 설정 워크플로우

## 개요

이 문서는 **Code QA Workflow v4**의 환경 설정 단계(Phase -1)를 설명합니다.
OpenCode TUI에서 빌드/기능 테스트를 위한 올바른 실행 환경을 검증하고 구성합니다.

### 핵심 목적

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              Core Purpose                                        │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│   "OpenCode TUI가 빌드/기능 테스트를 수행하기 위해                              │
│    어떤 env 환경을 사용해야 하는가?"                                            │
│                                                                                  │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │  전제 조건 (이미 존재):                                                │   │
│   │  • 개발자의 conda/venv 환경                                            │   │
│   │  • ~/.zshrc, ~/.bashrc에 설정된 환경 변수                              │   │
│   │  • pip으로 설치된 패키지 (torch, numpy 등)                             │   │
│   └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
│   ┌─────────────────────────────────────────────────────────────────────────┐   │
│   │  수행해야 할 작업:                                                     │   │
│   │  1. 사용 중인 Shell 확인                                               │   │
│   │  2. 사용할 env 결정 (사용자 확인)                                      │   │
│   │  3. 최소한의 더블 체크 (Python, CUDA, PyTorch 버전)                    │   │
│   │  4. 해당 환경에서 빌드/테스트 실행                                     │   │
│   └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 대상 환경

| 항목 | 값 |
|------|-----|
| OS | Linux 개발 서버 |
| 접속 | SSH |
| Shell | bash / zsh / sh |
| 환경 관리자 | conda / venv / uv |

---

## 목차

1. [Shell 및 RC 파일](#1-shell-및-rc-파일)
2. [환경 설정](#2-환경-설정)
3. [워크플로우](#3-워크플로우)
4. [사용자 상호작용](#4-사용자-상호작용)
5. [환경 보고서](#5-환경-보고서)
6. [다이어그램](#6-다이어그램)
7. [에이전트 정의](#7-에이전트-정의)
8. [명령어 통합](#8-명령어-통합)
9. [Docker Sandbox](#9-docker-sandbox)

---

## 1. Shell 및 RC 파일

### 1.1 Shell과 RC 파일 매핑

| Shell | RC 파일 | 비고 |
|-------|---------|------|
| `zsh` | `~/.zshrc` | 기본값 (최신 Linux, macOS) |
| `bash` | `~/.bashrc` | 대화형 셸 |
| `bash` | `~/.bash_profile` | 로그인 셸 |
| `sh` | `~/.profile` | POSIX 호환 |

### 1.2 Shell 감지 방법

```bash
# 현재 Shell 확인
echo $SHELL
# → /bin/zsh

# 또는 현재 프로세스 Shell
echo $0
# → -zsh
```

### 1.3 RC 파일에서 확인할 내용

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         RC File Analysis                                         │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ~/.zshrc or ~/.bashrc                                                          │
│                                                                                  │
│  1. conda init 블록                                                             │
│     ┌───────────────────────────────────────────────────────────────────────┐   │
│     │ # >>> conda initialize >>>                                            │   │
│     │ __conda_setup="$('/home/user/miniconda3/bin/conda' 'shell.zsh' ...)"  │   │
│     │ ...                                                                    │   │
│     │ # <<< conda initialize <<<                                            │   │
│     └───────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
│  2. 자동 활성화                                                                 │
│     ┌───────────────────────────────────────────────────────────────────────┐   │
│     │ conda activate my-project-env                                          │   │
│     │ # or                                                                    │   │
│     │ source ~/projects/my-project/venv/bin/activate                         │   │
│     └───────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
│  3. CUDA 환경 변수                                                              │
│     ┌───────────────────────────────────────────────────────────────────────┐   │
│     │ export CUDA_HOME=/usr/local/cuda-11.8                                  │   │
│     │ export PATH=$CUDA_HOME/bin:$PATH                                       │   │
│     │ export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH               │   │
│     └───────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. 환경 설정

### 2.1 파일 위치

```
project-root/
└── .opencode/
    └── env-config.yaml      # 환경 설정 (선택 사항)
```

### 2.2 설정 구조

```yaml
# =============================================================================
# Environment Config - Execution Environment Settings
# =============================================================================

# Shell 설정
shell:
  type: "zsh"                # zsh | bash | sh
  rc_file: "~/.zshrc"        # 자동 추론 (생략 가능)

# 환경 설정
environment:
  name: "my-project-env"     # conda 환경 이름 또는 venv 경로
  type: "conda"              # conda | venv | uv

# 최소 요구 사항 (더블 체크용, 선택 사항)
requirements:
  python: ">=3.10"
  cuda: ">=11.8"
  torch: ">=2.0"
```

### 2.3 필드 상세

| 섹션 | 필드 | 타입 | 설명 | 필수 | 기본값 |
|------|------|------|------|------|--------|
| **shell** | `type` | string | 사용할 Shell | 아니오 | `$SHELL`에서 감지 |
| | `rc_file` | string | RC 파일 경로 | 아니오 | Shell에서 자동 추론 |
| **environment** | `name` | string | 환경 이름/경로 | 아니오 | 사용자에게 질문 |
| | `type` | string | conda / venv / uv | 아니오 | 자동 감지 |
| **requirements** | `python` | string | Python 버전 확인 | 아니오 | - |
| | `cuda` | string | CUDA 버전 확인 | 아니오 | - |
| | `torch` | string | PyTorch 버전 확인 | 아니오 | - |

### 2.4 Shell에서 RC 파일 자동 추론

| shell.type | rc_file (자동) |
|------------|----------------|
| `zsh` | `~/.zshrc` |
| `bash` | `~/.bashrc` |
| `sh` | `~/.profile` |

### 2.5 설정 파일이 없는 경우

설정 파일은 선택 사항입니다. 없는 경우:

1. Shell은 `$SHELL`에서 자동 감지
2. 환경은 사용자에게 질문
3. 더블 체크 생략

---

## 3. 워크플로우

### 3.1 전체 흐름

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    Environment Setup Workflow                                    │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  STEP 1: Shell 확인                                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │  $ echo $SHELL                                                           │   │
│  │  → /bin/zsh                                                              │   │
│  │                                                                          │   │
│  │  RC File: ~/.zshrc                                                       │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                      │                                          │
│                                      ▼                                          │
│  STEP 2: 현재 환경 확인                                                         │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │  $ echo $CONDA_DEFAULT_ENV                                               │   │
│  │  → ml-dev                                                                │   │
│  │                                                                          │   │
│  │  Or check $VIRTUAL_ENV                                                   │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                      │                                          │
│                                      ▼                                          │
│  STEP 3: 사용자 확인                                                            │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │  ❓ 현재 환경(ml-dev)을 사용하시겠습니까?                               │   │
│  │  [Y] 예  [N] 다른 환경 선택                                             │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                      │                                          │
│                                      ▼                                          │
│  STEP 4: 더블 체크 (선택 사항)                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │  Python: 3.11.5    ✅                                                    │   │
│  │  CUDA:   11.8      ✅                                                    │   │
│  │  PyTorch: 2.1.0    ✅                                                    │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                      │                                          │
│                                      ▼                                          │
│  STEP 5: 환경 보고서 → Phase 0으로 진행                                         │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 단계별 명령어

| 단계 | 목적 | 명령어 |
|------|------|--------|
| **STEP 1** | Shell 확인 | `echo $SHELL` |
| **STEP 2a** | conda 환경 확인 | `echo $CONDA_DEFAULT_ENV` |
| **STEP 2b** | venv 확인 | `echo $VIRTUAL_ENV` |
| **STEP 2c** | conda 환경 목록 | `conda env list` |
| **STEP 4a** | Python 버전 | `python --version` |
| **STEP 4b** | CUDA 버전 | `nvcc --version` 또는 `python -c "import torch; print(torch.version.cuda)"` |
| **STEP 4c** | PyTorch 버전 | `python -c "import torch; print(torch.__version__)"` |

### 3.3 결정 트리

| 조건 | 결과 |
|------|------|
| 설정에 환경이 지정됨 | → 해당 환경 사용 (확인 포함) |
| 현재 활성 환경이 존재 | → 현재 환경 사용 여부 질문 |
| 활성 환경 없음 | → 환경 목록 표시 및 선택 요청 |

---

## 4. 사용자 상호작용

### 4.1 케이스 1: 현재 환경이 존재하는 경우

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│  🔧 환경 설정                                                                   │
│                                                                                  │
│  🐚 Shell: zsh (RC: ~/.zshrc)                                                   │
│                                                                                  │
│  현재 활성 환경:                                                                │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │ 유형     : conda                                                         │   │
│  │ 이름     : ml-dev                                                        │   │
│  │ Python   : 3.11.5                                                        │   │
│  │ PyTorch  : 2.1.0+cu118                                                   │   │
│  │ CUDA     : 11.8                                                          │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
│  ❓ 이 환경을 사용하시겠습니까?                                                 │
│                                                                                  │
│  [Y] 예, 이 환경을 사용합니다                                                   │
│  [N] 아니오, 다른 환경을 선택합니다                                             │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 케이스 2: 환경이 없는 경우

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│  🔧 환경 설정                                                                   │
│                                                                                  │
│  🐚 Shell: zsh (RC: ~/.zshrc)                                                   │
│                                                                                  │
│  ⚠️ 현재 활성 환경이 없습니다.                                                  │
│                                                                                  │
│  사용 가능한 환경:                                                              │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │ #  │ 유형  │ 이름        │ Python │ PyTorch     │ CUDA  │              │   │
│  │────┼───────┼─────────────┼────────┼─────────────┼───────│              │   │
│  │ 1  │ conda │ base        │ 3.11.5 │ -           │ -     │              │   │
│  │ 2  │ conda │ ml-dev      │ 3.11.5 │ 2.1.0+cu118 │ 11.8  │              │   │
│  │ 3  │ conda │ torch21     │ 3.11.0 │ 2.1.0+cu121 │ 12.1  │              │   │
│  │ 4  │ venv  │ ./venv      │ 3.10.12│ 2.0.1       │ 11.7  │              │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
│  ❓ 어떤 환경을 사용하시겠습니까? [1-4]:                                        │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### 4.3 케이스 3: 더블 체크 실패

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│  🔧 환경 설정                                                                   │
│                                                                                  │
│  ⚠️ 요구 사항 확인 결과:                                                        │
│  ┌─────────────────────────────────────────────────────────────────────────┐   │
│  │ 항목     │ 요구 사항   │ 현재 값    │ 상태   │                           │   │
│  │──────────┼────────────┼────────────┼────────│                           │   │
│  │ Python   │ >=3.10     │ 3.11.5     │ ✅     │                           │   │
│  │ CUDA     │ >=11.8     │ 11.7       │ ⚠️     │                           │   │
│  │ PyTorch  │ >=2.0      │ 1.13.1     │ ❌     │                           │   │
│  └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                  │
│  ❓ 그래도 계속하시겠습니까?                                                    │
│                                                                                  │
│  [Y] 예, 경고를 무시하고 진행합니다                                             │
│  [N] 아니오, 다른 환경을 선택합니다                                             │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 5. 환경 보고서

### 5.1 보고서 형식

```
══════════════════════════════════════════════════════════════
                    Environment Report
══════════════════════════════════════════════════════════════

🐚 Shell
┌──────────────┬─────────────────────────────────┐
│ Type         │ zsh                             │
│ RC File      │ ~/.zshrc                        │
└──────────────┴─────────────────────────────────┘

📦 Environment
┌──────────────┬─────────────────────────────────┐
│ Type         │ conda                           │
│ Name         │ ml-dev                          │
│ Path         │ ~/miniconda3/envs/ml-dev        │
└──────────────┴─────────────────────────────────┘

✅ Requirements Check
┌──────────────┬──────────────┬──────────────────┐
│ Item         │ Required     │ Current          │
├──────────────┼──────────────┼──────────────────┤
│ Python       │ >=3.10       │ 3.11.5      ✅   │
│ CUDA         │ >=11.8       │ 11.8        ✅   │
│ PyTorch      │ >=2.0        │ 2.1.0       ✅   │
└──────────────┴──────────────┴──────────────────┘

➡️ 다음 단계: Git Input (Phase 0)

══════════════════════════════════════════════════════════════
```

---

## 6. 다이어그램

### 6.1 전체 흐름 (Mermaid)

```mermaid
flowchart TB
    START([Phase -1 Start]) --> SHELL[STEP 1: Check Shell]

    SHELL --> RC[Determine RC File<br/>zsh→.zshrc<br/>bash→.bashrc]

    RC --> ENV_CHECK[STEP 2: Check Current Env]

    ENV_CHECK --> HAS_ENV{Active Env<br/>Exists?}

    HAS_ENV -->|Yes| ASK_USE[/"❓ Use this env?"/]
    HAS_ENV -->|No| LIST_ENV[Show Env List]

    ASK_USE -->|Yes| DOUBLE_CHECK
    ASK_USE -->|No| LIST_ENV

    LIST_ENV --> SELECT[/"❓ Select env"/]
    SELECT --> ACTIVATE[Activate Env]
    ACTIVATE --> DOUBLE_CHECK

    DOUBLE_CHECK[STEP 4: Double Check<br/>Python/CUDA/PyTorch]

    DOUBLE_CHECK --> CHECK_OK{Pass?}

    CHECK_OK -->|Yes| REPORT
    CHECK_OK -->|No/Warning| ASK_CONTINUE[/"❓ Continue?"/]

    ASK_CONTINUE -->|Yes| REPORT
    ASK_CONTINUE -->|No| LIST_ENV

    REPORT[STEP 5: Env Report] --> DONE([To Phase 0])

    style SHELL fill:#3498DB22,stroke:#3498DB
    style DOUBLE_CHECK fill:#27AE6022,stroke:#27AE60
    style REPORT fill:#9B59B622,stroke:#9B59B6
```

### 6.2 Code QA v4 전체 파이프라인

```mermaid
flowchart LR
    subgraph PHASE_NEG1["Phase -1"]
        ENV[🔧 Env Setup]
    end

    subgraph PHASE_0_5["Phase 0-5: QA"]
        GIT[📂 Git Input]
        PRE[⚡ Pre-Check]
        REV[🔍 Review]
        FIX[🔧 Fix]
        QA[📋 Quality]
        BUILD[🏗️ Build]
        TEST[🧪 Test]
    end

    subgraph PHASE_6_8["Phase 6-8"]
        COMMIT[📝 Commit]
        SUMMARY[📊 Summary]
        PUSH[📤 Push]
    end

    ENV --> GIT --> PRE --> REV --> FIX --> QA --> BUILD --> TEST --> COMMIT --> SUMMARY --> PUSH

    style PHASE_NEG1 fill:#95A5A622,stroke:#95A5A6
    style PHASE_0_5 fill:#3498DB22,stroke:#3498DB
    style PHASE_6_8 fill:#27AE6022,stroke:#27AE60
```

---

## 7. 에이전트 정의

### 7.1 파일 위치

```
project-root/
└── .opencode/
    └── agent/
        └── env-setup.md      # 환경 설정 에이전트
```

### 7.2 에이전트 설정

| 항목 | 값 | 설명 |
|------|-----|------|
| **mode** | `subagent` | 다른 에이전트에서 호출 |
| **model** | `qwen-coder/Qwen3-Coder-Next-FP8` | Coder 모델 (vLLM, port 8001) |
| **color** | `#95A5A6` | UI 표시 색상 |

### 7.3 권한 매트릭스

| 명령 유형 | 권한 | 예시 |
|-----------|------|------|
| Shell 감지 | `allow` | `echo $SHELL`, `echo $0` |
| 환경 관리자 감지 | `allow` | `conda env list`, `which conda` |
| Python 감지 | `allow` | `python --version`, `python -c "..."` |
| GPU/CUDA 감지 | `allow` | `nvidia-smi`, `nvcc --version` |
| 환경 활성화 | `ask` | `conda activate`, `source */activate` |
| 파일 삭제 | `deny` | `rm *` |
| 패키지 제거 | `deny` | `conda remove`, `pip uninstall` |

### 7.4 호출 방법

다른 에이전트 또는 명령에서 호출:

```markdown
# Code QA 명령에서 호출
Invoke @env-setup to configure environment

# 또는 직접 호출
@env-setup Please check the environment.
```

---

## 8. 명령어 통합

### 8.1 파일 위치

```
project-root/
└── .opencode/
    └── command/
        └── code-qa.md      # Code QA v4 명령어
```

### 8.2 사용법

```bash
# 기본 (작업 중인 변경사항)
> /code-qa

# Staged 변경사항만
> /code-qa --staged

# 마지막 커밋
> /code-qa --last

# 전체 브랜치
> /code-qa --branch
```

### 8.3 실행 흐름

```
/code-qa 실행
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│  Phase -1: @env-setup 호출                                   │
│  ├─ Shell 확인                                               │
│  ├─ 환경 확인/선택                                           │
│  └─ 더블 체크                                                │
└─────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│  Phase 0-5: QA 파이프라인                                    │
│  ├─ Git Input → Pre-Check → Review → Fix                     │
│  └─ Quality → Build → Test                                   │
└─────────────────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────────────────┐
│  Phase 6-8: Commit & Push                                    │
│  ├─ Commit/Amend                                             │
│  ├─ Summary Report                                           │
│  └─ Push & PR (사용자 확인)                                  │
└─────────────────────────────────────────────────────────────┘
```

---

## 9. Docker Sandbox

### 9.1 개요

Docker Sandbox는 격리된 Docker 컨테이너에서 Build와 Test를 실행합니다.

| 항목 | 호스트 실행 | Sandbox 실행 |
|------|------------|-------------|
| 환경 | 호스트 의존적 | 격리된 컨테이너 |
| 재현성 | 환경에 따라 다름 | 일관된 결과 |
| GPU | 직접 사용 | nvidia-docker |
| 속도 | 빠름 | 첫 빌드 느림 (캐시 후 빠름) |

### 9.2 사용법

```bash
# Docker Sandbox에서 Build/Test 실행 (기본값)
> /code-qa --last

# 호스트에서 직접 Build/Test 실행 (Sandbox 비활성화)
> /code-qa --last --no-sandbox

# 다른 Git 옵션과 함께
> /code-qa --staged              # Sandbox (기본값)
> /code-qa --branch --no-sandbox # 호스트 실행
```

### 9.3 파일 구조

```
project-root/
└── .opencode/
    ├── docker/
    │   └── Dockerfile.sandbox    # 범용 Dockerfile
    └── env-config.yaml           # Sandbox 설정 포함
```

### 9.4 Dockerfile 템플릿

`.opencode/docker/Dockerfile.sandbox`:

```dockerfile
# Base Image: NVIDIA CUDA + Python
ARG CUDA_VERSION=11.8.0
ARG PYTHON_VERSION=3.11

FROM nvidia/cuda:${CUDA_VERSION}-cudnn8-runtime-ubuntu22.04

ENV PYTHONUNBUFFERED=1
WORKDIR /workspace

# System Dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python${PYTHON_VERSION} \
    python${PYTHON_VERSION}-dev \
    python3-pip \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

# Python symlinks
RUN ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python

# Project Dependencies
COPY requirements*.txt ./
RUN pip install -r requirements.txt

CMD ["python", "--version"]
```

### 9.5 env-config.yaml 설정

```yaml
# 기존 설정
shell:
  type: "zsh"
environment:
  name: "ml-dev"
  type: "conda"
requirements:
  python: ">=3.10"
  cuda: ">=11.8"
  torch: ">=2.0"

# Sandbox 설정
sandbox:
  enabled: true                     # 기본값: Docker Sandbox 사용
  dockerfile: ".opencode/docker/Dockerfile.sandbox"
  image_name: "qa-sandbox"
  gpu: true                         # nvidia-docker 사용
  build_args:
    CUDA_VERSION: "11.8.0"
    PYTHON_VERSION: "3.11"
```

### 9.6 요구 사항

| 요구 사항 | 설명 |
|-----------|------|
| Docker | Docker Engine 필요 |
| nvidia-docker | GPU용 NVIDIA Container Toolkit |
| CUDA Driver | 호스트에 NVIDIA 드라이버 필요 |

### 9.7 장점

- 호스트 환경 오염 없음
- 재현 가능한 빌드/테스트
- CI/CD와 동일한 환경
- 의존성 격리

---

## 관련 문서

- [Code QA v4 아키텍처 다이어그램](./02-architecture.kr.md)
- [Code QA v4 빠른 시작](./01-quick-start.kr.md)
- [Code QA v4 구현 요약](./05-implementation-summary.kr.md)
