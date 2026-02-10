# Code QA Workflow - 작업 현황 (GLM-4.7-FP8 단일 모델)

**마지막 업데이트**: 2026-02-10
**브랜치**: `claude/review-opencode-docs-RPUNO`
**모델**: GLM-4.7-FP8 (Z.ai, 355B MoE, 32B active, MIT License)

---

## 1. 모델 마이그레이션 요약

### 변경 전 (Dual Qwen3)
```
SGLang (port 8000): Qwen3-Next-80B-A3B-Thinking-FP8
  → code-reviewer, quality-checker, summary-reporter

SGLang (port 8001): Qwen3-Coder-Next-FP8
  → Orchestrator, env-setup, git-input, workspace-analyzer,
    pre-checker, code-fixer, build-tester, function-tester,
    git-committer, git-pusher, file-input
```

### 변경 후 (Single GLM-4.7-FP8)
```
SGLang (port 8000): GLM-4.7-FP8
  → ALL agents (13개 서브 에이전트 + Orchestrator)
```

### 변경 이유
- GLM-4.7은 Interleaved Thinking을 내장하여 별도 Thinking 모델이 불필요
- 단일 모델로 운영 복잡성 감소 (듀얼 서버 → 단일 서버)
- 200K context + 128K output (Qwen3 대비 확장)
- Tool calling: τ²-Bench 87.4% (open-source SOTA)
- Coding: SWE-bench 73.8%, LiveCodeBench-v6 84.9%

---

## 2. 변경된 파일 목록

### .opencode/ 설정 파일
| 파일 | 변경 내용 |
|------|----------|
| `opencode.jsonc` | 듀얼 프로바이더 → 단일 `glm` 프로바이더 (port 8000) |
| `mode/code-qa.md` | Orchestrator 모델 → `glm/GLM-4.7-FP8`, health check 단일화 |
| `config/workflow-settings.yaml` | 모델 할당/sampling/health check 단일화 |
| `config/context-schema.md` | 모델 참조 업데이트 |
| `scripts/test-workflow.sh` | 단일 모델 검증 로직으로 변경 (v4) |

### .opencode/agent/ (13개 파일)
| 에이전트 | 이전 모델 | 변경 후 |
|----------|----------|---------|
| build-tester | qwen-coder/Qwen3-Coder-Next-FP8 | glm/GLM-4.7-FP8 |
| code-fixer | qwen-coder/Qwen3-Coder-Next-FP8 | glm/GLM-4.7-FP8 |
| code-reviewer | qwen/Qwen3-Next-80B-A3B-Thinking-FP8 | glm/GLM-4.7-FP8 |
| env-setup | qwen-coder/Qwen3-Coder-Next-FP8 | glm/GLM-4.7-FP8 |
| file-input | qwen-coder/Qwen3-Coder-Next-FP8 | glm/GLM-4.7-FP8 |
| function-tester | qwen-coder/Qwen3-Coder-Next-FP8 | glm/GLM-4.7-FP8 |
| git-committer | qwen-coder/Qwen3-Coder-Next-FP8 | glm/GLM-4.7-FP8 |
| git-input | qwen-coder/Qwen3-Coder-Next-FP8 | glm/GLM-4.7-FP8 |
| git-pusher | qwen-coder/Qwen3-Coder-Next-FP8 | glm/GLM-4.7-FP8 |
| pre-checker | qwen-coder/Qwen3-Coder-Next-FP8 | glm/GLM-4.7-FP8 |
| quality-checker | qwen/Qwen3-Next-80B-A3B-Thinking-FP8 | glm/GLM-4.7-FP8 |
| summary-reporter | qwen/Qwen3-Next-80B-A3B-Thinking-FP8 | glm/GLM-4.7-FP8 |
| workspace-analyzer | qwen-coder/Qwen3-Coder-Next-FP8 | glm/GLM-4.7-FP8 |

### .opencode/command/ (이미 마이그레이션 완료)
모든 command 파일의 `model:` 필드가 `glm/GLM-4.7-FP8`로 설정됨.

---

## 3. 아키텍처 요약

### 단일 모델 구성
```
SGLang (port 8000): zai-org/GLM-4.7-FP8
  → ALL agents: Orchestrator (code-qa), env-setup, git-input,
    workspace-analyzer, pre-checker, code-reviewer, code-fixer,
    quality-checker, build-tester, function-tester, git-committer,
    git-pusher, file-input, summary-reporter
```

### GLM-4.7-FP8 스펙
```
아키텍처:     MoE (355B total, 32B active)
Context:      200,000 tokens
Max Output:   128,000 tokens (131,072)
Tool Calling: Yes (--tool-call-parser glm47)
Thinking:     Interleaved Thinking (built-in, --reasoning-parser glm45)
라이선스:     MIT
Hardware:     8× H100 or 4× H200 (FP8)
```

### Sampling 파라미터 (Z.ai 공식 권장)
```
temperature: 1.0
top_p:       0.95
주의: 두 값을 동시에 조절하지 말 것 — 하나만 조절할 것
```

### SGLang 서빙 커맨드
```bash
python3 -m sglang.launch_server \
  --model-path zai-org/GLM-4.7-FP8 \
  --tp-size 4 \
  --tool-call-parser glm47 \
  --reasoning-parser glm45 \
  --mem-fraction-static 0.85 \
  --served-model-name GLM-4.7-FP8 \
  --host 0.0.0.0 --port 8000
```

