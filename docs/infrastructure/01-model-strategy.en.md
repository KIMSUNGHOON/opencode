# Dual Model Strategy Report: Qwen3.5-122B-A10B Hybrid Thinking/Instruct Strategy

## 1. Executive Summary

The Code QA v4 workflow serves a single **Qwen3.5-122B-A10B-FP8** model from one SGLang server, using a **hybrid strategy** that switches between Thinking/Instruct modes per request via the `enable_thinking` flag in `chat_template_kwargs`. It has evolved from the earlier dual model (Thinking+Coder) to dual endpoint to the current single-server approach.

---

## 2. Current System Analysis

### 2.1 Current Model: Qwen3-Next-Thinking-80B-A3B-FP8

| Item | Value |
|------|-----|
| Total Parameters | 80B (Active: 3B, Sparse MoE) |
| Context Window | 256K tokens |
| Output Limit | 16K tokens |
| Quantization | FP8 (~76GB VRAM) |
| Mode | Thinking (CoT) + Tool Calling |
| Deployment | 2x H100 NVL 96GB (TP=2) |

### 2.2 New Model: Qwen3-Coder-Next-FP8

| Item | Value |
|------|-----|
| Total Parameters | 80B (Active: 3B, Sparse MoE) |
| Context Window | 256K tokens (expandable up to 1M) |
| Quantization | FP8 (can serve 256K on a single GPU) |
| Mode | **Non-thinking** (no `<think>` block) |
| Coding Specialization | SWE-Bench Verified 70.6% |
| Language Support | 370 programming languages |
| Training Base | Qwen3-Next-80B-A3B-Base + 600B token repo-level data |
| Inference Speed | ~43 tok/s (DGX Spark, FP8) |
| License | Apache 2.0 |
| SGLang Requirement | >= v0.5.8 |
| vLLM Requirement | >= 0.15.0 |

### 2.3 Key Differences Between the Two Models

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                          Model Comparison Matrix                                     │
├──────────────────────┬──────────────────────────┬──────────────────────────────────┤
│ Characteristic       │ Thinking (Current)        │ Coder-Next (New)                 │
├──────────────────────┼──────────────────────────┼──────────────────────────────────┤
│ Inference Mode       │ Thinking (includes CoT)   │ Non-thinking (direct response)   │
│ Strengths            │ Complex reasoning,         │ Code generation/modification,    │
│                      │ analysis, planning         │ SWE tasks                        │
│ Response Speed       │ Slow (thinking overhead)   │ Fast (non-thinking)              │
│ Token Efficiency     │ Low (consumes think tokens)│ High (all tokens are useful      │
│                      │                            │ output)                          │
│ Tool Calling         │ Supported                  │ Supported                        │
│ Code Quality         │ Good                       │ Very Good (SWE-Bench 70.6%)      │
│ Secure Code Gen      │ Good                       │ Very Good (exceeds Claude        │
│                      │                            │ Opus 4.5)                        │
│ Architecture Base    │ Qwen3-Next-80B-A3B-Base    │ Qwen3-Next-80B-A3B-Base          │
│ VRAM Requirement     │ ~76GB                      │ ~76GB (same architecture)        │
└──────────────────────┴──────────────────────────┴──────────────────────────────────┘
```

> **Key Insight**: Both models are derived from the same Base model, but the Thinking model is optimized for **reasoning capability** while the Coder model is optimized for **code execution/modification capability**. Non-thinking mode provides significant advantages in response speed and token efficiency.

---

## 3. Current Workflow Sub-Agent Analysis

### 3.1 Overall Pipeline Structure

```
Phase -1    Phase 0     Phase 1     Phase 2     Phase 3     Phase 4
┌────────┐ ┌────────┐ ┌────────┐ ┌─────────┐ ┌────────┐ ┌─────────┐
│env-    │→│git-    │→│pre-    │→│code-    │→│code-   │→│quality- │
│setup   │ │input   │ │checker │ │reviewer │ │fixer   │ │checker  │
└────────┘ └────────┘ └────────┘ └─────────┘ └───┬────┘ └────┬────┘
                                                 │◀── Regression ◀──┤ <70%

