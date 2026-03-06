# Long-term Indexing & Plugin Extension Roadmap

This document describes the long-term implementation plan for large-scale codebase indexing and how to extend opencode through plugins.

---

## 1. Current State and Limitations

### 1.1 Current Workspace Analysis Method

```
Current: JSON file-based cache
┌─────────────────────────────────────────────────────────────────────────┐
│ .opencode/workspace-cache/analysis.json                                  │
├─────────────────────────────────────────────────────────────────────────┤
│ - Project structure                                                       │
│ - File list (by_type)                                                    │
│ - Dependency information                                                  │
│ - Build system information                                                │
└─────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Limitations of the Current Approach

| Limitation | Impact | Threshold |
|------------|--------|-----------|
| **JSON file size** | Increased memory usage, parsing time | 10,000+ files |
| **Full scan required** | Increased analysis time | Large monorepos |
| **No semantic search** | Difficulty finding related code | Complex codebases |
| **No incremental updates** | Full re-analysis every time | Frequent changes |

---

## 2. Long-term Implementation Plan

### 2.1 Phase 1: SQLite FTS5 Indexing (Recommended)

**Goal**: Fast full-text search and incremental updates

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     SQLite FTS5 Architecture                             │
└─────────────────────────────────────────────────────────────────────────┘

.opencode/workspace-cache/
├── analysis.json        # Basic metadata (current)
└── index.db             # SQLite index (new)
    ├── files            # File metadata
    ├── symbols          # Function/class/variable symbols
    ├── content_fts      # FTS5 full-text search index
    └── file_hashes      # Hashes for incremental updates
```

**Schema Design**:

```sql
-- File metadata
CREATE TABLE files (
    id INTEGER PRIMARY KEY,
    path TEXT UNIQUE NOT NULL,
    type TEXT,              -- typescript, python, go, etc.
    size INTEGER,
    mtime INTEGER,
    hash TEXT,              -- Content hash (for incremental updates)
    analyzed_at INTEGER
);

-- Symbol table (functions, classes, variables)
CREATE TABLE symbols (
    id INTEGER PRIMARY KEY,
    file_id INTEGER REFERENCES files(id),
    name TEXT NOT NULL,
    kind TEXT,              -- function, class, variable, interface
    line_start INTEGER,
    line_end INTEGER,
    signature TEXT,         -- Function signature
    parent_id INTEGER       -- For nested symbols
);

-- FTS5 full-text search index
CREATE VIRTUAL TABLE content_fts USING fts5(
    path,
    content,
    symbols,
    tokenize='porter unicode61'
);

-- Indexes
CREATE INDEX idx_symbols_name ON symbols(name);
CREATE INDEX idx_symbols_kind ON symbols(kind);
CREATE INDEX idx_files_type ON files(type);
```

**Advantages**:
- Fast full-text search (FTS5)
- Incremental updates (hash comparison)
- Low dependencies (SQLite built-in)
- Queryable structure

**Implementation Method** (opencode plugin):

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

### 2.2 Phase 2: Vector Database Integration

**Goal**: Semantic search, finding similar code

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

**Option 1: ChromaDB (local, lightweight)**

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

**Option 2: External Vector DB via MCP Server**

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

### 2.3 Phase 3: AST-based Indexing

**Goal**: Accurate symbol extraction, code structure analysis

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     AST-based Indexing                                   │
└─────────────────────────────────────────────────────────────────────────┘

    Source Code
         │
         ▼
    ┌─────────────┐
    │ Tree-sitter │  (already included in opencode)
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

**Using tree-sitter** (built into opencode):

