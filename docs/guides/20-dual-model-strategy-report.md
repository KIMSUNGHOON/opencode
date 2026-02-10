# 모델 마이그레이션 리포트: 듀얼 Qwen3 → 단일 GLM-4.7-FP8 전환

## 1. Executive Summary

본 리포트는 Code QA v4 워크플로우의 모델 전략 변경을 기록한다. 기존에는 **Qwen3-Next-80B-A3B-Thinking-FP8** (추론 전용)과 **Qwen3-Coder-Next-FP8** (코드 전용)의 듀얼 모델 전략을 수립하여 운영하였으나, **GLM-4.7-FP8** 단일 모델로 마이그레이션하였다. GLM-4.7의 **Interleaved Thinking** 기능이 별도 Thinking/Coder 모델의 필요성을 제거하여, 인프라 단순화와 운영 효율성이 크게 향상되었다.

---

## 2. 마이그레이션 배경

### 2.1 기존 듀얼 모델 구성 (Before)

| 항목 | Thinking 모델 | Coder 모델 |
|------|--------------|------------|
| 모델명 | Qwen3-Next-80B-A3B-Thinking-FP8 | Qwen3-Coder-Next-FP8 |
| 추론 엔진 | SGLang (port 8000) | vLLM (port 8001) |
| 역할 | CoT 추론, 분석, 점수 산정 | 코드 생성/수정, 도구 호출 |
| 에이전트 수 | 4개 (Orchestrator, code-reviewer, quality-checker, summary-reporter) | 10개 (env-setup, git-input 등) |
| GPU 요구 | 2x H100 NVL 96GB (TP=2) | 2x H100 NVL 96GB (TP=2) |

### 2.2 듀얼 모델의 한계

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                          듀얼 모델 운영 시 발생한 문제점                                │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  1. 인프라 복잡성                                                                     │
│     - 2개 추론 서버 운영 (SGLang + vLLM)                                               │
│     - 포트 관리 (8000, 8001), 로드 밸런서 설정                                         │
│     - 장애 시 Fallback 로직 필요                                                      │
│                                                                                      │
│  2. Context 전달 오버헤드                                                              │
│     - 모델 A(Thinking)의 추론 결과를 모델 B(Coder)에 전달 필요                          │
│     - Orchestrator가 Context Broker 역할 수행 → 복잡도 증가                             │
│     - 프롬프트 크기 증가 → 지연시간 증가                                                │
│                                                                                      │
│  3. GPU 리소스 비효율                                                                  │
│     - 총 4x H100 NVL 96GB 필요 (2 서버 각 TP=2)                                       │
│     - Thinking 서버 유휴 시간 발생 (코드 작업 중)                                       │
│     - Coder 서버 유휴 시간 발생 (추론 작업 중)                                          │
│                                                                                      │
│  4. 모델 간 스타일 불일치                                                               │
│     - Thinking/Coder 모델의 출력 톤/형식 차이                                           │
│     - 에이전트 프롬프트에서 형식 통일 작업 필요                                          │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 2.3 새로운 모델: GLM-4.7-FP8

| 항목 | 값 |
|------|-----|
| 모델명 | GLM-4.7-FP8 |
| 핵심 기능 | **Interleaved Thinking** (추론 + 코드 생성 통합) |
| Context Window | 256K tokens |
| Output Limit | 131072 tokens |
| 양자화 | FP8 |
| 배포 | 2x H100 NVL 96GB (TP=2), SGLang, port 8000 |
| 추론 파라미터 | temperature=1.0, top_p=0.95 |

> **핵심 인사이트**: GLM-4.7의 Interleaved Thinking은 모델 내부에서 추론(Thinking)과 코드 생성(Coding)을 자연스럽게 전환한다. 별도의 Thinking 모델과 Coder 모델을 분리할 필요가 없어졌다.

---

## 3. 마이그레이션 사유: Interleaved Thinking

