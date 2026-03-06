# DeepWiki 문서 생성 워크플로우

## 개요

`/deepwiki` 명령은 프로젝트에 대한 종합적이고 탐색 가능한 기술 위키를 생성합니다
-- [DeepWiki](https://deepwiki.com)와 유사하게 -- mermaid 다이어그램, 코드 참조,
교차 링크된 페이지를 포함합니다. 모든 것이 AI 에이전트를 통해 로컬에서 실행됩니다.

## 아키텍처

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
│  (Phase 5: publish — HITL deployment)   │
│  (Phase 6: output summary)             │
└──────────────┬──────────────────────────┘
               │ Task tool (parallel)
               ▼
┌──────────┐ ┌──────────┐ ┌──────────┐
│ wiki-page│ │ wiki-page│ │ wiki-page│  ... (8-12 pages)
│ generator│ │ generator│ │ generator│
│ agent    │ │ agent    │ │ agent    │
└──────────┘ └──────────┘ └──────────┘
```

### 에이전트

| 에이전트 | 역할 | 도구 |
|----------|------|------|
| `deepwiki` | 오케스트레이터: 컨텍스트 수집, 구조 계획, 위임, 조립 | Task, Read, Write, Bash, Glob, Grep |
| `wiki-page-generator` | 다이어그램과 코드 참조를 포함한 위키 페이지 1개 생성 | Read, Glob, Bash, Grep (읽기 전용) |

## 사용법

```bash
/deepwiki              # 전체 위키 (8-12 페이지)
/deepwiki --concise    # 간결한 위키 (4-6 페이지)
/deepwiki --force      # 기존 위키 덮어쓰기
/deepwiki --module api # 특정 모듈 페이지만 재생성
```

### 캐시 확인 (HITL)

`/deepwiki` 시작 시 워크스페이스 캐시를 확인하고 사용자에게 질문합니다:

| 캐시 상태 | 제시되는 옵션 |
|-----------|--------------|
| **최신** (< 24시간) | 캐시 사용 / 새로고침 / 캐시 없이 생성 |
| **만료** (> 24시간) | 캐시 새로고침 / 만료된 캐시 사용 / 캐시 없이 생성 |
| **없음** | /analyze 먼저 실행 / 캐시 없이 생성 |

사용자가 `/analyze` 실행을 선택하면 위키 생성 전에 자동으로 실행됩니다.
별도로 `/analyze`를 실행할 필요가 없습니다.

### 수동 워크플로우 (대안)

```bash
# Step 1: 프로젝트 분석 (tier 정보 포함 워크스페이스 캐시 빌드)
/analyze

# Step 2: 위키 생성 (더 빠르고 풍부한 결과를 위해 캐시 사용)
/deepwiki
```

## 출력 구조

```
docs/wiki/
├── index.md                    # 프로젝트 개요 + 탐색 테이블이 포함된 메인 페이지
├── _sidebar.md                 # 사이드바 탐색 (위키 렌더러용)
├── .wiki-structure.yaml        # 위키 구조 메타데이터 (페이지, 섹션, 계층)
├── 01-overview.md              # 프로젝트 개요 및 시작하기
├── 02-architecture.md          # mermaid 다이어그램 포함 시스템 아키텍처
├── 03-{module-a}.md            # 핵심 모듈 문서
├── 04-{module-b}.md            # 핵심 모듈 문서
├── ...                         # 추가 모듈 페이지
├── {N-1}-configuration.md      # 설정 및 배포
└── {N}-development-guide.md    # 개발 가이드 및 기여
```

## 페이지 내용

생성된 모든 페이지에는 다음이 포함됩니다:

| 요소 | 설명 |
|------|------|
| **H1 제목** | 위키 구조에 맞는 페이지 제목 |
| **소개** | 이 페이지에서 다루는 내용과 중요한 이유 |
| **Mermaid 다이어그램** | 페이지당 최소 1개: flowchart, sequence, class, ER, state |
| **코드 스니펫** | 파일 경로 참조 포함 (`file.ts:L10-25`) |
| **소스 인용** | 섹션별 실제 소스 파일 참조 |
| **관련 페이지** | 관련 위키 페이지로의 교차 링크 |

### 사용되는 다이어그램 유형

| 다이어그램 | 사용 시점 |
|-----------|-----------|
| `flowchart TD/LR` | 아키텍처, 데이터 흐름, 컴포넌트 연결 |
| `sequenceDiagram` | API 라이프사이클, 요청 처리, 이벤트 흐름 |
| `classDiagram` | 모듈 관계, 상속, 합성 |
| `erDiagram` | 데이터베이스 스키마, 엔티티 관계 |
| `stateDiagram-v2` | 상태 머신, 워크플로우 상태 |

## 워크스페이스 캐시와의 통합

`/deepwiki` 명령은 `/analyze`의 3-Level 워크스페이스 캐시를 활용합니다:

| 캐시 레벨 | DeepWiki에서의 사용 방법 |
|-----------|------------------------|
| **L1** (`project-map.yaml`) | 프로젝트 타입, 모듈 목록, **tier 정보**, 빌드 명령 → 위키 구조 계획 |
| **L2** (`modules/*.yaml`) | 파일 인벤토리, exports, 의존성 → 모듈 페이지 내용 |
| **L3** (소스 파일) | 실제 코드 → 코드 스니펫, 상세 설명 |

캐시가 없어도 DeepWiki는 파일을 직접 스캔하여 작동합니다(느리지만 기능적).

### Tier 기반 페이지 계획 (v2.1)

워크스페이스 캐시에 tier 정보(`/analyze` v2.1+)가 포함되어 있으면,
DeepWiki가 이를 사용하여 지능적으로 페이지를 계획합니다:

| 모듈 Tier | 페이지 전략 |
|-----------|------------|
| **Tier 1** (core) | 모듈당 전용 페이지 1개 (전체 상세, 개별 다이어그램) |
| **Tier 2** (important) | 관련된 2-3개 모듈을 결합 페이지로 그룹화 |
| **Tier 3** (peripheral) | Overview 또는 부록 페이지에서 간략히 언급 |

50개 모듈 프로젝트의 경우 일반적으로 다음과 같은 결과가 나옵니다:
- 5개 Tier 1 전용 페이지
- 3-4개 Tier 2 그룹 페이지
- 1개 Tier 3 모듈 목록 부록 페이지
- Overview, Architecture, Config/Deploy 페이지 추가 = 총 ~12 페이지

## 퍼블리싱 (HITL 배포)

위키 생성 후, 오케스트레이터가 사용자에게 퍼블리싱 방법을 질문합니다:

| 선택 | 동작 |
|------|------|
| **GitLab Pages 설정** | `mkdocs.yml` + `.gitlab-ci.yml` 생성, 전부 커밋, 푸시 |
| **커밋만** | `git add docs/wiki/ && git commit` (로컬만) |
| **건너뛰기** | 파일을 디스크에 저장, git 작업 없음 |

### GitLab Pages 자동 배포

"GitLab Pages 설정"을 선택하면 에이전트가:
1. `mkdocs.yml` 생성 (Material 테마 + Mermaid 지원)
2. `.gitlab-ci.yml` 생성 (Pages 배포 파이프라인)
3. 모든 파일 커밋 및 푸시
4. `https://{namespace}.gitlab.io/{project}/`에서 위키 사용 가능

기존 설정 파일(`mkdocs.yml`, `.gitlab-ci.yml`)은 `--force` 사용 시에만 덮어씁니다.

### 기타 퍼블리싱 옵션

| 플랫폼 | 방법 |
|--------|------|
| **GitHub Wiki** | `docs/wiki/*.md`를 리포지토리의 위키 디렉토리에 복사 |
| **Docusaurus** | 사이드바 설정과 함께 마크다운 파일을 `docs/`에 임포트 |
| **MkDocs 로컬** | `mkdocs serve`로 `http://localhost:8000`에서 로컬 미리보기 |
| **직접 보기** | VS Code, Obsidian 또는 마크다운 뷰어에서 `docs/wiki/index.md` 열기 |

## 성능

| 단계 | 시간 | 비고 |
|------|------|------|
| 컨텍스트 수집 | ~5초 | 캐시 + README + 파일 구조 읽기 |
| 구조 계획 | ~10초 | LLM이 8-12 페이지 계획 |
| 페이지 생성 | ~30-60초 | 모든 페이지가 병렬로 생성 |
| 조립 | ~5초 | 인덱스, 사이드바 작성, 검증 |
| 퍼블리시 (HITL) | ~5-10초 | 사용자 선택: GitLab Pages / 커밋 / 건너뛰기 |
| **합계** | **~1-2분** | 워크스페이스 캐시 있는 경우 |

캐시 없이는 직접 파일 스캔을 위해 ~30초 추가.

## 제한 사항

- 페이지가 독립적으로 생성됨 → 간헐적 교차 참조 불일치
- Mermaid 다이어그램은 AI가 생성 → 복잡한 아키텍처의 경우 수동 조정 필요할 수 있음
- 생성당 최대 12 페이지 → 대규모 모노레포는 여러 번 실행 필요할 수 있음
- 코드 스니펫이 생성 시점의 파일 경로를 참조 → 리팩토링 후 오래될 수 있음
