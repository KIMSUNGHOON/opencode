# MCP and Tool Deep Analysis Guide

## Overview

This document provides an in-depth analysis of the internal workings, architecture, and extension methods of OpenCode's MCP (Model Context Protocol) and Tool system.

---

## Table of Contents

1. [Architecture Deep Analysis](#1-architecture-deep-analysis)
2. [MCP Protocol Details](#2-mcp-protocol-details)
3. [Tool System Internal Structure](#3-tool-system-internal-structure)
4. [Execution Flow Analysis](#4-execution-flow-analysis)
5. [Performance Optimization](#5-performance-optimization)
6. [Security Considerations](#6-security-considerations)
7. [Extension Development Guide](#7-extension-development-guide)
8. [Debugging and Troubleshooting](#8-debugging-and-troubleshooting)

---

## 1. Architecture Deep Analysis

### 1.1 Overall System Architecture

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

### 1.2 Tool Registry Structure

```typescript
// Conceptual structure
interface ToolRegistry {
  // Built-in tools
  builtinTools: Map<string, Tool>

  // MCP tools
  mcpTools: Map<string, MCPTool>

  // Plugin tools
  pluginTools: Map<string, PluginTool>

  // Unified lookup
  get(name: string): Tool | undefined
  list(): Tool[]

  // Dynamic registration
  register(tool: Tool): void
  unregister(name: string): void
}
```

### 1.3 Tool Execution Pipeline

```
Tool Call Request
       │
       ▼
┌──────────────┐
│  Validation  │ ─── Input schema validation
└──────┬───────┘
       │
       ▼
┌──────────────┐
│  Permission  │ ─── allow/ask/deny decision
│    Check     │
└──────┬───────┘
       │
       ├─── Denied ──▶ [Error Response]
       │
       ├─── Ask ──▶ [User Confirmation] ──┐
       │                                   │
       ▼                                   │
┌──────────────┐◀──────────────────────────┘
│  Execution   │ ─── Actual tool execution
└──────┬───────┘
       │
       ▼
┌──────────────┐
│   Result     │ ─── Result formatting
│  Processing  │
└──────┬───────┘
       │
       ▼
[Tool Result]
```

---

## 2. MCP Protocol Details

### 2.1 MCP Protocol Structure

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

### 2.2 MCP Message Format

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

### 2.3 Transport Type Characteristics

| Transport | Protocol | Characteristics | Use Cases |
|-----------|----------|-----------------|-----------|
| stdio | stdin/stdout | Local, fast, simple | Local CLI tools |
| HTTP/SSE | HTTP + Server-Sent Events | Remote, unidirectional stream | Web services |
| WebSocket | WS/WSS | Remote, bidirectional, real-time | Real-time services |

### 2.4 MCP Client Implementation

```typescript
// OpenCode MCP Client core structure (conceptual)
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

  // Convert tools to AI SDK Tool format
  convertToAITool(mcpTool: MCPToolDef): Tool {
    return dynamicTool({
      description: mcpTool.description,
      inputSchema: jsonSchema(mcpTool.inputSchema),
      execute: (args) => this.callTool(mcpTool.name, args)
    })
  }
}
```

### 2.5 OAuth Authentication Flow

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

## 3. Tool System Internal Structure

### 3.1 Tool Definition Structure

```typescript
// AI SDK Tool interface
interface Tool<TParams = unknown, TResult = unknown> {
  // Metadata
  description: string

  // Input schema (JSON Schema)
  inputSchema: JSONSchema7

  // Execution function
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

  // Permission request
  ask(request: PermissionRequest): Promise<void>

  // Metadata update
  metadata(update: ToolMetadata): void
}
```

### 3.2 Built-in Tool Implementation Pattern

```typescript
// Built-in tool definition pattern (conceptual)
const ReadTool = Tool.define("read", async (ctx) => {
  return {
    description: "Reads file contents",
    parameters: z.object({
      file_path: z.string(),
      offset: z.number().optional(),
      limit: z.number().optional()
    }),

    async execute(params, ctx) {
      // Permission check
      await ctx.ask({
        permission: "read",
        patterns: [params.file_path]
      })

      // Read file
      const content = await Bun.file(params.file_path).text()

      // Return result
      return {
        title: `Read ${params.file_path}`,
        output: content
      }
    }
  }
})
```

### 3.3 Tool Execution State Machine

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

### 3.4 Tool Result Format

```typescript
interface ToolResult {
  // Display title
  title?: string

  // Main output (passed to LLM)
  output: string

  // Metadata (for UI display)
  metadata?: Record<string, unknown>

  // Error information
  error?: {
    code: string
    message: string
  }
}
```

---

## 4. Execution Flow Analysis

### 4.1 Agent to Tool Execution Flow

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

### 4.2 MCP Tool Integration Flow

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

### 4.3 Permission Check Detailed Flow

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

## 5. Performance Optimization

### 5.1 MCP Connection Optimization

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

**Optimization Strategies:**
1. **Lazy Loading**: Connect to MCP only when needed
2. **Connection Pooling**: Reuse connections
3. **Appropriate Timeout**: Configure based on network conditions

### 5.2 Tool Execution Optimization

```typescript
// Tools that can be executed in parallel
const parallelTools = ['glob', 'grep', 'read']

// Tools that require sequential execution
const sequentialTools = ['edit', 'bash']
```

**Optimization Strategies:**
1. **Parallel Execution**: Run independent tools concurrently
2. **Caching**: Cache results for repeated requests
3. **Early Return**: Terminate unnecessary work early

### 5.3 Memory Management

```typescript
// Large result handling
const MAX_OUTPUT_SIZE = 30000 // characters

function truncateOutput(output: string): string {
  if (output.length > MAX_OUTPUT_SIZE) {
    return output.slice(0, MAX_OUTPUT_SIZE) + '\n... [truncated]'
  }
  return output
}
```

---

## 6. Security Considerations

### 6.1 Permission System Design Principles

1. **Principle of Least Privilege**: Grant only necessary permissions
2. **Explicit Deny**: Deny sensitive operations by default
3. **Pattern-based Control**: Fine-grained access control

### 6.2 Dangerous Tool Control

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

### 6.3 MCP Server Security

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

**Security Checklist:**
- [ ] Connect only to trusted MCP servers
- [ ] Use minimum required OAuth scope
- [ ] Set appropriate timeout values
- [ ] Network isolation (when necessary)

### 6.4 Input Validation

```typescript
// All tool inputs are validated against a schema
const parameters = z.object({
  file_path: z.string()
    .refine(path => !path.includes('..'), 'Path traversal not allowed')
    .refine(path => path.startsWith('/'), 'Absolute path required')
})
```

---

## 7. Extension Development Guide

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
        // Implementation
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

// Tool definition
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

// Tool execution
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

// Start server
const transport = new StdioServerTransport()
await server.connect(transport)
```

### 7.3 Registration and Usage

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

## 8. Debugging and Troubleshooting

### 8.1 Enabling Logging

```bash
# Environment variable
OPENCODE_LOG_LEVEL=debug opencode

# Or configuration file
{
  "logLevel": "debug"
}
```

### 8.2 MCP Debugging

```bash
# Check MCP status
opencode mcp status

# Test individual MCP connection
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05"}}' | \
  npx -y @modelcontextprotocol/server-github
```

### 8.3 Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| MCP connection failure | Command error | Check the command array |
| Tool not found | Not registered | Check plugin/MCP configuration |
| Permission denied | Permission settings | Check permission rules |
| Timeout | Slow server | Increase timeout |
| Schema error | Input mismatch | Check parameter format |

### 8.4 Performance Profiling

```bash
# Node.js profiler
node --inspect opencode

# Memory usage
node --expose-gc opencode
```
