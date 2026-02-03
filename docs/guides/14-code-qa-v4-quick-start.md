# Code QA v4 Quick Start Guide

이 문서는 Code QA v4 워크플로우의 설치, 설정, 사용 방법을 제공합니다.

## 목차

1. [개요](#1-개요)
2. [사전 요구사항](#2-사전-요구사항)
3. [설치](#3-설치)
4. [설정 파일 구조](#4-설정-파일-구조)
5. [글로벌 설정](#5-글로벌-설정)
6. [사용 방법](#6-사용-방법)
7. [제거](#7-제거)
8. [문제 해결](#8-문제-해결)

---

## 1. 개요

### 1.1 Code QA v4란?

Code QA v4는 11개의 Phase로 구성된 자동화된 코드 품질 검사 워크플로우입니다.

### 1.2 주요 특징

- **단일 모델 전략**: Qwen3-Next-80B-A3B-Thinking-FP8 (reasoning + tool calling)
- **사용자 확인 단계**: env-setup, git-input, build-tester, function-tester, git-committer, git-pusher에서 필수 확인
- **Docker Sandbox**: 격리된 Build/Test 환경 (CUDA 13.0, Python 3.12)
- **회귀 루프**: 품질 기준 미달 시 자동 재시도 (최대 3회)
- **GitLab-CE 지원**: GitHub 및 GitLab 모두 지원 (gh/glab CLI)
- **인증 오류 처리**: SSH/HTTPS/GPG/CLI 인증 문제 감지 및 안내

### 1.3 모델 스펙

| 항목 | 값 |
|------|-----|
| **모델** | Qwen3-Next-80B-A3B-Thinking-FP8 |
| **Context Window** | 256K |
| **Output Limit** | 16K |
| **Reasoning** | ✅ (thinking mode) |
| **Tool Calling** | ✅ |
| **VRAM 요구량** | ~76GB (FP8) |
| **권장 GPU** | 2x H100 NVL 96GB |

### 1.4 공식 샘플링 파라미터

```
Temperature: 0.6
TopP: 0.95
TopK: 20
MinP: 0
```

---

## 2. 사전 요구사항

### 2.1 하드웨어

- GPU: 2x H100 NVL 96GB (또는 동급)
- VRAM: 최소 160GB (모델 + KV cache)

### 2.2 소프트웨어

```bash
# Python 3.10+
python --version

# SGLang 설치
pip install sglang[all]

# Docker (Sandbox 사용 시)
docker --version
nvidia-docker --version  # GPU 사용 시
```

### 2.3 모델 서버 실행

```bash
# SGLang으로 Qwen3-Next-80B-A3B-Thinking-FP8 서빙
python -m sglang.launch_server \
    --model-path Qwen/Qwen3-Next-80B-A3B-Thinking-FP8 \
    --tp 2 \
    --context-length 262144 \
    --port 30000 \
    --host 0.0.0.0
```

**NEXTN Speculative Decoding 사용 시 (~30% 성능 향상):**
```bash
python -m sglang.launch_server \
    --model-path Qwen/Qwen3-Next-80B-A3B-Thinking-FP8 \
    --tp 2 \
    --context-length 262144 \
    --speculative-algorithm NEXTN \
    --speculative-num-draft-tokens 3 \
    --port 30000 \
    --host 0.0.0.0
```

---

## 3. 설치

### 3.1 글로벌 설정 디렉토리 생성

```bash
mkdir -p ~/.config/opencode/.opencode/{agent,command,mode}
```

### 3.2 글로벌 설정 파일 복사

**방법 1: 저장소에서 복사 (권장)**

```bash
# opencode 저장소 clone
git clone https://github.com/your-org/opencode.git /tmp/opencode-setup

# 글로벌 설정 파일 복사
cp /tmp/opencode-setup/.opencode/agent/{env-setup,build-tester,function-tester,code-reviewer,code-fixer,git-input,git-committer,git-pusher,pre-checker,quality-checker,summary-reporter}.md \
   ~/.config/opencode/.opencode/agent/

cp /tmp/opencode-setup/.opencode/command/code-qa.md \
   ~/.config/opencode/.opencode/command/

cp /tmp/opencode-setup/.opencode/mode/code-qa.md \
   ~/.config/opencode/.opencode/mode/

# 정리
rm -rf /tmp/opencode-setup
```

**방법 2: 수동 생성**

아래 섹션 5의 설정 파일을 직접 생성합니다.

### 3.3 환경 변수 설정

```bash
# ~/.bashrc 또는 ~/.zshrc에 추가
export QWEN_BASE_URL="http://localhost:30000/v1"
```

---

## 4. 설정 파일 구조

### 4.1 글로벌 설정 (모든 프로젝트 공통)

```
~/.config/opencode/
├── opencode.json                    # Provider, Model, Agent 샘플링 파라미터
└── .opencode/
    ├── agent/                       # Code QA Agents (11개)
    │   ├── env-setup.md             # Phase -1: 환경 설정 (사용자 입력 필수)
    │   ├── git-input.md             # Phase 0: Git 변경 파일 추출
    │   ├── pre-checker.md           # Phase 1: Lint/Format 자동 수정
    │   ├── code-reviewer.md         # Phase 2: 코드 심층 분석
    │   ├── code-fixer.md            # Phase 3: 이슈 수정
    │   ├── quality-checker.md       # Phase 4: 품질 점수 검사
    │   ├── build-tester.md          # Phase 5: 빌드 테스트 (사용자 확인 필수)
    │   ├── function-tester.md       # Phase 6: 기능 테스트 (사용자 확인 필수)
    │   ├── git-committer.md         # Phase 7: Git 커밋
    │   ├── summary-reporter.md      # Phase 8: 결과 종합 리포트
    │   └── git-pusher.md            # Phase 9: Push 및 PR
    ├── command/
    │   └── code-qa.md               # /code-qa 커맨드
    └── mode/
        └── code-qa.md               # Code QA 오케스트레이터 모드

```

### 4.2 프로젝트별 설정 (오버라이드용)

```
your-project/
├── .opencode/
│   ├── opencode.jsonc               # 프로젝트별 오버라이드 (선택)
│   ├── env-config.yaml              # 환경 설정 (선택)
│   ├── agent/                       # 프로젝트 전용 agent만
│   │   └── custom-agent.md
│   └── docker/
│       └── Dockerfile.sandbox       # Sandbox 이미지 (선택)
└── ...
```

### 4.3 설정 우선순위

```
1. 환경 변수 (OPENCODE_*)           ← 최우선
2. CLI 플래그
3. 프로젝트 루트 opencode.json
4. 프로젝트 .opencode/opencode.jsonc
5. 글로벌 ~/.config/opencode/opencode.json
6. 기본값                           ← 최하위
```

---

## 5. 글로벌 설정

### 5.1 글로벌 설정 파일 (`~/.config/opencode/opencode.json`)

아래 내용을 복사하여 사용하세요:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "qwen/qwen3-next-80b-a3b-thinking",
  "provider": {
    "qwen": {
      "name": "Qwen3-Next-Thinking Server (SGLang)",
      "npm": "@ai-sdk/openai-compatible",
      "options": {
        "timeout": 600000,
        "baseURL": "{env:QWEN_BASE_URL}"
      },
      "models": {
        "qwen3-next-80b-a3b-thinking": {
          "name": "Qwen3-Next-80B-A3B-Thinking-FP8",
          "id": "Qwen/Qwen3-Next-80B-A3B-Thinking-FP8",
          "tool_call": true,
          "reasoning": true,
          "temperature": true,
          "limit": {
            "context": 262144,
            "output": 16384
          }
        }
      }
    }
  },
  "agent": {
    "code-reviewer": { "temperature": 0.6, "top_p": 0.95, "top_k": 20, "min_p": 0 },
    "code-fixer": { "temperature": 0.6, "top_p": 0.95, "top_k": 20, "min_p": 0 },
    "env-setup": { "temperature": 0.6, "top_p": 0.95, "top_k": 20, "min_p": 0 },
    "build-tester": { "temperature": 0.6, "top_p": 0.95, "top_k": 20, "min_p": 0 },
    "function-tester": { "temperature": 0.6, "top_p": 0.95, "top_k": 20, "min_p": 0 },
    "pre-checker": { "temperature": 0.6, "top_p": 0.95, "top_k": 20, "min_p": 0 },
    "quality-checker": { "temperature": 0.6, "top_p": 0.95, "top_k": 20, "min_p": 0 },
    "git-input": { "temperature": 0.6, "top_p": 0.95, "top_k": 20, "min_p": 0 },
    "git-committer": { "temperature": 0.6, "top_p": 0.95, "top_k": 20, "min_p": 0 },
    "git-pusher": { "temperature": 0.6, "top_p": 0.95, "top_k": 20, "min_p": 0 },
    "summary-reporter": { "temperature": 0.6, "top_p": 0.95, "top_k": 20, "min_p": 0 }
  },
  "experimental": {
    "chatMaxRetries": 5
  }
}
```

### 5.2 프로젝트별 설정 (`.opencode/opencode.jsonc`)

글로벌 설정을 상속하므로 오버라이드할 항목만 정의:

```jsonc
{
  "$schema": "https://opencode.ai/config.json"
  // 필요 시 프로젝트별 오버라이드 추가
  // Provider, Agent 설정은 글로벌에서 상속됨
}
```

### 5.3 환경 설정 파일 (`.opencode/env-config.yaml`, 선택)

```yaml
shell:
  type: "zsh"
  rc_file: "~/.zshrc"

environment:
  name: "my-project-env"
  type: "conda"

requirements:
  python: ">=3.10"
  cuda: ">=11.8"

sandbox:
  enabled: true
  dockerfile: ".opencode/docker/Dockerfile.sandbox"
  image_name: "qa-sandbox"
  gpu: true
```

---

## 6. 사용 방법

### 6.1 설치 확인

```bash
# opencode 실행
opencode

# 모델 연결 확인
> 안녕하세요. 현재 사용 중인 모델은 무엇인가요?
```

### 6.2 Mode로 사용하기

모드 선택기에서 "code-qa"를 선택합니다:

```
# Ctrl+X → m (또는 설정된 키바인드)
> code-qa (Code QA 워크플로우)
```

### 6.3 Command로 사용하기

```bash
# Working directory 변경 검사 (기본값)
/code-qa

# Staged 변경만 검사
/code-qa --staged

# 마지막 커밋 검사
/code-qa --last

# 호스트에서 직접 실행 (Docker Sandbox 비활성화)
/code-qa --no-sandbox
```

### 6.4 사용자 확인 단계

다음 Agent들에서 사용자 입력을 요구합니다:

| Agent | 필요한 입력 | 설명 |
|-------|------------|------|
| **env-setup** | Shell 선택 (1-3), 환경 타입 선택 (1-4) | 어떤 Shell과 가상환경을 사용할지 선택 |
| **git-input** | "초기화/git init", 파일 경로, 또는 "종료/exit" | Git 저장소가 아닌 경우 처리 방법 선택 |
| **build-tester** | "확인/y" 또는 "재설정/n" | 환경 설정이 올바른지 확인 후 빌드 진행 |
| **function-tester** | "실행/y", 특정 언어, 또는 "스킵/n" | 모든 언어 테스트 한 번에 표시 후 실행 여부 결정 |
| **git-committer** | "확인/y", 새 메시지, 또는 "취소/n" | 커밋 정보 확인 후 커밋 실행 여부 결정 |
| **git-pusher** | "확인/y", "재시도", 또는 "스킵/n" | Push 여부 및 인증 오류 처리 |

### 6.5 워크플로우 진행 과정

```
Phase -1: Environment Setup (사용자 입력 필수)
    │
    ↓
Phase 0: Git Input ────────────────┐
    │                               │ (Git 저장소 아님)
    │                               ↓
    │                          사용자 선택
    │                          - 초기화 → 계속
    │                          - 파일 지정 → 계속
    │                          - 종료 → 워크플로우 종료
    ↓
Phase 1: Pre-Check (Lint/Format)
    ↓
Phase 2: Code Review
    ↓
Phase 3: Code Fix
    ↓
Phase 4: Quality Check ──────────────┐
    │                                │
    ↓ (>=70점)                       │ (<70점)
    │                                │
Phase 5: Build Test (사용자 확인)   │
    │                                │
    ↓ (성공)                         │
    │                                │
Phase 6: Function Test (사용자 확인)│
    │    └─ 모든 언어 한 번에 표시   │
    │    └─ 한 번만 확인 요청        │
    │                                │
    └──→ 실패 시 ───────────────────┘
                        ↓
                   Code Fixer로 회귀
                   (최대 3회)
    ↓
Phase 7: Git Commit (사용자 확인 필수)
    │    └─ 커밋 정보 미리보기
    │    └─ 메시지 수정 가능
    ↓
Phase 8: Summary Report
    ↓
Phase 9: Push & PR/MR (사용자 확인)
    │    └─ GitHub: gh pr create
    │    └─ GitLab: glab mr create
    │    └─ 인증 오류 시: 해결 안내
    ↓
워크플로우 완료
```

---

## 7. 제거

### 7.1 글로벌 설정 제거

```bash
# 글로벌 Code QA 설정 제거
rm -rf ~/.config/opencode/.opencode/agent/{env-setup,build-tester,function-tester,code-reviewer,code-fixer,git-input,git-committer,git-pusher,pre-checker,quality-checker,summary-reporter}.md
rm -rf ~/.config/opencode/.opencode/command/code-qa.md
rm -rf ~/.config/opencode/.opencode/mode/code-qa.md

# 글로벌 설정 파일에서 Code QA agent 설정 제거 (수동)
vim ~/.config/opencode/opencode.json
# → "agent" 섹션에서 Code QA 관련 항목 삭제
```

### 7.2 전체 글로벌 설정 제거

```bash
# 모든 글로벌 설정 제거 (주의!)
rm -rf ~/.config/opencode/
```

### 7.3 프로젝트별 설정 제거

```bash
# 프로젝트의 Code QA 관련 파일 제거
rm -rf .opencode/agent/{env-setup,build-tester,function-tester,code-reviewer,code-fixer,git-input,git-committer,git-pusher,pre-checker,quality-checker,summary-reporter}.md
rm -rf .opencode/command/code-qa.md
rm -rf .opencode/mode/code-qa.md
rm -rf .opencode/env-config.yaml
rm -rf .opencode/docker/
```

---

## 8. 문제 해결

### 8.1 설정 오류: "Unrecognized key"

```
Error: Configuration is invalid
Unrecognized key: "agents"
```

**원인**: `agents` (복수형) 대신 `agent` (단수형)을 사용해야 합니다.

**해결**:
```bash
sed -i 's/"agents":/"agent":/' ~/.config/opencode/opencode.json
```

### 8.2 모델 연결 실패

```
Error: Failed to connect to model server
```

**해결**:
```bash
# 서버 상태 확인
curl http://localhost:30000/v1/models

# 환경 변수 확인
echo $QWEN_BASE_URL
```

### 8.3 Docker Sandbox 실패

```
Error: Docker image not found
```

**해결**:
```bash
# Dockerfile 확인
ls .opencode/docker/Dockerfile.sandbox

# 이미지 빌드
docker build -t qa-sandbox -f .opencode/docker/Dockerfile.sandbox .
```

### 8.4 Agent를 찾을 수 없음

```
Error: Agent 'env-setup' not found
```

**원인**: 글로벌 또는 프로젝트 설정에 Agent 파일이 없습니다.

**해결**:
```bash
# 글로벌 Agent 확인
ls ~/.config/opencode/.opencode/agent/

# 프로젝트 Agent 확인
ls .opencode/agent/
```

### 8.5 WAITING_INPUT 상태에서 멈춤

env-setup, git-input, build-tester, function-tester, git-committer에서 사용자 입력을 기다리는 상태입니다.

**해결**: 요청된 입력을 제공하세요:
- Shell 선택: `1`, `2`, 또는 `3`
- 환경 타입: `1`, `2`, `3`, 또는 `4`
- 확인: `y` 또는 `확인`
- 스킵: `n` 또는 `스킵`
- Git 초기화: `git init` 또는 `초기화`
- 커밋 메시지 수정: 새 메시지 직접 입력

### 8.6 Git 저장소가 아닌 경우 (NO_GIT_REPO)

```
GIT_INPUT_RESULT: NO_GIT_REPO
```

**해결**:
- Git 저장소로 초기화: `git init` 또는 `초기화` 입력
- 특정 파일만 QA: 파일 경로 입력 (예: `src/main.py`)
- QA 종료: `종료` 또는 `exit` 입력

### 8.7 인증 오류 (AUTH_ERROR)

```
PUSH_RESULT: AUTH_ERROR
AUTH_TYPE: SSH
```

**해결**: 인증 유형에 따라 다음 명령 실행

| 오류 유형 | 해결 명령 |
|----------|----------|
| SSH 키 없음 | `ssh-keygen -t ed25519` |
| SSH agent 비활성 | `eval "$(ssh-agent -s)"` |
| SSH 키 미등록 | `ssh-add ~/.ssh/id_ed25519` |
| GitHub CLI 미인증 | `gh auth login` |
| GitLab CLI 미인증 | `glab auth login` |
| GPG 서명 실패 | `gpg --list-secret-keys` |

### 8.8 GitLab-CE Push/MR 실패

```
Error: glab not found
```

**해결**:
```bash
# GitLab CLI 설치
# macOS
brew install glab

# Linux (snap)
sudo snap install glab

# 또는 pip
pip install python-gitlab

# 인증
glab auth login
```

**GitLab-CE (self-hosted) 설정:**
```bash
# GitLab instance 설정
glab config set host your-gitlab.example.com
glab auth login --hostname your-gitlab.example.com
```

---

## 부록: 파일 체크리스트

### 글로벌 설정 파일 (필수)

```
~/.config/opencode/
├── opencode.json                           ✅ Provider, Agent 설정
└── .opencode/
    ├── agent/
    │   ├── env-setup.md                    ✅
    │   ├── git-input.md                    ✅
    │   ├── pre-checker.md                  ✅
    │   ├── code-reviewer.md                ✅
    │   ├── code-fixer.md                   ✅
    │   ├── quality-checker.md              ✅
    │   ├── build-tester.md                 ✅
    │   ├── function-tester.md              ✅
    │   ├── git-committer.md                ✅
    │   ├── summary-reporter.md             ✅
    │   └── git-pusher.md                   ✅
    ├── command/
    │   └── code-qa.md                      ✅
    └── mode/
        └── code-qa.md                      ✅
```

### 환경 변수 (필수)

```bash
QWEN_BASE_URL="http://localhost:30000/v1"   ✅
```

---

## 관련 문서

- [05-integrated-configuration.md](./05-integrated-configuration.md) - 전체 설정 통합 가이드
- [12-environment-setup-workflow.md](./12-environment-setup-workflow.md) - 환경 설정 상세
- [13-code-qa-v4-complete-diagram.md](./13-code-qa-v4-complete-diagram.md) - 전체 워크플로우 다이어그램
