# MCP와 Tool 심층 분석 가이드

## 개요

이 문서는 OpenCode의 MCP(Model Context Protocol)와 Tool 시스템의 내부 동작 원리, 아키텍처, 확장 방법을 심층적으로 분석합니다.

---

## 목차

1. [아키텍처 심층 분석](#1-아키텍처-심층-분석)
2. [MCP 프로토콜 상세](#2-mcp-프로토콜-상세)
3. [Tool 시스템 내부 구조](#3-tool-시스템-내부-구조)
4. [실행 흐름 분석](#4-실행-흐름-분석)
5. [성능 최적화](#5-성능-최적화)
6. [보안 고려사항](#6-보안-고려사항)
7. [확장 개발 가이드](#7-확장-개발-가이드)
8. [디버깅 및 문제 해결](#8-디버깅-및-문제-해결)

---

## 1. 아키텍처 심층 분석

### 1.1 전체 시스템 아키텍처

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           OpenCode Core                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐              │
│  │   Session    │───▶│    Agent     │───▶│   Provider   │              │
│  │   Manager    │    │   Runtime    │    │   (LLM)      │              │
│  └──────┬───────┘    └──────┬───────┘    └──────────────┘              │
│         │                   │                                           │
│         │                   ▼                                           │
│         │           ┌──────────────┐                                    │
│         │           │    Tool      │                                    │
│         │           │   Registry   │                                    │
│         │           └──────┬───────┘                                    │
│         │                  │                                            │
│         ▼                  ▼                                            │
│  ┌──────────────────────────────────────────────────────────────┐      │
│  │                      Tool Execution Layer                     │      │
│  ├──────────────────────────────────────────────────────────────┤      │
│  │                                                               │      │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │      │
│  │  │  Built-in   │  │    MCP      │  │   Plugin    │          │      │
│  │  │   Tools     │  │   Tools     │  │   Tools     │          │      │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘          │      │
│  │         │                │                │                   │      │
│  │         ▼                ▼                ▼                   │      │
│  │  ┌─────────────────────────────────────────────────────┐    │      │
│  │  │              Permission System                       │    │      │
│  │  │  ┌─────────┐  ┌─────────┐  ┌─────────┐             │    │      │
│  │  │  │  Allow  │  │   Ask   │  │  Deny   │             │    │      │
│  │  │  └─────────┘  └─────────┘  └─────────┘             │    │      │
│  │  └─────────────────────────────────────────────────────┘    │      │
│  │                                                               │      │
│  └──────────────────────────────────────────────────────────────┘      │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Tool Registry 구조

```typescript
// 개념적 구조
interface ToolRegistry {
  // 내장 도구
  builtinTools: Map<string, Tool>

  // MCP 도구
  mcpTools: Map<string, MCPTool>

  // 플러그인 도구
  pluginTools: Map<string, PluginTool>

  // 통합 조회
  get(name: string): Tool | undefined
  list(): Tool[]

  // 동적 등록
  register(tool: Tool): void
  unregister(name: string): void
}
```

### 1.3 도구 실행 파이프라인

```
Tool Call Request
       │
       ▼
┌──────────────┐
│  Validation  │ ─── 입력 스키마 검증
└──────┬───────┘
       │
       ▼
┌──────────────┐
│  Permission  │ ─── allow/ask/deny 결정
│    Check     │
└──────┬───────┘
       │
       ├─── Denied ──▶ [Error Response]
       │
       ├─── Ask ──▶ [User Confirmation] ──┐
       │                                   │
       ▼                                   │
┌──────────────┐◀──────────────────────────┘
│  Execution   │ ─── 실제 도구 실행
└──────┬───────┘
       │
       ▼
┌──────────────┐
│   Result     │ ─── 결과 포맷팅
│  Processing  │
└──────┬───────┘
       │
       ▼
[Tool Result]
```

---

## 2. MCP 프로토콜 상세

### 2.1 MCP 프로토콜 구조

```
┌─────────────────────────────────────────────────────────────────┐
│                    MCP Protocol Stack                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Application Layer                                               │
│  ┌────────────────────────────────────────────────────────┐    │
│  │  Tools  │  Resources  │  Prompts  │  Notifications     │    │
│  └────────────────────────────────────────────────────────┘    │
│                              │                                   │
│  Message Layer               │                                   │
│  ┌────────────────────────────────────────────────────────┐    │
│  │              JSON-RPC 2.0 Messages                      │    │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐             │    │
│  │  │ Request  │  │ Response │  │  Notify  │             │    │
│  │  └──────────┘  └──────────┘  └──────────┘             │    │
│  └────────────────────────────────────────────────────────┘    │
│                              │                                   │
│  Transport Layer             │                                   │
│  ┌────────────────────────────────────────────────────────┐    │
│  │    stdio    │    HTTP/SSE    │    WebSocket            │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 MCP 메시지 형식

#### Initialize Request
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "protocolVersion": "2024-11-05",
    "capabilities": {
      "tools": {},
      "resources": {},
      "prompts": {}
    },
    "clientInfo": {
      "name": "opencode",
      "version": "1.0.0"
    }
  }
}
```

#### List Tools Request
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/list",
  "params": {}
}
```

#### Call Tool Request
```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "tools/call",
  "params": {
    "name": "read_file",
    "arguments": {
      "path": "/path/to/file.txt"
    }
  }
}
```

### 2.3 Transport 유형별 특성

| Transport | 프로토콜 | 특성 | 사용 사례 |
|-----------|----------|------|----------|
| stdio | stdin/stdout | 로컬, 빠름, 단순 | 로컬 CLI 도구 |
| HTTP/SSE | HTTP + Server-Sent Events | 원격, 단방향 스트림 | 웹 서비스 |
| WebSocket | WS/WSS | 원격, 양방향, 실시간 | 실시간 서비스 |

### 2.4 MCP Client 구현

```typescript
// OpenCode MCP Client 핵심 구조 (개념적)
class MCPClient {
  private transport: Transport
  private tools: Map<string, MCPTool> = new Map()

  async connect() {
    await this.transport.connect()
    await this.initialize()
    await this.listTools()
  }

  async callTool(name: string, args: unknown) {
    const response = await this.transport.send({
      method: 'tools/call',
      params: { name, arguments: args }
    })
    return response.result
  }

  // 도구를 AI SDK Tool 형식으로 변환
  convertToAITool(mcpTool: MCPToolDef): Tool {
    return dynamicTool({
      description: mcpTool.description,
      inputSchema: jsonSchema(mcpTool.inputSchema),
      execute: (args) => this.callTool(mcpTool.name, args)
    })
  }
}
```

### 2.5 OAuth 인증 흐름

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│ OpenCode │     │   MCP    │     │  OAuth   │     │  User    │
│  Client  │     │  Server  │     │ Provider │     │ Browser  │
└────┬─────┘     └────┬─────┘     └────┬─────┘     └────┬─────┘
     │                │                │                │
     │ 1. Connect     │                │                │
     ├───────────────▶│                │                │
     │                │                │                │
     │ 2. 401 Unauth  │                │                │
     │◀───────────────┤                │                │
     │                │                │                │
     │ 3. Get Auth URL│                │                │
     ├───────────────▶│                │                │
     │                │                │                │
     │ 4. Auth URL    │                │                │
     │◀───────────────┤                │                │
     │                │                │                │
     │ 5. Open Browser│                │                │
     ├────────────────┼────────────────┼───────────────▶│
     │                │                │                │
     │                │ 6. Authorize   │                │
     │                │◀───────────────┼────────────────┤
     │                │                │                │
     │ 7. Callback    │                │                │
     │◀───────────────┼────────────────┤                │
     │                │                │                │
     │ 8. Exchange    │                │                │
     ├───────────────▶│───────────────▶│                │
     │                │                │                │
     │ 9. Tokens      │                │                │
     │◀───────────────┤◀───────────────┤                │
     │                │                │                │
     │ 10. Authed     │                │                │
     ├───────────────▶│                │                │
     │                │                │                │
```

---

## 3. Tool 시스템 내부 구조

### 3.1 Tool 정의 구조

```typescript
// AI SDK Tool 인터페이스
interface Tool<TParams = unknown, TResult = unknown> {
  // 메타데이터
  description: string

  // 입력 스키마 (JSON Schema)
  inputSchema: JSONSchema7

  // 실행 함수
  execute: (
    params: TParams,
    context: ToolContext
  ) => Promise<TResult>
}

// OpenCode Tool Context
interface ToolContext {
  sessionID: string
  messageID: string
  agent: Agent
  abort: AbortSignal

  // 권한 요청
  ask(request: PermissionRequest): Promise<void>

  // 메타데이터 업데이트
  metadata(update: ToolMetadata): void
}
```

### 3.2 내장 도구 구현 패턴

```typescript
// 내장 도구 정의 패턴 (개념적)
const ReadTool = Tool.define("read", async (ctx) => {
  return {
    description: "파일 내용을 읽습니다",
    parameters: z.object({
      file_path: z.string(),
      offset: z.number().optional(),
      limit: z.number().optional()
    }),

    async execute(params, ctx) {
      // 권한 확인
      await ctx.ask({
        permission: "read",
        patterns: [params.file_path]
      })

      // 파일 읽기
      const content = await Bun.file(params.file_path).text()

      // 결과 반환
      return {
        title: `Read ${params.file_path}`,
        output: content
      }
    }
  }
})
```

### 3.3 Tool 실행 상태 머신

```
┌─────────────────────────────────────────────────────────────────┐
│                    Tool Execution State Machine                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│    ┌────────┐                                                   │
│    │ IDLE   │◀─────────────────────────────────────┐           │
│    └───┬────┘                                       │           │
│        │ execute()                                  │           │
│        ▼                                            │           │
│    ┌────────┐                                       │           │
│    │PENDING │                                       │           │
│    └───┬────┘                                       │           │
│        │ permission check                           │           │
│        ├────────────────────┐                       │           │
│        │                    │                       │           │
│        ▼                    ▼                       │           │
│    ┌────────┐          ┌────────┐                  │           │
│    │WAITING │          │DENIED  │──────────────────┤           │
│    │ _USER  │          └────────┘                  │           │
│    └───┬────┘                                       │           │
│        │ user confirms                              │           │
│        ▼                                            │           │
│    ┌────────┐                                       │           │
│    │RUNNING │                                       │           │
│    └───┬────┘                                       │           │
│        │                                            │           │
│        ├─────────────┬──────────────┐              │           │
│        ▼             ▼              ▼              │           │
│    ┌────────┐   ┌────────┐    ┌────────┐          │           │
│    │COMPLETE│   │ ERROR  │    │ABORTED │──────────┘           │
│    └────────┘   └────────┘    └────────┘                       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 3.4 Tool 결과 포맷

```typescript
interface ToolResult {
  // 표시용 제목
  title?: string

  // 메인 출력 (LLM에 전달)
  output: string

  // 메타데이터 (UI 표시용)
  metadata?: Record<string, unknown>

  // 오류 정보
  error?: {
    code: string
    message: string
  }
}
```

---

## 4. 실행 흐름 분석

### 4.1 Agent → Tool 실행 흐름

```
┌─────────────────────────────────────────────────────────────────┐
│                     Complete Execution Flow                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. User Message                                                 │
│     │                                                            │
│     ▼                                                            │
│  2. Session.prompt()                                             │
│     │                                                            │
│     ▼                                                            │
│  3. Agent.getTools() ──────────────────────────────────────┐    │
│     │                                                       │    │
│     │  ┌─────────────────────────────────────────────────┐ │    │
│     │  │  Tool Registry                                  │ │    │
│     │  │  ├── Built-in Tools                             │ │    │
│     │  │  ├── MCP Tools (from MCP.tools())               │ │    │
│     │  │  └── Plugin Tools                               │ │    │
│     │  └─────────────────────────────────────────────────┘ │    │
│     │◀──────────────────────────────────────────────────────┘    │
│     ▼                                                            │
│  4. Provider.streamText() with tools                             │
│     │                                                            │
│     ▼                                                            │
│  5. LLM generates tool calls                                     │
│     │                                                            │
│     ├──▶ toolCall: { name: "read", arguments: {...} }           │
│     │                                                            │
│     ▼                                                            │
│  6. Tool.execute()                                               │
│     │                                                            │
│     ├── Permission.check() ──▶ allow/ask/deny                   │
│     │                                                            │
│     ├── Actual execution                                         │
│     │                                                            │
│     └── Return result                                            │
│                                                                  │
│     ▼                                                            │
│  7. toolResult fed back to LLM                                   │
│     │                                                            │
│     ▼                                                            │
│  8. Loop until LLM finishes or max steps                        │
│     │                                                            │
│     ▼                                                            │
│  9. Final Response                                               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 4.2 MCP Tool 통합 흐름

```
┌─────────────────────────────────────────────────────────────────┐
│                    MCP Tool Integration Flow                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  OpenCode Startup                                                │
│  │                                                               │
│  ├─▶ Config.get() ──▶ Load MCP configurations                   │
│  │                                                               │
│  ├─▶ MCP.state() ──▶ For each MCP config:                       │
│  │       │                                                       │
│  │       ├─▶ Create transport (stdio/HTTP/SSE)                  │
│  │       │                                                       │
│  │       ├─▶ Client.connect(transport)                          │
│  │       │                                                       │
│  │       ├─▶ client.listTools()                                 │
│  │       │                                                       │
│  │       └─▶ Store client in state                              │
│  │                                                               │
│  ▼                                                               │
│  During Session                                                  │
│  │                                                               │
│  ├─▶ MCP.tools() ──▶ For each connected client:                 │
│  │       │                                                       │
│  │       ├─▶ client.listTools()                                 │
│  │       │                                                       │
│  │       └─▶ convertMcpTool() ──▶ AI SDK Tool format            │
│  │                                                               │
│  ├─▶ Merge with built-in tools                                  │
│  │                                                               │
│  └─▶ Return combined tool set                                   │
│                                                                  │
│  Tool Execution                                                  │
│  │                                                               │
│  ├─▶ LLM calls MCP tool                                         │
│  │                                                               │
│  ├─▶ convertMcpTool.execute()                                   │
│  │       │                                                       │
│  │       └─▶ client.callTool(name, arguments)                   │
│  │               │                                               │
│  │               └─▶ JSON-RPC to MCP server                     │
│  │                                                               │
│  └─▶ Return result                                               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 4.3 Permission Check 상세 흐름

```
Permission Check Flow
│
├─▶ PermissionNext.evaluate(permission, pattern, ruleset)
│       │
│       ├─▶ Find matching rules in ruleset
│       │       │
│       │       └─▶ Match by pattern (glob matching)
│       │
│       ├─▶ Priority order:
│       │       1. Exact match
│       │       2. Glob match (more specific first)
│       │       3. Wildcard (*)
│       │       4. Default
│       │
│       └─▶ Return action: allow | ask | deny
│
├─── If "allow" ──▶ Proceed with execution
│
├─── If "deny" ──▶ Return error
│
└─── If "ask" ──▶ User confirmation UI
        │
        ├─▶ Display permission request
        │
        ├─▶ Wait for user response
        │       │
        │       ├─── "Allow" ──▶ Proceed
        │       │
        │       ├─── "Allow Always" ──▶ Update ruleset + Proceed
        │       │
        │       └─── "Deny" ──▶ Return error
        │
        └─▶ Continue execution
```

---

## 5. 성능 최적화

### 5.1 MCP 연결 최적화

```json
{
  "mcp": {
    "github": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-github"],
      "timeout": 30000,
      "enabled": true
    }
  },
  "experimental": {
    "mcp_timeout": 30000
  }
}
```

**최적화 전략:**
1. **Lazy Loading**: 필요할 때만 MCP 연결
2. **Connection Pooling**: 연결 재사용
3. **적절한 Timeout**: 네트워크 상태에 맞는 설정

### 5.2 Tool 실행 최적화

```typescript
// 병렬 실행 가능한 도구들
const parallelTools = ['glob', 'grep', 'read']

// 순차 실행 필요한 도구들
const sequentialTools = ['edit', 'bash']
```

**최적화 전략:**
1. **병렬 실행**: 독립적인 도구는 동시 실행
2. **캐싱**: 반복 요청에 대한 결과 캐싱
3. **Early Return**: 불필요한 작업 조기 종료

### 5.3 메모리 관리

```typescript
// 대용량 결과 처리
const MAX_OUTPUT_SIZE = 30000 // characters

function truncateOutput(output: string): string {
  if (output.length > MAX_OUTPUT_SIZE) {
    return output.slice(0, MAX_OUTPUT_SIZE) + '\n... [truncated]'
  }
  return output
}
```

---

## 6. 보안 고려사항

### 6.1 권한 시스템 설계 원칙

1. **최소 권한 원칙**: 필요한 권한만 부여
2. **명시적 거부**: 민감한 작업은 기본 거부
3. **패턴 기반 제어**: 세밀한 접근 제어

### 6.2 위험 도구 제어

```json
{
  "permission": {
    "bash": {
      "rm -rf *": "deny",
      "sudo *": "deny",
      "chmod 777 *": "deny",
      "> /dev/*": "deny",
      "curl * | bash": "deny",
      "*": "ask"
    },
    "edit": {
      "*.env": "deny",
      "*.pem": "deny",
      "*.key": "deny",
      "**/credentials*": "deny"
    }
  }
}
```

### 6.3 MCP 서버 보안

```json
{
  "mcp": {
    "untrusted-server": {
      "type": "remote",
      "url": "https://...",
      "oauth": {
        "clientId": "...",
        "scope": "read"
      },
      "timeout": 10000
    }
  }
}
```

**보안 체크리스트:**
- [ ] 신뢰할 수 있는 MCP 서버만 연결
- [ ] 최소 필요 권한의 OAuth scope
- [ ] 적절한 timeout 설정
- [ ] 네트워크 격리 (필요시)

### 6.4 입력 검증

```typescript
// 모든 도구 입력은 스키마로 검증
const parameters = z.object({
  file_path: z.string()
    .refine(path => !path.includes('..'), 'Path traversal not allowed')
    .refine(path => path.startsWith('/'), 'Absolute path required')
})
```

---

## 7. 확장 개발 가이드

### 7.1 Custom Tool Plugin

```typescript
// plugins/my-tools.ts
import { definePlugin } from "@opencode-ai/plugin"

export default definePlugin({
  name: "my-tools",

  tools: {
    "my-custom-tool": {
      description: "My custom tool",
      parameters: z.object({
        input: z.string()
      }),
      execute: async (params, ctx) => {
        // 구현
        return {
          output: `Processed: ${params.input}`
        }
      }
    }
  }
})
```

### 7.2 Custom MCP Server

```typescript
// mcp-server/index.ts
import { Server } from "@modelcontextprotocol/sdk/server/index.js"
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js"

const server = new Server({
  name: "my-mcp-server",
  version: "1.0.0"
}, {
  capabilities: {
    tools: {}
  }
})

// 도구 정의
server.setRequestHandler("tools/list", async () => ({
  tools: [{
    name: "my_tool",
    description: "My custom MCP tool",
    inputSchema: {
      type: "object",
      properties: {
        param: { type: "string" }
      }
    }
  }]
}))

// 도구 실행
server.setRequestHandler("tools/call", async (request) => {
  const { name, arguments: args } = request.params

  if (name === "my_tool") {
    return {
      content: [{
        type: "text",
        text: `Result: ${args.param}`
      }]
    }
  }
})

// 서버 시작
const transport = new StdioServerTransport()
await server.connect(transport)
```

### 7.3 등록 및 사용

```json
{
  "mcp": {
    "my-server": {
      "type": "local",
      "command": ["node", "./mcp-server/index.js"]
    }
  },
  "plugin": ["./plugins/my-tools.ts"]
}
```

---

## 8. 디버깅 및 문제 해결

### 8.1 로깅 활성화

```bash
# 환경 변수
OPENCODE_LOG_LEVEL=debug opencode

# 또는 설정 파일
{
  "logLevel": "debug"
}
```

### 8.2 MCP 디버깅

```bash
# MCP 상태 확인
opencode mcp status

# 개별 MCP 연결 테스트
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05"}}' | \
  npx -y @modelcontextprotocol/server-github
```

### 8.3 일반적인 문제

| 문제 | 원인 | 해결 |
|------|------|------|
| MCP 연결 실패 | 명령어 오류 | command 배열 확인 |
| Tool not found | 등록 안됨 | plugin/MCP 설정 확인 |
| Permission denied | 권한 설정 | permission 규칙 확인 |
| Timeout | 서버 느림 | timeout 증가 |
| Schema error | 입력 불일치 | 파라미터 형식 확인 |

### 8.4 성능 프로파일링

```bash
# Node.js 프로파일러
node --inspect opencode

# 메모리 사용량
node --expose-gc opencode
```