Phase 5     Phase 6     Phase 7     Phase 8     Phase 9
┌────────┐ ┌─────────┐ ┌────────┐ ┌─────────┐ ┌────────┐
│build-  │→│function-│→│git-    │→│summary- │→│git-    │
│tester  │ │tester   │ │committer│ │reporter │ │pusher  │
└────────┘ └─────────┘ └────────┘ └─────────┘ └────────┘
```

### 3.2 Agent Task Characteristic Classification

Each agent's **core task characteristics** are analyzed and classified into 3 categories:

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                        Agent Task Characteristic Analysis                            │
├──────────────────┬────────────┬───────────┬───────────┬───────────┬────────────────┤
│ Agent            │ Reasoning  │ Code Work │ Tool      │ Response  │ Category       │
│                  │ Intensity  │           │ Complexity│ Size      │                │
├──────────────────┼────────────┼───────────┼───────────┼───────────┼────────────────┤
│ Orchestrator     │ ★★★★★    │ ☆☆☆☆☆  │ ★★★☆☆  │ Medium    │ A. Reasoning-  │
│                  │            │           │           │           │    Intensive   │
│ code-reviewer    │ ★★★★★    │ ★★★☆☆  │ ★☆☆☆☆  │ Large     │ A. Reasoning-  │
│                  │            │           │           │           │    Intensive   │
│ quality-checker  │ ★★★★☆    │ ★★☆☆☆  │ ★★★☆☆  │ Medium    │ A. Reasoning-  │
│                  │            │           │           │           │    Intensive   │
│ summary-reporter │ ★★★★☆    │ ☆☆☆☆☆  │ ★★☆☆☆  │ Large     │ A. Reasoning-  │
│                  │            │           │           │           │    Intensive   │
├──────────────────┼────────────┼───────────┼───────────┼───────────┼────────────────┤
│ code-fixer       │ ★★★☆☆    │ ★★★★★  │ ★★★★☆  │ Large     │ B. Code-       │
│                  │            │           │           │           │    Intensive   │
│ pre-checker      │ ★☆☆☆☆    │ ★★★☆☆  │ ★★★★☆  │ Small     │ B. Code-       │
│                  │            │           │           │           │    Intensive   │
│ build-tester     │ ★★☆☆☆    │ ★★★☆☆  │ ★★★★★  │ Medium    │ B. Code-       │
│                  │            │           │           │           │    Intensive   │
│ function-tester  │ ★★☆☆☆    │ ★★★☆☆  │ ★★★★★  │ Medium    │ B. Code-       │
│                  │            │           │           │           │    Intensive   │
├──────────────────┼────────────┼───────────┼───────────┼───────────┼────────────────┤
│ env-setup        │ ★☆☆☆☆    │ ☆☆☆☆☆  │ ★★★☆☆  │ Small     │ C. Utility     │
│ git-input        │ ★☆☆☆☆    │ ☆☆☆☆☆  │ ★★☆☆☆  │ Small     │ C. Utility     │
│ git-committer    │ ★★☆☆☆    │ ☆☆☆☆☆  │ ★★☆☆☆  │ Small     │ C. Utility     │
│ git-pusher       │ ★☆☆☆☆    │ ☆☆☆☆☆  │ ★★☆☆☆  │ Small     │ C. Utility     │
│ workspace-analyzer│ ★★☆☆☆   │ ☆☆☆☆☆  │ ★★★☆☆  │ Medium    │ C. (DEPRECATED) │
└──────────────────┴────────────┴───────────┴───────────┴───────────┴────────────────┘
```

---

## 4. Dual Model Balancing Strategy

