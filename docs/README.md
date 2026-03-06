# OpenCode Documentation / 문서 안내

All guides are available in **English (.en.md)** and **Korean (.kr.md)**.
모든 가이드는 **영어 (.en.md)** 와 **한국어 (.kr.md)** 두 가지 언어로 제공됩니다.

---

## Core Guides / 핵심 가이드

Fundamental guides for using OpenCode's platform features.
OpenCode 플랫폼의 핵심 기능 사용 가이드입니다.

| # | Guide | EN | KR |
|---|-------|----|----|
| 01 | MCP Connection Guide | [EN](core/01-mcp-connection-guide.en.md) | [KR](core/01-mcp-connection-guide.kr.md) |
| 02 | Custom Agent Guide | [EN](core/02-custom-agent-guide.en.md) | [KR](core/02-custom-agent-guide.kr.md) |
| 03 | External Tools Guide | [EN](core/03-external-tools-guide.en.md) | [KR](core/03-external-tools-guide.kr.md) |
| 04 | Git Rebase Workflow | [EN](core/04-git-rebase-workflow.en.md) | [KR](core/04-git-rebase-workflow.kr.md) |

---

## Code QA Workflow / 코드 QA 워크플로우

Complete documentation for the Code QA v4 pipeline.
Code QA v4 파이프라인 관련 전체 문서입니다.

| # | Guide | EN | KR |
|---|-------|----|----|
| 01 | Quick Start | [EN](code-qa/01-quick-start.en.md) | [KR](code-qa/01-quick-start.kr.md) |
| 02 | Architecture (Complete Diagram) | [EN](code-qa/02-architecture.en.md) | [KR](code-qa/02-architecture.kr.md) |
| 03 | Environment Setup | [EN](code-qa/03-environment-setup.en.md) | [KR](code-qa/03-environment-setup.kr.md) |
| 04 | Workspace Analysis | [EN](code-qa/04-workspace-analysis.en.md) | [KR](code-qa/04-workspace-analysis.kr.md) |
| 05 | Implementation Summary | [EN](code-qa/05-implementation-summary.en.md) | [KR](code-qa/05-implementation-summary.kr.md) |
| 06 | Scenario Testing & Case Review | [EN](code-qa/06-scenario-testing.en.md) | [KR](code-qa/06-scenario-testing.kr.md) |
| 07 | DeepWiki Workflow | [EN](code-qa/07-deepwiki-workflow.en.md) | [KR](code-qa/07-deepwiki-workflow.kr.md) |

---

## Infrastructure / 인프라스트럭처

Model strategy, deployment, and enterprise setup guides.
모델 전략, 배포, 기업 환경 설정 가이드입니다.

| # | Guide | EN | KR |
|---|-------|----|----|
| 01 | Model Strategy | [EN](infrastructure/01-model-strategy.en.md) | [KR](infrastructure/01-model-strategy.kr.md) |
| 02 | Open Weight Models | [EN](infrastructure/02-open-weight-models.en.md) | [KR](infrastructure/02-open-weight-models.kr.md) |
| 03 | Enterprise Air-Gapped Setup | [EN](infrastructure/03-enterprise-air-gapped.en.md) | [KR](infrastructure/03-enterprise-air-gapped.kr.md) |

---

## Advanced / 심화

Deep analysis and long-term roadmap documents.
심화 분석 및 장기 로드맵 문서입니다.

| # | Guide | EN | KR |
|---|-------|----|----|
| 01 | MCP Deep Analysis | [EN](advanced/01-mcp-deep-analysis.en.md) | [KR](advanced/01-mcp-deep-analysis.kr.md) |
| 02 | Indexing Roadmap | [EN](advanced/02-indexing-roadmap.en.md) | [KR](advanced/02-indexing-roadmap.kr.md) |

---

## Directory Structure / 디렉토리 구조

```
docs/
├── README.md                              ← You are here
├── core/                                  (4 guides × 2 languages)
│   ├── 01-mcp-connection-guide.{en,kr}.md
│   ├── 02-custom-agent-guide.{en,kr}.md
│   ├── 03-external-tools-guide.{en,kr}.md
│   └── 04-git-rebase-workflow.{en,kr}.md
├── code-qa/                               (7 guides × 2 languages)
│   ├── 01-quick-start.{en,kr}.md
│   ├── 02-architecture.{en,kr}.md
│   ├── 03-environment-setup.{en,kr}.md
│   ├── 04-workspace-analysis.{en,kr}.md
│   ├── 05-implementation-summary.{en,kr}.md
│   ├── 06-scenario-testing.{en,kr}.md
│   └── 07-deepwiki-workflow.{en,kr}.md
├── infrastructure/                        (3 guides × 2 languages)
│   ├── 01-model-strategy.{en,kr}.md
│   ├── 02-open-weight-models.{en,kr}.md
│   └── 03-enterprise-air-gapped.{en,kr}.md
└── advanced/                              (2 guides × 2 languages)
    ├── 01-mcp-deep-analysis.{en,kr}.md
    └── 02-indexing-roadmap.{en,kr}.md
```

**Total: 16 guides × 2 languages = 32 files**

Previously: 20 files in flat `docs/guides/` directory, mixed languages, inconsistent numbering.