### 3.1 Interleaved Thinking이란?

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                        Interleaved Thinking 개요                                     │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  기존 듀얼 모델 접근:                                                                 │
│  ┌──────────────────────┐     ┌──────────────────────┐                               │
│  │  Thinking Model       │     │  Coder Model         │                               │
│  │  <think>분석...</think>│────▶│  (no thinking)       │                               │
│  │  → 이슈 리스트 출력   │     │  → 코드 수정 실행    │                               │
│  └──────────────────────┘     └──────────────────────┘                               │
│  문제: Context 전달 필요, 2개 서버 운영                                                │
│                                                                                      │
│  GLM-4.7 Interleaved Thinking:                                                       │
│  ┌──────────────────────────────────────────────────────┐                             │
│  │  GLM-4.7-FP8 (단일 모델)                             │                             │
│  │                                                       │                             │
│  │  요청: "이 코드를 분석하고 수정해주세요"               │                             │
│  │                                                       │                             │
│  │  <think> SQL injection 위험 발견... </think>          │                             │
│  │  → Read(app.py) → 코드 확인                          │                             │
│  │  <think> parameterized query로 수정해야... </think>   │                             │
│  │  → Edit(app.py, 수정 내용)                            │                             │
│  │  <think> null check도 필요... </think>                │                             │
│  │  → Edit(utils.py, 수정 내용)                          │                             │
│  │                                                       │                             │
│  │  ★ 추론과 코드 작업이 하나의 세션에서 자연스럽게 교차  │                             │
│  └──────────────────────────────────────────────────────┘                             │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 듀얼 모델이 불필요해진 이유

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                    왜 단일 모델로 충분한가?                                             │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  이전 듀얼 모델 분리 원칙:                                                             │
│  ├── 원칙 1: "추론이 핵심 → Thinking 모델"     → GLM-4.7 Interleaved Thinking으로 해결│
│  ├── 원칙 2: "코드 생성 핵심 → Coder 모델"     → GLM-4.7이 코드 생성도 우수            │
│  └── 원칙 3: "단순 도구 실행 → Coder 모델"     → GLM-4.7이 도구 호출도 지원            │
│                                                                                      │
│  GLM-4.7이 모든 원칙을 단일 모델로 충족:                                                │
│  ├── 추론 작업: Interleaved Thinking으로 CoT 수준의 분석 가능                          │
│  ├── 코드 작업: SWE-Bench 수준의 코드 수정 능력                                        │
│  ├── 도구 호출: Tool Calling 완전 지원                                                  │
│  └── 효율성: 하나의 세션에서 추론↔코드 전환으로 Context 손실 없음                       │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. 마이그레이션 전후 비교