### 4.1 Model Assignment Principles

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                           Model Assignment Principles                                │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  Principle 1: "Agents where reasoning is core → Thinking Model"                      │
│    - Tasks requiring complex logical judgment, comprehensive analysis,               │
│      and scoring                                                                     │
│    - Tasks where CoT (Chain-of-Thought) reasoning directly impacts quality           │
│                                                                                      │
│  Principle 2: "Agents where code generation/modification is core → Coder Model"      │
│    - SWE-Bench style code modifications, bug fixes                                   │
│    - Tasks that read code and directly Edit                                           │
│    - Tasks that run Lint/Format/Build/Test tools                                     │
│                                                                                      │
│  Principle 3: "Simple tool execution agents → Coder Model (speed optimized)"         │
│    - Leverages fast response speed of Non-thinking mode                              │
│    - Utility tasks where Thinking overhead is unnecessary                            │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 4.2 Specific Model Assignments

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│              Qwen3.5-122B-A10B-FP8 Hybrid Mode Assignment Strategy                  │
│              (Single SGLang server, per-request enable_thinking control)             │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  ┌─ Thinking Mode (enable_thinking=true) ────────────────────────────────────────┐  │
│  │                                                                                │  │
│  │  [Phase 2] code-reviewer  ★ Core reasoning agent                              │  │
│  │    Reason: Deep analysis of security vulnerabilities, logical errors,          │  │
│  │    and code quality issues                                                     │  │
│  │    Characteristics: Uses only Read tool, discovers issues through              │  │
│  │    manual code reading via CoT                                                 │  │
│  │    Scope: Dedicated to issue discovery — external tool execution               │  │
│  │    is handled by quality-checker                                               │  │
│  │                                                                                │  │
│  │  [Phase 4] quality-checker                                                     │  │
│  │    Reason: Scoring after running external tools (linter, type checker,         │  │
│  │    complexity metrics)                                                          │  │
│  │    Scope: Dedicated to tool-based scoring — manual code reading                │  │
│  │    is handled by code-reviewer                                                 │  │
│  │                                                                                │  │
│  │  [Phase 8] summary-reporter                                                    │  │
│  │    Reason: Comprehensive analysis of all QA results to generate                │  │
│  │    meaningful reports                                                           │  │
│  │                                                                                │  │
│  └────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                      │
│  ┌─ Instruct Mode (enable_thinking=false) ───────────────────────────────────────┐  │
│  │                                                                                │  │
│  │  [Orchestrator] code-qa orchestrator                                           │  │
│  │    Reason: Uses Instruct mode for tool calling stability                       │  │
│  │                                                                                │  │
│  │  [Phase 3] code-fixer  ★ Core code agent                                     │  │
│  │    Reason: SWE-Bench 70.6% performance → optimal for actual code              │  │
│  │    modifications/bug fixes                                                     │  │
│  │    Characteristics: Read + Edit tools, directly modifies code                  │  │
│  │    Expected Effect: Reduced regression count, improved code quality            │  │
│  │                                                                                │  │
│  │  [Phase 1] pre-checker                                                         │  │
│  │    Reason: Lint/Format tool execution relies more on tool calling              │  │
│  │    than reasoning                                                               │  │
│  │    Expected Effect: Faster processing with Non-thinking                        │  │
│  │                                                                                │  │
│  │  [Phase 5] build-tester                                                        │  │
│  │    Reason: Build command execution and result interpretation,                  │  │
│  │    code comprehension focused                                                   │  │
│  │    Expected Effect: Improved build error interpretation capability             │  │
│  │                                                                                │  │
│  │  [Phase 6] function-tester                                                     │  │
│  │    Reason: Test execution and result analysis, code comprehension focused      │  │
│  │    Expected Effect: Improved test failure root cause analysis capability       │  │
│  │                                                                                │  │
│  │  [Phase -1] env-setup                                                          │  │
│  │    Reason: Environment detection is simple tool execution, CoT unnecessary    │  │
│  │    Expected Effect: Faster environment setup completion                        │  │
│  │                                                                                │  │
│  │  [Phase 0] git-input                                                           │  │
│  │    Reason: Git command execution and file list extraction, CoT unnecessary    │  │
│  │                                                                                │  │
│  │  [Phase 7] git-committer                                                       │  │
│  │    Reason: Commit message generation is based on code understanding,           │  │
│  │    CoT unnecessary                                                              │  │
│  │                                                                                │  │
│  │  [Phase 9] git-pusher                                                          │  │
│  │    Reason: Git/GitHub/GitLab CLI execution, CoT unnecessary                   │  │
│  │                                                                                │  │
│  │  [Phase 0B] workspace-analyzer                                                 │  │
│  │    Reason: File system exploration and structure analysis,                     │  │
│  │    code comprehension based                                                     │  │
│  │                                                                                │  │
│  └────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 4.3 Assignment Ratio Summary

```
┌───────────────────────────────────────────────────────────────────┐
│                    Agent Assignment Ratio by Model                 │
├───────────────────────────────────────────────────────────────────┤
│                                                                    │
│  Thinking Model: 4 (Orchestrator + 3 Agents)                      │
│  ├── Orchestrator (code-qa)                                       │
│  ├── code-reviewer     (Phase 2)                                  │
│  ├── quality-checker   (Phase 4)                                  │
│  └── summary-reporter  (Phase 8)                                  │
│                                                                    │
│  Coder Model: 10 Agents                                           │
│  ├── env-setup           (Phase -1)                               │
│  ├── workspace-analyzer  (Phase 0B)                               │
│  ├── git-input           (Phase 0)                                │
│  ├── file-input          (Non-Git Input)                          │
│  ├── pre-checker         (Phase 1)                                │
│  ├── code-fixer          (Phase 3)   ★ Biggest Impact            │
│  ├── build-tester        (Phase 5)                                │
│  ├── function-tester     (Phase 6)                                │
│  ├── git-committer       (Phase 7)                                │
│  └── git-pusher          (Phase 9)                                │
│                                                                    │
│  Ratio: Thinking 29% vs Coder 71% (by agent count, 4:10)         │
│  Reasoning Load: Thinking 60% vs Coder 40% (by inference time,   │
│  estimated)                                                        │
│                                                                    │
└───────────────────────────────────────────────────────────────────┘
```

