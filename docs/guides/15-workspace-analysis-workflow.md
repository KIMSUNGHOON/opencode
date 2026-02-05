# Workspace Analysis Workflow 설계 문서

이 문서는 `/analyze` 명령어와 워크스페이스 분석 워크플로우의 설계를 설명합니다.

## 목차

1. [개요](#1-개요)
2. [동기 및 배경](#2-동기-및-배경)
3. [아키텍처](#3-아키텍처)
4. [캐시 스키마](#4-캐시-스키마)
5. [워크플로우 설계](#5-워크플로우-설계)
6. [Code-QA 통합](#6-code-qa-통합)
7. [구현 계획](#7-구현-계획)
8. [사용 예시](#8-사용-예시)

---

## 1. 개요

### 1.1 Workspace Analysis란?

Workspace Analysis는 프로젝트의 구조, 파일 목록, 의존성, 환경 정보를 사전에 분석하여 캐시에 저장하는 워크플로우입니다.

### 1.2 주요 기능

- **프로젝트 구조 분석**: 디렉토리 구조, 파일 목록, 파일 타입 분류
- **의존성 탐지**: package.json, requirements.txt, go.mod 등 분석
- **빌드 시스템 감지**: npm, cargo, go, make 등 빌드 도구 식별
- **환경 정보 수집**: 언어 버전, 프레임워크, 설정 파일
- **캐시 저장**: 분석 결과를 JSON 캐시로 저장
- **증분 업데이트**: 변경된 파일만 재분석

### 1.3 설계 원칙

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      ★★★ 핵심 설계 원칙 ★★★                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  1. 관심사 분리 (Separation of Concerns)                                 │
│     - 분석: workspace-analyzer가 담당                                    │
│     - 품질 검사: code-qa가 담당                                          │
│                                                                          │
│  2. 데이터 중심 설계 (Data-Driven)                                       │
│     - 모델이 파일을 추측하지 않음                                        │
│     - 사전 분석된 정확한 데이터 제공                                     │
│                                                                          │
│  3. Unix 철학                                                            │
│     - 한 가지 일을 잘 수행하는 도구                                      │
│     - 파이프라인으로 조합 가능                                           │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. 동기 및 배경

### 2.1 기존 문제점

Code-QA v4 워크플로우에서 `code-reviewer` 에이전트가 파일을 분석할 때 발생하는 문제:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      문제 상황                                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  1. 파일 할루시네이션                                                    │
│     - 모델이 존재하지 않는 파일 경로를 추측                              │
│     - 예: main.py, model.py, test_*.py 등 일반적 이름 시도               │
│                                                                          │
│  2. 불완전한 분석                                                        │
│     - 일부 파일만 분석하고 완료 처리                                     │
│     - 중요한 파일 누락 가능                                              │
│                                                                          │
│  3. 비효율성                                                             │
│     - 매번 같은 파일 구조를 재분석                                       │
│     - 동일한 프로젝트에서 반복적인 탐색                                  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.2 해결 방안

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      해결 전략                                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  기존 접근 (제한적):                                                     │
│    → code-reviewer의 도구 제한 (Glob, Grep, Bash 제거)                  │
│    → 문제: 오케스트레이터가 정확한 파일 목록을 제공해야 함               │
│                                                                          │
│  새로운 접근 (근본적):                                                   │
│    → 사전 분석 워크플로우로 정확한 데이터 생성                           │
│    → 캐시된 데이터를 code-qa에서 재사용                                  │
│    → 모델이 추측할 필요 없음                                             │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 2.3 장점

| 장점 | 설명 |
|------|------|
| **정확성** | 실제 파일 시스템 기반 정확한 데이터 |
| **재사용성** | 한 번 분석, 여러 번 사용 |
| **효율성** | 증분 업데이트로 빠른 재분석 |
| **독립성** | code-qa 없이 분석만 수행 가능 |
| **확장성** | 다른 워크플로우에서도 활용 가능 |

---

## 3. 아키텍처

### 3.1 컴포넌트 다이어그램

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       Workspace Analysis Architecture                    │
└─────────────────────────────────────────────────────────────────────────┘

                              사용자
                                │
                                ▼
                    ┌───────────────────┐
                    │  /analyze 명령어   │
                    │   (command)        │
                    └─────────┬─────────┘
                              │
                              ▼
                    ┌───────────────────┐
                    │ workspace-analyzer │
                    │     (agent)        │
                    │                    │
                    │  Tools:            │
                    │  - Glob            │
                    │  - Grep            │
                    │  - Read            │
                    │  - Bash (read-only)│
                    └─────────┬─────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
        ┌──────────┐   ┌──────────┐   ┌──────────┐
        │ Project  │   │ Deps     │   │ Build    │
        │ Structure│   │ Analysis │   │ System   │
        └────┬─────┘   └────┬─────┘   └────┬─────┘
              │               │               │
              └───────────────┼───────────────┘
                              │
                              ▼
                    ┌───────────────────┐
                    │   Cache File      │
                    │                   │
                    │ .opencode/        │
                    │ workspace-cache/  │
                    │   analysis.json   │
                    └───────────────────┘
                              │
                              │ (재사용)
                              ▼
                    ┌───────────────────┐
                    │    Code-QA        │
                    │   Orchestrator    │
                    └───────────────────┘
```

### 3.2 파일 구조

```
.opencode/
├── command/
│   └── analyze.md              # /analyze 명령어 정의
├── agent/
│   └── workspace-analyzer.md   # 분석 에이전트 정의
├── mode/
│   └── code-qa.md              # (수정) 캐시 통합 로직 추가
└── workspace-cache/            # 캐시 저장 디렉토리
    ├── analysis.json           # 메인 분석 결과
    └── file-hashes.json        # 파일 해시 (증분 업데이트용)
```

### 3.3 데이터 흐름

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       데이터 흐름                                        │
└─────────────────────────────────────────────────────────────────────────┘

1. 분석 실행 (/analyze)
   ┌────────┐     ┌─────────────────┐     ┌────────────────┐
   │  User  │────▶│ workspace-      │────▶│ analysis.json  │
   │        │     │ analyzer        │     │                │
   └────────┘     └─────────────────┘     └────────────────┘

2. Code-QA에서 캐시 사용
   ┌────────────────┐     ┌─────────────────┐     ┌─────────────────┐
   │ analysis.json  │────▶│ code-qa         │────▶│ code-reviewer   │
   │                │     │ orchestrator    │     │ (정확한 데이터) │
   └────────────────┘     └─────────────────┘     └─────────────────┘

3. 증분 업데이트
   ┌────────────────┐     ┌─────────────────┐     ┌────────────────┐
   │ file-hashes    │────▶│ 변경 감지       │────▶│ 부분 재분석    │
   │ (이전)         │     │                 │     │                │
   └────────────────┘     └─────────────────┘     └────────────────┘
```

---

## 4. 캐시 스키마

### 4.1 analysis.json 스키마

```json
{
  "version": "1.0",
  "analyzed_at": "2024-01-15T10:30:00Z",
  "project_root": "/home/user/myproject",

  "project": {
    "name": "myproject",
    "type": "typescript",
    "languages": ["typescript", "javascript"],
    "frameworks": ["react", "express"]
  },

  "structure": {
    "directories": [
      "src/",
      "src/components/",
      "src/utils/",
      "tests/",
      "docs/"
    ],
    "total_files": 156,
    "total_directories": 23
  },

  "files": {
    "by_type": {
      "typescript": [
        {"path": "src/index.ts", "size": 1234, "mtime": "2024-01-15T09:00:00Z"},
        {"path": "src/app.ts", "size": 5678, "mtime": "2024-01-15T08:30:00Z"}
      ],
      "javascript": [
        {"path": "scripts/build.js", "size": 890, "mtime": "2024-01-10T12:00:00Z"}
      ],
      "json": [
        {"path": "package.json", "size": 2345, "mtime": "2024-01-14T15:00:00Z"},
        {"path": "tsconfig.json", "size": 567, "mtime": "2024-01-01T10:00:00Z"}
      ]
    },
    "entry_points": ["src/index.ts", "src/server.ts"],
    "config_files": ["package.json", "tsconfig.json", ".eslintrc.js"],
    "test_files": ["tests/**/*.test.ts"]
  },

  "dependencies": {
    "package_manager": "npm",
    "manifest_file": "package.json",
    "lock_file": "package-lock.json",
    "production": {
      "react": "^18.2.0",
      "express": "^4.18.2"
    },
    "development": {
      "typescript": "^5.0.0",
      "jest": "^29.0.0"
    }
  },

  "build_system": {
    "type": "npm",
    "scripts": {
      "build": "tsc && vite build",
      "test": "jest",
      "lint": "eslint src/"
    },
    "build_command": "npm run build",
    "test_command": "npm test"
  },

  "environment": {
    "node_version": "20.x",
    "typescript_version": "5.0.0",
    "env_files": [".env.example"],
    "docker": {
      "has_dockerfile": true,
      "has_compose": true
    }
  },

  "git": {
    "is_repo": true,
    "remote_url": "git@github.com:user/myproject.git",
    "default_branch": "main",
    "current_branch": "feature/new-feature"
  },

  "analysis_stats": {
    "files_analyzed": 156,
    "duration_ms": 2340,
    "errors": []
  }
}
```

### 4.2 file-hashes.json 스키마

```json
{
  "version": "1.0",
  "generated_at": "2024-01-15T10:30:00Z",
  "algorithm": "mtime",
  "files": {
    "src/index.ts": {
      "mtime": "2024-01-15T09:00:00Z",
      "size": 1234
    },
    "src/app.ts": {
      "mtime": "2024-01-15T08:30:00Z",
      "size": 5678
    }
  }
}
```

### 4.3 캐시 무효화 전략

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      캐시 무효화 규칙                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  자동 무효화:                                                            │
│    - 캐시 파일이 24시간 이상 경과                                        │
│    - package.json, go.mod 등 의존성 파일 변경                            │
│    - 새 파일 추가 또는 파일 삭제                                         │
│                                                                          │
│  부분 업데이트:                                                          │
│    - 기존 파일의 mtime 변경 시 해당 파일만 재분석                        │
│    - 구조적 변경 없이 내용만 변경된 경우                                 │
│                                                                          │
│  강제 재분석:                                                            │
│    - /analyze --force 옵션 사용                                          │
│    - 캐시 디렉토리 삭제                                                  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 5. 워크플로우 설계

### 5.1 workspace-analyzer 에이전트

```yaml
# .opencode/agent/workspace-analyzer.md
---
description: Workspace Structure Analyzer
mode: subagent
model: qwen-coder/Qwen3-Coder-Next-FP8
tools:
  "*": false
  "Glob": true
  "Grep": true
  "Read": true
  "Bash": true  # read-only commands only
permission:
  read: allow
  edit: deny
---
```

### 5.2 분석 단계

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      분석 워크플로우 단계                                │
└─────────────────────────────────────────────────────────────────────────┘

STEP 1: 프로젝트 타입 감지
├── package.json → Node.js/TypeScript
├── go.mod → Go
├── Cargo.toml → Rust
├── requirements.txt/pyproject.toml → Python
├── pom.xml/build.gradle → Java
└── Makefile → C/C++

STEP 2: 파일 구조 수집
├── 모든 소스 파일 목록 (Glob)
├── 디렉토리 구조 매핑
├── 파일 타입별 분류
└── mtime 기록

STEP 3: 의존성 분석
├── 패키지 매니저 식별
├── 의존성 파일 파싱
├── 직접 의존성 목록
└── 개발 의존성 분리

STEP 4: 빌드 시스템 분석
├── 빌드 도구 감지
├── 빌드 스크립트 파싱
├── 테스트 명령 식별
└── 린트 설정 확인

STEP 5: 환경 정보 수집
├── 언어 버전
├── 프레임워크 버전
├── 환경 설정 파일
└── Docker 설정

STEP 6: 캐시 저장
├── analysis.json 생성
├── file-hashes.json 생성
└── 결과 요약 출력
```

### 5.3 출력 형식

```
═══════════════════════════════════════════════════════════════
WORKSPACE_ANALYSIS_RESULT: COMPLETE
═══════════════════════════════════════════════════════════════

📊 분석 요약
┌──────────────────┬──────────────────┐
│ 프로젝트 타입     │ TypeScript       │
│ 총 파일 수       │ 156              │
│ 소스 파일        │ 89               │
│ 테스트 파일      │ 34               │
│ 설정 파일        │ 12               │
│ 의존성           │ 45 packages      │
│ 분석 시간        │ 2.34s            │
└──────────────────┴──────────────────┘

📁 주요 디렉토리
├── src/           (소스 코드)
├── tests/         (테스트)
├── docs/          (문서)
└── scripts/       (빌드 스크립트)

💾 캐시 저장됨
→ .opencode/workspace-cache/analysis.json

═══════════════════════════════════════════════════════════════
```

---

## 6. Code-QA 통합

### 6.1 통합 방식

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      Code-QA 통합 전략                                   │
└─────────────────────────────────────────────────────────────────────────┘

시나리오 1: 캐시 존재 + 최신
┌────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│ /code-qa 실행  │────▶│ 캐시 확인       │────▶│ 캐시 데이터     │
│                │     │ (유효)          │     │ 직접 사용       │
└────────────────┘     └─────────────────┘     └─────────────────┘

시나리오 2: 캐시 없음 또는 오래됨
┌────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│ /code-qa 실행  │────▶│ 캐시 확인       │────▶│ /analyze 자동   │
│                │     │ (무효)          │     │ 실행            │
└────────────────┘     └─────────────────┘     └─────────────────┘
                                                       │
                                               ┌───────▼───────┐
                                               │ 분석 완료 후  │
                                               │ code-qa 계속  │
                                               └───────────────┘

시나리오 3: 강제 스킵
┌────────────────┐     ┌─────────────────┐
│ /code-qa       │────▶│ 캐시 무시       │
│ --skip-cache   │     │ 기존 방식 사용  │
└────────────────┘     └─────────────────┘
```

### 6.2 code-qa.md 수정 사항

```markdown
## Phase 0: Cache Check (새로 추가)

### 0.1 캐시 확인
1. `.opencode/workspace-cache/analysis.json` 존재 확인
2. `analyzed_at` 타임스탬프 확인 (24시간 이내)
3. 주요 파일 mtime 비교

### 0.2 캐시 유효 시
- 캐시 데이터를 컨텍스트에 로드
- Phase 1로 직접 진행

### 0.3 캐시 무효 시
- workspace-analyzer 자동 호출
- 분석 완료 후 Phase 1 진행

### 0.4 캐시 데이터 활용 위치
- **Phase 2 (Code Review)**: 파일 목록 제공
- **Phase 4 (Build Test)**: 빌드 명령 참조
- **Phase 5 (Function Test)**: 테스트 명령 참조
```

### 6.3 code-reviewer 프롬프트 개선

```markdown
## 기존 방식 (Changed files만 전달)
Changed files:
- /path/to/file1.ts
- /path/to/file2.ts

## 개선된 방식 (캐시 데이터 포함)
Project Context (from workspace cache):
- Project Type: TypeScript
- Entry Points: src/index.ts, src/server.ts
- Test Framework: Jest

Changed files to analyze:
- /path/to/file1.ts (src/components/)
- /path/to/file2.ts (src/utils/)

Related files (for context):
- /path/to/types.ts (type definitions)
- /path/to/config.ts (configuration)
```

---

## 7. 구현 계획

### 7.1 Phase 1: MVP (최소 기능)

| 작업 | 설명 | 우선순위 |
|------|------|----------|
| workspace-analyzer.md | 에이전트 정의 | P0 |
| analyze.md | 명령어 정의 | P0 |
| 프로젝트 구조 분석 | 파일 목록, 디렉토리 | P0 |
| 의존성 분석 | package.json 등 파싱 | P0 |
| 캐시 저장 | analysis.json 생성 | P0 |
| code-qa 통합 | 캐시 확인 로직 | P1 |

### 7.2 Phase 2: 확장 기능

| 작업 | 설명 | 우선순위 |
|------|------|----------|
| 증분 업데이트 | 변경 파일만 재분석 | P1 |
| 다중 언어 지원 | Go, Rust, Java 등 | P1 |
| 복잡도 분석 | cyclomatic complexity | P2 |
| 의존성 그래프 | 파일 간 import 관계 | P2 |
| 보안 스캔 | 민감 파일 감지 | P2 |

### 7.3 구현 순서

```
Day 1: 기본 구조
├── workspace-analyzer.md 생성
├── analyze.md 생성
└── 캐시 디렉토리 구조 설정

Day 2: 분석 로직
├── 프로젝트 타입 감지
├── 파일 구조 수집
└── 의존성 분석

Day 3: 캐시 및 통합
├── analysis.json 생성 로직
├── code-qa.md 캐시 통합
└── code-reviewer 프롬프트 개선

Day 4: 테스트 및 문서화
├── 다양한 프로젝트 타입 테스트
├── 문서 업데이트
└── 버그 수정
```

---

## 8. 사용 예시

### 8.1 기본 사용

```bash
# 워크스페이스 분석
/analyze

# 결과 확인
cat .opencode/workspace-cache/analysis.json
```

### 8.2 Code-QA와 함께 사용

```bash
# 방법 1: 사전 분석 후 QA
/analyze
/code-qa

# 방법 2: code-qa가 자동으로 분석 실행
/code-qa  # 캐시 없으면 자동 분석
```

### 8.3 강제 재분석

```bash
# 캐시 무시하고 재분석
/analyze --force

# code-qa에서 캐시 무시
/code-qa --skip-cache
```

### 8.4 분석만 사용 (QA 없이)

```bash
# 프로젝트 구조 파악용
/analyze

# 결과 활용
# - 신규 개발자 온보딩
# - 프로젝트 문서화
# - 코드 리뷰 준비
```

---

## 부록 A: 지원 프로젝트 타입

| 타입 | 감지 파일 | 패키지 매니저 |
|------|-----------|---------------|
| TypeScript/JavaScript | package.json, tsconfig.json | npm, yarn, pnpm |
| Python | requirements.txt, pyproject.toml, setup.py | pip, poetry, pipenv |
| Go | go.mod | go modules |
| Rust | Cargo.toml | cargo |
| Java | pom.xml, build.gradle | maven, gradle |
| C/C++ | Makefile, CMakeLists.txt | make, cmake |
| Ruby | Gemfile | bundler |
| PHP | composer.json | composer |

---

## 부록 B: 에러 처리

| 에러 상황 | 처리 방식 |
|-----------|-----------|
| 빈 프로젝트 | 기본 구조로 캐시 생성 |
| 권한 오류 | 경고 후 접근 가능한 파일만 분석 |
| 대용량 프로젝트 | 진행 상황 표시, 타임아웃 설정 |
| 알 수 없는 프로젝트 타입 | "unknown" 타입으로 기본 분석 |

---

## 변경 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|-----------|
| 1.0 | 2024-01-15 | 초기 설계 문서 |