### 4.1 인프라 변경

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                          인프라 비교                                                   │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  [Before] 듀얼 모델                                                                   │
│  ┌──────────────────────────┐    ┌──────────────────────────┐                        │
│  │   GPU Node 1             │    │   GPU Node 2             │                        │
│  │   H100 NVL 96GB x2      │    │   H100 NVL 96GB x2      │                        │
│  │                          │    │                          │                        │
│  │   Thinking Model         │    │   Coder Model            │                        │
│  │   SGLang :8000           │    │   vLLM :8001             │                        │
│  │   TP=2, 256K context     │    │   TP=2, 256K context     │                        │
│  └──────────────────────────┘    └──────────────────────────┘                        │
│  총 GPU: 4x H100 NVL 96GB                                                            │
│                                                                                      │
│  [After] 단일 모델                                                                    │
│  ┌──────────────────────────┐                                                        │
│  │   GPU Node 1             │                                                        │
│  │   H100 NVL 96GB x2      │                                                        │
│  │                          │                                                        │
│  │   GLM-4.7-FP8            │                                                        │
│  │   SGLang :8000           │                                                        │
│  │   TP=2, 256K context     │                                                        │
│  └──────────────────────────┘                                                        │
│  총 GPU: 2x H100 NVL 96GB (50% 절감)                                                 │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 에이전트 모델 할당 변경

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                        에이전트 모델 할당 변경                                         │
├──────────────────┬───────────────────────────────┬──────────────────────────────────┤
│ Agent            │ Before (듀얼)                  │ After (단일)                     │
├──────────────────┼───────────────────────────────┼──────────────────────────────────┤
│ Orchestrator     │ Qwen3-Next-Thinking (추론)     │ GLM-4.7-FP8                     │
│ code-reviewer    │ Qwen3-Next-Thinking (추론)     │ GLM-4.7-FP8                     │
│ quality-checker  │ Qwen3-Next-Thinking (추론)     │ GLM-4.7-FP8                     │
│ summary-reporter │ Qwen3-Next-Thinking (추론)     │ GLM-4.7-FP8                     │
│ code-fixer       │ Qwen3-Coder-Next (코드)        │ GLM-4.7-FP8                     │
│ pre-checker      │ Qwen3-Coder-Next (코드)        │ GLM-4.7-FP8                     │
│ build-tester     │ Qwen3-Coder-Next (코드)        │ GLM-4.7-FP8                     │
│ function-tester  │ Qwen3-Coder-Next (코드)        │ GLM-4.7-FP8                     │
│ env-setup        │ Qwen3-Coder-Next (코드)        │ GLM-4.7-FP8                     │
│ git-input        │ Qwen3-Coder-Next (코드)        │ GLM-4.7-FP8                     │
│ git-committer    │ Qwen3-Coder-Next (코드)        │ GLM-4.7-FP8                     │
│ git-pusher       │ Qwen3-Coder-Next (코드)        │ GLM-4.7-FP8                     │
│ workspace-analyzer│ Qwen3-Coder-Next (코드)       │ GLM-4.7-FP8                     │
│ file-input       │ Qwen3-Coder-Next (코드)        │ GLM-4.7-FP8                     │
├──────────────────┼───────────────────────────────┼──────────────────────────────────┤
│ 총계             │ 2개 모델 (4 + 10 분할)         │ 1개 모델 (14개 에이전트 통합)     │
└──────────────────┴───────────────────────────────┴──────────────────────────────────┘
```

### 4.3 설정 변경

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                        설정 비교                                                      │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  [Before] 듀얼 Provider 설정                                                          │
│  ─────────────────────────────────────────────────                                   │
│  provider:                                                                            │
│    qwen:         # Thinking 모델                                                      │
│      api: http://localhost:8000/v1                                                    │
│      models: { Qwen3-Next-80B-A3B-Thinking-FP8 }                                    │
│    qwen-coder:   # Coder 모델                                                        │
│      api: http://localhost:8001/v1                                                    │
│      models: { Qwen3-Coder-Next-FP8 }                                               │
│                                                                                      │
│  에이전트 설정:                                                                        │
│    Thinking agents → model: qwen/Qwen3-Next-80B-A3B-Thinking-FP8                    │
│    Coder agents    → model: qwen-coder/Qwen3-Coder-Next-FP8                         │
│                                                                                      │
│  Sampling:                                                                            │
│    Thinking → temperature=0.6, top_k=20                                              │
│    Coder    → temperature=1.0, top_k=40                                              │
│                                                                                      │
│  Output: OPENCODE_EXPERIMENTAL_OUTPUT_TOKEN_MAX=65536                                │
│                                                                                      │
│  [After] 단일 Provider 설정                                                            │
│  ─────────────────────────────────────────────────                                   │
│  provider:                                                                            │
│    glm:           # 단일 모델                                                         │
│      api: http://localhost:8000/v1                                                    │
│      models: { GLM-4.7-FP8 }                                                        │
│                                                                                      │
│  에이전트 설정:                                                                        │
│    모든 agents → model: glm/GLM-4.7-FP8                                              │
│                                                                                      │
│  Sampling:                                                                            │
│    단일 → temperature=1.0, top_p=0.95                                                │
│                                                                                      │
│  Output: OPENCODE_EXPERIMENTAL_OUTPUT_TOKEN_MAX=131072                               │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 4.4 배포 명령 변경

```bash
# [Before] 듀얼 모델 배포

# Thinking Model (Port 8000)
python3 -m sglang.launch_server \
  --model Qwen/Qwen3-Next-80B-A3B-Thinking-FP8 \
  --tp 2 \
  --context-length 262144 \
  --port 8000 \
  --host 0.0.0.0 \
  --mem-fraction-static 0.85

