---
name: session-checkpoint
description: Session context preservation knowledge — checkpoint structure, context compression, progress tracking, and session resumption patterns. Load this skill when creating checkpoints, resuming from a previous session, or managing long-running workflows.
---

# Session Checkpoint Knowledge Base

Rules for capturing session context, writing checkpoint files, and enabling seamless resumption after TUI crashes, session drops, or program terminations.

## Checkpoint Architecture

```
.opencode/checkpoints/
├── latest.md                          # Symlink/copy of most recent checkpoint
├── 2026-03-10T14-30-00_code-qa.md     # Timestamped checkpoint
├── 2026-03-10T15-45-00_code-qa.md     # Later checkpoint (same workflow)
└── 2026-03-10T16-00-00_deepwiki.md    # Different workflow checkpoint
```

### File Naming Convention

```
{YYYY-MM-DD}T{HH-MM-SS}_{workflow_name}.md
```

- Use filesystem-safe timestamp (hyphens instead of colons)
- `workflow_name` = mode or command name (e.g., `code-qa`, `deepwiki`, `analyze`, `manual`)
- For ad-hoc sessions without a mode, use `manual`

## Checkpoint Structure (Markdown)

```markdown
# Session Checkpoint

**Workflow**: {workflow_name}
**Created**: {ISO-8601 timestamp}
**Branch**: {current git branch}
**Commit**: {latest commit hash (short)}
**Working Directory**: {relative path from repo root, typically "."}

## Progress

### Completed Steps
- [x] {step_name}: {brief outcome}
- [x] {step_name}: {brief outcome}

### Current Step
- [ ] {step_name}: {what was in progress}

### Pending Steps
- [ ] {step_name}
- [ ] {step_name}

## State Variables

Key values collected during the session that downstream steps need:

| Variable | Value |
|----------|-------|
| PROJECT_TYPE | {value} |
| BUILD_CMD | {value} |
| ENV_STATE.ACTIVATE_CMD | {value} |
| changed_files | {comma-separated list or "see below"} |
| ... | ... |

### Changed Files
{if too many for table, list them here}
```
{file1}
{file2}
```

## Key Decisions

Decisions made during this session that should carry forward:

1. {decision}: {rationale}
2. {decision}: {rationale}

## Context Store

Compressed state from agents that have completed:

### {agent_name} Result
```json
{compressed JSON — key fields only, not full output}
```

## Errors & Blockers

Issues encountered that may need attention on resume:

- {error_description}: {status (resolved/unresolved)}

## Resume Instructions

To resume this workflow:
1. Read this checkpoint file
2. Restore state variables from the table above
3. Continue from: **{current_step_name}**
4. Skip completed steps unless their outputs are needed
```

## When to Create Checkpoints

### Automatic Triggers (Agent-Driven)

| Trigger | When | Why |
|---------|------|-----|
| **Step completion** | After each major workflow step completes | Capture progress incrementally |
| **Before risky operations** | Before git push, file deletion, external API calls | Recovery point if operation fails |
| **Time-based** | Every 5 minutes during long workflows | Protect against unexpected crashes |
| **State accumulation** | When 3+ state variables have been collected | Ensure collected data isn't lost |

### Manual Triggers

- User says "checkpoint" or "save progress"
- User says "I need to leave" or "pause"
- Before switching to a different task

## Context Compression Rules

Checkpoints should be **concise** — they exist for the next session's cold start, not as a transcript.

### What to Include
- Step completion status (done/in-progress/pending)
- State variables (PROJECT_TYPE, BUILD_CMD, ENV_STATE, changed_files, etc.)
- Key decisions and rationale
- Errors and their resolution status
- Agent result summaries (compressed — counts, statuses, not full output)
- Current git state (branch, latest commit)

### What to Exclude
- Full tool call logs
- Complete file contents (reference by path instead)
- Verbose agent output (compress to key metrics)
- Intermediate reasoning or exploration steps
- Redundant information already in state variables

