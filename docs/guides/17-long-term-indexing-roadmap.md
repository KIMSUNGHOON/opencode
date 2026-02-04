# Long-term Indexing & Plugin Extension Roadmap

이 문서는 대규모 코드베이스 인덱싱을 위한 장기 구현 계획과 opencode 플러그인 확장 방법을 설명합니다.

---

## 1. 현재 상황 및 한계

### 1.1 현재 워크스페이스 분석 방식

```
현재: JSON 파일 기반 캐시
┌─────────────────────────────────────────────────────────────────────────┐
│ .opencode/workspace-cache/analysis.json                                  │
├─────────────────────────────────────────────────────────────────────────┤
│ - 프로젝트 구조                                                           │
│ - 파일 목록 (by_type)                                                    │
│ - 의존성 정보                                                             │
│ - 빌드 시스템 정보                                                        │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.2 현재 방식의 한계

| 한계점 | 영향 | 임계점 |
|--------|------|--------|
| **JSON 파일 크기** | 메모리 사용량 증가, 파싱 시간 | 10,000+ 파일 |
| **전체 스캔 필요** | 분석 시간 증가 | 대규모 모노레포 |
| **시맨틱 검색 불가** | 관련 코드 찾기 어려움 | 복잡한 코드베이스 |
| **증분 업데이트 없음** | 매번 전체 재분석 | 빈번한 변경 |

---

## 2. 장기 구현 계획

### 2.1 Phase 1: SQLite FTS5 인덱싱 (권장)

**목표**: 빠른 전문 검색 및 증분 업데이트

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     SQLite FTS5 Architecture                             │
└─────────────────────────────────────────────────────────────────────────┘

.opencode/workspace-cache/
├── analysis.json        # 기본 메타데이터 (현재)
└── index.db             # SQLite 인덱스 (추가)
    ├── files            # 파일 메타데이터
    ├── symbols          # 함수/클래스/변수 심볼
    ├── content_fts      # FTS5 전문 검색 인덱스
    └── file_hashes      # 증분 업데이트용 해시
```

**스키마 설계**:

```sql
-- 파일 메타데이터
CREATE TABLE files (
    id INTEGER PRIMARY KEY,
    path TEXT UNIQUE NOT NULL,
    type TEXT,              -- typescript, python, go, etc.
    size INTEGER,
    mtime INTEGER,
    hash TEXT,              -- 내용 해시 (증분 업데이트용)
    analyzed_at INTEGER
);

-- 심볼 테이블 (함수, 클래스, 변수)
CREATE TABLE symbols (
    id INTEGER PRIMARY KEY,
    file_id INTEGER REFERENCES files(id),
    name TEXT NOT NULL,
    kind TEXT,              -- function, class, variable, interface
    line_start INTEGER,
    line_end INTEGER,
    signature TEXT,         -- 함수 시그니처
    parent_id INTEGER       -- 중첩 심볼용
);

-- FTS5 전문 검색 인덱스
CREATE VIRTUAL TABLE content_fts USING fts5(
    path,
    content,
    symbols,
    tokenize='porter unicode61'
);

-- 인덱스
CREATE INDEX idx_symbols_name ON symbols(name);
CREATE INDEX idx_symbols_kind ON symbols(kind);
CREATE INDEX idx_files_type ON files(type);
```

**장점**:
- 빠른 전문 검색 (FTS5)
- 증분 업데이트 (hash 비교)
- 낮은 의존성 (SQLite 내장)
- 쿼리 가능한 구조

**구현 방법** (opencode 플러그인):

```typescript
// .opencode/plugin/sqlite-indexer.ts
import type { Hooks } from "@opencode-ai/plugin"
import Database from 'better-sqlite3'

export default async (input): Promise<Hooks> => ({
  tool: {
    "index-search": {
      description: "Search codebase using SQLite FTS5 index",
      args: {
        query: z.string().describe("Search query"),
        type: z.string().optional().describe("File type filter"),
        limit: z.number().default(20)
      },
      async execute(args, ctx) {
        const db = new Database('.opencode/workspace-cache/index.db')
        const results = db.prepare(`
          SELECT path, snippet(content_fts, 1, '>>>', '<<<', '...', 32) as snippet
          FROM content_fts
          WHERE content_fts MATCH ?
          ORDER BY rank
          LIMIT ?
        `).all(args.query, args.limit)
        return JSON.stringify(results, null, 2)
      }
    },

    "index-symbols": {
      description: "Find symbols (functions, classes) by name",
      args: {
        name: z.string().describe("Symbol name pattern"),
        kind: z.enum(["function", "class", "interface", "variable"]).optional()
      },
      async execute(args, ctx) {
        const db = new Database('.opencode/workspace-cache/index.db')
        let query = `SELECT s.*, f.path FROM symbols s JOIN files f ON s.file_id = f.id WHERE s.name LIKE ?`
        if (args.kind) query += ` AND s.kind = '${args.kind}'`
        return JSON.stringify(db.prepare(query).all(`%${args.name}%`), null, 2)
      }
    }
  }
})
```