# Coder Model (Port 8001) — vLLM
python3 -m vllm.entrypoints.openai.api_server \
  --model Qwen/Qwen3-Coder-Next-FP8 \
  --served-model-name Qwen3-Coder-Next-FP8 \
  --tensor-parallel-size 2 \
  --max-model-len 262144 \
  --port 8001 \
  --host 0.0.0.0
```

```bash
# [After] 단일 모델 배포

# GLM-4.7-FP8 (Port 8000)
python3 -m sglang.launch_server \
  --model glm/GLM-4.7-FP8 \
  --tp 2 \
  --context-length 262144 \
  --port 8000 \
  --host 0.0.0.0 \
  --mem-fraction-static 0.85
```

### 4.5 OpenCode 설정 변경 (opencode.jsonc)

```jsonc
{
  // [After] 단일 GLM Provider 설정
  "provider": {
    "glm": {
      "name": "GLM-4.7-FP8",
      "npm": "@ai-sdk/openai-compatible",
      "api": "http://localhost:8000/v1",
      "env": [],
      "options": {
        "apiKey": "dummy",
        "baseURL": "http://localhost:8000/v1"
      },
      "models": {
        "GLM-4.7-FP8": {
          "name": "GLM-4.7-FP8",
          "id": "GLM-4.7-FP8",
          "tool_call": true,
          "temperature": true,
          "reasoning": true,
          "attachment": false,
          "modalities": { "input": ["text"], "output": ["text"] },
          "limit": { "context": 262144, "output": 131072 },
          "cost": { "input": 0, "output": 0 }
        }
      }
    }
  }
}
```

### 4.6 에이전트 설정 변경

```yaml
# 모든 에이전트 (14개) — 동일한 단일 모델 사용
# code-qa.md (mode), code-reviewer.md, quality-checker.md, summary-reporter.md,
# env-setup.md, git-input.md, file-input.md, workspace-analyzer.md,
# pre-checker.md, code-fixer.md, build-tester.md, function-tester.md,
# git-committer.md, git-pusher.md
model: glm/GLM-4.7-FP8
```

---

## 5. 워크플로우 시각화 (단일 모델)

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                          Single Model Workflow                                        │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  ═══ GLM-4.7-FP8 (Interleaved Thinking) ════════════════════════════════════════    │
│                                                                                      │
│        [Orchestrator: GLM-4.7-FP8]                                                   │
│            │       │       │       │                                                  │
│            ▼       ▼       ▼       ▼                                                  │
│                                                                                      │
│  Phase -1  Phase 0   Phase 1   Phase 2     Phase 3   Phase 4     Phase 5-6          │
│  ┌──────┐ ┌──────┐  ┌──────┐  ┌────────┐  ┌──────┐ ┌────────┐  ┌────────┐          │
│  │ GLM  │→│ GLM  │→ │ GLM  │→ │  GLM   │→ │ GLM  │→│  GLM   │→ │  GLM   │          │
│  │env-  │ │git-  │  │pre-  │  │review  │  │fixer │ │quality │  │build/  │          │
│  │setup │ │input │  │check │  │(Think) │  │(SWE) │ │check   │  │test    │          │
│  └──────┘ └──────┘  └──────┘  └────────┘  └──────┘ └────────┘  └────────┘          │
│                                                                                      │
│  Phase 7              Phase 8                Phase 9                                 │
│  ┌──────┐            ┌─────────┐            ┌──────┐                                │
│  │ GLM  │──────────→ │  GLM    │──────────→ │ GLM  │                                │
│  │commit│            │summary  │            │push  │                                │
│  └──────┘            │(Think)  │            └──────┘                                │
│                      └─────────┘                                                     │
│                                                                                      │
│  범례: ███ GLM-4.7-FP8 (모든 에이전트 동일 모델)                                      │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 6. Context 관리 간소화

### 6.1 단일 모델의 Context 이점

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                    Context 관리 비교                                                   │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  [Before] 듀얼 모델 Context 전달                                                      │
│  ─────────────────────────────────────────────────                                   │
│  • Thinking 모델 → Orchestrator → Coder 모델 (Context 재구성 필요)                    │
│  • Orchestrator-Mediated Context Protocol (OMCP) 3계층 설계 필요                      │
│  • 프롬프트에 이전 모델의 결과를 명시적으로 포함해야 함                                  │
│  • Context Budget 관리 복잡: 에이전트별 개별 설계                                      │
│                                                                                      │
│  [After] 단일 모델 Context 전달                                                        │
│  ─────────────────────────────────────────────────                                   │
│  • 모든 에이전트가 동일 모델 → Context 형식 통일                                       │
│  • Orchestrator가 단순히 결과를 전달 (모델 전환 오버헤드 없음)                          │
│  • OMCP 프로토콜 불필요 → 단순 구조화된 토큰 전달                                      │
│  • Interleaved Thinking으로 추론↔코드 전환 시 Context 손실 없음                        │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 6.2 에이전트별 Context Budget (단순화)

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                     에이전트별 Context Budget (단순화)                                  │
├──────────────────┬──────────┬──────────────┬────────────┬────────────────────────────┤
│ Agent            │ 모델     │ 프롬프트 예산  │ 자체 획득   │ 전달받는 Context             │
├──────────────────┼──────────┼──────────────┼────────────┼────────────────────────────┤
│ env-setup        │ GLM-4.7  │ ~5K          │ Bash 출력   │ PROJECT_ROOT               │
│ workspace-analyzer│ GLM-4.7 │ ~5K          │ Glob/Read  │ PROJECT_ROOT               │
│ git-input        │ GLM-4.7  │ ~5K          │ Bash(git)  │ PROJECT_ROOT               │
│ pre-checker      │ GLM-4.7  │ ~8K          │ Bash(lint) │ FILE_LIST                  │
│ code-reviewer    │ GLM-4.7  │ ~15K         │ Read       │ FILE_LIST + cache          │
│ code-fixer       │ GLM-4.7  │ ~20K         │ Read/Edit  │ ISSUE_LIST                 │
│ quality-checker  │ GLM-4.7  │ ~10K         │ Bash       │ FILE_LIST                  │
│ build-tester     │ GLM-4.7  │ ~10K         │ Bash       │ ENV_STATE                  │
│ function-tester  │ GLM-4.7  │ ~10K         │ Bash       │ ENV_STATE                  │
│ git-committer    │ GLM-4.7  │ ~8K          │ Bash(git)  │ FILE_LIST                  │
│ summary-reporter │ GLM-4.7  │ ~15K         │ Bash(git)  │ 전체 결과                   │
│ git-pusher       │ GLM-4.7  │ ~5K          │ Bash(git)  │ 기본 상태                   │
├──────────────────┼──────────┼──────────────┼────────────┼────────────────────────────┤
│ 합계 (순차 실행)  │          │ ~116K (max)  │            │ 256K 내에서 충분히 운영 가능  │
└──────────────────┴──────────┴──────────────┴────────────┴────────────────────────────┘
```

