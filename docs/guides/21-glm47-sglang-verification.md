# GLM-4.7-FP8 SGLang 서빙 검증 가이드

**목적**: GLM-4.7-FP8을 SGLang에 서빙한 후, OpenCode Code QA 워크플로우에 필요한 기능들이 정상 동작하는지 단계별로 검증한다.

**관련 설정**: `.opencode/opencode.jsonc`, `.opencode/config/workflow-settings.yaml`

---

## 사전 준비

### SGLang 설치

```bash
# SGLang nightly 설치 (GLM-4.7 지원 필수)
uv pip install -U sglang[all] --pre

# transformers도 최신 필요
uv pip install git+https://github.com/huggingface/transformers.git
```

### SGLang 서버 시작

```bash
python3 -m sglang.launch_server \
  --model-path zai-org/GLM-4.7-FP8 \
  --tp-size 4 \
  --tool-call-parser glm47 \
  --reasoning-parser glm45 \
  --mem-fraction-static 0.85 \
  --max-model-len 65536 \
  --served-model-name GLM-4.7-FP8 \
  --host 0.0.0.0 --port 8000
```

### 서버 준비 확인

```bash
curl -s http://localhost:8000/v1/models | python3 -m json.tool
```

`"id": "GLM-4.7-FP8"` 이 응답에 포함되면 서버 준비 완료.

---

## STEP 1: 기본 추론 확인

가장 기본적인 chat completion 요청으로 모델이 정상 응답하는지 확인.

```bash
curl -s http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "GLM-4.7-FP8",
    "messages": [{"role": "user", "content": "3+5는?"}],
    "max_tokens": 512
  }' | python3 -m json.tool
```

**확인 항목:**
- [ ] `choices[0].message.content`에 정상 답변이 있는지
- [ ] 에러 없이 응답 완료되는지

---

## STEP 2: Thinking(추론) 모드 제어

### 2-1. Thinking ON (기본값)

```bash
curl -s http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "GLM-4.7-FP8",
    "messages": [{"role": "user", "content": "피보나치 수열의 10번째 값은?"}],
    "max_tokens": 1024
  }' | python3 -m json.tool
```

**확인 항목:**
- [ ] `choices[0].message.reasoning_content` 필드가 존재하고 thinking 내용이 포함되는지
- [ ] `choices[0].message.content`에 최종 답변이 있는지

### 2-2. Thinking OFF (`chat_template_kwargs`로 비활성화)

```bash
curl -s http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "GLM-4.7-FP8",
    "messages": [{"role": "user", "content": "피보나치 수열의 10번째 값은?"}],
    "max_tokens": 1024,
    "chat_template_kwargs": {"enable_thinking": false}
  }' | python3 -m json.tool
```

**확인 항목:**
- [ ] `reasoning_content`가 **null 또는 빈 문자열**이면 thinking OFF 성공
- [ ] `content`에만 답변이 나오는지

### 2-3. Preserved Thinking (멀티턴 추론 보존)

```bash
curl -s http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "GLM-4.7-FP8",
    "messages": [{"role": "user", "content": "피보나치 함수를 파이썬으로 작성해줘"}],
    "max_tokens": 2048,
    "chat_template_kwargs": {"enable_thinking": true, "clear_thinking": false}
  }' | python3 -m json.tool
```

**확인 항목:**
- [ ] `reasoning_content`에 추론 과정이 포함되는지
- [ ] `clear_thinking: false`가 에러 없이 수락되는지

---

## STEP 3: Tool Calling 확인

### 3-1. 기본 Tool Calling

```bash
curl -s http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "GLM-4.7-FP8",
    "messages": [{"role": "user", "content": "현재 디렉토리의 파일 목록을 보여줘"}],
    "max_tokens": 1024,
    "tools": [{
      "type": "function",
      "function": {
        "name": "Bash",
        "description": "Run a bash command",
        "parameters": {
          "type": "object",
          "properties": {
            "command": {"type": "string", "description": "The bash command to run"}
          },
          "required": ["command"]
        }
      }
    }],
    "tool_choice": "auto"
  }' | python3 -m json.tool
```

