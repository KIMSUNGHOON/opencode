---
description: "개발 환경 설정 (독립 실행)"
model: qwen/qwen3-next-80b-a3b-thinking
subtask: true
prompt: |
  당신은 환경 설정 에이전트입니다.

  ## 지시사항

  1. env-setup agent를 호출하여 환경을 설정합니다.
  2. 사용자에게 Shell과 가상 환경 타입을 선택받습니다.

  ## 입력 파싱

  $ARGUMENTS를 파싱하세요:
  - --shell <타입>: Shell 타입 미리 지정 (zsh/bash/sh)
  - --env <타입>: 환경 타입 미리 지정 (conda/uv/venv/none)
  - 지정되지 않음: 대화형으로 선택

  ## 실행

  Task 도구 호출:
  - subagent_type: "env-setup"
  - prompt: "Shell, 환경, Python/CUDA 버전을 확인하세요. 옵션: $ARGUMENTS. 옵션이 없으면 사용자에게 Shell 타입과 가상 환경 타입을 선택받으세요."
  - description: "환경 설정 확인"
---

# /env - 개발 환경 설정

**사용법:**
```bash
# 대화형 환경 설정 (기본)
/env

# Shell과 환경 타입 미리 지정
/env --shell zsh --env conda

# 현재 환경 정보만 확인
/env --info

# 환경 초기화 (새로 설정)
/env --reset
```

**감지되는 Shell:**
- `zsh` (oh-my-zsh 포함)
- `bash`
- `sh`

**감지되는 가상 환경:**
- `conda` (Anaconda, Miniconda)
- `uv` (uv venv)
- `venv` (Python 내장)
- `poetry` (Poetry 환경)
- `none` (시스템 Python)

**감지되는 런타임:**
- Python 버전
- CUDA 버전 (GPU 환경)
- Node.js 버전
- Go 버전
- Rust 버전

**옵션:**
- `--shell <타입>`: Shell 타입 지정 (zsh/bash/sh)
- `--env <타입>`: 환경 타입 지정 (conda/uv/venv/none)
- `--info`: 현재 환경 정보만 출력
- `--reset`: 환경 설정 초기화
- `--save`: 설정을 .opencode/env-config.yaml에 저장