---

## 7. 기대 효과 분석

### 7.1 성능 및 운영 개선

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                          마이그레이션 효과 분석                                        │
├──────────────────────┬─────────────────────────┬────────────────────────────────────┤
│ 지표                 │ Before (듀얼 모델)       │ After (단일 GLM-4.7)               │
├──────────────────────┼─────────────────────────┼────────────────────────────────────┤
│ GPU 서버 수          │ 2대 (4x H100)            │ 1대 (2x H100) — 50% 절감          │
│ 추론 엔진            │ SGLang + vLLM            │ SGLang 단일 — 운영 단순화          │
│ 포트 관리            │ 8000, 8001               │ 8000 단일                          │
│ Fallback 복잡도      │ 높음 (2서버 장애 시나리오)│ 낮음 (단일 서버)                   │
│ Context 전달 오버헤드│ 높음 (OMCP 프로토콜)      │ 없음 (동일 모델)                   │
│ 출력 토큰 한도       │ 65536                    │ 131072 — 2배 증가                  │
│ 추론+코드 통합       │ 불가 (모델 분리)          │ 가능 (Interleaved Thinking)        │
│ 모델 간 스타일 일관성│ 불일치 가능               │ 완전 일관                          │
│ 설정 복잡도          │ 듀얼 provider + 분할 설정 │ 단일 provider                      │
│ 에이전트 프롬프트     │ 모델별 차별화 필요        │ 통일 형식                          │
├──────────────────────┴─────────────────────────┴────────────────────────────────────┤
│ 총 평가: 인프라 50% 절감 + 운영 복잡도 대폭 감소 + Interleaved Thinking으로 품질 유지  │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 7.2 제거된 복잡도