### 4.4 Workflow Visualization (Dual Model)

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                            Dual Model Workflow                                       │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  ═══ Thinking Model (Reasoning) ══════════════════════════════════════════════     │
│                                                                                      │
│        [Orchestrator: Thinking]                                                      │
│            │       │       │       │                                                  │
│            ▼       ▼       ▼       ▼                                                  │
│                                                                                      │
│  ═══ Coder Model (Code) ═════    ═══ Thinking Model ═══    ═══ Coder Model ═══     │
│                                                                                      │
│  Phase -1  Phase 0   Phase 1   Phase 2     Phase 3   Phase 4     Phase 5-6          │
│  ┌──────┐ ┌──────┐  ┌──────┐  ┌────────┐  ┌──────┐ ┌────────┐  ┌────────┐          │
│  │Coder │→│Coder │→ │Coder │→ │Thinking│→ │Coder │→│Thinking│→ │ Coder  │          │
│  │env-  │ │git-  │  │pre-  │  │review  │  │fixer │ │quality │  │build/  │          │
│  │setup │ │input │  │check │  │(CoT)   │  │(SWE) │ │check   │  │test    │          │
│  └──────┘ └──────┘  └──────┘  └────────┘  └──────┘ └────────┘  └────────┘          │
│                                                                                      │
│  ═══ Coder Model ═══          ═══ Thinking Model ═══   ═══ Coder Model ═══          │
│                                                                                      │
│  Phase 7              Phase 8                Phase 9                                 │
│  ┌──────┐            ┌─────────┐            ┌──────┐                                │
│  │Coder │──────────→ │Thinking │──────────→ │Coder │                                │
│  │commit│            │summary  │            │push  │                                │
│  └──────┘            │(CoT)    │            └──────┘                                │
│                      └─────────┘                                                     │
│                                                                                      │
│  Legend: ███ Thinking Model    ███ Coder Model                                      │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 5. Context Window Sharing and Management Strategy

### 5.1 Core Problem

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                          Context Sharing Problem Definition                          │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  LLMs are fundamentally Stateless systems of "prompt input → result output".         │
│  The following problems arise when using two models:                                 │
│                                                                                      │
│  1. Model A (Thinking) reasoning results must be passed to Model B (Coder)          │
│  2. Model B's code modification results must be passed back to Model A              │
│  3. Each model call is an independent inference session → no prior conversation     │
│     history                                                                          │
│  4. The orchestrator must include all state in the prompt                            │
│  5. As prompt size grows, token cost + latency increases                             │
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────┐                 │
│  │  Model A (Thinking)          Model B (Coder)                    │                 │
│  │  ┌──────────────────┐       ┌──────────────────┐               │                 │
│  │  │ Prompt: 50K tok  │       │ Prompt: 80K tok  │               │                 │
│  │  │ (Analysis request)│      │ (Code modification │               │                │
│  │  │                  │       │  request)          │               │                │
│  │  │ Output: 8K tok   │──────▶│ + Previous analysis│               │                │
│  │  │ (Analysis result)│  ???  │   results          │               │                │
│  │  │                  │       │ + Full code content │               │                │
│  │  └──────────────────┘       └──────────────────┘               │                 │
│  │                                                                 │                 │
│  │  Key question: How to efficiently transfer Context?              │                 │
│  └─────────────────────────────────────────────────────────────────┘                 │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 5.2 Strategy: Orchestrator-Mediated Context Protocol (OMCP)

The orchestrator acts as a **Context Broker** to manage context between the two models.

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                    Orchestrator-Mediated Context Protocol                             │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│                     ┌──────────────────────────────┐                                 │
│                     │    Orchestrator (Thinking)    │                                 │
│                     │                              │                                 │
│                     │  ┌────────────────────────┐  │                                 │
│                     │  │   State Store           │  │                                 │
│                     │  │                        │  │                                 │
│                     │  │  ENV_STATE: {...}       │  │                                 │
│                     │  │  changed_files: [...]   │  │                                 │
│                     │  │  review_issues: [...]   │  │                                 │
│                     │  │  quality_score: 85      │  │                                 │
│                     │  │  build_result: "..."    │  │                                 │
│                     │  │  test_result: "..."     │  │                                 │
│                     │  │  workspace_cache: {...} │  │                                 │
│                     │  └────────────────────────┘  │                                 │
│                     │            │                  │                                 │
│                     │    ┌───────┴───────┐          │                                 │
│                     │    │ Prompt Builder │          │                                 │
│                     │    │ (Context       │          │                                 │
│                     │    │  Selection)    │          │                                 │
│                     │    └───────┬───────┘          │                                 │
│                     └────────────┼──────────────────┘                                 │
│                         ┌────────┼────────┐                                           │
│                         ▼                 ▼                                           │
│               ┌──────────────┐   ┌──────────────┐                                    │
│               │ Thinking API │   │  Coder API   │                                    │
│               │  :8000       │   │  :8001       │                                    │
│               └──────────────┘   └──────────────┘                                    │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 5.3 Context Transfer Layer Structure

