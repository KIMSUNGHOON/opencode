# Workspace Analysis Workflow 설계 문서 (v2)

이 문서는 `/analyze` 명령어와 3-Level Progressive Cache 기반 워크스페이스 분석 워크플로우의 설계를 설명합니다.

## 목차

1. [개요](#1-개요)
2. [동기 및 배경](#2-동기-및-배경)
3. [아키텍처 (v2)](#3-아키텍처-v2)
4. [3-Level 캐시 스키마](#4-3-level-캐시-스키마)
5. [에이전트 설계](#5-에이전트-설계)
6. [병렬 실행 전략](#6-병렬-실행-전략)
7. [디렉토리 제외 규칙](#7-디렉토리-제외-규칙)
8. [Code-QA 통합](#8-code-qa-통합)
9. [사용 예시](#9-사용-예시)
10. [에러 처리 및 폴백](#10-에러-처리-및-폴백)

---

## 1. 개요

### 1.1 Workspace Analysis란?

Workspace Analysis는 프로젝트의 구조, 모듈 경계, 의존성, 빌드 시스템을 사전에 분석하여 3-Level Progressive Cache에 저장하는 워크플로우입니다.

### 1.2 v1 → v2 변경 사항

| 항목 | v1 (기존) | v2 (현재) |
|------|-----------|-----------|
| 에이전트 | workspace-analyzer 1개 | workspace-scanner + module-analyzer N개 |
| 실행 방식 | 순차 (단일 에이전트) | 병렬 (모듈별 동시 분석) |
| 캐시 구조 | analysis.json 단일 파일 | 3-Level (project-map + modules + dependency-graph) |
| 컨텍스트 효율 | 전체 로드 (대규모 프로젝트에서 비효율) | L1만 항상 로드 (~1K), L2는 필요시 (~2-5K/모듈) |
| 분석 속도 | 직렬, 프로젝트 크기에 비례 | 병렬, 모듈 수 무관하게 ~30초 |
| 대규모 프로젝트 | 미지원 (타임아웃) | Tiered + Batched (v2.1): 모듈 중요도별 3단계 분석 |
| 증분 분석 | 없음 (매번 전체) | Incremental (v2.1): 변경된 모듈만 재분석 |

### 1.3 설계 원칙

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      ★★★ 핵심 설계 원칙 ★★★                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  1. Progressive Disclosure                                               │
│     - L1 (~1K tokens): 항상 로드, 프로젝트 전체 맵                       │
│     - L2 (~2-5K/module): 필요시 로드, 모듈 상세 분석                     │
│     - L3 (원본): 필요시 Read tool로 직접 접근                            │
│                                                                          │
│  2. 병렬 실행 (Parallel Execution)                                       │
│     - 모듈 분석을 단일 응답에서 N개 Task 동시 호출                       │
│     - AI SDK fire-and-forget 패턴으로 실제 병렬 실행                     │
│                                                                          │
│  3. 관심사 분리 (Separation of Concerns)                                 │
│     - Scanner: 빠른 구조 스캔 (what modules exist)                       │
│     - Analyzer: 깊은 모듈 분석 (what each module does)                   │
│     - Orchestrator: 결과 통합 및 캐시 저장                               │
│                                                                          │
│  4. 레거시 호환                                                          │
│     - analysis.json도 동시에 생성                                        │
│     - v1 캐시가 있으면 그것도 활용                                       │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. 동기 및 배경

### 2.1 v1의 한계

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      v1 한계점                                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  1. 단일 에이전트 병목                                                   │
│     - workspace-analyzer 1개가 전체 프로젝트를 순차 분석                 │
│     - 대규모 프로젝트(100+ 모듈)에서 수 분 소요                         │
│                                                                          │
│  2. 컨텍스트 비효율                                                     │
│     - analysis.json 전체를 로드 → 대규모 프로젝트에서 수만 토큰          │
│     - 256K 컨텍스트에서 분석 데이터가 차지하는 비중 과다                  │
│                                                                          │
│  3. All-or-Nothing                                                       │
│     - 특정 모듈만 재분석 불가                                            │
│     - 부분 실패 시 전체 재실행 필요                                      │
│                                                                          │
│  4. 자기 참조 문제                                                       │
│     - .opencode/ 디렉토리를 분석 대상에 포함                             │
│     - 캐시 디렉토리, 빌드 결과물 등 불필요한 파일 스캔                   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.2 v2 해결 전략

| 문제 | 해결 |
|------|------|
| 단일 에이전트 병목 | 2-Phase 병렬: Scanner(1개) → Analyzer(N개 동시) |
| 컨텍스트 비효율 | 3-Level Cache: L1 항상 로드, L2/L3 필요시만 |
| All-or-Nothing | 모듈별 독립 캐시 → `--modules-only`로 부분 재분석 |
| 자기 참조 | EXCLUDED_DIRS 규칙을 3중 적용 (Scanner + Analyzer + Orchestrator) |

---

## 3. 아키텍처 (v2)

### 3.1 컴포넌트 다이어그램

```
┌─────────────────────────────────────────────────────────────────────────┐
│              Workspace Analysis Architecture (v2)                        │
└─────────────────────────────────────────────────────────────────────────┘

                              사용자
                                │
                                ▼
                    ┌───────────────────┐
                    │  /analyze 명령어   │  (Thinking Model - Orchestrator)
                    │  (analyze.md)     │
                    └─────────┬─────────┘
                              │
              ┌───────────────┘
              ▼
    ┌───────────────────┐
    │ workspace-scanner  │  Phase 1: Fast Scan (~15s)
    │   (Coder Model)   │
    │                    │
    │  Tools: Glob,      │
    │  Read, Bash        │
    └─────────┬─────────┘
              │
              │ modules[] 반환
              ▼
    ┌─────────────────────────────────────────────────────┐
    │              Phase 2: Parallel Module Analysis        │
    │                                                       │
    │  ┌──────────┐ ┌──────────┐ ┌──────────┐            │
    │  │ module-  │ │ module-  │ │ module-  │  ... × N    │
    │  │ analyzer │ │ analyzer │ │ analyzer │  (동시 실행) │
    │  │ (api)    │ │ (models) │ │ (utils)  │            │
    │  └────┬─────┘ └────┬─────┘ └────┬─────┘            │
    │       │             │             │                   │
    └───────┼─────────────┼─────────────┼───────────────────┘
            │             │             │
            └─────────────┼─────────────┘
                          │
                          ▼
                ┌───────────────────┐
                │  Phase 3: Merge   │  Orchestrator가 결과 통합
                └─────────┬─────────┘
                          │
          ┌───────────────┼───────────────────────────┐
          ▼               ▼               ▼            ▼
    ┌──────────┐   ┌──────────┐   ┌──────────┐  ┌──────────┐
    │ L1:      │   │ L2:      │   │ Dep      │  │ Legacy:  │
    │ project- │   │ modules/ │   │ Graph    │  │ analysis │
    │ map.yaml │   │ *.yaml   │   │ .yaml    │  │ .json    │
    └──────────┘   └──────────┘   └──────────┘  └──────────┘
          │
          │ (항상 로드)
          ▼
    ┌───────────────────┐
    │ Code-QA / 일반    │
    │ 코딩 작업에서     │
    │ 컨텍스트로 활용   │
    └───────────────────┘
```

### 3.2 파일 구조

```
.opencode/
├── command/
│   └── analyze.md              # /analyze 명령어 (Orchestrator)
├── agent/
│   ├── workspace-scanner.md    # Phase 1: 빠른 프로젝트 스캔
│   ├── module-analyzer.md      # Phase 2: 모듈별 딥 분석
│   └── workspace-analyzer.md   # (레거시) v1 분석 에이전트
├── mode/
│   └── code-qa.md              # STEP 0에서 캐시 통합
├── config/
│   └── workflow-settings.yaml  # 에이전트 타임아웃/모델 설정
└── workspace-cache/            # 캐시 저장 디렉토리
    ├── project-map.yaml        # L1: 프로젝트 전체 맵 (~1K tokens)
    ├── modules/                # L2: 모듈별 상세 분석
    │   ├── api.yaml            #     (~2-5K tokens per module)
    │   ├── models.yaml
    │   └── services.yaml
    ├── dependency-graph.yaml   # 모듈간 의존성 그래프
    ├── .cache-meta.json        # 캐시 메타데이터
    └── analysis.json           # 레거시 호환용 (v1 형식)
```

### 3.3 데이터 흐름

```
1. 분석 실행 (/analyze)

   ┌────────┐     ┌─────────────────┐     ┌───────────────────────────────┐
   │  User  │────▶│ workspace-      │────▶│ modules[] (JSON)              │
   │        │     │ scanner         │     │ [{name, path, file_count}...] │
   └────────┘     └─────────────────┘     └───────────────┬───────────────┘
                                                           │
                                           ┌───────────────┼───────────────┐
                                           ▼               ▼               ▼
                                     ┌──────────┐   ┌──────────┐   ┌──────────┐
                                     │ module-  │   │ module-  │   │ module-  │
                                     │ analyzer │   │ analyzer │   │ analyzer │
                                     └────┬─────┘   └────┬─────┘   └────┬─────┘
                                           │               │               │
                                           └───────────────┼───────────────┘
                                                           │
                                                           ▼
                                                  ┌────────────────┐
                                                  │ Merge & Save   │
                                                  │ 3-Level Cache  │
                                                  └────────────────┘

2. Code-QA / 일반 작업에서 캐시 사용

   ┌─────────────────┐     ┌─────────────────────┐
   │ project-map.yaml│────▶│ 프로젝트 구조 파악   │  (L1: ~1K tokens, 항상)
   │ (L1)            │     │ 어떤 모듈이 있는지   │
   └─────────────────┘     └─────────────────────┘
                                     │
                                     │ (특정 모듈 작업 시)
                                     ▼
   ┌─────────────────┐     ┌─────────────────────┐
   │ modules/api.yaml│────▶│ 모듈 상세 파악       │  (L2: ~2-5K tokens, 필요시)
   │ (L2)            │     │ 어떤 파일/함수가     │
   └─────────────────┘     └─────────────────────┘
                                     │
                                     │ (실제 코드 필요 시)
                                     ▼
   ┌─────────────────┐     ┌─────────────────────┐
   │ src/api/app.py  │────▶│ 코드 직접 읽기       │  (L3: Read tool)
   │ (L3 원본)       │     │                     │
   └─────────────────┘     └─────────────────────┘
```

---

## 4. 3-Level 캐시 스키마

### 4.1 Level 1: project-map.yaml (~500-1K tokens)

항상 시스템 프롬프트에 포함되는 프로젝트 전체 맵.

```yaml
version: "2.0"
analyzed_at: "2025-01-15T10:30:00Z"
project_root: "/home/user/myproject"

project:
  name: "myproject"
  type: "node"
  languages: ["typescript", "javascript"]
  frameworks: ["react", "express"]

build:
  build_command: "npm run build"
  test_command: "npm test"
  lint_command: "eslint src/"

modules:
  api:
    path: "src/api"
    tier: 1
    summary: "FastAPI REST endpoints with JWT auth"
    files: 12
    key_exports: ["create_app", "router", "verify_token"]
  models:
    path: "src/models"
    tier: 1
    summary: "SQLAlchemy ORM models for users, orders, products"
    files: 8
    key_exports: ["User", "Order", "Product"]
  services:
    path: "src/services"
    tier: 2
    summary: "Business logic layer with transaction support"
    files: 6
    key_exports: ["UserService", "OrderService"]

dependencies:
  api: [services, models]
  services: [models]
  models: []

entry_points:
  - "src/main.py"
  - "src/server.ts"

git:
  remote_url: "git@github.com:user/myproject.git"
  current_branch: "main"
```

### 4.2 Level 2: modules/{name}.yaml (~3-8K tokens per module)

특정 모듈 작업 시 on-demand로 로드. DB 스키마, API 계약, 타입 정의까지 포함.

```yaml
name: "api"
path: "src/api"
summary: "FastAPI REST endpoints with JWT auth and role-based access control. Handles user CRUD, order management, and payment processing via Stripe."
file_count: 12
test_count: 3
total_lines: 1850

files:
  - path: "src/api/app.py"
    role: "FastAPI app factory, CORS setup, exception handlers"
    exports: ["create_app"]
    lines: 85
  - path: "src/api/routes/users.py"
    role: "User CRUD endpoints - register, login, profile"
    exports: ["router"]
    lines: 120
    imports_from: ["services.UserService", "models.User"]

key_exports: ["create_app", "router", "verify_token", "require_role"]

internal_dependencies:
  - module: "services"
    imports: ["UserService", "OrderService"]
  - module: "models"
    imports: ["User", "Order", "Product"]

# --- Deep Analysis (Steps 5-8) ---

data_models:
  - name: "User"
    type: "sqlalchemy"
    file: "src/models/user.py"
    fields:
      - {name: "id", type: "Integer", primary_key: true}
      - {name: "email", type: "String(255)", unique: true, nullable: false}
      - {name: "hashed_password", type: "String(255)", nullable: false}
      - {name: "is_active", type: "Boolean", default: true}
    relationships:
      - {field: "orders", target: "Order", type: "one-to-many"}

api_endpoints:
  - {method: "POST", path: "/api/users/register", handler: "register_user", request_type: "UserCreateSchema", response_type: "UserResponse", auth: false}
  - {method: "GET", path: "/api/users/me", handler: "get_current_user", response_type: "UserResponse", auth: "verify_token"}

type_definitions:
  - name: "UserCreateSchema"
    kind: "pydantic"
    file: "src/api/schemas/user.py"
    fields: [{name: "email", type: "EmailStr"}, {name: "password", type: "str", min_length: 8}]
  - name: "UserResponse"
    kind: "pydantic"
    file: "src/api/schemas/user.py"
    fields: [{name: "id", type: "int"}, {name: "email", type: "str"}, {name: "is_active", type: "bool"}]

error_handling:
  custom_errors:
    - {name: "UserNotFoundError", file: "src/api/errors.py", http_status: 404}
    - {name: "DuplicateEmailError", file: "src/api/errors.py", http_status: 409}
  error_handlers: ["global_exception_handler in app.py"]

config:
  env_vars:
    - {name: "DATABASE_URL", file: "src/api/config.py", required: true}
    - {name: "JWT_SECRET", file: "src/api/auth.py", required: true}

patterns:
  - "All routes use Depends(verify_token) for auth"
  - "Pydantic schemas in schemas/ for request/response validation"
  - "Custom exceptions mapped to HTTP status codes via global handler"
  - "Config loaded from env vars with pydantic Settings"
```

**Deep Analysis 필드 설명:**

| 필드 | 탐지 대상 | 용도 |
|------|-----------|------|
| `data_models` | SQLAlchemy, Django, Prisma, Drizzle, TypeORM, GORM 등 | DB 스키마 이해, 마이그레이션 계획 |
| `api_endpoints` | FastAPI, Express, NestJS, Gin 등의 라우트 | API 계약 파악, 새 엔드포인트 일관성 |
| `type_definitions` | Pydantic, Zod, TypeScript interfaces, Go structs | DTO/스키마 재사용, 타입 안전성 |
| `error_handling` | 커스텀 에러 클래스, 에러 핸들러 | 에러 처리 패턴 일관성 |
| `config` | 환경변수, 설정 파일 참조 | 새 기능의 설정 요구사항 파악 |

### 4.3 dependency-graph.yaml

```yaml
# 모듈간 의존성 관계
graph:
  api: [services, models]
  services: [models, database]
  models: [database]
  database: []
```

### 4.4 .cache-meta.json

```json
{
  "version": "2.1",
  "analyzed_at": "2025-01-15T10:30:00Z",
  "scanner_version": "1.1",
  "modules_analyzed": 5,
  "modules_skipped": 0,
  "modules_reused": 2,
  "tier_breakdown": {
    "tier1": 3,
    "tier2": 2,
    "tier3": 0
  },
  "total_analysis_time_ms": 28500
}
```

### 4.5 캐시 무효화 전략

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      캐시 무효화 규칙                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  자동 무효화:                                                            │
│    - analyzed_at이 24시간 이상 경과                                      │
│    - /analyze --force로 강제 재분석                                      │
│                                                                          │
│  증분 캐시 (v2.1):                                                      │
│    - 모듈별 파일 수정 시간 비교 (find -newer)                            │
│    - 변경된 모듈만 재분석, 나머지는 캐시 재사용                          │
│    - --force 시 무시                                                     │
│                                                                          │
│  부분 업데이트:                                                          │
│    - /analyze --modules-only: 스캐너 스킵, 모듈만 재분석                 │
│    - 개별 모듈 yaml 삭제 → 해당 모듈만 재분석                            │
│                                                                          │
│  레거시 폴백:                                                            │
│    - project-map.yaml 없고 analysis.json만 있으면 v1 캐시 사용           │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 5. 에이전트 설계

### 5.1 workspace-scanner (Phase 1)

빠른 프로젝트 스캔으로 모듈 목록을 생성합니다.

```yaml
# .opencode/agent/workspace-scanner.md
---
description: Fast workspace scanner
mode: subagent
model: qwen-coder/Qwen3-Coder-Next-FP8
tools: [Glob, Read, Bash]
permission: read-only
---
```

**실행 단계:**

| Step | 작업 | 도구 | 소요 시간 |
|------|------|------|-----------|
| 1 | 프로젝트 루트 & 타입 감지 | Bash (pwd, ls) | ~1s |
| 2 | 디렉토리 구조 매핑 | Glob | ~2s |
| 3 | 모듈 경계 탐지 | Glob | ~5s |
| 4 | 모듈별 파일 수 카운트 | Bash (find) | ~3s |
| 5 | **모듈 중요도 점수 & Tier 분류** | Glob | ~3s |
| 6 | 엔트리 포인트 & 설정 감지 | Glob | ~2s |
| 7 | 모노레포 감지 | Read (package.json) | ~1s |

**Tier 분류 기준 (v2.1):**

| Tier | 점수 기준 | 분석 깊이 | 일반적 모듈 |
|------|-----------|-----------|-------------|
| T1 (core) | ≥ 20 | 9-step 전체 딥 분석 | 핵심 비즈니스 로직, API, 데이터 레이어 |
| T2 (important) | ≥ 8 | 4-step 표준 분석 | 유틸리티, 미들웨어, 헬퍼 |
| T3 (peripheral) | < 8 | 파일 목록 + exports만 | 설정, 스크립트, 작은 모듈 |

**출력:** `WORKSPACE_SCAN_RESULT: COMPLETE` + `SCAN_DATA` JSON

**모듈 경계 탐지 기준:**

| 언어 | 경계 마커 |
|------|-----------|
| Python | `__init__.py` |
| TypeScript/JS | `index.ts`, `index.js`, `package.json` |
| Go | 디렉토리 내 `.go` 파일 |
| Rust | `mod.rs`, `lib.rs`, `main.rs` |
| Java | `src/main/java/` 하위 디렉토리 |

### 5.2 module-analyzer (Phase 2)

단일 모듈의 파일, 내보내기, 의존성을 딥 분석합니다.

```yaml
# .opencode/agent/module-analyzer.md
---
description: Deep module analyzer
mode: subagent
model: qwen-coder/Qwen3-Coder-Next-FP8
tools: [Glob, Grep, Read]
permission: read-only
---
```

**입력:** `MODULE_PATH`, `MODULE_NAME`, `PROJECT_ROOT`, `PROJECT_TYPE`, `ANALYSIS_TIER` (optional, default: 1)

**실행 단계:**

| Step | 작업 | 도구 | 상세 |
|------|------|------|------|
| 1 | 파일 인벤토리 | Glob | 소스/테스트/스키마/라우트/타입 파일 분류 |
| 2 | 공개 API / 내보내기 탐지 | Grep | 언어별 export 패턴 |
| 3 | 내부 의존성 분석 | Grep | 프로젝트 내부 import만 추출 |
| 4 | 파일별 역할 요약 (상위 20개) | Read (첫 50줄) | 스키마/라우트/타입 파일 우선 |
| 5 | **DB 모델/스키마 탐지** | Grep + Read | SQLAlchemy, Prisma, Drizzle, TypeORM 등 |
| 6 | **API 엔드포인트 탐지** | Grep + Read | FastAPI, Express, NestJS, Gin 등 |
| 7 | **타입/인터페이스 추출** | Grep + Read | Pydantic, Zod, TS interfaces, Go structs |
| 8 | **에러 처리 & 설정 탐지** | Grep | 커스텀 에러, 환경변수, 설정 참조 |
| 9 | 모듈 요약 생성 | - | 전체 데이터 기반 2-3문장 요약 |

**출력:** `MODULE_ANALYSIS_RESULT: COMPLETE` + `MODULE_DATA` JSON (스키마, API, 타입, 에러, 설정 포함)

### 5.3 workspace-analyzer (DEPRECATED)

v1 호환용 단일 분석 에이전트. workspace-scanner가 실패할 경우 폴백으로 사용됩니다.
이 폴백이 빈번하게 발생한다면 workspace-scanner의 실패 원인을 조사해야 합니다.

### 5.4 타임아웃 설정

```yaml
# workflow-settings.yaml
timeout:
  agent:
    workspace-scanner: 30000   # 30초
    module-analyzer: 90000     # 1.5분 (per module, deep analysis w/ schema+API+types)
```

---

## 6. 병렬 실행 전략

### 6.1 AI SDK 병렬 실행 원리

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      AI SDK 병렬 실행 메커니즘                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  AI SDK의 runToolsTransformation()은 tool-call 이벤트를 받으면:          │
│                                                                          │
│    outstandingToolResults.add(toolCallId)                                │
│    executeToolCall(toolCall)  // ← await 없이 fire-and-forget            │
│                                                                          │
│  모델이 하나의 응답에서 여러 Task 호출을 하면,                            │
│  각 Task는 await 없이 즉시 시작됨 → 실제 병렬 실행                       │
│                                                                          │
│  핵심: 모델이 하나의 응답에 N개의 Task call을 포함해야 함                 │
│  → 프롬프트 설계가 병렬 실행의 핵심                                      │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 6.2 analyze.md의 병렬 실행 지시

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      병렬 실행 패턴                                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ✅ 올바른 방법 (1 응답에 5 Task 호출):                                  │
│                                                                          │
│    Orchestrator Response:                                                │
│    ├── Task(module-analyzer, "Analyze api")                              │
│    ├── Task(module-analyzer, "Analyze models")                           │
│    ├── Task(module-analyzer, "Analyze services")                         │
│    ├── Task(module-analyzer, "Analyze utils")                            │
│    └── Task(module-analyzer, "Analyze tests")                            │
│                                                                          │
│    → 5개 에이전트 동시 실행, ~30초 완료                                  │
│                                                                          │
│  ❌ 잘못된 방법 (5개 응답에 각 1 Task):                                  │
│                                                                          │
│    Response 1: Task(module-analyzer, "Analyze api")     → 30초           │
│    Response 2: Task(module-analyzer, "Analyze models")  → 30초           │
│    Response 3: Task(module-analyzer, "Analyze services") → 30초          │
│    ...                                                                    │
│                                                                          │
│    → 순차 실행, ~150초 소요                                              │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 6.3 Tiered Batched Execution (v2.1)

**Small project (≤ 15 modules):**
- 전부 Tier 1 (full deep analysis)로 단일 배치 병렬 분석 (기존 동작과 동일)

**Large project (> 15 modules):**
```
Batch 1: Tier 1 모듈 전부 (병렬)  → 결과 즉시 L2 저장
Batch 2: Tier 2 모듈 1-10 (병렬)  → 결과 즉시 L2 저장
Batch 3: Tier 2 모듈 11-20 (병렬) → 결과 즉시 L2 저장
...
Final:   Tier 3 모듈 (--all 시만)  → 결과 즉시 L2 저장
```

- 배치 내: 병렬 실행 (단일 응답에 N개 Task)
- 배치 간: 순차 (이전 배치 결과 저장 후 다음 시작)
- 배치 크기: 기본 10 (`--batch-size N`으로 조정)
- Tier 3 모듈: `--all` 플래그 없으면 스킵 (project-map.yaml에 목록만 기록)

---

## 7. 디렉토리 제외 규칙

### 7.1 제외 대상

```
EXCLUDED_DIRS:
  .opencode, .git, node_modules, __pycache__, .venv, venv, .env,
  target, build, dist, out, .next, .nuxt, .output,
  vendor, .cache, .gradle, .idea, .vscode,
  .mypy_cache, .ruff_cache, .pytest_cache, .tox, .nox,
  .turbo, .parcel-cache, .webpack,
  coverage, .nyc_output, htmlcov, workspace-cache
```

### 7.2 3중 적용 원칙

제외 규칙은 3개 레이어 모두에서 적용됩니다:

| 레이어 | 적용 위치 | 방식 |
|--------|-----------|------|
| **workspace-scanner** | Glob 결과 필터링, `find` 명령에 `-not -path` | 스캔 단계에서 제외 |
| **module-analyzer** | Glob/Grep 결과 필터링 | 분석 단계에서 제외 |
| **analyze.md (Orchestrator)** | 스캐너 결과 후처리 | 제외된 경로의 모듈을 분석 대상에서 제거 |

### 7.3 제외가 필요한 이유

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      자기 참조 방지                                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  .opencode/ 를 분석하면:                                                 │
│    - 에이전트 정의 파일(.md)을 소스코드로 분석                            │
│    - workspace-cache/를 분석 결과로 다시 읽기                             │
│    - 무한 자기참조 루프 가능성                                            │
│                                                                          │
│  build/dist/ 를 분석하면:                                                │
│    - 트랜스파일된 코드를 원본으로 오인                                    │
│    - 번들된 파일이 모듈로 감지                                            │
│    - 분석 결과 부풀리기 (context overflow)                                │
│                                                                          │
│  __pycache__/.mypy_cache/ 를 분석하면:                                   │
│    - 캐시 파일을 소스코드로 오인                                          │
│    - changed_files 목록 폭증 → context overflow → 워크플로우 실패         │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 8. Code-QA 통합

### 8.1 STEP 0 흐름

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      Code-QA STEP 0: Workspace Cache                     │
└─────────────────────────────────────────────────────────────────────────┘

  /code-qa 실행
      │
      ▼
  mkdir -p .opencode/workspace-cache/modules
      │
      ▼
  ┌─────────────────────────────────────────┐
  │ project-map.yaml 존재 + 24시간 이내?    │
  └────────────┬────────────┬───────────────┘
               │            │
           YES │        NO  │
               ▼            ▼
  ┌──────────────┐   ┌─────────────────────────────┐
  │ L1 캐시 사용  │   │ analysis.json 존재 + 유효?  │
  │ STEP 1 진행  │   └──────────┬─────────┬────────┘
  └──────────────┘              │         │
                            YES │     NO  │
                                ▼         ▼
                   ┌──────────────┐   ┌──────────────────────┐
                   │ 레거시 캐시   │   │ 분석 실행            │
                   │ 사용         │   │ Scanner → Analyzer×N │
                   │ STEP 1 진행  │   │ → Merge → STEP 1    │
                   └──────────────┘   └──────────────────────┘
                                              │
                                              │ (Scanner 실패 시)
                                              ▼
                                      ┌──────────────────────┐
                                      │ 레거시 폴백           │
                                      │ workspace-analyzer   │
                                      └──────────────────────┘
```

### 8.2 Code-QA에서의 캐시 활용

| Phase | 사용하는 캐시 | 용도 |
|-------|--------------|------|
| STEP 0 | project-map.yaml | 프로젝트 구조 파악 |
| STEP 4 (Review) | modules/*.yaml | 리뷰 대상 모듈 컨텍스트 |
| STEP 5 (Build) | project-map.yaml → build_command | 빌드 명령 참조 |
| STEP 6 (Test) | project-map.yaml → test_command | 테스트 명령 참조 |

---

## 9. 사용 예시

### 9.1 기본 사용

```bash
# 워크스페이스 분석 (캐시 유효하면 스킵, 증분: 변경 모듈만)
/analyze

# 강제 전체 재분석
/analyze --force

# 모듈만 재분석 (스캐너 결과 재사용)
/analyze --modules-only

# Tier 3 (peripheral) 모듈까지 전부 분석
/analyze --all

# 전체 모듈 강제 재분석 (대규모 프로젝트)
/analyze --all --force

# 배치 크기 조정 (서버 부하 제어)
/analyze --batch-size 5
```

### 9.2 Code-QA와 자동 통합

```bash
# 방법 1: 사전 분석 후 QA
/analyze
/code-qa

# 방법 2: code-qa가 자동으로 캐시 확인/분석
/code-qa  # 캐시 없으면 자동 분석
```

### 9.3 일반 코딩 작업에서 캐시 활용

```bash
# 프로젝트 구조 빠르게 파악 (L1만 읽기)
Read .opencode/workspace-cache/project-map.yaml

# 특정 모듈 상세 확인 (L2 로드)
Read .opencode/workspace-cache/modules/api.yaml

# 모듈간 의존성 확인
Read .opencode/workspace-cache/dependency-graph.yaml
```

---

## 10. 에러 처리 및 폴백

### 10.1 에러 시나리오

| 에러 | 처리 |
|------|------|
| Scanner 실패 | → 레거시 workspace-analyzer 폴백 |
| 개별 module-analyzer 실패 | → 해당 모듈 스킵, cache-meta에 기록 |
| 모든 module-analyzer 실패 | → Scanner 결과만으로 L1 생성 (L2 없음) |
| JSON 파싱 실패 | → 에러 로그, 가용 데이터로 계속 |
| 캐시 파일 손상 | → `rm .opencode/workspace-cache/` 후 재분석 |

### 10.2 레거시 폴백 흐름

```
Scanner 실패
    │
    ▼
┌─────────────────────┐
│ workspace-analyzer  │  (v1 에이전트)
│ 단일 분석 실행       │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ analysis.json 저장  │  (v1 형식)
│ L2/L3 캐시 없음     │
└─────────────────────┘
```

---

## 부록 A: 지원 프로젝트 타입

| 타입 | 감지 파일 | 빌드 도구 |
|------|-----------|-----------|
| TypeScript/JavaScript | package.json, tsconfig.json | npm, yarn, pnpm, bun |
| Python | requirements.txt, pyproject.toml, setup.py | pip, poetry, pipenv |
| Go | go.mod | go modules |
| Rust | Cargo.toml | cargo |
| Java | pom.xml, build.gradle | maven, gradle |
| C/C++ | Makefile, CMakeLists.txt | make, cmake |
| Ruby | Gemfile | bundler |
| PHP | composer.json | composer |

## 부록 B: workflow-settings.yaml 설정

```yaml
timeout:
  agent:
    workspace-scanner: 30000   # 30초
    module-analyzer: 90000     # 1.5분

model:
  assignment:
    coder_agents:
      - workspace-scanner      # Phase 0B: Fast project scan
      - module-analyzer        # Phase 0B: Per-module deep analysis
      - workspace-analyzer     # Phase 0B: Legacy fallback

analysis:
  tier_thresholds:
    tier1: 20                  # Score >= 20 → full deep analysis
    tier2: 8                   # Score >= 8  → standard analysis
  batch:
    size: 10                   # Max modules per parallel batch
    delay_between_ms: 1000     # Pause between batches
  incremental:
    enabled: true              # Skip unchanged modules
  limits:
    small_project_max: 15      # Single-batch mode threshold
    tier3_default: "skip"      # "skip" or "analyze"
    max_modules_total: 100     # Absolute cap
```

---

## 변경 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|-----------|
| 1.0 | 2024-01-15 | 초기 설계 문서 (v1: 단일 workspace-analyzer) |
| 2.0 | 2025-02-12 | v2 전면 개정: 3-Level Cache, 병렬 실행, 디렉토리 제외 규칙 |
| 2.1 | 2026-02-12 | Tiered Priority + Batched Parallel + Incremental Cache |