```typescript
// web-tree-sitter is included in opencode dependencies
import Parser from 'web-tree-sitter'

async function extractSymbols(code: string, language: string) {
  await Parser.init()
  const parser = new Parser()
  const Lang = await Parser.Language.load(`tree-sitter-${language}.wasm`)
  parser.setLanguage(Lang)

  const tree = parser.parse(code)
  const symbols = []

  // Extract functions
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

## 3. opencode Extension Mechanisms

### 3.1 Extension Methods Summary

| Extension Method | Use Case | Complexity | Recommendation |
|------------------|----------|------------|----------------|
| **Custom Tool (file)** | Simple tool addition | Low | Starting point |
| **Plugin** | Hook-based extension | Medium | Recommended |
| **MCP Server** | External service integration | High | Large-scale systems |
| **Custom Command** | User commands | Low | Workflows |

### 3.2 Adding a Custom Tool (Simplest)

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
        // Indexing logic
        return "Indexing complete"
      case "search":
        // Search logic
        return `Results for: ${args.query}`
      case "update":
        // Incremental update logic
        return "Index updated"
    }
  }
})
```

### 3.3 Plugin Development

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
  // Initialization logic
  console.log("Plugin loaded for project:", input.project.root)

  return {
    // Event hooks
    event: async ({ event }) => {
      if (event.type === "session.created") {
        console.log("New session started")
      }
    },

    // Tool definitions
    tool: {
      "index-codebase": {
        description: "Index the codebase for fast searching",
        args: { force: z.boolean().default(false) },
        execute: async (args, ctx) => {
          // Indexing implementation
          return "Codebase indexed successfully"
        }
      }
    },

    // Permission hooks
    "permission.ask": async (input, output) => {
      // Auto-allow specific patterns
      if (input.tool === "index-codebase") {
        output.status = "allow"
      }
    }
  }
}

export default plugin
```

**Configuration**:
```json
// opencode.json
{
  "plugin": [
    "file:///path/to/my-opencode-plugin"
  ]
}
```

### 3.4 MCP Server Development

Implement an external indexing service as an MCP server:

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

// Tool definition
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

// Tool execution
server.setRequestHandler("tools/call", async (request) => {
  if (request.params.name === "semantic_search") {
    // Vector DB search logic
    const results = await searchVectorDB(request.params.arguments.query)
    return { content: [{ type: "text", text: JSON.stringify(results) }] }
  }
})

// Start server
const transport = new StdioServerTransport()
server.connect(transport)
```

**opencode Configuration**:
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

## 4. Implementation Priorities

### 4.1 Short-term (1-2 weeks)

1. **SQLite FTS5-based Indexer Plugin**
   - File metadata storage
   - Full-text search support
   - Incremental updates

2. **workspace-analyzer Improvements**
   - SQLite index generation option
   - Large project optimization

### 4.2 Mid-term (1-2 months)

1. **AST-based Symbol Extraction**
   - Using tree-sitter
   - Function/class/interface indexing

2. **Incremental Indexing**
   - File hash-based change detection
   - Git hooks integration

### 4.3 Long-term (3-6 months)

1. **Vector DB Integration**
   - Semantic search
   - Finding similar code

2. **MCP Indexing Server**
   - Separation into an external service
   - Multi-project support

---

## 5. Recommended Implementation Path

```
Current State
    │
    ▼
Phase 1: SQLite FTS5 (Custom Tool)
    │   - .opencode/tool/sqlite-indexer.ts
    │   - Full-text search + incremental updates
    │
    ▼
Phase 2: AST Symbol Extraction (Plugin)
    │   - tree-sitter parsing
    │   - Symbol table construction
    │
    ▼
Phase 3: Vector Search (MCP Server)
    │   - ChromaDB or external service
    │   - Semantic search
    │
    ▼
Final: Integrated Indexing System
```

---

## 6. References

### opencode Extension-related Files

| File | Role |
|------|------|
| `packages/opencode/src/mcp/index.ts` | MCP server integration |
| `packages/opencode/src/tool/registry.ts` | Tool registry |
| `packages/opencode/src/plugin/index.ts` | Plugin loading |
| `packages/plugin/src/index.ts` | Plugin interface definition |
| `packages/plugin/src/tool.ts` | Tool definition helper |

### External Libraries

| Library | Purpose | Installation |
|---------|---------|-------------|
| better-sqlite3 | SQLite bindings | `npm install better-sqlite3` |
| chromadb | Vector DB | `npm install chromadb` |
| @modelcontextprotocol/sdk | MCP server SDK | `npm install @modelcontextprotocol/sdk` |

---

## Change History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2024-01-15 | Initial roadmap document |