**확인 항목:**
- [ ] `choices[0].message.tool_calls` 배열이 생성되는지
- [ ] `function.name` = `"Bash"`, `arguments`에 유효한 JSON이 있는지
- [ ] 크래시 없이 응답 완료 (SGLang #15721 확인)

### 3-2. Tool Calling + Thinking OFF 조합

```bash
curl -s http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "GLM-4.7-FP8",
    "messages": [{"role": "user", "content": "현재 디렉토리의 파일 목록을 보여줘"}],
    "max_tokens": 1024,
    "chat_template_kwargs": {"enable_thinking": false},
    "tools": [{
      "type": "function",
      "function": {
        "name": "Bash",
        "description": "Run a bash command",
        "parameters": {
          "type": "object",
          "properties": {
            "command": {"type": "string", "description": "The bash command to run"}
          },
          "required": ["command"]
        }
      }
    }],
    "tool_choice": "auto"
  }' | python3 -m json.tool
```

**확인 항목:**
- [ ] tool_calls가 정상 생성되면서 reasoning_content가 없는지
- [ ] thinking OFF 상태에서도 tool calling이 정확한지

### 3-3. 복수 Tool 제공

code-fixer 에이전트는 Bash, Read, Edit, Write, Glob, Grep 6개 도구를 동시에 제공받는다. 복수 tool 환경에서 정확한 선택이 되는지 확인.

```bash
curl -s http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "GLM-4.7-FP8",
    "messages": [{"role": "user", "content": "/home/user/test.py 파일의 내용을 읽어줘"}],
    "max_tokens": 1024,
    "tools": [
      {"type": "function", "function": {"name": "Bash", "description": "Run a bash command", "parameters": {"type": "object", "properties": {"command": {"type": "string"}}, "required": ["command"]}}},
      {"type": "function", "function": {"name": "Read", "description": "Read a file from disk", "parameters": {"type": "object", "properties": {"file_path": {"type": "string"}}, "required": ["file_path"]}}},
      {"type": "function", "function": {"name": "Edit", "description": "Edit a file", "parameters": {"type": "object", "properties": {"file_path": {"type": "string"}, "old_string": {"type": "string"}, "new_string": {"type": "string"}}, "required": ["file_path", "old_string", "new_string"]}}},
      {"type": "function", "function": {"name": "Glob", "description": "Find files by pattern", "parameters": {"type": "object", "properties": {"pattern": {"type": "string"}}, "required": ["pattern"]}}}
    ],
    "tool_choice": "auto"
  }' | python3 -m json.tool
```

**확인 항목:**
- [ ] `"Read"` 도구를 정확히 선택하는지 (Bash의 cat이 아닌)
- [ ] `file_path` 인자가 올바른 JSON으로 생성되는지

---

## STEP 4: Streaming Tool Call 확인

OpenCode는 streaming 모드를 사용한다. Streaming 환경에서 tool call이 안정적으로 전달되는지 확인.

```bash
curl -s http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "GLM-4.7-FP8",
    "messages": [{"role": "user", "content": "test.py 파일을 읽어줘"}],
    "max_tokens": 1024,
    "stream": true,
    "tools": [{
      "type": "function",
      "function": {
        "name": "Read",
        "description": "Read a file from disk",
        "parameters": {
          "type": "object",
          "properties": {
            "file_path": {"type": "string", "description": "Absolute path to the file"}
          },
          "required": ["file_path"]
        }
      }
    }],
    "tool_choice": "auto"
  }' 2>&1
```

**확인 항목:**
- [ ] SSE 이벤트(`data: {...}`)가 정상적으로 스트리밍되는지
- [ ] `delta.tool_calls`가 점진적으로 전달되는지
- [ ] `data: [DONE]`으로 정상 종료되는지
- [ ] 중간에 끊기거나 NoneType 에러 없이 완료되는지 (SGLang #15721)

---

## STEP 5: OpenCode `providerOptions` 전달 확인

**이 단계가 가장 핵심이다.** OpenCode → AI SDK → SGLang으로 `chat_template_kwargs`가 실제 전달되는지 확인.

### 5-1. 프록시 서버 준비

아래 스크립트를 `test_proxy.py`로 저장:

```python
#!/usr/bin/env python3
"""
Request body 캡처 프록시.
Port 8001에서 수신 → request body 출력 → port 8000(SGLang)으로 전달.

사용법:
  1. python3 test_proxy.py
  2. opencode.jsonc의 baseURL/api를 http://localhost:8001/v1 로 변경
  3. OpenCode에서 간단한 명령 실행
  4. 이 프록시의 콘솔 출력에서 chat_template_kwargs 존재 여부 확인
"""
import json
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler
import urllib.request

TARGET = "http://localhost:8000"

class ProxyHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length)

        try:
            data = json.loads(body)
        except json.JSONDecodeError:
            data = {}

        # === 핵심: request body 키 출력 ===
        print("\n" + "=" * 70)
        print(f"  PATH:                  {self.path}")
        print(f"  model:                 {data.get('model', 'N/A')}")
        print(f"  chat_template_kwargs:  {data.get('chat_template_kwargs', '❌ NOT PRESENT')}")
        print(f"  thinking:              {data.get('thinking', '❌ NOT PRESENT')}")
        print(f"  temperature:           {data.get('temperature', 'N/A')}")
        print(f"  top_p:                 {data.get('top_p', 'N/A')}")
        print(f"  stream:                {data.get('stream', 'N/A')}")
        print(f"  tools:                 {'YES (' + str(len(data.get('tools', []))) + ')' if 'tools' in data else 'NO'}")
        print(f"  ALL KEYS:              {sorted(data.keys())}")
        print("=" * 70 + "\n")
        sys.stdout.flush()

        # SGLang으로 전달
        req = urllib.request.Request(
            f"{TARGET}{self.path}",
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            resp = urllib.request.urlopen(req, timeout=120)
            self.send_response(resp.status)
            for h, v in resp.getheaders():
                if h.lower() not in ("transfer-encoding",):
                    self.send_header(h, v)
            self.end_headers()
            self.wfile.write(resp.read())
        except Exception as e:
            print(f"  ⚠️  PROXY ERROR: {e}")
            self.send_response(502)
            self.end_headers()
            self.wfile.write(str(e).encode())

    def do_GET(self):
        # /v1/models 등 GET 요청도 전달
        req = urllib.request.Request(
            f"{TARGET}{self.path}",
            headers=dict(self.headers),
            method="GET",
        )
        try:
            resp = urllib.request.urlopen(req, timeout=10)
            self.send_response(resp.status)
            for h, v in resp.getheaders():
                if h.lower() not in ("transfer-encoding",):
                    self.send_header(h, v)
            self.end_headers()
            self.wfile.write(resp.read())
        except Exception as e:
            self.send_response(502)
            self.end_headers()
            self.wfile.write(str(e).encode())

    def log_message(self, format, *args):
        pass  # suppress default access logs


if __name__ == "__main__":
    port = 8001
    print(f"🔍 Proxy listening on :{port} → forwarding to {TARGET}")
    print(f"   Change opencode.jsonc baseURL to http://localhost:{port}/v1")
    print(f"   Then run any OpenCode command and watch this console.\n")
    HTTPServer(("0.0.0.0", port), ProxyHandler).serve_forever()
```

### 5-2. 테스트 절차

```bash
# 1. 프록시 시작 (별도 터미널)
python3 test_proxy.py

# 2. opencode.jsonc의 baseURL을 임시로 8001로 변경
#    "api": "http://localhost:8001/v1"
#    "baseURL": "http://localhost:8001/v1"

# 3. OpenCode에서 간단한 명령 실행
#    예: /review, /build, /env 등

# 4. 프록시 콘솔 출력 확인
```

### 5-3. 판정 기준

**성공 (chat_template_kwargs 전달됨):**
```
======================================================================
  PATH:                  /v1/chat/completions
  model:                 GLM-4.7-FP8
  chat_template_kwargs:  {'enable_thinking': false}    ← ✅ 전달됨
  thinking:              ❌ NOT PRESENT
  temperature:           1.0
  top_p:                 0.95
  stream:                True
  tools:                 YES (3)
  ALL KEYS:              ['chat_template_kwargs', 'max_tokens', 'messages', ...]
======================================================================
```

**실패 (chat_template_kwargs 미전달):**
```
======================================================================
  PATH:                  /v1/chat/completions
  model:                 GLM-4.7-FP8
  chat_template_kwargs:  ❌ NOT PRESENT                ← ❌ 전달 안됨
  thinking:              ❌ NOT PRESENT
  ALL KEYS:              ['max_tokens', 'messages', 'model', 'stream', ...]
======================================================================
```

### 5-4. 실패 시 대안

`chat_template_kwargs`가 전달되지 않는 경우:

1. **providerID를 `"zai"`로 변경** — OpenCode 빌트인 Z.ai thinking 코드 활용 (transform.ts:614-619)
2. **`opencode.jsonc`의 model.options에 직접 추가** — 전역 설정으로 우회
3. **OpenCode 소스 수정** — `transform.ts`의 `sdkKey()` 함수에 `@ai-sdk/openai-compatible` 엔트리 추가

---

## 결과 기록 템플릿

테스트 완료 후 아래 표를 채워서 결과를 기록.

| # | 테스트 항목 | 기대 결과 | 실제 결과 | 판정 |
|---|-----------|----------|----------|:----:|
| 1 | `/v1/models` 응답 | `"id": "GLM-4.7-FP8"` | | |
| 2-1 | Thinking ON (기본) | `reasoning_content` 존재 | | |
| 2-2 | Thinking OFF | `reasoning_content` = null | | |
| 2-3 | Preserved Thinking | `clear_thinking: false` 정상 | | |
| 3-1 | Tool Calling | `tool_calls` 정상 생성 | | |
| 3-2 | Tool + Thinking OFF | tool_calls + no reasoning | | |
| 3-3 | 복수 Tool 선택 | 정확한 tool 선택 | | |
| 4 | Streaming Tool Call | 끊김/에러 없이 완료 | | |
| 5 | providerOptions 전달 | `chat_template_kwargs` 존재 | | |

**판정 기준:**
- ✅ PASS: 기대대로 동작
- ⚠️ WARN: 동작하지만 부분적 이슈
- ❌ FAIL: 동작하지 않음

---

## 관련 이슈

- [SGLang #15721](https://github.com/sgl-project/sglang/issues/15721) — GLM-4.7 tool calling 크래시 (`glm47_moe_detector.py:421`)
- [vLLM GLM-4.7-FP8 Reasoning Issue](https://discuss.vllm.ai/t/glm-4-7-fp8-reasoning-start-issues/2146) — reasoning parser null 반환
- [OpenCode #971](https://github.com/sst/opencode/issues/971) — providerOptions 미전달 (name 미설정 시)
- [OpenCode #5674](https://github.com/anomalyco/opencode/issues/5674) — 커스텀 provider options 누락

## 관련 파일

| 파일 | 역할 |
|------|------|
| `.opencode/opencode.jsonc` | 프로바이더/모델 설정 |
| `.opencode/config/workflow-settings.yaml` | 워크플로우 설정 |
| `.opencode/WORK_STATUS.md` | 마이그레이션 현황 |
| `packages/opencode/src/provider/transform.ts` | sampling/options 변환 |
| `packages/opencode/src/session/llm.ts` | LLM 호출 + options 머지 |