Data transferred between agents is classified into 3 layers for efficient management:

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                       Context Transfer 3-Layer Model                                 │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  Layer 1: Structured Tokens (always transferred, small)                              │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━       │
│  • ENV_STATE (shell, environment, Python path, activation commands)                  │
│  • FILE_LIST (list of changed file paths)                                            │
│  • QUALITY_SCORE (quality score)                                                     │
│  • BUILD_RESULT / TEST_RESULT (SUCCESS/FAIL)                                        │
│  • COMMIT_RESULT (commit hash)                                                       │
│  → Size: approximately 1-3K tokens                                                   │
│  → Included in prompt for all agent calls                                            │
│                                                                                      │
│  Layer 2: Summarized Context (transferred when needed, medium)                       │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━       │
│  • ISSUE_LIST (code review issue summary)                                            │
│  • workspace_cache (project structure summary JSON)                                  │
│  • Build/test error logs (only key parts extracted)                                   │
│  → Size: approximately 3-10K tokens                                                  │
│  → Selectively transferred to relevant agents only                                   │
│                                                                                      │
│  Layer 3: Raw Content (transferred minimally, large)                                 │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━       │
│  • Source code file contents (agent reads directly with Read tool)                    │
│  • Full build logs                                                                   │
│  • Full test output                                                                  │
│  → Size: 10K-200K+ tokens                                                            │
│  → Agent obtains directly with its own tools when needed                             │
│    (not included in prompt)                                                           │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 5.4 Per-Agent Context Budget Design

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                     Per-Agent Context Budget Plan                                    │
├──────────────────┬──────────┬──────────────┬────────────┬────────────────────────────┤
│ Agent            │ Model    │ Prompt Budget │ Self-      │ Received Context           │
│                  │          │              │ Acquired   │                            │
├──────────────────┼──────────┼──────────────┼────────────┼────────────────────────────┤
│ env-setup        │ Coder    │ ~5K          │ Bash output│ PROJECT_ROOT               │
│ workspace-analyzer│ Coder   │ ~5K          │ Glob/Read  │ PROJECT_ROOT               │
│ git-input        │ Coder    │ ~5K          │ Bash(git)  │ PROJECT_ROOT               │
│ pre-checker      │ Coder    │ ~8K          │ Bash(lint) │ L1 + FILE_LIST             │
│ code-reviewer    │ Thinking │ ~15K         │ Read       │ L1 + FILE_LIST + cache     │
│ code-fixer       │ Coder    │ ~20K         │ Read/Edit  │ L1 + L2(ISSUE_LIST)        │
│ quality-checker  │ Thinking │ ~10K         │ Bash       │ L1 + FILE_LIST             │
│ build-tester     │ Coder    │ ~10K         │ Bash       │ L1 + ENV_STATE             │
│ function-tester  │ Coder    │ ~10K         │ Bash       │ L1 + ENV_STATE             │
│ git-committer    │ Coder    │ ~8K          │ Bash(git)  │ L1 + FILE_LIST             │
│ summary-reporter │ Thinking │ ~15K         │ Bash(git)  │ L1 + L2(All Results)       │
│ git-pusher       │ Coder    │ ~5K          │ Bash(git)  │ L1                         │
├──────────────────┼──────────┼──────────────┼────────────┼────────────────────────────┤
│ Total (sequential│          │ ~116K (max)  │            │ Sufficiently operable      │
│ execution)       │          │              │            │ within 256K                │
└──────────────────┴──────────┴──────────────┴────────────┴────────────────────────────┘
```

### 5.5 Detailed Context Transfer Flow

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                     Phase 2→3 Transition Example (Thinking → Coder)                  │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  [Phase 2: code-reviewer on Thinking Model]                                          │
│                                                                                      │
│  Input Prompt:                                                                       │
│    System: code-reviewer.md agent prompt                                             │
│    User: "PROJECT_ROOT: /home/user/project                                           │
│           Changed files:                                                              │
│           - /home/user/project/src/app.py                                            │
│           - /home/user/project/src/utils.py"                                         │
│                                                                                      │
│  Model Internal: <think> Reading and analyzing code... SQL injection found... </think>│
│                                                                                      │
│  Output:                                                                              │
│    "ISSUE_LIST:                                                                       │
│     [C001] /home/user/project/src/app.py:45 - SQL injection vulnerability            │
│     [H001] /home/user/project/src/utils.py:78 - Null reference possible"             │
│                                                                                      │
│  ────── Orchestrator parses ISSUE_LIST ──────                                        │
│                                                                                      │
│  [Phase 3: code-fixer on Coder Model]                                                │
│                                                                                      │
│  Input Prompt (constructed by Orchestrator):                                          │
│    System: code-fixer.md agent prompt                                                 │
│    User: "Fix the following issues:                                                   │
│                                                                                      │
│           ISSUE_LIST:                                                                 │
│           [C001] /home/user/project/src/app.py:45 - SQL injection vulnerability      │
│           [H001] /home/user/project/src/utils.py:78 - Null reference possible        │
│                                                                                      │
│           Target files:                                                               │
│           - /home/user/project/src/app.py                                            │
│           - /home/user/project/src/utils.py"                                         │
│                                                                                      │
│  Coder Model: (no thinking) → Directly calls Read + Edit tools to modify code        │
│                                                                                      │
│  Output: "FIX_RESULT: SUCCESS, FIXED_FILES: 2, ISSUES_FIXED: 2"                     │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 5.6 Context Management in Regression Loops

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                   Regression Loop Context Management Strategy                        │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  When regression occurs (quality < 70% or build/test failure):                       │
│                                                                                      │
│  Accumulated in Orchestrator State:                                                  │
│  ┌────────────────────────────────────────────────────────┐                          │
│  │  retry_counters = {                                    │                          │
│  │    "quality": 1,  # per-source (max 3)                 │                          │
│  │    "build": 0,    # per-source (max 3)                 │                          │
│  │    "test": 0      # per-source (max 3)                 │                          │
│  │  }                                                     │                          │
│  │  total_regressions = 1  # TOTAL_CAP = 5                │                          │
│  │  regression_history = [...]  ← Accumulated regression  │                          │
│  │                                  history               │                          │
│  │  error_context = "build failed: ..."  ← Error log      │                          │
│  │                                          summary       │                          │
│  └────────────────────────────────────────────────────────┘                          │
│                                                                                      │
│  Additional Context to include in code-fixer prompt during regression:               │
│  ┌────────────────────────────────────────────────────────┐                          │
│  │  "Issue [H001] was not resolved in the previous fix    │                          │
│  │   attempt.                                             │                          │
│  │   Previous attempt result: {error_context}             │                          │
│  │   Please fix using a different approach."              │                          │
│  └────────────────────────────────────────────────────────┘                          │
│                                                                                      │
│  Context Growth Management:                                                          │
│  ┌────────────────────────────────────────────────────────┐                          │
│  │  Regression 1st: Prompt +3K tokens (previous issue +   │                          │
│  │                  error summary)                         │                          │
│  │  Regression 2nd: Prompt +5K tokens (accumulated        │                          │
│  │                  history)                               │                          │
│  │  Regression 3rd: Prompt +7K tokens (full history)      │                          │
│  │  → PER_SOURCE_MAX=3, TOTAL_CAP=5, so growth is limited│                          │
│  │  → timeout_guard: skip regression if exceeds 85%       │                          │
│  └────────────────────────────────────────────────────────┘                          │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 6. Infrastructure Deployment Strategy

### 6.1 Server Configuration

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                          Infrastructure Deployment Configuration                     │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  Option A: Separate GPU Nodes (Recommended)                                          │
│  ══════════════════════════════                                                       │
│                                                                                      │
│  ┌──────────────────────────┐    ┌──────────────────────────┐                        │
│  │   GPU Node 1             │    │   GPU Node 2             │                        │
│  │   H100 NVL 96GB x2      │    │   H100 NVL 96GB x2      │                        │
│  │                          │    │                          │                        │
│  │   Thinking Model         │    │   Coder Model            │                        │
│  │   SGLang :8000           │    │   SGLang :8001           │                        │
│  │   TP=2, 256K context     │    │   TP=2, 256K context     │                        │
│  └─────────────┬────────────┘    └─────────────┬────────────┘                        │
│                │                                │                                     │
│                └────────────┬───────────────────┘                                     │
│                             │                                                         │
│                    ┌────────▼────────┐                                                │
│                    │  Load Balancer  │                                                │
│                    │  (Nginx/HAProxy)│                                                │
│                    │                 │                                                │
│                    │  /v1/thinking/* │──→ :8000                                       │
│                    │  /v1/coder/*    │──→ :8001                                       │
│                    └─────────────────┘                                                │
│                                                                                      │
│  Option B: Single Node 4-GPU (Cost Saving)                                           │
│  ══════════════════════════════════                                                    │
│                                                                                      │
│  ┌──────────────────────────────────────────────────────────┐                        │
│  │   GPU Node 1: H100 NVL 96GB x4                          │                        │
│  │                                                          │                        │
│  │   GPU 0,1: Thinking Model (SGLang :8000, TP=2)          │                        │
│  │   GPU 2,3: Coder Model    (vLLM :8001, TP=2)            │                        │
│  └──────────────────────────────────────────────────────────┘                        │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 6.2 SGLang Deployment Commands

```bash
# Thinking Model (Port 8000)
python3 -m sglang.launch_server \
  --model Qwen/Qwen3-Next-80B-A3B-Thinking-FP8 \
  --tp 2 \
  --context-length 262144 \
  --port 8000 \
  --host 0.0.0.0 \
  --mem-fraction-static 0.85

