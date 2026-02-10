> **Note**: This document references `sglang/gpt-oss-120b` model IDs which are outdated. The current system uses a single model: `glm/GLM-4.7-FP8` (355B MoE with Interleaved Thinking). See [14-code-qa-v4-quick-start.md](./14-code-qa-v4-quick-start.md) for current configuration. The tool usage patterns described here remain valid.

# 외부 도구 사용 가이드

## 개요

OpenCode는 다양한 내장 도구와 MCP를 통한 외부 도구를 제공합니다. 이 가이드에서는 각 도구의 용도, 사용법, 설정 방법을 상세히 설명합니다.

---

## 목차

1. [도구 시스템 개요](#1-도구-시스템-개요)
2. [내장 도구](#2-내장-도구)
3. [MCP 확장 도구](#3-mcp-확장-도구)
4. [Custom Command](#4-custom-command)
5. [권한 관리](#5-권한-관리)
6. [실전 활용](#6-실전-활용)

---

## 1. 도구 시스템 개요

### 아키텍처

```
┌────────────────────────────────────────────────────────────────┐
│                      OpenCode Tool System                       │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    Built-in Tools                        │   │
│  ├─────────────────────────────────────────────────────────┤   │
│  │  File      │  Search    │  Execution │  Web      │ Task │   │
│  │  ─────     │  ──────    │  ─────────  │  ───      │ ──── │   │
│  │  read      │  glob      │  bash      │  webfetch │ task │   │
│  │  edit      │  grep      │            │  websearch│      │   │
│  │  list      │  codesearch│            │           │      │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                  │
│                              ▼                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    MCP Tools                             │   │
│  ├─────────────────────────────────────────────────────────┤   │
│  │  filesystem_*  │  github_*  │  postgres_*  │  custom_*  │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

### 도구 호출 흐름

```
User Request
     │
     ▼
┌─────────────┐
│   Agent     │
└──────┬──────┘
       │
       ▼
┌─────────────┐     ┌─────────────┐
│  Permission │────▶│   Denied    │
│    Check    │     └─────────────┘
└──────┬──────┘
       │ Allowed/Ask
       ▼
┌─────────────┐
│    Tool     │
│  Execution  │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Result    │
└─────────────┘
```

---

## 2. 내장 도구

### 2.1 파일 도구

#### read - 파일 읽기

파일 내용을 읽어 반환합니다.

**기능:**
- 텍스트 파일 읽기
- 이미지 파일 시각적 분석
- PDF 파일 읽기
- Jupyter Notebook 읽기

**예시:**
```
파일 src/index.ts의 내용을 읽어주세요.
```

**권한 설정:**
```yaml
permission:
  read:
    "*": allow
    "*.env": ask
    "*.env.*": ask
    ".git/**": deny
```

#### edit - 파일 편집

파일의 특정 부분을 수정합니다.

**기능:**
- 문자열 치환
- 전체 치환 (replace_all)
- 정확한 매칭 필요

**예시:**
```
index.ts에서 console.log를 logger.info로 변경해주세요.
```

**권한 설정:**
```yaml
permission:
  edit:
    "src/**/*.ts": allow
    "config/*": ask
    "package.json": ask
    "*": deny
```

#### list - 디렉토리 목록

디렉토리의 파일/폴더 목록을 반환합니다.

**예시:**
```
src 디렉토리의 구조를 보여주세요.
```

---

### 2.2 검색 도구

#### glob - 파일 패턴 검색

파일 경로 패턴으로 파일을 찾습니다.

**패턴 문법:**
| 패턴 | 설명 | 예시 |
|------|------|------|
| `*` | 단일 레벨 와일드카드 | `*.ts` |
| `**` | 재귀 와일드카드 | `src/**/*.ts` |
| `?` | 단일 문자 | `file?.txt` |
| `{a,b}` | 대안 | `*.{ts,js}` |
| `[abc]` | 문자 클래스 | `file[123].txt` |

**예시:**
```
src 폴더의 모든 TypeScript 파일을 찾아주세요.
→ glob: src/**/*.ts
```

#### grep - 텍스트 검색

파일 내용에서 텍스트를 검색합니다.

**기능:**
- 정규식 지원
- 파일 타입 필터
- 컨텍스트 라인 표시

**예시:**
```
"fetchUser" 함수가 사용된 모든 위치를 찾아주세요.
→ grep: fetchUser
```

**출력 모드:**
| 모드 | 설명 |
|------|------|
| `files_with_matches` | 파일 경로만 (기본) |
| `content` | 매칭된 라인 포함 |
| `count` | 매칭 횟수 |

#### codesearch - 코드 검색

코드 구조 기반 검색 (심볼, 정의, 참조).

**예시:**
```
UserService 클래스의 정의를 찾아주세요.
```

---

### 2.3 실행 도구

#### bash - 쉘 명령 실행

쉘 명령을 실행합니다.

**기능:**
- 명령 실행
- 타임아웃 설정 (기본 2분, 최대 10분)
- 백그라운드 실행

**예시:**
```
npm install을 실행해주세요.
```

**안전 설정:**
```yaml
permission:
  bash:
    "npm *": allow
    "bun *": allow
    "git status": allow
    "git log *": allow
    "rm -rf *": deny
    "sudo *": deny
    "*": ask
```

**주의사항:**
- 파일 조작은 전용 도구 사용 권장 (read, edit, glob 등)
- 민감한 명령은 권한 시스템으로 제어

---

### 2.4 웹 도구

#### webfetch - 웹 페이지 가져오기

URL의 내용을 가져와 분석합니다.

**기능:**
- HTML → Markdown 변환
- AI를 통한 내용 분석
- 리다이렉트 처리

**예시:**
```
https://docs.example.com/api 문서를 읽어주세요.
```

**제한사항:**
- 인증이 필요한 페이지는 MCP 사용 권장
- 대용량 페이지는 요약됨

#### websearch - 웹 검색

웹에서 정보를 검색합니다.

**기능:**
- 실시간 검색 결과
- 도메인 필터링 가능

**예시:**
```
React 18의 새로운 기능을 검색해주세요.
```

---

### 2.5 에이전트 도구

#### task - 서브에이전트 호출

다른 에이전트에게 작업을 위임합니다.

**기능:**
- 특화된 에이전트 호출
- 병렬 작업 처리
- 세션 컨텍스트 분리

**호출 방법:**
```
@explore src 디렉토리에서 API 관련 파일을 찾아주세요.
@general 복잡한 리팩토링 작업을 병렬로 처리해주세요.
```

**내장 서브에이전트:**

| 에이전트 | 용도 |
|----------|------|
| `@general` | 복잡한 검색, 다단계 작업 |
| `@explore` | 코드베이스 탐색 |

---

### 2.6 기타 도구

#### todowrite / todoread

작업 목록 관리 (Primary Agent 전용).

```
이 작업을 할 일 목록에 추가해주세요.
```

#### question

사용자에게 질문 (Primary Agent 전용).

```
어떤 데이터베이스를 사용할지 선택해주세요:
1. PostgreSQL
2. MySQL
3. SQLite
```

#### lsp

Language Server Protocol 기능 활용.

```
이 함수의 정의로 이동해주세요.
```

---

## 3. MCP 확장 도구

### 3.1 MCP 도구 네이밍

MCP 도구는 `{서버명}_{도구명}` 형식으로 명명됩니다.

```
예시:
- github_create_issue
- filesystem_read_file
- postgres_query
```

### 3.2 주요 MCP 도구 목록

#### Filesystem 서버

| 도구 | 설명 |
|------|------|
| `filesystem_read_file` | 파일 읽기 |
| `filesystem_write_file` | 파일 쓰기 |
| `filesystem_list_directory` | 디렉토리 목록 |
| `filesystem_create_directory` | 디렉토리 생성 |
| `filesystem_move_file` | 파일 이동 |
| `filesystem_search_files` | 파일 검색 |

#### GitHub 서버

| 도구 | 설명 |
|------|------|
| `github_create_issue` | 이슈 생성 |
| `github_create_pull_request` | PR 생성 |
| `github_get_file_contents` | 파일 내용 가져오기 |
| `github_push_files` | 파일 푸시 |
| `github_list_commits` | 커밋 목록 |
| `github_search_code` | 코드 검색 |

#### Git 서버

| 도구 | 설명 |
|------|------|
| `git_status` | 상태 확인 |
| `git_diff` | 변경 내용 |
| `git_log` | 히스토리 |
| `git_commit` | 커밋 |
| `git_branch` | 브랜치 관리 |

#### PostgreSQL 서버

| 도구 | 설명 |
|------|------|
| `postgres_query` | SQL 쿼리 실행 |
| `postgres_list_tables` | 테이블 목록 |
| `postgres_describe_table` | 테이블 스키마 |

### 3.3 MCP 도구 설정

```json
{
  "mcp": {
    "github": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-github"],
      "environment": {
        "GITHUB_TOKEN": "{env:GITHUB_TOKEN}"
      }
    }
  }
}
```

---

## 4. Custom Command

### 4.1 Command 정의

`.opencode/command/` 디렉토리에 마크다운 파일로 정의합니다.

**기본 구조:**
```markdown
---
description: "명령어 설명"
model: sglang/gpt-oss-120b
agent: build
subtask: false
---

명령어 실행 시 전달될 프롬프트 템플릿

$ARGUMENTS
```

### 4.2 Frontmatter 옵션

| 옵션 | 타입 | 설명 |
|------|------|------|
| `description` | string | 명령어 설명 |
| `model` | string | 사용할 모델 |
| `agent` | string | 사용할 에이전트 |
| `subtask` | boolean | 서브태스크로 실행 여부 |

### 4.3 변수

| 변수 | 설명 |
|------|------|
| `$ARGUMENTS` | 사용자가 입력한 인자 |

### 4.4 Command 예제

#### 커밋 명령어

`.opencode/command/commit.md`:
```markdown
---
description: "Git 커밋 생성"
model: sglang/gpt-oss-120b
subtask: true
---

다음 지침에 따라 커밋을 생성하세요:

1. `git status`로 변경사항 확인
2. `git diff`로 상세 변경 내용 확인
3. 커밋 메시지 작성 (Conventional Commits)
4. `git commit` 실행

$ARGUMENTS

## 커밋 메시지 형식

type(scope): description

- feat: 새 기능
- fix: 버그 수정
- docs: 문서
- refactor: 리팩토링
- test: 테스트
```

**사용:**
```
/commit 사용자 인증 기능 추가
```

#### 코드 리뷰 명령어

`.opencode/command/review.md`:
```markdown
---
description: "코드 리뷰 수행"
model: sglang/gpt-oss-120b
---

다음 파일/변경사항을 리뷰하세요:

$ARGUMENTS

## 리뷰 기준

1. 코드 품질
2. 보안 취약점
3. 성능 이슈
4. 베스트 프랙티스

## 출력 형식

각 이슈에 대해:
- 위치
- 심각도
- 설명
- 제안
```

**사용:**
```
/review src/auth/login.ts
```

#### 테스트 명령어

`.opencode/command/test.md`:
```markdown
---
description: "테스트 실행 및 분석"
model: sglang/gpt-oss-120b
subtask: true
---

$ARGUMENTS

## 작업 순서

1. 테스트 실행: `bun test`
2. 실패한 테스트 분석
3. 수정 제안

실패 시 원인을 분석하고 해결 방안을 제시하세요.
```

---

## 5. 권한 관리

### 5.1 글로벌 권한

`opencode.json`에서 전역 권한 설정:

```json
{
  "permission": {
    "read": "allow",
    "edit": "allow",
    "bash": "ask",
    "webfetch": "allow",
    "websearch": "allow",
    "external_directory": "ask"
  }
}
```

### 5.2 에이전트별 권한

특정 에이전트에 대한 권한 오버라이드:

```yaml
# .opencode/agent/readonly.md
---
permission:
  "*": deny
  read: allow
  glob: allow
  grep: allow
---
```

### 5.3 패턴 기반 권한

```json
{
  "permission": {
    "read": {
      "*": "allow",
      "*.env": "deny",
      "*.key": "deny",
      ".git/**": "deny"
    },
    "edit": {
      "src/**": "allow",
      "test/**": "allow",
      "*.config.*": "ask",
      "*": "deny"
    },
    "bash": {
      "npm *": "allow",
      "git log *": "allow",
      "git status": "allow",
      "rm *": "deny",
      "*": "ask"
    }
  }
}
```

### 5.4 MCP 도구 권한

MCP 도구도 동일한 권한 시스템 적용:

```json
{
  "permission": {
    "github_create_issue": "allow",
    "github_push_files": "ask",
    "postgres_query": "ask"
  }
}
```

---

## 6. 실전 활용

### 6.1 코드 분석 워크플로우

```
사용자: 이 프로젝트의 아키텍처를 분석해주세요.

Agent:
1. glob: **/*.ts - 파일 구조 파악
2. read: src/index.ts - 진입점 확인
3. grep: "import.*from" - 의존성 분석
4. @explore: 코드베이스 심층 탐색
5. 결과 종합 및 다이어그램 생성
```

### 6.2 버그 수정 워크플로우

```
사용자: TypeError: Cannot read property 'name' of undefined 에러를 수정해주세요.

Agent:
1. grep: "\.name" - 관련 코드 검색
2. read: 오류 발생 파일
3. 원인 분석
4. edit: 수정 적용
5. bash: bun test - 테스트 실행
```

### 6.3 리팩토링 워크플로우

```
사용자: UserService를 분리해주세요.

Agent:
1. read: src/services/UserService.ts
2. 의존성 분석
3. 분리 계획 수립
4. @general: 병렬로 파일 생성
5. edit: 기존 파일 수정
6. 테스트 검증
```

### 6.4 문서화 워크플로우

```
사용자: API 문서를 생성해주세요.

Agent:
1. glob: src/api/**/*.ts
2. read: 각 API 파일
3. 엔드포인트, 파라미터, 응답 추출
4. edit: docs/api.md 생성
```

### 6.5 도구 조합 팁

| 작업 | 권장 도구 조합 |
|------|---------------|
| 코드 찾기 | glob → grep → read |
| 리팩토링 | grep → read → edit → bash (test) |
| 문서화 | glob → read → edit |
| 디버깅 | grep → read → bash (run) |
| 의존성 분석 | glob → grep → @explore |