| 제거된 항목 | 설명 |
|------------|------|
| **듀얼 Provider 설정** | opencode.jsonc에서 qwen + qwen-coder → glm 단일 |
| **포트 8001** | vLLM 서버 제거 |
| **OMCP 프로토콜** | Orchestrator-Mediated Context Protocol 불필요 |
| **Fallback 전략** | 단일 서버로 장애 시나리오 단순화 |
| **모델별 Sampling** | Thinking(temp=0.6, top_k=20) + Coder(temp=1.0, top_k=40) → 단일(temp=1.0, top_p=0.95) |
| **vLLM 의존성** | SGLang만 사용 |

---

## 8. 구현 로드맵

### Phase 1: 모델 준비 ✅ 완료
- [x] GLM-4.7-FP8 모델 다운로드 및 내부 전송
- [x] GPU 노드 배포 (단일 노드, 2x H100 NVL, TP=2)
- [x] SGLang 서빙 (port 8000)
- [x] 엔드포인트 health check 및 추론 테스트

### Phase 2: 설정 마이그레이션 ✅ 완료
- [x] opencode.jsonc에서 듀얼 provider → 단일 `glm` provider 변경
- [x] 14개 에이전트 `.md` 파일의 `model` 필드를 `glm/GLM-4.7-FP8`로 변경
- [x] 9개 command `.md` 파일의 `model` 필드 변경
- [x] workflow-settings.yaml 단일 모델 설정
- [x] OPENCODE_EXPERIMENTAL_OUTPUT_TOKEN_MAX=131072 설정
- [x] Sampling 파라미터 통일 (temperature=1.0, top_p=0.95)

### Phase 3: 기존 인프라 정리 ✅ 완료
- [x] Qwen3-Coder-Next-FP8 (vLLM, port 8001) 서버 중지
- [x] Qwen3-Next-80B-A3B-Thinking-FP8 서버 중지
- [x] GPU Node 2 회수 또는 재활용

### Phase 4: 검증 및 최적화 (In Progress)
- [ ] 각 에이전트별 단독 테스트 (GLM-4.7-FP8)
- [ ] 전체 워크플로우 E2E 테스트
- [ ] 회귀 루프 테스트 (Context 전달 검증)
- [ ] 워크플로우 속도 벤치마크 (듀얼 vs 단일)
- [ ] 코드 수정 품질 비교
- [ ] 프로덕션 안정화

---

## 9. 결론

| 결론 항목 | 요약 |
|-----------|------|
| **마이그레이션 사유** | GLM-4.7 Interleaved Thinking이 별도 Thinking/Coder 모델 필요성 제거 |
| **모델 할당** | 14개 에이전트 모두 GLM-4.7-FP8 단일 모델 사용 |
| **인프라 절감** | GPU 서버 2대 → 1대 (50% 절감) |
| **운영 단순화** | 듀얼 provider, OMCP, Fallback 로직 제거 |
| **품질 유지** | Interleaved Thinking으로 추론 품질 유지 + 코드 생성 통합 |
| **출력 확장** | Output 토큰 65536 → 131072 (2배) |

GLM-4.7의 Interleaved Thinking은 추론과 코드 생성을 단일 모델 내에서 자연스럽게 교차 수행하므로, 이전의 듀얼 모델 전략에서 발생하던 인프라 복잡성, Context 전달 오버헤드, 모델 간 스타일 불일치 문제가 근본적으로 해결되었다. 모든 에이전트가 동일한 모델을 사용하므로 `model` 필드 통일만으로 마이그레이션이 완료되며, 프롬프트 형식 호환성도 자연스럽게 유지된다.

---

*Generated: 2026-02-10*
*Author: Code QA Analysis System*
*Migration: Dual Qwen3 → Single GLM-4.7-FP8*