# Coder Model (Port 8001) — vLLM
python3 -m vllm.entrypoints.openai.api_server \
  --model Qwen/Qwen3-Coder-Next-FP8 \
  --served-model-name Qwen3-Coder-Next-FP8 \
  --tensor-parallel-size 2 \
  --max-model-len 262144 \
  --port 8001 \
  --host 0.0.0.0
```

### 6.3 OpenCode Configuration Change Proposal

```jsonc
{
  // Actual implemented Provider settings (opencode.jsonc)
  "provider": {
    "qwen": {
      "name": "Qwen3-Next-Thinking (Reasoning)",
      "npm": "@ai-sdk/openai-compatible",
      "api": "http://localhost:8000/v1",
      "env": [],
      "options": {
        "apiKey": "dummy",
        "baseURL": "http://localhost:8000/v1"
      },
      "models": {
        "Qwen3-Next-80B-A3B-Thinking-FP8": {
          "name": "Qwen3-Next-80B-A3B-Thinking-FP8",
          "id": "Qwen3-Next-80B-A3B-Thinking-FP8",
          "tool_call": true,
          "temperature": true,
          "reasoning": true,
          "attachment": false,
          "modalities": { "input": ["text"], "output": ["text"] },
          "limit": { "context": 262144, "output": 16384 },
          "cost": { "input": 0, "output": 0 }
        }
      }
    },
    "qwen-coder": {
      "name": "Qwen3-Coder-Next (Code)",
      "npm": "@ai-sdk/openai-compatible",
      "api": "http://localhost:8001/v1",
      "env": [],
      "options": {
        "apiKey": "dummy",
        "baseURL": "http://localhost:8001/v1"
      },
      "models": {
        "Qwen3-Coder-Next-FP8": {
          "name": "Qwen3-Coder-Next-FP8",
          "id": "Qwen3-Coder-Next-FP8",
          "tool_call": true,
          "temperature": true,
          "reasoning": false,
          "attachment": false,
          "modalities": { "input": ["text"], "output": ["text"] },
          "limit": { "context": 262144, "output": 16384 },
          "cost": { "input": 0, "output": 0 }
        }
      }
    }
  }
}
```

### 6.4 Agent Configuration Change Proposal

Change the `model` field in each agent `.md` file's frontmatter:

```yaml
# Thinking model agents (4)
# code-qa.md (mode), code-reviewer.md, quality-checker.md, summary-reporter.md
model: qwen/Qwen3-Next-80B-A3B-Thinking-FP8

