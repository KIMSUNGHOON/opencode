# Custom Agent Creation Guide

## Overview

OpenCode's Agent system allows you to define and use AI agents specialized for specific tasks. This guide explains in detail how to create and utilize Custom Agents.

---

## Table of Contents

1. [Agent Basic Concepts](#1-agent-basic-concepts)
2. [Agent Types](#2-agent-types)
3. [Agent Definition Methods](#3-agent-definition-methods)
4. [Configuration Options in Detail](#4-configuration-options-in-detail)
5. [Permission System](#5-permission-system)
6. [Practical Examples](#6-practical-examples)
7. [Best Practices](#7-best-practices)

---

## 1. Agent Basic Concepts

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        OpenCode Agent System                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │    build    │  │    plan     │  │  (custom)   │   Primary    │
│  │  (default)  │  │  (readonly) │  │   agents    │   Agents     │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘              │
│         │                │                │                      │
│         └────────────────┼────────────────┘                      │
│                          │                                       │
│                          ▼                                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │   general   │  │   explore   │  │  (custom)   │   Sub        │
│  │  (general)  │  │  (codebase) │  │  subagents  │   Agents     │
│  └─────────────┘  └─────────────┘  └─────────────┘              │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Built-in Agents

| Agent | Mode | Description |
|-------|------|-------------|
| `build` | primary | Default development agent, full permissions |
| `plan` | primary | Read-only, analysis and planning |
| `general` | subagent | Complex search and multi-step tasks |
| `explore` | subagent | Codebase exploration specialized |
| `title` | primary (hidden) | Session title generation |
| `summary` | primary (hidden) | Summary generation |
| `compaction` | primary (hidden) | Context compaction |

---

## 2. Agent Types

### 2.1 Primary Agent

The main agent that users can directly select and interact with.

**Features:**
- Switch between agents using the `Tab` key
- Main conversation partner for the session
- Can use primary-only tools like TodoWrite, questions

**Use Scenarios:**
- Code development (`build`)
- Code analysis and planning (`plan`)
- Specialized domain work (custom)

### 2.2 Subagent

A supporting agent that the Primary Agent calls to delegate specific tasks.

**Features:**
- Called using the `@agent_name` syntax
- Runs as a sub-session of the Primary Agent
- TodoWrite disabled by default

**Use Scenarios:**
- Code search (`explore`)
- Parallel task processing (`general`)
- Specialized task execution (custom)

### 2.3 All Mode

An agent that can be used as both Primary and Subagent.

---

## 3. Agent Definition Methods

### 3.1 Markdown File Method (Recommended)

Define agents as markdown files in the `.opencode/agent/` directory.

**File Location:**
```
.opencode/
└── agent/
    ├── my-agent.md
    ├── code-reviewer.md
    └── git-expert.md
```

**Basic Structure:**
```markdown
---
# YAML Frontmatter (Configuration)
description: Agent description
mode: subagent
model: provider/model-id
---

# System Prompt (Markdown Body)

Write the agent's role and instructions here.
```

### 3.2 JSON Configuration Method

Define agents in the `agent` section of `opencode.json`.

```json
{
  "agent": {
    "my-agent": {
      "description": "Agent description",
      "mode": "subagent",
      "model": "provider/model-id",
      "prompt": "System prompt content"
    }
  }
}
```

### 3.3 Global vs Project Agent

| Location | Scope | Path |
|----------|-------|------|
| Global | All projects | `~/.config/opencode/.opencode/agent/` |
| Project | Current project only | `./.opencode/agent/` |

---

## 4. Configuration Options in Detail

### 4.1 Frontmatter Options

```yaml
---
# Basic Information
description: "Description of what the agent does"
mode: subagent  # primary | subagent | all

# Model Settings
model: provider/model-id
temperature: 0.7
top_p: 0.9

# Display Settings
color: "#FF6B35"
hidden: false

# Execution Limits
steps: 50

# Permission Settings
permission:
  bash: allow
  read: allow
  edit: deny
---
```

### 4.2 Detailed Option Descriptions

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `description` | string | - | Agent description (shown in @ autocomplete) |
| `mode` | enum | `all` | `primary`, `subagent`, `all` |
| `model` | string | parent setting | `provider/model-id` format |
| `temperature` | number | model default | Output diversity (0.0-2.0) |
| `top_p` | number | model default | Cumulative probability sampling |
| `color` | string | - | HEX color code (#RRGGBB) |
| `hidden` | boolean | false | Hide from @ menu |
| `steps` | number | - | Maximum iteration count |
| `disable` | boolean | false | Disable the agent |
| `permission` | object | - | Per-tool permission settings |

### 4.3 Model Configuration

In a single model environment, configure all agents to use the same model.

```yaml
---
model: provider/model-id
---
```

Or in global settings:
```json
{
  "model": "provider/model-id",
  "agent": {
    "build": { "model": "provider/model-id" },
    "plan": { "model": "provider/model-id" },
    "general": { "model": "provider/model-id" },
    "explore": { "model": "provider/model-id" }
  }
}
```

---

## 5. Permission System

### 5.1 Permission Structure

```yaml
permission:
  <permission_name>: <action>
  # or
  <permission_name>:
    <pattern>: <action>
```

### 5.2 Permission Types

| Permission | Description |
|------------|-------------|
| `read` | File reading |
| `edit` | File editing |
| `bash` | Shell command execution |
| `glob` | File pattern search |
| `grep` | Text search |
| `list` | Directory listing |
| `task` | Subagent invocation |
| `webfetch` | Web page fetching |
| `websearch` | Web search |
| `codesearch` | Code search |
| `todowrite` | Todo list writing |
| `todoread` | Todo list reading |
| `question` | Ask user questions |
| `external_directory` | External directory access |
| `lsp` | LSP feature usage |

### 5.3 Action Types

| Action | Description |
|--------|-------------|
| `allow` | Always allow |
| `deny` | Always deny |
| `ask` | Ask user for confirmation |

### 5.4 Pattern Matching

```yaml
permission:
  read:
    "*": allow
    "*.env": deny
    "*.env.example": allow
  edit:
    "src/**/*.ts": allow
    "config/*": ask
  bash:
    "git *": allow
    "rm -rf *": deny
```

### 5.5 Permission Examples

**Read-only Agent:**
```yaml
permission:
  "*": deny
  read: allow
  glob: allow
  grep: allow
  list: allow
```

**Code Editing Agent:**
```yaml
permission:
  "*": allow
  bash:
    "rm *": deny
    "git push --force *": deny
```

**Specific Directory Only:**
```yaml
permission:
  read:
    "src/**": allow
    "*": deny
  edit:
    "src/**/*.ts": allow
    "*": deny
```

---

## 6. Practical Examples

### 6.1 Code Reviewer

`.opencode/agent/code-reviewer.md`:
```markdown
---
description: Code quality review and improvement suggestions
mode: subagent
color: "#4CAF50"
permission:
  read: allow
  glob: allow
  grep: allow
  edit: deny
  bash: deny
---

# Code Reviewer

You are an experienced senior developer performing code reviews.

## Review Criteria

1. **Code Quality**
   - Readability
   - Maintainability
   - SOLID principles compliance

2. **Security**
   - Input validation
   - Authentication/Authorization
   - Sensitive data handling

3. **Performance**
   - Algorithm efficiency
   - Memory usage
   - Unnecessary computations

## Output Format

For each issue:
- Location (file:line)
- Severity (Critical/Major/Minor/Suggestion)
- Description
- Suggested code (if applicable)
```

### 6.2 Test Writer

`.opencode/agent/test-writer.md`:
```markdown
---
description: Unit test and integration test writing
mode: subagent
color: "#2196F3"
permission:
  read: allow
  glob: allow
  grep: allow
  edit:
    "**/*.test.ts": allow
    "**/*.spec.ts": allow
    "**/__tests__/**": allow
    "*": deny
  bash:
    "bun test *": allow
    "npm test *": allow
    "*": deny
---

# Test Writing Expert

You are a Test-Driven Development (TDD) expert.

## Test Writing Principles

1. **AAA Pattern**: Arrange, Act, Assert
2. **Single Responsibility**: One behavior verification per test
3. **Independence**: No dependencies between tests
4. **Clear Naming**: Intent should be clear from the test name

## Coverage Goals

- Line coverage: 80% or higher
- Branch coverage: 75% or higher
- Edge cases included

## Test Frameworks

- TypeScript: Vitest, Jest, Bun Test
- Pattern: describe/it/expect
```

### 6.3 Documentation Writer

`.opencode/agent/doc-writer.md`:
```markdown
---
description: Technical documentation and API documentation writing
mode: subagent
color: "#FF9800"
permission:
  read: allow
  glob: allow
  grep: allow
  edit:
    "**/*.md": allow
    "docs/**": allow
    "*": deny
  bash: deny
---

# Technical Documentation Writer

You write clear and structured technical documentation.

## Documentation Style

- Concise and clear sentences
- Include code examples
- Step-by-step guide format

## Documentation Structure

1. Overview
2. Installation/Setup
3. Basic Usage
4. Advanced Features
5. API Reference
6. FAQ/Troubleshooting
```

### 6.4 Git Expert

`.opencode/agent/git-expert.md`:
```markdown
---
description: Git operations and version control expert
mode: subagent
color: "#F44336"
permission:
  read: allow
  glob: allow
  grep: allow
  edit: deny
  bash:
    "git status": allow
    "git log *": allow
    "git diff *": allow
    "git branch *": allow
    "git checkout *": allow
    "git fetch *": allow
    "git pull *": allow
    "git rebase *": ask
    "git merge *": ask
    "git push *": ask
    "git push --force *": deny
    "git reset --hard *": deny
    "*": deny
---

# Git Expert

You are a Git version control expert.

## Safety Rules

1. **Strictly Prohibited**
   - `git push --force` (main/master)
   - `git reset --hard` (commits synced with remote)
   - History tampering

2. **Requires Confirmation**
   - Rebase operations
   - Merge operations
   - Remote push

## Work Patterns

- Feature Branch: feature/issue-number-description
- Commit Message: type(scope): description
- PR: Split into small units
```

### 6.5 Security Analyst

`.opencode/agent/security-analyst.md`:
```markdown
---
description: Security vulnerability analysis and recommendations
mode: subagent
color: "#9C27B0"
permission:
  read: allow
  glob: allow
  grep: allow
  edit: deny
  bash:
    "npm audit *": allow
    "bun audit *": allow
    "*": deny
---

# Security Analyst

You are an application security expert.

## Analysis Areas

1. **OWASP Top 10**
   - Injection (SQL, XSS, Command)
   - Broken Authentication
   - Sensitive Data Exposure
   - Security Misconfiguration

2. **Dependency Vulnerabilities**
   - npm audit result analysis
   - CVE verification

3. **Code Patterns**
   - Hardcoded secrets
   - Insecure encryption
   - Improper error handling

## Report Format

| Severity | Vulnerability | Location | Recommendation |
|----------|--------------|----------|----------------|
| Critical/High/Medium/Low | Description | file:line | Solution |
```

---

## 7. Best Practices

### 7.1 Clear Role Definition

**Good Example:**
```markdown
---
description: TypeScript type error fixing expert
---
You analyze and fix TypeScript compilation errors.
```

**Bad Example:**
```markdown
---
description: Development helper
---
Helps with coding.
```

### 7.2 Principle of Least Privilege

Grant only necessary permissions:
```yaml
permission:
  "*": deny
  read: allow
  glob: allow
  # Add only what's needed
```

### 7.3 Single Model Environment Optimization

Specify the same model for all agents:
```json
{
  "agent": {
    "build": { "model": "provider/model-id" },
    "plan": { "model": "provider/model-id" },
    "general": { "model": "provider/model-id" },
    "explore": { "model": "provider/model-id" },
    "code-reviewer": { "model": "provider/model-id" }
  }
}
```

### 7.4 Prompt Structuring

```markdown
# Role

## Goals

## Rules/Constraints

## Output Format

## Examples
```

### 7.5 Testing and Verification

1. Test basic behavior after creating a new agent
2. Verify permission settings (allowing/denying as intended)
3. Test edge cases