### vLLM 서빙 커맨드 (대안)
```bash
vllm serve zai-org/GLM-4.7-FP8 \
  --tensor-parallel-size 4 \
  --speculative-config.method mtp \
  --speculative-config.num_speculative_tokens 1 \
  --tool-call-parser glm47 \
  --reasoning-parser glm45 \
  --enable-auto-tool-choice \
  --served-model-name GLM-4.7-FP8
```

### Preserved Thinking (에이전트 작업 권장)
```json
"chat_template_kwargs": {
  "enable_thinking": true,
  "clear_thinking": false
}
```
GLM-4.7은 멀티턴 대화에서 이전 추론 블록을 자동 보존하여 정보 손실을 줄임.

### 파라미터 우선순위 체인
```
transform.ts 기본값 → opencode.jsonc model.options (override) → agent.options → variant
                       ↑ providerOptions로 request body에 spread
                       (SDK 표준 파라미터보다 나중에 적용되어 override됨)
```

### Context Passing 흐름
```
STEP 0: workspace-analyzer → workspace_cache (JSON)
STEP 1: env-setup → env_state (텍스트 토큰)
STEP 2: git-input/file-input → changed_files (텍스트 토큰)
STEP 3: pre-checker → pre_check_result (JSON)
STEP 4: code-reviewer → review_result (JSON) ← receives: env_state, file_list, workspace_cache
STEP 5: code-fixer → fix_result (JSON) ← receives: review_result.issues, file_list, regression_history
STEP 6: quality-checker → quality_result (JSON) ← receives: file_list, fix_result.files_modified
STEP 7: build-tester → build_result (JSON) ← receives: env_state, file_list
STEP 8: function-tester → test_result (JSON) ← receives: env_state, file_list
STEP 9: git-committer → commit_result (JSON) ← uses git directly
STEP 10: summary-reporter ← receives: ALL context_store + regression_history
STEP 11: git-pusher → push_result ← uses git directly
```

### 핵심 환경변수
```bash
export OPENCODE_EXPERIMENTAL_OUTPUT_TOKEN_MAX=131072  # GLM-4.7 128K output 활성화
```

---

## 4. 주요 파일 위치

| 파일 | 용도 |
|------|------|
| `.opencode/opencode.jsonc` | 프로바이더/모델 설정, sampling 파라미터 |
| `.opencode/mode/code-qa.md` | Orchestrator (single source of truth) |
| `.opencode/command/code-qa.md` | /code-qa 슬래시 커맨드 (thin wrapper) |
| `.opencode/agent/*.md` | 13개 서브 에이전트 |
| `.opencode/config/workflow-settings.yaml` | 타임아웃, 재시도, 모델 할당 설정 |
| `.opencode/config/context-schema.md` | Agent간 JSON 스키마 정의 |
| `.opencode/config/permission-templates.yaml` | 권한 템플릿 |
| `.opencode/scripts/test-workflow.sh` | 워크플로 검증 스크립트 (v4) |
| `docs/guides/14-code-qa-v4-quick-start.md` | Quick Start 가이드 (EN) |
| `docs/guides/14-code-qa-v4-quick-start.kr.md` | Quick Start 가이드 (KR) |
| `packages/opencode/src/session/llm.ts` | LLM 스트리밍 (OUTPUT_TOKEN_MAX) |
| `packages/opencode/src/provider/transform.ts` | sampling 기본값 (opencode.jsonc로 override) |

---

## 5. 알려진 이슈 / 참고

- **OpenCode #6918**: Edit tool이 old_string을 JSON object로 받으면 silent fail → code-fixer에 경고 추가됨
- **SGLang #15721**: GLM-4.7 tool calling 시 `glm47_moe_detector.py:421`에서 NoneType 오류 보고됨 → SGLang 최신 nightly 빌드 권장
- **GLM-4.7 FP8 reasoning**: vLLM에서 GLM-4.7-FP8의 initial thinking token이 생성되지 않는 이슈 보고 → SGLang 사용 권장
- **Sampling 주의**: Z.ai 공식 권장은 temperature=1.0, top_p=0.95이며, 두 값을 동시에 수정하지 말 것
- **설치 요구사항**: SGLang/vLLM main 브랜치 또는 nightly 빌드 필요 (GLM-4.7 지원)

---

## 6. 다음 세션 시작 시

1. 이 파일 읽기: `.opencode/WORK_STATUS.md`
2. SGLang 서버 상태 확인: `curl http://localhost:8000/v1/models`
3. 환경변수 확인: `echo $OPENCODE_EXPERIMENTAL_OUTPUT_TOKEN_MAX` (131072여야 함)
4. 실제 `/code-qa` 테스트 실행
5. 결과에 따라 추가 조정

---

## 7. 확인/테스트 필요한 항목

### SGLang 서버 관련
- [ ] `--tool-call-parser glm47` 플래그가 SGLang에서 정상 작동하는지 확인
- [ ] `--reasoning-parser glm45` 플래그로 Thinking/Content 분리가 정상 동작하는지 확인
- [ ] Streaming tool call이 정상 전달되는지 테스트
- [ ] Preserved Thinking (`clear_thinking: false`) 동작 확인

### 실제 워크플로 테스트
- [ ] `/code-qa` 커맨드 실행 테스트 (전체 11 STEP)
- [ ] 단일 모델에서 tool call 안정적으로 수행하는지 확인
- [ ] Regression loop (quality < 70 → code-fixer 재시도) 테스트
- [ ] WAITING_INPUT 단계에서 사용자 입력 대기 정상 동작 확인

### env-setup / git-input JSON 전환 (추후)
- [ ] env-setup이 텍스트 토큰 대신 JSON 출력하도록 전환 검토
- [ ] git-input도 동일하게 JSON 출력 전환 검토