# Coder model agents (10)
# env-setup.md, git-input.md, file-input.md, workspace-analyzer.md,
# pre-checker.md, code-fixer.md, build-tester.md, function-tester.md,
# git-committer.md, git-pusher.md
model: qwen-coder/Qwen3-Coder-Next-FP8
```

---

## 7. Expected Impact Analysis

### 7.1 Expected Performance Improvements

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                          Expected Impact Analysis                                    │
├──────────────────────┬─────────────────────────┬────────────────────────────────────┤
│ Metric               │ Current (Single Model)   │ Dual Model Expected               │
├──────────────────────┼─────────────────────────┼────────────────────────────────────┤
│ Code Fix Quality     │ Baseline (Thinking-based)│ Improved (SWE-Bench 70.6% model)  │
│ Secure Code Gen      │ Good                     │ Very Good (exceeds Opus 4.5)       │
│ Regression Count     │ Average 1-2 times        │ Average 0-1 times (expected)       │
│ Total Workflow Time  │ Baseline (100%)           │ ~70-80% (estimated)                │
│ Utility Agent Speed  │ Has Thinking overhead     │ 30-40% faster with Non-thinking    │
│ Token Efficiency     │ Consumes think tokens     │ Increased useful output ratio      │
│ GPU Utilization      │ 1 server 100%             │ 2 servers each ~50-70%             │
│                      │                           │ (parallelizable)                   │
├──────────────────────┴─────────────────────────┴────────────────────────────────────┤
│ Overall Assessment: Expected improvement in code fix quality + workflow speed +      │
│ reduced regression frequency                                                         │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### 7.2 Risk Factors and Mitigation

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                          Risk Factors and Mitigation                                 │
├──────────────────────┬──────────────────────────┬───────────────────────────────────┤
│ Risk                 │ Impact                    │ Mitigation                         │
├──────────────────────┼──────────────────────────┼───────────────────────────────────┤
│ Increased infra cost │ 2x GPU servers            │ Use Option B (single 4-GPU node)  │
│ Style mismatch       │ Code/analysis tone         │ Unify output format in agent      │
│ between models       │ differences               │ prompts                            │
│ One server failure   │ Workflow interruption      │ Fallback: switch to remaining     │
│                      │                            │ model                             │
│ Coder model lacking  │ Possible insufficient      │ Keep reasoning-critical agents    │
│ reasoning            │ complex judgment           │ on Thinking                       │
│ Context transfer     │ Agent execution failure    │ OMCP Layer 1 required token       │
│ missing              │                            │ validation                        │
│ Inference engine     │ Serving failure             │ SGLang >= 0.5.8, vLLM >= 0.15.0  │
│ version compat.      │                            │                                   │
└──────────────────────┴──────────────────────────┴───────────────────────────────────┘
```

