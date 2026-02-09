# Code QA Workflow - 작업 현황

**마지막 업데이트**: 2025-02-09
**브랜치**: `claude/build-method-options-ZXRek`
**마지막 커밋**: `35242a2c0` (Fix context passing mismatches between orchestrator and agents)

---

## 1. 완료된 작업

### 커밋 이력 (최신순)

| 커밋 | 내용 |
|------|------|
| `35242a2c0` | Context passing 불일치 수정 (pre-checker JSON, git-pusher 토큰, workspace_cache 스키마) |
| `9eebda409` | P2/P3 전체 수정 (권한, 에러핸들링, 문서동기화, 프롬프트 정리) |
| `00143aad8` | P0/P1 수정 (Orchestrator→Coder 모델, Edit tool 경고, command/mode 통합) |
| `08a2f1076` | Sampling 파라미터 + output limit 수정 (opencode.jsonc 통합 관리) |
| `3e89c19f6` | docs/guides/ 문서 19개 가져옴 |
| `290382549` | tool-call-extractor 미들웨어 추가 |

### P0 (Critical) - 전부 완료
- [x] `OPENCODE_EXPERIMENTAL_OUTPUT_TOKEN_MAX=65536` 환경변수 문서화
- [x] Orchestrator 모델을 Thinking → Coder로 전환 (tool call 안정성)
- [x] Sampling 파라미터 opencode.jsonc로 통합 관리 (temperature, top_p, top_k)

### P1 (High) - 전부 완료
- [x] Edit tool JSON object 경고 추가 (code-fixer, OpenCode #6918)
- [x] command/code-qa.md → thin wrapper로 통합 (mode/code-qa.md가 single source of truth)

### P2 (Should Fix) - 전부 완료
- [x] Quick Start 가이드 vLLM → SGLang 수정 (EN + KR)
- [x] Quick Start 가이드 output limit 16K → 32K/65K 수정
- [x] Quick Start 가이드 orchestrator 모델 할당 동기화
- [x] 손상된 workspace cache 감지/삭제 로직 추가
- [x] build-tester, function-tester ENV_STATE null fallback 추가
- [x] workspace-analyzer bash 권한 명시적 read-only 제한
- [x] git-input Write 권한 스코프 명확화
- [x] test-workflow.sh workspace-cache/ENV_STATE 검증 추가

### P3 (Nice to Have) - 전부 완료
- [x] code-reviewer 중복 도구 거부 제거
- [x] degraded_mode 상태변수 + health check 분기 로직
- [x] workspace-analyzer 타임아웃 정의 (60초)
- [x] code-reviewer 대용량 파일 가이드 (>2000줄)
- [x] env-setup 셸 호환성 노트
- [x] opencode.jsonc output token 코멘트 명확화
- [x] context-schema SSOT 런타임 vs 검증 차이 명시
- [x] code-fixer 패키지 버전 충돌 경고

### Context Passing 수정 - 전부 완료
- [x] pre-checker에 Structured JSON Output 추가 (스키마에만 있고 agent에 없었음)
- [x] git-pusher를 Result Token Parsing 테이블에 추가 (누락)
- [x] workspace_cache를 context_store 스키마 + orchestrator state에 추가
- [x] file-input 스키마를 context-schema.md에 추가
- [x] git-committer/git-pusher "git 직접 사용" 명시

---

## 2. 아직 확인/테스트 필요한 항목

### SGLang 서버 관련 (출근 후 확인)
- [ ] `--tool-call-parser qwen3_coder` 플래그가 SGLang에서 정상 작동하는지 확인
- [ ] `--reasoning-parser` 플래그가 Thinking 모델에 필요한지 확인
- [ ] Streaming tool call이 정상 전달되는지 테스트
- [ ] `qwen3_coder_detector_sgl.py`가 SGLang 서버에 자동 로드되는지 확인
- [ ] `chat_template.jinja`가 HuggingFace에서 자동 로드되는지 확인

### 실제 워크플로 테스트
- [ ] `/code-qa` 커맨드 실행 테스트 (전체 11 STEP)
- [ ] Orchestrator가 Coder 모델에서 tool call 안정적으로 수행하는지 확인
- [ ] Regression loop (quality < 70 → code-fixer 재시도) 테스트
- [ ] degraded_mode (한쪽 서버 다운) 시나리오 테스트
- [ ] WAITING_INPUT 단계에서 사용자 입력 대기 정상 동작 확인

### env-setup / git-input JSON 전환 (추후)
- [ ] env-setup이 텍스트 토큰 대신 JSON 출력하도록 전환 검토
- [ ] git-input도 동일하게 JSON 출력 전환 검토
- 현재는 텍스트 토큰으로 충분하므로, tool call 안정성 확보 후 전환 권장

---

## 3. 아키텍처 요약

### 듀얼 모델 구성
```
SGLang (port 8000): Qwen3-Next-80B-A3B-Thinking-FP8
  → code-reviewer, quality-checker, summary-reporter

SGLang (port 8001): Qwen3-Coder-Next-FP8
  → Orchestrator (code-qa), env-setup, git-input, workspace-analyzer,
    pre-checker, code-fixer, build-tester, function-tester,
    git-committer, git-pusher, file-input
```

### Sampling 파라미터 (opencode.jsonc에서 통합 관리)
```
Thinking: temperature=0.6, top_p=0.95, top_k=20
Coder:    temperature=1.0, top_p=0.95, top_k=40
```

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
export OPENCODE_EXPERIMENTAL_OUTPUT_TOKEN_MAX=65536  # Coder 65K output 활성화
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
| `.opencode/scripts/test-workflow.sh` | 워크플로 검증 스크립트 |
| `docs/guides/14-code-qa-v4-quick-start.md` | Quick Start 가이드 (EN) |
| `docs/guides/14-code-qa-v4-quick-start.kr.md` | Quick Start 가이드 (KR) |
| `packages/opencode/src/session/llm.ts` | LLM 스트리밍 (OUTPUT_TOKEN_MAX) |
| `packages/opencode/src/provider/transform.ts` | sampling 기본값 (opencode.jsonc로 override) |
| `packages/opencode/src/provider/tool-call-extractor.ts` | XML tool call → JSON 변환 미들웨어 |

---

## 5. 알려진 이슈 / 참고

- **OpenCode #6918**: Edit tool이 old_string을 JSON object로 받으면 silent fail → code-fixer에 경고 추가됨
- **vllm-project/vllm#23992**: Streaming tool call에서 content 누락 이슈 → SGLang 사용으로 회피
- **Thinking 모델 tool calling**: Qwen3-Next-Thinking README에서는 Qwen-Agent 권장, 직접 OpenAI API 불안정 → Orchestrator를 Coder로 전환한 이유
- **top_k**: OpenAI-compatible SDK가 topK를 `unsupported-setting` 경고와 함께 drop → opencode.jsonc model.options로 providerOptions 경유하여 우회

---

## 6. 다음 세션 시작 시

1. 이 파일 읽기: `.opencode/WORK_STATUS.md`
2. SGLang 서버 상태 확인: `curl http://localhost:8000/v1/models && curl http://localhost:8001/v1/models`
3. 환경변수 확인: `echo $OPENCODE_EXPERIMENTAL_OUTPUT_TOKEN_MAX`
4. 실제 `/code-qa` 테스트 실행
5. 결과에 따라 추가 조정
