# OpenCode Skills: Complete Usage Guide

## What Are Skills?

Skills are **on-demand knowledge modules** that inject domain-specific instructions, checklists, workflows, and bundled resources into the conversation context. Unlike system prompts (always loaded), skills are loaded **only when needed**, keeping the context window efficient.

### Skills vs Other Concepts

| Concept | When Loaded | Purpose |
|---------|------------|---------|
| **AGENTS.md / CLAUDE.md** | Always (system prompt) | Global project instructions |
| **Agent** | When agent is selected | Different LLM persona/model |
| **Command** | On `/command` invocation | Predefined prompt templates |
| **Skill** | On-demand (tool call or `/skill`) | Domain-specific knowledge injection |

Key difference: Skills provide **reference knowledge** (checklists, patterns, decision trees), while commands provide **action templates** (prompt text). A skill stays in context as a knowledge base; a command is a one-shot prompt.

---

## How Skills Work in OpenCode TUI

### Invocation Method 1: Slash Command (`/skill-name`)

The simplest way. Type `/` followed by the skill name directly in the prompt input:

```
/code-review Review the authentication module for security issues
```

This sends the skill's content as part of your prompt. The LLM receives both the skill instructions and your task.

### Invocation Method 2: Skills Dialog

1. Open the **Command Palette** (default: `Ctrl+K` or your configured keybinding)
2. Select **"Skills"** from the menu
3. A searchable dialog appears listing all available skills
4. Select a skill → it inserts `/{skill-name} ` into your prompt input
5. Type your task after the skill name and submit

### Invocation Method 3: Automatic (LLM-Driven)

The LLM sees available skills in its `skill` tool description. When it recognizes a task matches a skill, it **automatically calls** the skill tool to load the knowledge. You don't need to do anything.

For example, if you ask "review this code for security vulnerabilities" and a `code-review` skill exists, the LLM may automatically invoke it.

### Invocation Method 4: CLI Debug

```bash
# List all discovered skills
opencode skill list

# Show a specific skill's content
opencode skill show code-review
```

---

## Creating Your Own Skills

### Directory Structure

Create a folder with `SKILL.md` inside it. OpenCode searches these locations (in order):

```
# Project-level (highest priority, overrides global)
.opencode/skills/<name>/SKILL.md        # OpenCode native
.claude/skills/<name>/SKILL.md          # Claude Code compatible
.agents/skills/<name>/SKILL.md          # Agent compatible

# Global (lower priority)
~/.config/opencode/skills/<name>/SKILL.md
~/.claude/skills/<name>/SKILL.md
~/.agents/skills/<name>/SKILL.md
```

### SKILL.md Format

```markdown
---
name: my-skill-name
description: One-line description of what this skill provides (max 1024 chars)
---

# Skill Title

Your skill content here. This is the knowledge that gets injected
into the conversation when the skill is loaded.

## Decision Trees, Checklists, Reference Tables...

Everything in the body becomes the skill's `content`.
```

### Naming Rules

- **1-64 characters**, lowercase alphanumeric
- Single hyphens as separators (no `--`)
- Cannot start or end with `-`
- **Must match the directory name** (folder `code-review/` → `name: code-review`)
- Regex: `^[a-z0-9]+(-[a-z0-9]+)*$`

---

## Bundling Resources with Skills

This is where it gets powerful. **The skill directory is not just for SKILL.md** — you can include any files alongside it, and the LLM gains access to them.

### How It Works

When a skill is loaded, OpenCode:
1. Reads `SKILL.md` content → injected as `<skill_content>`
2. Lists up to **10 files** in the skill directory → injected as `<skill_files>`
3. Sets the **base directory** so the LLM can reference files by relative path

### Example: Skill with Reference Data

```
.opencode/skills/api-review/
├── SKILL.md                    # Main instructions
├── reference/
│   ├── owasp-top-10.md        # Reference document
│   └── api-standards.md       # Company API standards
├── scripts/
│   └── check-endpoints.sh     # Helper script
└── templates/
    └── review-report.md       # Output template
```

In your `SKILL.md`, reference these files:

```markdown
---
name: api-review
description: API security review with OWASP top 10 and company standards
---

## Instructions

1. Read `reference/owasp-top-10.md` for the security checklist
2. Read `reference/api-standards.md` for company conventions
3. Run `scripts/check-endpoints.sh` to enumerate endpoints
4. Use `templates/review-report.md` as the output format

## When to Use

Load this skill when reviewing API endpoints for security and compliance.
```

The LLM can then use its `read` tool to access these bundled files using the skill's base directory.

---

## Injecting Domain Knowledge via Skills

### Strategy 1: Markdown Reports as Skill Content

If you have detailed analysis reports, embed them directly in the SKILL.md body:

```
.opencode/skills/project-knowledge/
├── SKILL.md              # Contains or references the reports
├── architecture.md       # Detailed architecture analysis
├── api-inventory.md      # All API endpoints documented
└── dependency-map.md     # Dependency analysis results
```

**SKILL.md:**
```markdown
---
name: project-knowledge
description: Project domain knowledge — architecture, APIs, dependencies. Load when you need deep context about this project's structure.
---

## How to Use This Knowledge

This skill provides access to pre-analyzed project documentation:

1. `architecture.md` — System architecture and component relationships
2. `api-inventory.md` — Complete API endpoint inventory
3. `dependency-map.md` — Dependency graph and version constraints

Read the relevant file based on the task:
- Architecture questions → read `architecture.md`
- API work → read `api-inventory.md`
- Dependency issues → read `dependency-map.md`

## Key Architecture Summary

(Embed a condensed summary here so the LLM gets immediate context
without needing to read additional files)

### Core Components
- Component A: handles X
- Component B: handles Y
- Component C: handles Z

### Critical Paths
- User authentication: A → B → DB
- Data processing: C → Queue → Worker
```

