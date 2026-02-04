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
9. [부록 A: Agent Tool 권한 매트릭스](#부록-a-agent-tool-권한-매트릭스)
10. [부록 B: 결과 토큰 및 상태 관리](#부록-b-결과-토큰-및-상태-관리)
11. [부록 C: 파일 체크리스트](#부록-c-파일-체크리스트)

---

## 1. 개요

### 1.1 Code QA v4란?

Code QA v4는 11개의 Phase로 구성된 자동화된 코드 품질 검사 워크플로우입니다.

### 1.2 주요 특징

- **단일 모델 전략**: Qwen3-Next-80B-A3B-Thinking-FP8 (reasoning + tool calling)
- **사용자 확인 단계**: env-setup, build-tester, function-tester에서 필수 확인
- **Docker Sandbox**: 격리된 Build/Test 환경
- **회귀 루프**: 품질 기준 미달 시 자동 재시도 (최대 3회)
- **구조화된 상태 관리**: 결과 토큰 파싱을 통한 Agent간 데이터 전달

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

다음 3개의 Agent에서 사용자 입력을 요구합니다:

| Agent | 필요한 입력 | 설명 |
|-------|------------|------|
| **env-setup** | Shell 선택 (1-3), 환경 타입 선택 (1-4) | 어떤 Shell과 가상환경을 사용할지 선택 |
| **build-tester** | "확인/y" 또는 "재설정/n" | 환경 설정이 올바른지 확인 후 빌드 진행 |
| **function-tester** | "실행/y" 또는 "스킵/n" | 테스트 존재 여부 확인 후 실행 여부 결정 |

### 6.5 워크플로우 진행 과정

```
Phase -1: Environment Setup (사용자 입력 필수)
    ↓
Phase 0: Git Input
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
    │                                │
    └──→ 실패 시 ───────────────────┘
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

env-setup, build-tester, function-tester에서 사용자 입력을 기다리는 상태입니다.

**해결**: 요청된 입력을 제공하세요:
- Shell 선택: `1`, `2`, 또는 `3`
- 환경 타입: `1`, `2`, `3`, 또는 `4`
- 확인: `y` 또는 `확인`
- 스킵: `n` 또는 `스킵`

---

## 부록 A: Agent Tool 권한 매트릭스

각 Agent가 사용할 수 있는 Tool 목록입니다:

| Agent | Bash | Read | Edit | Write | Glob | Grep | 주요 역할 |
|-------|:----:|:----:|:----:|:-----:|:----:|:----:|----------|
| env-setup | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ | 환경 감지 |
| git-input | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ | Git 파싱 |
| pre-checker | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ | Lint/Format |
| code-reviewer | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ | 코드 분석 |
| code-fixer | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | 코드 수정 |
| quality-checker | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ | 품질 검사 |
| build-tester | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ | 빌드 테스트 |
| function-tester | ✅ | ✅ | ❌ | ❌ | ✅ | ✅ | 기능 테스트 |
| git-committer | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | Git 커밋 |
| summary-reporter | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | 리포트 생성 |
| git-pusher | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ | Push/PR |

**주요 권한 설명:**
- **code-fixer**: 유일하게 Edit/Write 권한을 가짐 (코드 수정 필요)
- **code-reviewer, summary-reporter**: Bash/Read 권한으로 파일 내용 분석 가능
- **모든 Agent**: 위험한 명령 (rm -rf, git push --force 등) 차단됨

---

## 부록 B: 결과 토큰 및 상태 관리

### 결과 토큰 형식

각 Agent는 실행 완료 시 다음 형식의 토큰을 출력합니다:

| Agent | 출력 토큰 | 예시 |
|-------|----------|------|
| env-setup | `ENV_SETUP_RESULT: SUCCESS/FAIL/WAITING_INPUT` | `ENV_SETUP_RESULT: SUCCESS` |
| git-input | `FILE_LIST: {파일목록}` | `FILE_LIST: src/app.py, src/utils.py` |
| pre-checker | `PRE_CHECK_RESULT: SUCCESS/PARTIAL` | `PRE_CHECK_RESULT: SUCCESS` |
| code-reviewer | `ISSUE_LIST: {이슈목록}` | `ISSUE_LIST: [H001] Null ref...` |
| code-fixer | `FIX_RESULT: SUCCESS/PARTIAL` | `FIX_RESULT: SUCCESS` |
| quality-checker | `QUALITY_SCORE: XX/100` | `QUALITY_SCORE: 85/100` |
| build-tester | `BUILD_RESULT: SUCCESS/FAIL/WAITING_INPUT` | `BUILD_RESULT: SUCCESS` |
| function-tester | `TEST_RESULT: SUCCESS/FAIL/SKIPPED/NO_TESTS` | `TEST_RESULT: SUCCESS` |
| git-committer | `COMMIT_RESULT: SUCCESS/NO_CHANGES` | `COMMIT_RESULT: SUCCESS` |
| git-pusher | `PUSH_RESULT: SUCCESS/SKIPPED/FAIL` | `PUSH_RESULT: SUCCESS` |

### 오케스트레이터 상태 변수

오케스트레이터(mode/code-qa.md)가 추적하는 상태 변수:

```
retry_count = 0              # 회귀 횟수 (최대 3)
quality_score = 0            # 품질 점수

env_result = ""              # 환경 설정 결과
changed_files = []           # 변경 파일 목록
review_issues = []           # 리뷰 이슈 목록
fix_result = ""              # 수정 결과
build_result = ""            # 빌드 결과
test_result = ""             # 테스트 결과
commit_result = ""           # 커밋 결과
```

### 회귀 조건

| 조건 | 동작 |
|------|------|
| `QUALITY_SCORE < 70` | STEP 5 (code-fixer)로 회귀 |
| `BUILD_RESULT: FAIL` | STEP 5 (code-fixer)로 회귀 |
| `TEST_RESULT: FAIL` | STEP 5 (code-fixer)로 회귀 |
| `retry_count >= 3` | 워크플로우 중단, 수동 검토 요청 |

---

## 부록 C: 파일 체크리스트

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
