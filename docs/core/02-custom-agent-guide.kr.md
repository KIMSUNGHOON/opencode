# Custom Agent 생성 가이드

## 개요

OpenCode의 Agent 시스템은 특정 작업에 특화된 AI 에이전트를 정의하고 사용할 수 있게 해줍니다. 이 가이드에서는 Custom Agent를 생성하고 활용하는 방법을 상세히 설명합니다.

---

## 목차

1. [Agent 기본 개념](#1-agent-기본-개념)
2. [Agent 유형](#2-agent-유형)
3. [Agent 정의 방법](#3-agent-정의-방법)
4. [설정 옵션 상세](#4-설정-옵션-상세)
5. [권한 시스템](#5-권한-시스템)
6. [실전 예제](#6-실전-예제)
7. [모범 사례](#7-모범-사례)

---

## 1. Agent 기본 개념

### 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                        OpenCode Agent System                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │    build    │  │    plan     │  │  (custom)   │   Primary    │
│  │  (default)  │  │  (readonly) │  │   agents    │   Agents     │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘              │
│         │                │                │                      │
│         └────────────────┼────────────────┘                      │
│                          │                                       │
│                          ▼                                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │
│  │   general   │  │   explore   │  │  (custom)   │   Sub        │
│  │  (general)  │  │  (codebase) │  │  subagents  │   Agents     │
│  └─────────────┘  └─────────────┘  └─────────────┘              │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### 내장 Agent

| Agent | 모드 | 설명 |
|-------|------|------|
| `build` | primary | 기본 개발 에이전트, 전체 권한 |
| `plan` | primary | 읽기 전용, 분석 및 계획 수립 |
| `general` | subagent | 복잡한 검색 및 다단계 작업 |
| `explore` | subagent | 코드베이스 탐색 특화 |
| `title` | primary (hidden) | 세션 제목 생성 |
| `summary` | primary (hidden) | 요약 생성 |
| `compaction` | primary (hidden) | 컨텍스트 압축 |

---

## 2. Agent 유형

### 2.1 Primary Agent

사용자가 직접 선택하여 대화할 수 있는 메인 에이전트입니다.

**특징:**
- `Tab` 키로 에이전트 간 전환 가능
- 세션의 주 대화 상대
- TodoWrite, 질문 등 primary 전용 도구 사용 가능

**사용 시나리오:**
- 코드 개발 (`build`)
- 코드 분석 및 계획 (`plan`)
- 특정 도메인 전문 작업 (custom)

### 2.2 Subagent

Primary Agent가 호출하여 특정 작업을 위임하는 보조 에이전트입니다.

**특징:**
- `@agent_name` 구문으로 호출
- Primary Agent의 하위 세션으로 실행
- TodoWrite 기본 비활성화

**사용 시나리오:**
- 코드 검색 (`explore`)
- 병렬 작업 처리 (`general`)
- 특화된 작업 수행 (custom)

### 2.3 All 모드

Primary와 Subagent 모두로 사용 가능한 에이전트입니다.

---

## 3. Agent 정의 방법

### 3.1 마크다운 파일 방식 (권장)

`.opencode/agent/` 디렉토리에 마크다운 파일로 정의합니다.

**파일 위치:**
```
.opencode/
└── agent/
    ├── my-agent.md
    ├── code-reviewer.md
    └── git-expert.md
```

**기본 구조:**
```markdown
---
# YAML Frontmatter (설정)
description: 에이전트 설명
mode: subagent
model: provider/model-id
---

# 시스템 프롬프트 (마크다운 본문)

여기에 에이전트의 역할과 지시사항을 작성합니다.
```

### 3.2 JSON 설정 방식

`opencode.json`의 `agent` 섹션에서 정의합니다.

```json
{
  "agent": {
    "my-agent": {
      "description": "에이전트 설명",
      "mode": "subagent",
      "model": "provider/model-id",
      "prompt": "시스템 프롬프트 내용"
    }
  }
}
```

### 3.3 글로벌 vs 프로젝트 Agent

| 위치 | 범위 | 경로 |
|------|------|------|
| 글로벌 | 모든 프로젝트 | `~/.config/opencode/.opencode/agent/` |
| 프로젝트 | 해당 프로젝트만 | `./.opencode/agent/` |

---

## 4. 설정 옵션 상세

### 4.1 Frontmatter 옵션

```yaml
---
# 기본 정보
description: "에이전트가 하는 일에 대한 설명"
mode: subagent  # primary | subagent | all

# 모델 설정
model: provider/model-id
temperature: 0.7
top_p: 0.9

# 표시 설정
color: "#FF6B35"
hidden: false

# 실행 제한
steps: 50

# 권한 설정
permission:
  bash: allow
  read: allow
  edit: deny
---
```

### 4.2 옵션 상세 설명

| 옵션 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `description` | string | - | 에이전트 설명 (@ 자동완성에 표시) |
| `mode` | enum | `all` | `primary`, `subagent`, `all` |
| `model` | string | 상위 설정 | `provider/model-id` 형식 |
| `temperature` | number | 모델 기본값 | 출력 다양성 (0.0-2.0) |
| `top_p` | number | 모델 기본값 | 누적 확률 샘플링 |
| `color` | string | - | HEX 색상 코드 (#RRGGBB) |
| `hidden` | boolean | false | @ 메뉴에서 숨김 |
| `steps` | number | - | 최대 반복 횟수 |
| `disable` | boolean | false | 에이전트 비활성화 |
| `permission` | object | - | 도구별 권한 설정 |

### 4.3 Model 설정

단일 모델 환경에서는 모든 에이전트가 동일 모델을 사용하도록 설정합니다.

```yaml
---
model: provider/model-id
---
```

또는 글로벌 설정에서:
```json
{
  "model": "provider/model-id",
  "agent": {
    "build": { "model": "provider/model-id" },
    "plan": { "model": "provider/model-id" },
    "general": { "model": "provider/model-id" },
    "explore": { "model": "provider/model-id" }
  }
}
```

---

## 5. 권한 시스템

### 5.1 권한 구조

```yaml
permission:
  <permission_name>: <action>
  # 또는
  <permission_name>:
    <pattern>: <action>
```

### 5.2 권한 종류

| 권한 | 설명 |
|------|------|
| `read` | 파일 읽기 |
| `edit` | 파일 편집 |
| `bash` | 쉘 명령 실행 |
| `glob` | 파일 패턴 검색 |
| `grep` | 텍스트 검색 |
| `list` | 디렉토리 목록 |
| `task` | 서브에이전트 호출 |
| `webfetch` | 웹 페이지 가져오기 |
| `websearch` | 웹 검색 |
| `codesearch` | 코드 검색 |
| `todowrite` | 할 일 목록 작성 |
| `todoread` | 할 일 목록 읽기 |
| `question` | 사용자에게 질문 |
| `external_directory` | 외부 디렉토리 접근 |
| `lsp` | LSP 기능 사용 |

### 5.3 액션 종류

| 액션 | 설명 |
|------|------|
| `allow` | 항상 허용 |
| `deny` | 항상 거부 |
| `ask` | 사용자에게 확인 |

### 5.4 패턴 매칭

```yaml
permission:
  read:
    "*": allow
    "*.env": deny
    "*.env.example": allow
  edit:
    "src/**/*.ts": allow
    "config/*": ask
  bash:
    "git *": allow
    "rm -rf *": deny
```

### 5.5 권한 예제

**읽기 전용 에이전트:**
```yaml
permission:
  "*": deny
  read: allow
  glob: allow
  grep: allow
  list: allow
```

**코드 편집 에이전트:**
```yaml
permission:
  "*": allow
  bash:
    "rm *": deny
    "git push --force *": deny
```

**특정 디렉토리 전용:**
```yaml
permission:
  read:
    "src/**": allow
    "*": deny
  edit:
    "src/**/*.ts": allow
    "*": deny
```

---

## 6. 실전 예제

### 6.1 코드 리뷰어

`.opencode/agent/code-reviewer.md`:
```markdown
---
description: 코드 품질 검토 및 개선 제안
mode: subagent
color: "#4CAF50"
permission:
  read: allow
  glob: allow
  grep: allow
  edit: deny
  bash: deny
---

# 코드 리뷰어

당신은 경험 많은 시니어 개발자로서 코드 리뷰를 수행합니다.

## 검토 기준

1. **코드 품질**
   - 가독성
   - 유지보수성
   - SOLID 원칙 준수

2. **보안**
   - 입력 검증
   - 인증/인가
   - 민감 데이터 처리

3. **성능**
   - 알고리즘 효율성
   - 메모리 사용
   - 불필요한 연산

## 출력 형식

각 이슈에 대해:
- 위치 (파일:라인)
- 심각도 (Critical/Major/Minor/Suggestion)
- 설명
- 제안 코드 (있다면)
```

### 6.2 테스트 작성자

`.opencode/agent/test-writer.md`:
```markdown
---
description: 단위 테스트 및 통합 테스트 작성
mode: subagent
color: "#2196F3"
permission:
  read: allow
  glob: allow
  grep: allow
  edit:
    "**/*.test.ts": allow
    "**/*.spec.ts": allow
    "**/__tests__/**": allow
    "*": deny
  bash:
    "bun test *": allow
    "npm test *": allow
    "*": deny
---

# 테스트 작성 전문가

당신은 테스트 주도 개발(TDD) 전문가입니다.

## 테스트 작성 원칙

1. **AAA 패턴**: Arrange, Act, Assert
2. **단일 책임**: 테스트당 하나의 동작 검증
3. **독립성**: 테스트 간 의존성 없음
4. **명확한 이름**: 테스트 이름으로 의도 파악 가능

## 커버리지 목표

- 라인 커버리지: 80% 이상
- 분기 커버리지: 75% 이상
- 엣지 케이스 포함

## 테스트 프레임워크

- TypeScript: Vitest, Jest, Bun Test
- 패턴: describe/it/expect
```

### 6.3 문서 작성자

`.opencode/agent/doc-writer.md`:
```markdown
---
description: 기술 문서 및 API 문서 작성
mode: subagent
color: "#FF9800"
permission:
  read: allow
  glob: allow
  grep: allow
  edit:
    "**/*.md": allow
    "docs/**": allow
    "*": deny
  bash: deny
---

# 기술 문서 작성자

당신은 명확하고 구조화된 기술 문서를 작성합니다.

## 문서 스타일

- 간결하고 명확한 문장
- 코드 예제 포함
- 단계별 가이드 형식

## 문서 구조

1. 개요
2. 설치/설정
3. 기본 사용법
4. 고급 기능
5. API 레퍼런스
6. FAQ/문제 해결
```

### 6.4 Git 전문가

`.opencode/agent/git-expert.md`:
```markdown
---
description: Git 작업 및 버전 관리 전문가
mode: subagent
color: "#F44336"
permission:
  read: allow
  glob: allow
  grep: allow
  edit: deny
  bash:
    "git status": allow
    "git log *": allow
    "git diff *": allow
    "git branch *": allow
    "git checkout *": allow
    "git fetch *": allow
    "git pull *": allow
    "git rebase *": ask
    "git merge *": ask
    "git push *": ask
    "git push --force *": deny
    "git reset --hard *": deny
    "*": deny
---

# Git 전문가

당신은 Git 버전 관리 전문가입니다.

## 안전 규칙

1. **절대 금지**
   - `git push --force` (main/master)
   - `git reset --hard` (원격과 동기화된 커밋)
   - 히스토리 변조

2. **확인 필요**
   - Rebase 작업
   - Merge 작업
   - 원격 Push

## 작업 패턴

- Feature Branch: feature/이슈번호-설명
- Commit Message: type(scope): description
- PR: 작은 단위로 분리
```

### 6.5 보안 분석가

`.opencode/agent/security-analyst.md`:
```markdown
---
description: 보안 취약점 분석 및 권고
mode: subagent
color: "#9C27B0"
permission:
  read: allow
  glob: allow
  grep: allow
  edit: deny
  bash:
    "npm audit *": allow
    "bun audit *": allow
    "*": deny
---

# 보안 분석가

당신은 애플리케이션 보안 전문가입니다.

## 분석 영역

1. **OWASP Top 10**
   - Injection (SQL, XSS, Command)
   - Broken Authentication
   - Sensitive Data Exposure
   - Security Misconfiguration

2. **의존성 취약점**
   - npm audit 결과 분석
   - CVE 확인

3. **코드 패턴**
   - 하드코딩된 비밀
   - 안전하지 않은 암호화
   - 부적절한 에러 처리

## 보고서 형식

| 심각도 | 취약점 | 위치 | 권고 |
|--------|--------|------|------|
| Critical/High/Medium/Low | 설명 | 파일:라인 | 해결 방안 |
```

---

## 7. 모범 사례

### 7.1 명확한 역할 정의

**좋은 예:**
```markdown
---
description: TypeScript 타입 오류 수정 전문가
---
당신은 TypeScript 컴파일 오류를 분석하고 수정합니다.
```

**나쁜 예:**
```markdown
---
description: 개발 도우미
---
코딩을 도와줍니다.
```

### 7.2 최소 권한 원칙

필요한 권한만 부여:
```yaml
permission:
  "*": deny
  read: allow
  glob: allow
  # 필요한 것만 추가
```

### 7.3 단일 모델 환경 최적화

모든 에이전트에 동일 모델 지정:
```json
{
  "agent": {
    "build": { "model": "provider/model-id" },
    "plan": { "model": "provider/model-id" },
    "general": { "model": "provider/model-id" },
    "explore": { "model": "provider/model-id" },
    "code-reviewer": { "model": "provider/model-id" }
  }
}
```

### 7.4 프롬프트 구조화

```markdown
# 역할

## 목표

## 규칙/제약

## 출력 형식

## 예시
```

### 7.5 테스트 및 검증

1. 새 에이전트 생성 후 기본 동작 테스트
2. 권한 설정 확인 (의도한 대로 허용/거부되는지)
3. 엣지 케이스 테스트