### 7.3 Fallback Strategy

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                          Fallback Strategy                                            │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  When Coder server fails:                                                            │
│  → Fallback all Coder agents to Thinking model                                      │
│  → Performance degradation but workflow can continue                                 │
│    (same as current single model)                                                    │
│                                                                                      │
│  When Thinking server fails:                                                         │
│  → Fallback Orchestrator + reasoning agents to Coder model                          │
│  → Reasoning quality may degrade but code tasks perform normally                    │
│  → Expected reduction in analysis depth for quality-checker,                        │
│    summary-reporter                                                                  │
│                                                                                      │
│  Implementation method:                                                              │
│  Add fallback settings to workflow-settings.yaml:                                    │
│                                                                                      │
│  model:                                                                               │
│    thinking: "qwen/Qwen3-Next-80B-A3B-Thinking-FP8"                                 │
│    coder: "qwen-coder/Qwen3-Coder-Next-FP8"                                         │
│    fallback: "qwen/Qwen3-Next-80B-A3B-Thinking-FP8"  # Switch on failure            │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 8. Implementation Roadmap

### Phase 1: Infrastructure Preparation ✅ Complete
- [x] Download and internal transfer of Qwen3-Coder-Next-FP8 model
- [x] GPU node deployment (Option A: 2 separate nodes)
- [x] SGLang (Thinking, port 8000) + vLLM (Coder, port 8001) serving
- [x] Endpoint health check and inference testing

### Phase 2: Configuration Changes ✅ Complete
- [x] Add `qwen` + `qwen-coder` dual providers to opencode.jsonc
- [x] Change `model` field to Coder model in 10 agent `.md` files
- [x] Reflect dual model in `model` field of 9 command `.md` files
- [x] Add dual model settings to workflow-settings.yaml
- [x] Add Fallback settings

### Phase 3: Integration Testing (In Progress)
- [ ] Individual testing of each agent (Coder model)
- [ ] Full workflow E2E testing
- [ ] Regression loop testing (Context transfer verification)
- [ ] Fallback scenario testing

### Phase 4: Optimization
- [ ] Context budget monitoring and optimization
- [ ] Workflow speed benchmarking (single vs dual)
- [ ] Code fix quality comparison (SWE-Bench style)
- [ ] Production deployment

---

## 9. Conclusion

| Conclusion Item | Summary |
|-----------|------|
| **Model Assignment** | Thinking 4 (reasoning-intensive) + Coder 10 (code/utility) |
| **Context Management** | Orchestrator acts as Context Broker with 3-Layer protocol |
| **Key Improvements** | Leveraging code-fixer's SWE-Bench performance, Non-thinking speed advantage |
| **Infrastructure** | 2x H100 NVL addition (or single 4-GPU node) |
| **Risk Management** | Fallback strategy maintains single-model operability |

The two models share the **same Base architecture**, so the Tool Calling format in agent prompts is compatible. This means minimal prompt modifications when switching models, and dual model switching is possible by simply changing the `model` field.

---

*Generated: 2026-02-05*
*Author: Code QA Analysis System*
