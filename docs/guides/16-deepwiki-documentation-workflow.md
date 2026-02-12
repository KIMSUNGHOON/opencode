# DeepWiki Documentation Workflow

## Overview

The `/deepwiki` command generates a comprehensive, navigable technical wiki for your project
— similar to [DeepWiki](https://deepwiki.com) — with mermaid diagrams, code references,
and cross-linked pages. Everything runs locally via AI agents.

## Architecture

```
/deepwiki command
    │
    ▼
┌─────────────────────────────────────────┐
│  deepwiki orchestrator agent            │
│  (Phase 1: gather context)              │
│  (Phase 2: plan wiki structure)         │
│  (Phase 3: parallel page generation)    │
│  (Phase 4: assemble & save)             │
└──────────────┬──────────────────────────┘
               │ Task tool (parallel)
               ▼
┌──────────┐ ┌──────────┐ ┌──────────┐
│ wiki-page│ │ wiki-page│ │ wiki-page│  ... (8-12 pages)
│ generator│ │ generator│ │ generator│
│ agent    │ │ agent    │ │ agent    │
└──────────┘ └──────────┘ └──────────┘
```

### Agents

| Agent | Role | Tools |
|-------|------|-------|
| `deepwiki` | Orchestrator: gathers context, plans structure, delegates, assembles | Task, Read, Write, Bash, Glob, Grep |
| `wiki-page-generator` | Generates one wiki page with diagrams and code references | Read, Glob, Bash, Grep (read-only) |

## Usage

```bash
/deepwiki              # Full wiki (8-12 pages)
/deepwiki --concise    # Concise wiki (4-6 pages)
/deepwiki --force      # Overwrite existing wiki
/deepwiki --module api # Regenerate only one module's page
```

### Cache Check (HITL)

When `/deepwiki` starts, it checks for workspace cache and asks the user:

| Cache Status | Options Presented |
|-------------|-------------------|
| **Fresh** (< 24h) | Use cache / Refresh / Generate without cache |
| **Stale** (> 24h) | Refresh cache / Use stale / Generate without cache |
| **Missing** | Run /analyze first / Generate without cache |

If the user chooses to run `/analyze`, it executes automatically before wiki generation.
No need to run `/analyze` separately.

### Manual Workflow (alternative)

```bash
# Step 1: Analyze project (builds workspace cache with tier info)
/analyze

# Step 2: Generate wiki (uses cache for faster, richer results)
/deepwiki
```

## Output Structure

```
docs/wiki/
├── index.md                    # Main page with project overview + navigation table
├── _sidebar.md                 # Sidebar navigation (for wiki renderers)
├── .wiki-structure.yaml        # Wiki structure metadata (pages, sections, hierarchy)
├── 01-overview.md              # Project overview & getting started
├── 02-architecture.md          # System architecture with mermaid diagrams
├── 03-{module-a}.md            # Core module documentation
├── 04-{module-b}.md            # Core module documentation
├── ...                         # More module pages
├── {N-1}-configuration.md      # Configuration & deployment
└── {N}-development-guide.md    # Development guide & contributing
```

## Page Content

Every generated page includes:

| Element | Description |
|---------|-------------|
| **H1 Title** | Page title matching wiki structure |
| **Introduction** | What this covers and why it matters |
| **Mermaid Diagrams** | At least 1 per page: flowchart, sequence, class, ER, state |
| **Code Snippets** | With file path references (`file.ts:L10-25`) |
| **Source Citations** | Per-section references to actual source files |
| **Related Pages** | Cross-links to related wiki pages |

### Diagram Types Used

| Diagram | When Used |
|---------|-----------|
| `flowchart TD/LR` | Architecture, data flow, component connections |
| `sequenceDiagram` | API lifecycle, request handling, event flow |
| `classDiagram` | Module relationships, inheritance, composition |
| `erDiagram` | Database schema, entity relationships |
| `stateDiagram-v2` | State machines, workflow states |

## Integration with Workspace Cache

The `/deepwiki` command leverages the 3-level workspace cache from `/analyze`:

| Cache Level | How DeepWiki Uses It |
|-------------|---------------------|
| **L1** (`project-map.yaml`) | Project type, module list, **tier info**, build commands → wiki structure planning |
| **L2** (`modules/*.yaml`) | File inventory, exports, dependencies → module page content |
| **L3** (source files) | Actual code → code snippets, detailed explanations |

Without cache, DeepWiki still works by scanning files directly (slower but functional).

### Tier-Aware Page Planning (v2.1)

When the workspace cache includes tier information (from `/analyze` v2.1+), DeepWiki
uses it to plan pages intelligently:

| Module Tier | Page Strategy |
|-------------|---------------|
| **Tier 1** (core) | One dedicated page per module (full detail, individual diagrams) |
| **Tier 2** (important) | Group 2-3 related modules into combined pages |
| **Tier 3** (peripheral) | Mentioned briefly in Overview or appendix page |

For a 50-module project, this typically results in:
- 5 Tier 1 dedicated pages
- 3-4 Tier 2 grouped pages
- 1 appendix page listing Tier 3 modules
- Plus Overview, Architecture, Config/Deploy pages = ~12 pages total

## Publishing Options

| Platform | How To |
|----------|--------|
| **GitHub Wiki** | Copy `docs/wiki/*.md` to your repo's wiki directory |
| **MkDocs** | Set `docs_dir: docs/wiki` in `mkdocs.yml` |
| **Docusaurus** | Import markdown files into `docs/` with sidebar config |
| **GitHub Pages** | Use any static site generator with `docs/wiki/` as source |
| **Direct viewing** | Open `docs/wiki/index.md` in VS Code, Obsidian, or any markdown viewer |

## Performance

| Phase | Time | Notes |
|-------|------|-------|
| Context gathering | ~5s | Reads cache + README + file structure |
| Structure planning | ~10s | LLM plans 8-12 pages |
| Page generation | ~30-60s | All pages generated in parallel |
| Assembly | ~5s | Write index, sidebar, verify |
| **Total** | **~1-2 min** | With workspace cache |

Without cache, add ~30s for direct file scanning.

## Limitations

- Pages are generated independently → occasional cross-reference mismatches
- Mermaid diagrams are AI-generated → may need manual tweaking for complex architectures
- Maximum 12 pages per generation → large monorepos may need multiple runs
- Code snippets reference file paths at generation time → may become stale after refactoring