### 2.2 Phase 2: Vector Database 통합

**목표**: 시맨틱 검색, 유사 코드 찾기

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     Vector DB Architecture                               │
└─────────────────────────────────────────────────────────────────────────┘

                    ┌─────────────────┐
                    │  Embedding      │
                    │  Model          │
                    │  (local/API)    │
                    └────────┬────────┘
                             │
    Source Code ─────────────┼─────────────▶ Vector DB
                             │                  │
                    ┌────────▼────────┐         │
                    │  Code Chunks    │         │
                    │  - Functions    │         │
                    │  - Classes      │         │
                    │  - Docstrings   │         │
                    └─────────────────┘         │
                                                │
    Query ──────────────────────────────────────┼──▶ Similar Code
                                                │
                                                ▼
                                          Ranked Results
```

**옵션 1: ChromaDB (로컬, 경량)**

```typescript
// .opencode/plugin/chroma-indexer.ts
import { ChromaClient } from 'chromadb'

export default async (input): Promise<Hooks> => ({
  tool: {
    "semantic-search": {
      description: "Find semantically similar code",
      args: {
        query: z.string(),
        n_results: z.number().default(10)
      },
      async execute(args, ctx) {
        const client = new ChromaClient({ path: ".opencode/workspace-cache/chroma" })
        const collection = await client.getCollection({ name: "codebase" })
        const results = await collection.query({
          queryTexts: [args.query],
          nResults: args.n_results
        })
        return JSON.stringify(results, null, 2)
      }
    }
  }
})
```

**옵션 2: MCP Server로 외부 Vector DB 연동**

```json
// opencode.json
{
  "mcp": {
    "vector-index": {
      "type": "remote",
      "url": "http://localhost:8080/mcp",
      "headers": {
        "Authorization": "Bearer {env:VECTOR_DB_TOKEN}"
      }
    }
  }
}
```

### 2.3 Phase 3: AST 기반 인덱싱

**목표**: 정확한 심볼 추출, 코드 구조 분석

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     AST-based Indexing                                   │
└─────────────────────────────────────────────────────────────────────────┘

    Source Code
         │
         ▼
    ┌─────────────┐
    │ Tree-sitter │  (opencode에 이미 포함됨)
    │   Parser    │
    └──────┬──────┘
           │
           ▼
    ┌─────────────┐
    │    AST      │
    │   Nodes     │
    └──────┬──────┘
           │
    ┌──────┴──────┬──────────────┐
    ▼             ▼              ▼
┌───────┐   ┌─────────┐   ┌──────────┐
│Functions│ │Classes   │  │Imports   │
│        │ │Interfaces│  │Exports   │
└───────┘  └─────────┘   └──────────┘
    │             │              │
    └─────────────┴──────────────┘
                  │
                  ▼
           SQLite Index
```

**tree-sitter 활용** (opencode 내장):

```typescript
// web-tree-sitter는 opencode 의존성에 포함됨
import Parser from 'web-tree-sitter'

async function extractSymbols(code: string, language: string) {
  await Parser.init()
  const parser = new Parser()
  const Lang = await Parser.Language.load(`tree-sitter-${language}.wasm`)
  parser.setLanguage(Lang)

  const tree = parser.parse(code)
  const symbols = []

  // 함수 추출
  const functionQuery = Lang.query(`(function_declaration name: (identifier) @name)`)
  const matches = functionQuery.matches(tree.rootNode)

  for (const match of matches) {
    symbols.push({
      name: match.captures[0].node.text,
      kind: 'function',
      line: match.captures[0].node.startPosition.row
    })
  }

  return symbols
}
```

---

## 3. opencode 확장 메커니즘

### 3.1 확장 방법 요약

| 확장 방법 | 용도 | 복잡도 | 추천 |
|-----------|------|--------|------|
| **Custom Tool (파일)** | 단순 도구 추가 | 낮음 | ✅ 시작점 |
| **Plugin** | 훅 기반 확장 | 중간 | ✅ 권장 |
| **MCP Server** | 외부 서비스 연동 | 높음 | 대규모 시스템 |
| **Custom Command** | 사용자 명령 | 낮음 | 워크플로우 |

### 3.2 Custom Tool 추가 (가장 간단)

```
.opencode/
└── tool/
    └── my-indexer.ts
```

```typescript
// .opencode/tool/my-indexer.ts
import { tool } from "@opencode-ai/plugin"
import { z } from "zod"

export default tool({
  description: "Custom indexing tool",
  args: {
    action: z.enum(["index", "search", "update"]),
    query: z.string().optional()
  },
  async execute(args, context) {
    switch (args.action) {
      case "index":
        // 인덱싱 로직
        return "Indexing complete"
      case "search":
        // 검색 로직
        return `Results for: ${args.query}`
      case "update":
        // 증분 업데이트 로직
        return "Index updated"
    }
  }
})
```

### 3.3 Plugin 개발

```
my-opencode-plugin/
├── package.json
├── tsconfig.json
└── src/
    └── index.ts
```

