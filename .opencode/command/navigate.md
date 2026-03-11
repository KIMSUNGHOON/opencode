---
description: "Navigate codebase — ask questions about code architecture, find functions, trace dependencies"
subtask: true
prompt: |
  You are invoking the domain-router agent to answer a codebase navigation question.

  ## Instructions

  1. Parse $ARGUMENTS as the user's question about the codebase
  2. Delegate to @domain-router agent with the question
  3. Return the agent's structured response

  ## CRITICAL: Use the 3-layer navigation system

  The domain-router agent MUST:
  1. Load the codebase-navigator skill first
  2. Read L1 (project-map.yaml) to identify modules
  3. Read L2 (modules/*.yaml) for specific files
  4. Only then read actual source files (L3)

  ## Input

  $ARGUMENTS contains the user's question. Examples:
  - "How are skills loaded?"
  - "Where is the permission system implemented?"
  - "How do agents and tools interact?"
  - "Find the function that creates subagent sessions"
---

# /navigate — Codebase Navigation

Ask questions about the codebase and get precise answers with file locations.

Uses pre-indexed knowledge layers to minimize context usage while maximizing accuracy.

**Usage:**
```bash
# Architecture questions
/navigate "How does the skill system work?"

# Find specific code
/navigate "Where is the tool registry defined?"

# Trace dependencies
/navigate "What modules does the session system depend on?"

# Understand interactions
/navigate "How do plugins hook into the system prompt?"
```

**How it works:**
1. Loads L1 project map → identifies relevant modules
2. Loads L2 module details → finds specific files
3. Reads only the necessary source files
4. Returns answer with exact file:line locations
