# Code QA v4 다이어그램

이 폴더에는 Code QA v4 워크플로우의 Mermaid 다이어그램이 포함되어 있습니다.

## 다이어그램 목록

| 파일 | 설명 | 용도 |
|------|------|------|
| `code-qa-v4-pipeline.mmd` | 전체 파이프라인 상세 다이어그램 | 기술 문서, 상세 설명 |
| `code-qa-v4-simple.mmd` | 단순화된 선형 파이프라인 | 빠른 개요, 소개 |
| `code-qa-v4-timeline.mmd` | 세로형 타임라인 스타일 | PPT 프레젠테이션 |
| `code-qa-v4-sequence.mmd` | 시퀀스 다이어그램 | Agent 간 상호작용 |

## 이미지 변환 방법

### 방법 1: Mermaid Live Editor (권장)

1. https://mermaid.live 접속
2. `.mmd` 파일 내용 복사/붙여넣기
3. Actions → Export PNG/SVG

### 방법 2: CLI 도구

```bash
# mermaid-cli 설치
npm install -g @mermaid-js/mermaid-cli

# PNG 변환
mmdc -i code-qa-v4-pipeline.mmd -o code-qa-v4-pipeline.png -b white -w 1920

# SVG 변환
mmdc -i code-qa-v4-pipeline.mmd -o code-qa-v4-pipeline.svg

# 모든 파일 일괄 변환
for f in *.mmd; do mmdc -i "$f" -o "${f%.mmd}.png" -b white -w 1920; done
```

### 방법 3: VS Code 확장

1. "Mermaid Preview" 또는 "Markdown Preview Mermaid Support" 설치
2. `.mmd` 파일 열기
3. 미리보기에서 우클릭 → 이미지 저장

## PPT에서 사용하기

1. 위 방법으로 PNG 또는 SVG 생성
2. PowerPoint → 삽입 → 그림
3. 또는 SVG를 직접 PowerPoint에 삽입 (벡터 유지)

## 다이어그램 미리보기

### 1. 전체 파이프라인 (Pipeline)

```mermaid
flowchart LR
    P0[Workspace] --> P1[Setup] --> P2[Input] --> P3[Pre-Check]
    P3 --> P4[Review] --> P5[Fix] --> P6[Quality]
    P6 --> P7[Build] --> P8[Test] --> P9[Commit]
    P9 --> P10[Report] --> P11[Push]
```

### 2. Phase 색상 범례

| 색상 | Phase | 설명 |
|------|-------|------|
| 🟣 보라 | Phase 0 | Workspace Analysis |
| ⚪ 회색 | Phase 1-2 | Setup & Input |
| 🔵 파랑 | Phase 3-6 | Host QA |
| 🟠 주황 | Phase 7-8 | Docker Sandbox |
| 🟢 초록 | Phase 9-11 | Git Operations |

## 커스터마이징

테마 변경:
```mermaid
%%{init: {'theme': 'dark'}}%%
```

사용 가능한 테마: `default`, `base`, `dark`, `forest`, `neutral`

## 관련 문서

- [Code QA v4 Quick Start](../guides/14-code-qa-v4-quick-start.md)
- [Complete Diagram](../guides/13-code-qa-v4-complete-diagram.md)
- [Workspace Analysis Workflow](../guides/15-workspace-analysis-workflow.md)