### Compression Heuristics

| Data Type | Compression Strategy |
|-----------|---------------------|
| Review issues | Count per severity + top 3 critical issues |
| Test results | total/passed/failed/coverage% |
| File lists | First 10 + "and N more" |
| Agent JSON output | Extract status + key metrics only |
| Error messages | First line + error type |
| Code snippets | File path + line range reference |

## Session Resumption Protocol

When starting a new session and a checkpoint exists:

### Step 1: Detect Checkpoint
```bash
ls -t .opencode/checkpoints/*.md 2>/dev/null | head -1
```
Or read `.opencode/checkpoints/latest.md` directly.

### Step 2: Load & Parse
Read the checkpoint file and extract:
- Workflow name → determines which mode/command to continue
- Completed steps → skip these
- Current step → resume from here
- State variables → restore these to context
- Errors/blockers → check if still relevant

### Step 3: Validate State
Before resuming, verify:
- Git branch matches checkpoint's branch
- Latest commit matches (or is descendant of) checkpoint's commit
- Working directory is clean or has expected changes
- Referenced files still exist

### Step 4: Resume or Restart
| State Match | Action |
|-------------|--------|
| Branch + commit match | Resume from current step |
| Same branch, newer commits | Resume but re-validate state variables |
| Different branch | Warn user, ask whether to resume or restart |
| Files significantly changed | Suggest restart with fresh analysis |

## Integration with Code QA Workflow

The code-qa mode orchestrator can use checkpoints at these points:

| After Step | Checkpoint Contains |
|------------|-------------------|
| STEP 0 (init) | PROJECT_ROOT, PROJECT_TYPE, BUILD_CMD, domain_knowledge status |
| STEP 1 (env-setup) | + ENV_STATE |
| STEP 2 (git-input) | + changed_files |
| STEP 4 (review) | + review_issues summary |
| STEP 5 (fix) | + fix_results summary |
| STEP 7 (test) | + test_results summary |
| STEP 9 (report) | + report location |

## Retention Policy

- Keep last **5** checkpoints per workflow
- Delete older checkpoints automatically when creating new ones
- Never delete `latest.md` — always overwrite it with the newest checkpoint

## Example: Minimal Checkpoint

```markdown
# Session Checkpoint

**Workflow**: code-qa
**Created**: 2026-03-10T14:30:00+09:00
**Branch**: feature/auth-refactor
**Commit**: a1b2c3d

## Progress

### Completed Steps
- [x] STEP 0 (init): Python/Poetry project, 12 modules detected
- [x] STEP 1 (env-setup): Poetry venv activated
- [x] STEP 2 (git-input): 5 changed files detected
- [x] STEP 3 (pre-check): Passed (no syntax errors)
- [x] STEP 4 (review): 8 issues (2 critical, 3 major, 3 minor)

### Current Step
- [ ] STEP 5 (fix): In progress — 1/2 critical issues fixed

### Pending Steps
- [ ] STEP 6 (quality-check)
- [ ] STEP 7 (test)
- [ ] STEP 8-11 (report, commit, push)

## State Variables

| Variable | Value |
|----------|-------|
| PROJECT_TYPE | python-poetry |
| BUILD_CMD | poetry install |
| ENV_STATE.ACTIVATE_CMD | poetry shell |
| changed_files | src/auth/login.py, src/auth/token.py, src/models/user.py, tests/test_auth.py, tests/test_token.py |

## Key Decisions

1. Using Poetry virtualenv (not conda): matches project config
2. Review found SQL injection in login.py:45 — marked critical, fix in progress

## Resume Instructions

To resume this workflow:
1. Read this checkpoint
2. Restore state variables
3. Continue from: **STEP 5 (code-fix)** — pass remaining critical issue to code-fixer
4. Remaining critical issue: XSS in token.py:78 (review issue #2)
```