```typescript
// src/index.ts
import type { Plugin, Hooks, PluginInput } from "@opencode-ai/plugin"
import { z } from "zod"

const plugin: Plugin = async (input: PluginInput): Promise<Hooks> => {
  // 초기화 로직
  console.log("Plugin loaded for project:", input.project.root)

  return {
    // 이벤트 훅
    event: async ({ event }) => {
      if (event.type === "session.created") {
        console.log("New session started")
      }
    },

    // 도구 정의
    tool: {
      "index-codebase": {
        description: "Index the codebase for fast searching",
        args: { force: z.boolean().default(false) },
        execute: async (args, ctx) => {
          // 인덱싱 구현
          return "Codebase indexed successfully"
        }
      }
    },

    // 권한 훅
    "permission.ask": async (input, output) => {
      // 특정 패턴은 자동 허용
      if (input.tool === "index-codebase") {
        output.status = "allow"
      }
    }
  }
}

export default plugin
```

**설정**:
```json
// opencode.json
{
  "plugin": [
    "file:///path/to/my-opencode-plugin"
  ]
}
```

### 3.4 MCP Server 개발

외부 인덱싱 서비스를 MCP 서버로 구현:

```typescript
// mcp-index-server/index.ts
import { Server } from "@modelcontextprotocol/sdk/server"
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio"

const server = new Server({
  name: "codebase-indexer",
  version: "1.0.0"
}, {
  capabilities: {
    tools: {}
  }
})

// 도구 정의
server.setRequestHandler("tools/list", async () => ({
  tools: [
    {
      name: "semantic_search",
      description: "Search codebase using vector embeddings",
      inputSchema: {
        type: "object",
        properties: {
          query: { type: "string" },
          limit: { type: "number", default: 10 }
        },
        required: ["query"]
      }
    }
  ]
}))

// 도구 실행
server.setRequestHandler("tools/call", async (request) => {
  if (request.params.name === "semantic_search") {
    // Vector DB 검색 로직
    const results = await searchVectorDB(request.params.arguments.query)
    return { content: [{ type: "text", text: JSON.stringify(results) }] }
  }
})

// 서버 시작
const transport = new StdioServerTransport()
server.connect(transport)
```

**opencode 설정**:
```json
{
  "mcp": {
    "codebase-indexer": {
      "type": "local",
      "command": ["node", "/path/to/mcp-index-server/index.js"],
      "enabled": true
    }
  }
}
```

---

## 4. 구현 우선순위

### 4.1 단기 (1-2주)

1. **SQLite FTS5 기반 인덱서 플러그인**
   - 파일 메타데이터 저장
   - 전문 검색 지원
   - 증분 업데이트

2. **workspace-analyzer 개선**
   - SQLite 인덱스 생성 옵션
   - 대규모 프로젝트 최적화

### 4.2 중기 (1-2개월)

1. **AST 기반 심볼 추출**
   - tree-sitter 활용
   - 함수/클래스/인터페이스 인덱싱

2. **증분 인덱싱**
   - 파일 해시 기반 변경 감지
   - Git hooks 통합

### 4.3 장기 (3-6개월)

1. **Vector DB 통합**
   - 시맨틱 검색
   - 유사 코드 찾기

2. **MCP 인덱싱 서버**
   - 외부 서비스로 분리
   - 다중 프로젝트 지원

---

## 5. 권장 구현 경로

```
현재 상태
    │
    ▼
Phase 1: SQLite FTS5 (Custom Tool)
    │   - .opencode/tool/sqlite-indexer.ts
    │   - 전문 검색 + 증분 업데이트
    │
    ▼
Phase 2: AST 심볼 추출 (Plugin)
    │   - tree-sitter 파싱
    │   - 심볼 테이블 구축
    │
    ▼
Phase 3: Vector 검색 (MCP Server)
    │   - ChromaDB 또는 외부 서비스
    │   - 시맨틱 검색
    │
    ▼
최종: 통합 인덱싱 시스템
```

---

## 6. 참고 자료

### opencode 확장 관련 파일

| 파일 | 역할 |
|------|------|
| `packages/opencode/src/mcp/index.ts` | MCP 서버 통합 |
| `packages/opencode/src/tool/registry.ts` | 도구 레지스트리 |
| `packages/opencode/src/plugin/index.ts` | 플러그인 로딩 |
| `packages/plugin/src/index.ts` | 플러그인 인터페이스 정의 |
| `packages/plugin/src/tool.ts` | 도구 정의 헬퍼 |

### 외부 라이브러리

| 라이브러리 | 용도 | 설치 |
|-----------|------|------|
| better-sqlite3 | SQLite 바인딩 | `npm install better-sqlite3` |
| chromadb | Vector DB | `npm install chromadb` |
| @modelcontextprotocol/sdk | MCP 서버 SDK | `npm install @modelcontextprotocol/sdk` |

---

## 변경 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|----------|
| 1.0 | 2024-01-15 | 초기 로드맵 문서 |
