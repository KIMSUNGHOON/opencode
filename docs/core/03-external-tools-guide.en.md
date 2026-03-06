# External Tools Usage Guide

## Overview

OpenCode provides various built-in tools and external tools through MCP. This guide explains in detail the purpose, usage, and configuration methods of each tool.

---

## Table of Contents

1. [Tool System Overview](#1-tool-system-overview)
2. [Built-in Tools](#2-built-in-tools)
3. [MCP Extension Tools](#3-mcp-extension-tools)
4. [Custom Command](#4-custom-command)
5. [Permission Management](#5-permission-management)
6. [Practical Usage](#6-practical-usage)

---

## 1. Tool System Overview

### Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                      OpenCode Tool System                       │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    Built-in Tools                        │   │
│  ├─────────────────────────────────────────────────────────┤   │
│  │  File      │  Search    │  Execution │  Web      │ Task │   │
│  │  ─────     │  ──────    │  ─────────  │  ───      │ ──── │   │
│  │  read      │  glob      │  bash      │  webfetch │ task │   │
│  │  edit      │  grep      │            │  websearch│      │   │
│  │  list      │  codesearch│            │           │      │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                  │
│                              ▼                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    MCP Tools                             │   │
│  ├─────────────────────────────────────────────────────────┤   │
│  │  filesystem_*  │  github_*  │  postgres_*  │  custom_*  │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

### Tool Invocation Flow

```
User Request
     │
     ▼
┌─────────────┐
│   Agent     │
└──────┬──────┘
       │
       ▼
┌─────────────┐     ┌─────────────┐
│  Permission │────▶│   Denied    │
│    Check    │     └─────────────┘
└──────┬──────┘
       │ Allowed/Ask
       ▼
┌─────────────┐
│    Tool     │
│  Execution  │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Result    │
└─────────────┘
```

---

## 2. Built-in Tools

### 2.1 File Tools

#### read - Read File

Reads and returns file contents.

**Features:**
- Read text files
- Visual analysis of image files
- Read PDF files
- Read Jupyter Notebooks

**Example:**
```
Please read the contents of src/index.ts.
```

**Permission Settings:**
```yaml
permission:
  read:
    "*": allow
    "*.env": ask
    "*.env.*": ask
    ".git/**": deny
```

#### edit - Edit File

Modifies specific parts of a file.

**Features:**
- String replacement
- Full replacement (replace_all)
- Exact matching required

**Example:**
```
Replace console.log with logger.info in index.ts.
```

**Permission Settings:**
```yaml
permission:
  edit:
    "src/**/*.ts": allow
    "config/*": ask
    "package.json": ask
    "*": deny
```

#### list - Directory Listing

Returns the file/folder list of a directory.

**Example:**
```
Show the structure of the src directory.
```

---

### 2.2 Search Tools

#### glob - File Pattern Search

Finds files by file path patterns.

**Pattern Syntax:**
| Pattern | Description | Example |
|---------|-------------|---------|
| `*` | Single level wildcard | `*.ts` |
| `**` | Recursive wildcard | `src/**/*.ts` |
| `?` | Single character | `file?.txt` |
| `{a,b}` | Alternatives | `*.{ts,js}` |
| `[abc]` | Character class | `file[123].txt` |

**Example:**
```
Find all TypeScript files in the src folder.
→ glob: src/**/*.ts
```

#### grep - Text Search

Searches for text within file contents.

**Features:**
- Regular expression support
- File type filter
- Context line display

**Example:**
```
Find all locations where the "fetchUser" function is used.
→ grep: fetchUser
```

**Output Modes:**
| Mode | Description |
|------|-------------|
| `files_with_matches` | File paths only (default) |
| `content` | Including matched lines |
| `count` | Match count |

#### codesearch - Code Search

Structure-based code search (symbols, definitions, references).

**Example:**
```
Find the definition of the UserService class.
```

---

### 2.3 Execution Tools

#### bash - Shell Command Execution

Executes shell commands.

**Features:**
- Command execution
- Timeout settings (default 2 minutes, max 10 minutes)
- Background execution

**Example:**
```
Please run npm install.
```

**Safety Settings:**
```yaml
permission:
  bash:
    "npm *": allow
    "bun *": allow
    "git status": allow
    "git log *": allow
    "rm -rf *": deny
    "sudo *": deny
    "*": ask
```

**Notes:**
- Dedicated tools are recommended for file operations (read, edit, glob, etc.)
- Sensitive commands are controlled through the permission system

---

### 2.4 Web Tools

#### webfetch - Fetch Web Page

Fetches and analyzes URL content.

**Features:**
- HTML to Markdown conversion
- Content analysis through AI
- Redirect handling

**Example:**
```
Please read the documentation at https://docs.example.com/api.
```

**Limitations:**
- MCP is recommended for pages requiring authentication
- Large pages are summarized

#### websearch - Web Search

Searches for information on the web.

**Features:**
- Real-time search results
- Domain filtering available

**Example:**
```
Search for new features in React 18.
```

---

### 2.5 Agent Tools

#### task - Subagent Invocation

Delegates tasks to other agents.

**Features:**
- Invoke specialized agents
- Parallel task processing
- Session context isolation

**Invocation Method:**
```
@explore Find API-related files in the src directory.
@general Process complex refactoring tasks in parallel.
```

**Built-in Subagents:**

| Agent | Purpose |
|-------|---------|
| `@general` | Complex search, multi-step tasks |
| `@explore` | Codebase exploration |

---

### 2.6 Other Tools

#### todowrite / todoread

Task list management (Primary Agent only).

```
Please add this task to the todo list.
```

#### question

Ask user questions (Primary Agent only).

```
Please choose which database to use:
1. PostgreSQL
2. MySQL
3. SQLite
```

#### lsp

Language Server Protocol feature usage.

```
Navigate to the definition of this function.
```

---

## 3. MCP Extension Tools

### 3.1 MCP Tool Naming

MCP tools are named in the `{server_name}_{tool_name}` format.

```
Examples:
- github_create_issue
- filesystem_read_file
- postgres_query
```

### 3.2 Key MCP Tool List

#### Filesystem Server

| Tool | Description |
|------|-------------|
| `filesystem_read_file` | Read file |
| `filesystem_write_file` | Write file |
| `filesystem_list_directory` | List directory |
| `filesystem_create_directory` | Create directory |
| `filesystem_move_file` | Move file |
| `filesystem_search_files` | Search files |

#### GitHub Server

| Tool | Description |
|------|-------------|
| `github_create_issue` | Create issue |
| `github_create_pull_request` | Create PR |
| `github_get_file_contents` | Get file contents |
| `github_push_files` | Push files |
| `github_list_commits` | List commits |
| `github_search_code` | Search code |

#### Git Server

| Tool | Description |
|------|-------------|
| `git_status` | Check status |
| `git_diff` | View changes |
| `git_log` | History |
| `git_commit` | Commit |
| `git_branch` | Branch management |

#### PostgreSQL Server

| Tool | Description |
|------|-------------|
| `postgres_query` | Execute SQL query |
| `postgres_list_tables` | List tables |
| `postgres_describe_table` | Table schema |

### 3.3 MCP Tool Configuration

```json
{
  "mcp": {
    "github": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-github"],
      "environment": {
        "GITHUB_TOKEN": "{env:GITHUB_TOKEN}"
      }
    }
  }
}
```

---

## 4. Custom Command

### 4.1 Command Definition

Define commands as markdown files in the `.opencode/command/` directory.

**Basic Structure:**
```markdown
---
description: "Command description"
agent: build
subtask: false
---

Prompt template to be passed when the command is executed

$ARGUMENTS
```

### 4.2 Frontmatter Options

| Option | Type | Description |
|--------|------|-------------|
| `description` | string | Command description |
| `model` | string | Model to use |
| `agent` | string | Agent to use |
| `subtask` | boolean | Whether to run as subtask |

### 4.3 Variables

| Variable | Description |
|----------|-------------|
| `$ARGUMENTS` | Arguments entered by the user |

### 4.4 Command Examples

#### Commit Command

`.opencode/command/commit.md`:
```markdown
---
description: "Create Git commit"
subtask: true
---

Create a commit following these instructions:

1. Check changes with `git status`
2. Review detailed changes with `git diff`
3. Write commit message (Conventional Commits)
4. Execute `git commit`

$ARGUMENTS

## Commit Message Format

type(scope): description

- feat: New feature
- fix: Bug fix
- docs: Documentation
- refactor: Refactoring
- test: Tests
```

**Usage:**
```
/commit Add user authentication feature
```

#### Code Review Command

`.opencode/command/review.md`:
```markdown
---
description: "Perform code review"
---

Review the following files/changes:

$ARGUMENTS

## Review Criteria

1. Code quality
2. Security vulnerabilities
3. Performance issues
4. Best practices

## Output Format

For each issue:
- Location
- Severity
- Description
- Suggestion
```

**Usage:**
```
/review src/auth/login.ts
```

#### Test Command

`.opencode/command/test.md`:
```markdown
---
description: "Run and analyze tests"
subtask: true
---

$ARGUMENTS

## Task Order

1. Run tests: `bun test`
2. Analyze failed tests
3. Suggest fixes

If tests fail, analyze the cause and suggest solutions.
```

---

## 5. Permission Management

### 5.1 Global Permissions

Set global permissions in `opencode.json`:

```json
{
  "permission": {
    "read": "allow",
    "edit": "allow",
    "bash": "ask",
    "webfetch": "allow",
    "websearch": "allow",
    "external_directory": "ask"
  }
}
```

### 5.2 Per-Agent Permissions

Permission overrides for specific agents:

```yaml
# .opencode/agent/readonly.md
---
permission:
  "*": deny
  read: allow
  glob: allow
  grep: allow
---
```

### 5.3 Pattern-Based Permissions

```json
{
  "permission": {
    "read": {
      "*": "allow",
      "*.env": "deny",
      "*.key": "deny",
      ".git/**": "deny"
    },
    "edit": {
      "src/**": "allow",
      "test/**": "allow",
      "*.config.*": "ask",
      "*": "deny"
    },
    "bash": {
      "npm *": "allow",
      "git log *": "allow",
      "git status": "allow",
      "rm *": "deny",
      "*": "ask"
    }
  }
}
```

### 5.4 MCP Tool Permissions

The same permission system applies to MCP tools:

```json
{
  "permission": {
    "github_create_issue": "allow",
    "github_push_files": "ask",
    "postgres_query": "ask"
  }
}
```

---

## 6. Practical Usage

### 6.1 Code Analysis Workflow

```
User: Please analyze the architecture of this project.

Agent:
1. glob: **/*.ts - Understand file structure
2. read: src/index.ts - Check entry point
3. grep: "import.*from" - Analyze dependencies
4. @explore: Deep codebase exploration
5. Synthesize results and generate diagrams
```

### 6.2 Bug Fix Workflow

```
User: Please fix the TypeError: Cannot read property 'name' of undefined error.

Agent:
1. grep: "\.name" - Search related code
2. read: Error source file
3. Analyze root cause
4. edit: Apply fix
5. bash: bun test - Run tests
```

### 6.3 Refactoring Workflow

```
User: Please split UserService.

Agent:
1. read: src/services/UserService.ts
2. Analyze dependencies
3. Create splitting plan
4. @general: Create files in parallel
5. edit: Modify existing files
6. Test verification
```

### 6.4 Documentation Workflow

```
User: Please generate API documentation.

Agent:
1. glob: src/api/**/*.ts
2. read: Each API file
3. Extract endpoints, parameters, responses
4. edit: Create docs/api.md
```

### 6.5 Tool Combination Tips

| Task | Recommended Tool Combination |
|------|------------------------------|
| Find code | glob → grep → read |
| Refactoring | grep → read → edit → bash (test) |
| Documentation | glob → read → edit |
| Debugging | grep → read → bash (run) |
| Dependency analysis | glob → grep → @explore |