### Strategy 2: Workspace Cache as Skill Reference

If your project uses `analyze` or similar tools that generate workspace cache files, you can create a skill that references those outputs:

```
.opencode/skills/workspace-context/
├── SKILL.md
└── cache/                    # Symlink or copy of analysis results
    ├── file-index.json
    ├── module-tiers.json
    └── dependency-graph.json
```

**SKILL.md:**
```markdown
---
name: workspace-context
description: Pre-analyzed workspace structure — file index, module tiers, dependency graph. Load for codebase navigation and understanding.
---

## Workspace Analysis Data

This skill provides access to pre-computed workspace analysis:

- `cache/file-index.json` — All source files with metadata
- `cache/module-tiers.json` — Module importance tiers (1=core, 2=important, 3=peripheral)
- `cache/dependency-graph.json` — Inter-module dependency relationships

## How to Use

When asked about project structure or module relationships:
1. Read `cache/module-tiers.json` to understand component importance
2. Read `cache/dependency-graph.json` for relationships
3. Use tier information to prioritize analysis (Tier 1 first)

## Quick Reference

(Include a condensed summary so the LLM has immediate orientation)
```

### Strategy 3: Using `instructions` Config for Always-On Context

For knowledge that should **always** be available (not on-demand), use the `instructions` field in your config instead:

**opencode.json:**
```json
{
  "instructions": [
    "./docs/architecture-summary.md",
    "./docs/coding-conventions.md"
  ]
}
```

These files are loaded as part of the system prompt for every conversation.

### Strategy 4: Skills + Config `paths` for External Knowledge Bases

If your knowledge base lives outside the standard skill directories:

**opencode.json:**
```json
{
  "skills": {
    "paths": [
      "./knowledge-base/skills",
      "~/shared-team-skills"
    ],
    "urls": [
      "https://internal.example.com/.well-known/skills/"
    ]
  }
}
```

This tells OpenCode to scan additional directories for `**/SKILL.md` files.

---

## Permissions and Access Control

### Global Permission Config

**opencode.json:**
```json
{
  "permission": {
    "skill": {
      "*": "allow",
      "internal-*": "deny",
      "experimental-*": "ask"
    }
  }
}
```

| Permission | Behavior |
|-----------|----------|
| `allow` | Loads immediately without asking |
| `deny` | Hidden from agent, access rejected |
| `ask` | User prompted for approval |

### Per-Agent Permissions

In custom agent frontmatter:
```yaml
---
permission:
  skill:
    "documents-*": "allow"
    "code-*": "deny"
---
```

In opencode.json for built-in agents:
```json
{
  "agent": {
    "plan": {
      "permission": {
        "skill": {
          "internal-*": "allow"
        }
      }
    }
  }
}
```

### Disabling Skills Entirely

For agents that shouldn't use skills:

```yaml
# Custom agent frontmatter
---
tools:
  skill: false
---
```

```json
// opencode.json for built-in agents
{
  "agent": {
    "plan": {
      "tools": {
        "skill": false
      }
    }
  }
}
```

---

## Best Practices

### 1. Keep Skills Focused

One skill = one domain. Don't create a "everything" skill.

```
# Good
.opencode/skills/code-review/SKILL.md        # Code review checklists
.opencode/skills/api-security/SKILL.md       # API security patterns
.opencode/skills/build-test/SKILL.md         # Build & test workflows

# Bad
.opencode/skills/everything/SKILL.md         # Too broad
```

### 2. Write Clear Descriptions

The description is how the LLM decides whether to load a skill. Be specific:

```yaml
# Good — LLM knows exactly when to use it
description: Code review knowledge base — security checklists, bug patterns, performance anti-patterns, and language-specific rules. Load this skill when performing code analysis or review tasks.

# Bad — too vague
description: Useful information about code
```

### 3. Include Decision Trees

Structure knowledge as decision trees so the LLM can navigate systematically:

```markdown
## What to Check First
Code change type?
├─ New API endpoint → Security checklist
├─ Database query → SQL injection, N+1
├─ File I/O → Path traversal, resource leak
└─ Config change → Secret exposure
```

### 4. Provide Output Schemas

Tell the LLM what format to produce:

```json
{
  "id": "C001",
  "severity": "critical|high|medium|low",
  "file": "/path/to/file",
  "line": 42,
  "title": "Issue title",
  "suggestion": "How to fix"
}
```

### 5. Use Bundled Files for Large Content

Don't put 5000 lines in SKILL.md. Instead:
- SKILL.md: Summary + instructions (concise)
- Bundled files: Full reference data (read on demand)

This keeps initial skill loading fast while still making all knowledge accessible.

---

## Troubleshooting

| Symptom | Check |
|---------|-------|
| Skill not appearing | `SKILL.md` must be uppercase; frontmatter must have `name` and `description` |
| Skill name mismatch | Directory name must match `name` in frontmatter |
| Duplicate warning | Same skill name exists in multiple locations |
| Permission denied | Check `permission.skill` in config |
| Bundled files not found | Files must be in the same directory as SKILL.md or subdirectories |
| Skill not auto-loading | Description must be specific enough for LLM to match |
