---
description: "Generate DeepWiki-style project documentation with mermaid diagrams"
model: qwen/Qwen3-Next-80B-A3B-Thinking-FP8
agent: deepwiki
subtask: true
prompt: |
  Generate a comprehensive DeepWiki-style technical wiki for this project.

  ## Instructions

  Follow your agent instructions to:
  1. Gather project context (workspace cache + README + file structure)
  2. Plan wiki structure (8-12 pages with sections, diagrams, cross-references)
  3. Generate all pages in PARALLEL via wiki-page-generator agents
  4. Assemble: save all pages, index.md, _sidebar.md to docs/wiki/
  5. Verify all files were written

  ## Options

  $ARGUMENTS

  ## Requirements

  - Every page MUST have at least one mermaid diagram
  - Every page MUST reference actual source files
  - Pages MUST cross-link to related pages
  - Save ALL files to docs/wiki/
  - If workspace cache exists (.opencode/workspace-cache/project-map.yaml), use it
  - If no cache, scan the project directly (slower but still works)

  ## CRITICAL: Write ALL Files

  You MUST use the Write tool to save every generated page.
  After all writes, verify with: ls -la docs/wiki/
  If any file is missing, re-generate and save it.

---

# /deepwiki - Generate Project Documentation Wiki

**Input**: $ARGUMENTS

Generates a comprehensive, DeepWiki-style technical wiki with mermaid diagrams,
code references, and navigable cross-links.

## Usage

```bash
/deepwiki              # Full wiki (8-12 pages)
/deepwiki --concise    # Concise wiki (4-6 pages)
/deepwiki --force      # Overwrite existing wiki
/deepwiki --module api # Regenerate only the API module page
```

## Output Structure

```
docs/wiki/
├── index.md                    # Main page with navigation table
├── _sidebar.md                 # Sidebar navigation
├── .wiki-structure.yaml        # Wiki structure metadata
├── 01-overview.md              # Project overview & getting started
├── 02-architecture.md          # System architecture with diagrams
├── 03-{module-a}.md            # Module documentation
├── 04-{module-b}.md            # Module documentation
├── ...                         # More module pages
├── {N-1}-configuration.md      # Configuration & deployment
└── {N}-development-guide.md    # Development guide
```

## Prerequisites & Cache Behavior (HITL)

When `/deepwiki` starts, it checks for workspace cache and **asks the user** what to do:

- **Cache exists (fresh):** "Use existing cache" / "Refresh" / "Generate without cache"
- **Cache exists (stale):** "Refresh cache" / "Use stale cache" / "Generate without cache"
- **No cache:** "Run /analyze first" / "Generate without cache"

If the user chooses to run `/analyze`, it executes automatically before wiki generation.
No need to run `/analyze` separately — the HITL prompt handles it.

## Page Content

Each page includes:
- Introduction with context
- Mermaid diagrams (architecture, data flow, sequence, ER, class)
- Code snippets with file path references
- Source citations per section
- Related page cross-links

## Integration

- **GitHub Wiki:** Copy `docs/wiki/*.md` to your repo's wiki
- **MkDocs:** Point `docs_dir` to `docs/wiki/`
- **Docusaurus:** Import markdown files into `docs/` directory
- **Direct viewing:** Open `docs/wiki/index.md` in any markdown viewer
