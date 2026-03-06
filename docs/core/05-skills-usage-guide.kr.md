# OpenCode Skills: 완전 사용 가이드

## Skills란?

Skills는 **온디맨드 지식 모듈**로, 도메인 특화 지시사항, 체크리스트, 워크플로우, 번들 리소스를 대화 컨텍스트에 주입합니다. 시스템 프롬프트(항상 로드)와 달리, 스킬은 **필요할 때만 로드**되어 컨텍스트 윈도우를 효율적으로 유지합니다.

### Skills vs 다른 개념 비교

| 개념 | 로드 시점 | 목적 |
|------|----------|------|
| **AGENTS.md / CLAUDE.md** | 항상 (시스템 프롬프트) | 프로젝트 전역 지시사항 |
| **Agent** | 에이전트 선택 시 | 다른 LLM 페르소나/모델 |
| **Command** | `/command` 호출 시 | 미리 정의된 프롬프트 템플릿 |
| **Skill** | 온디맨드 (도구 호출 또는 `/skill`) | 도메인 특화 지식 주입 |

핵심 차이: Skills는 **참조 지식**(체크리스트, 패턴, 의사결정 트리)을 제공하고, Commands는 **액션 템플릿**(프롬프트 텍스트)을 제공합니다. 스킬은 컨텍스트에 지식 베이스로 남고, 커맨드는 일회성 프롬프트입니다.

---

## OpenCode TUI에서 Skills 사용법

### 호출 방법 1: 슬래시 커맨드 (`/skill-name`)

가장 간단한 방법입니다. 프롬프트 입력창에 `/` 뒤에 스킬 이름을 직접 입력합니다:

```
/code-review 인증 모듈의 보안 이슈를 검토해주세요
```

스킬의 내용이 프롬프트의 일부로 전송됩니다. LLM은 스킬 지시사항과 사용자 작업을 모두 받게 됩니다.

### 호출 방법 2: Skills 다이얼로그

1. **Command Palette** 열기 (기본: `Ctrl+K` 또는 설정된 키바인딩)
2. 메뉴에서 **"Skills"** 선택
3. 검색 가능한 다이얼로그가 나타나 사용 가능한 모든 스킬을 표시
4. 스킬 선택 → 프롬프트 입력창에 `/{skill-name} ` 삽입
5. 스킬 이름 뒤에 작업 내용을 입력하고 제출

### 호출 방법 3: 자동 (LLM 주도)

LLM은 `skill` 도구 설명에서 사용 가능한 스킬 목록을 봅니다. 작업이 스킬과 일치한다고 인식하면 **자동으로** 스킬 도구를 호출하여 지식을 로드합니다. 사용자가 별도로 할 일이 없습니다.

예를 들어, "이 코드의 보안 취약점을 검토해주세요"라고 요청하면 `code-review` 스킬이 있을 경우 LLM이 자동으로 호출할 수 있습니다.

### 호출 방법 4: CLI 디버그

```bash
# 발견된 모든 스킬 목록
opencode skill list

# 특정 스킬 내용 확인
opencode skill show code-review
```

---

## 나만의 Skills 만들기

### 디렉토리 구조

`SKILL.md` 파일이 포함된 폴더를 생성합니다. OpenCode는 다음 위치를 순서대로 검색합니다:

```
# 프로젝트 수준 (최우선, 글로벌 덮어쓰기)
.opencode/skills/<name>/SKILL.md        # OpenCode 네이티브
.claude/skills/<name>/SKILL.md          # Claude Code 호환
.agents/skills/<name>/SKILL.md          # Agent 호환

# 글로벌 (낮은 우선순위)
~/.config/opencode/skills/<name>/SKILL.md
~/.claude/skills/<name>/SKILL.md
~/.agents/skills/<name>/SKILL.md
```

### SKILL.md 형식

```markdown
---
name: my-skill-name
description: 이 스킬이 제공하는 것에 대한 한줄 설명 (최대 1024자)
---

# 스킬 제목

여기에 스킬 내용을 작성합니다. 이 내용이 스킬이 로드될 때
대화 컨텍스트에 주입되는 지식입니다.

## 의사결정 트리, 체크리스트, 참조 테이블...

본문의 모든 내용이 스킬의 `content`가 됩니다.
```

### 이름 규칙

- **1-64자**, 소문자 영숫자
- 단일 하이픈만 구분자로 사용 (`--` 불가)
- `-`로 시작하거나 끝날 수 없음
- **디렉토리 이름과 일치해야 함** (폴더 `code-review/` → `name: code-review`)
- 정규식: `^[a-z0-9]+(-[a-z0-9]+)*$`

---

## Skills에 리소스 번들링

여기서 강력해집니다. **스킬 디렉토리는 SKILL.md만을 위한 것이 아닙니다** — 함께 파일을 포함할 수 있으며, LLM이 이 파일들에 접근할 수 있습니다.

### 동작 원리

스킬이 로드되면 OpenCode는:
1. `SKILL.md` 내용 읽기 → `<skill_content>`로 주입
2. 스킬 디렉토리의 **최대 10개 파일** 목록 → `<skill_files>`로 주입
3. **베이스 디렉토리** 설정 → LLM이 상대 경로로 파일 참조 가능

### 예시: 참조 데이터가 포함된 스킬

```
.opencode/skills/api-review/
├── SKILL.md                    # 메인 지시사항
├── reference/
│   ├── owasp-top-10.md        # 참조 문서
│   └── api-standards.md       # 회사 API 표준
├── scripts/
│   └── check-endpoints.sh     # 헬퍼 스크립트
└── templates/
    └── review-report.md       # 출력 템플릿
```

`SKILL.md`에서 이 파일들을 참조합니다:

```markdown
---
name: api-review
description: OWASP top 10과 회사 표준을 활용한 API 보안 검토
---

## 지시사항

1. `reference/owasp-top-10.md`에서 보안 체크리스트 읽기
2. `reference/api-standards.md`에서 회사 컨벤션 읽기
3. `scripts/check-endpoints.sh` 실행하여 엔드포인트 열거
4. `templates/review-report.md`를 출력 형식으로 사용

## 사용 시점

API 엔드포인트의 보안 및 컴플라이언스 검토 시 이 스킬을 로드하세요.
```

LLM은 스킬의 베이스 디렉토리를 사용하여 `read` 도구로 이 번들 파일들에 접근할 수 있습니다.

---

## Skills를 통한 도메인 지식 주입

### 전략 1: Markdown 리포트를 스킬 콘텐츠로

상세 분석 리포트가 있다면, SKILL.md 본문에 직접 포함하거나 번들 파일로 참조합니다:

```
.opencode/skills/project-knowledge/
├── SKILL.md              # 리포트를 포함하거나 참조
├── architecture.md       # 상세 아키텍처 분석
├── api-inventory.md      # 모든 API 엔드포인트 문서화
└── dependency-map.md     # 의존성 분석 결과
```

**SKILL.md:**
```markdown
---
name: project-knowledge
description: 프로젝트 도메인 지식 — 아키텍처, API, 의존성. 이 프로젝트 구조에 대한 깊은 컨텍스트가 필요할 때 로드하세요.
---

## 이 지식 사용법

이 스킬은 사전 분석된 프로젝트 문서에 대한 접근을 제공합니다:

1. `architecture.md` — 시스템 아키텍처 및 컴포넌트 관계
2. `api-inventory.md` — 완전한 API 엔드포인트 인벤토리
3. `dependency-map.md` — 의존성 그래프 및 버전 제약

작업에 따라 관련 파일을 읽으세요:
- 아키텍처 질문 → `architecture.md` 읽기
- API 작업 → `api-inventory.md` 읽기
- 의존성 이슈 → `dependency-map.md` 읽기

## 핵심 아키텍처 요약

(LLM이 추가 파일을 읽지 않고도 즉시 컨텍스트를 얻을 수 있도록
압축된 요약을 여기에 포함)

### 핵심 컴포넌트
- 컴포넌트 A: X 처리
- 컴포넌트 B: Y 처리
- 컴포넌트 C: Z 처리

### 크리티컬 경로
- 사용자 인증: A → B → DB
- 데이터 처리: C → Queue → Worker
```

### 전략 2: 워크스페이스 캐시를 스킬 참조로

프로젝트에서 `analyze` 또는 유사한 도구로 생성된 워크스페이스 캐시 파일이 있다면, 그 출력을 참조하는 스킬을 만들 수 있습니다:

```
.opencode/skills/workspace-context/
├── SKILL.md
└── cache/                    # 분석 결과의 심볼릭 링크 또는 복사본
    ├── file-index.json
    ├── module-tiers.json
    └── dependency-graph.json
```

**SKILL.md:**
```markdown
---
name: workspace-context
description: 사전 분석된 워크스페이스 구조 — 파일 인덱스, 모듈 티어, 의존성 그래프. 코드베이스 탐색 및 이해를 위해 로드하세요.
---

## 워크스페이스 분석 데이터

이 스킬은 사전 계산된 워크스페이스 분석에 대한 접근을 제공합니다:

- `cache/file-index.json` — 메타데이터가 포함된 모든 소스 파일
- `cache/module-tiers.json` — 모듈 중요도 티어 (1=핵심, 2=중요, 3=주변)
- `cache/dependency-graph.json` — 모듈 간 의존성 관계

## 사용법

프로젝트 구조나 모듈 관계에 대한 질문 시:
1. `cache/module-tiers.json`을 읽어 컴포넌트 중요도 파악
2. `cache/dependency-graph.json`으로 관계 확인
3. 티어 정보를 활용하여 분석 우선순위 결정 (Tier 1 먼저)

## 빠른 참조

(LLM이 즉시 방향을 잡을 수 있도록 압축된 요약 포함)
```

### 전략 3: `instructions` 설정으로 항상 활성화된 컨텍스트

**항상** 사용 가능해야 하는 지식(온디맨드가 아닌)은 설정의 `instructions` 필드를 사용합니다:

**opencode.json:**
```json
{
  "instructions": [
    "./docs/architecture-summary.md",
    "./docs/coding-conventions.md"
  ]
}
```

이 파일들은 모든 대화의 시스템 프롬프트 일부로 로드됩니다.

### 전략 4: Skills + Config `paths`로 외부 지식 베이스

지식 베이스가 표준 스킬 디렉토리 외부에 있는 경우:

**opencode.json:**
```json
{
  "skills": {
    "paths": [
      "./knowledge-base/skills",
      "~/shared-team-skills"
    ],
    "urls": [
      "https://internal.example.com/.well-known/skills/"
    ]
  }
}
```

OpenCode에게 추가 디렉토리에서 `**/SKILL.md` 파일을 스캔하도록 지시합니다.

---

## 권한 및 접근 제어

### 글로벌 권한 설정

**opencode.json:**
```json
{
  "permission": {
    "skill": {
      "*": "allow",
      "internal-*": "deny",
      "experimental-*": "ask"
    }
  }
}
```

| 권한 | 동작 |
|------|------|
| `allow` | 확인 없이 즉시 로드 |
| `deny` | 에이전트에서 숨김, 접근 거부 |
| `ask` | 로드 전 사용자 승인 요청 |

### 에이전트별 권한

커스텀 에이전트 frontmatter에서:
```yaml
---
permission:
  skill:
    "documents-*": "allow"
    "code-*": "deny"
---
```

opencode.json에서 빌트인 에이전트용:
```json
{
  "agent": {
    "plan": {
      "permission": {
        "skill": {
          "internal-*": "allow"
        }
      }
    }
  }
}
```

### Skills 완전 비활성화

스킬을 사용하지 않아야 하는 에이전트:

```yaml
# 커스텀 에이전트 frontmatter
---
tools:
  skill: false
---
```

```json
// opencode.json - 빌트인 에이전트
{
  "agent": {
    "plan": {
      "tools": {
        "skill": false
      }
    }
  }
}
```

---

## 실전 활용 패턴

### 패턴 1: 도메인 특화 코드 리뷰

```
.opencode/skills/domain-review/
├── SKILL.md
├── business-rules.md          # 비즈니스 규칙 정리
├── data-model.md              # 데이터 모델 문서
└── coding-standards.md        # 팀 코딩 표준
```

사용: `/domain-review PR #42의 변경사항을 리뷰해주세요`

### 패턴 2: 분석 캐시 + 위키 생성

1. 먼저 워크스페이스 분석 실행 → 캐시 파일 생성
2. 캐시를 스킬 디렉토리에 복사/심링크
3. `wiki-generation` 스킬과 `workspace-context` 스킬을 함께 활용

```
/workspace-context 프로젝트 구조를 파악한 후 /wiki-generation 으로 문서를 생성해주세요
```

### 패턴 3: 팀 공유 스킬

```json
// opencode.json
{
  "skills": {
    "urls": ["https://github.com/our-team/shared-skills/releases/latest/download/skills.tar.gz"]
  }
}
```

팀 전체가 동일한 지식 베이스를 공유합니다.

---

## 베스트 프랙티스

### 1. 스킬을 집중적으로 유지

하나의 스킬 = 하나의 도메인. "모든 것"을 담는 스킬을 만들지 마세요.

### 2. 명확한 설명 작성

설명은 LLM이 스킬 로드 여부를 결정하는 기준입니다. 구체적으로 작성하세요:

```yaml
# 좋음 — LLM이 정확히 언제 사용할지 알 수 있음
description: 코드 리뷰 지식 베이스 — 보안 체크리스트, 버그 패턴, 성능 안티패턴, 언어별 규칙. 코드 분석 또는 리뷰 작업 시 이 스킬을 로드하세요.

# 나쁨 — 너무 모호함
description: 코드에 대한 유용한 정보
```

### 3. 의사결정 트리 포함

LLM이 체계적으로 탐색할 수 있도록 지식을 의사결정 트리로 구조화하세요.

### 4. 출력 스키마 제공

LLM에게 어떤 형식으로 결과를 생성할지 알려주세요.

### 5. 대량 콘텐츠는 번들 파일 활용

SKILL.md에 5000줄을 넣지 마세요. 대신:
- SKILL.md: 요약 + 지시사항 (간결하게)
- 번들 파일: 전체 참조 데이터 (온디맨드로 읽기)

초기 스킬 로딩을 빠르게 유지하면서도 모든 지식에 접근 가능합니다.

---

## 문제 해결

| 증상 | 확인 사항 |
|------|----------|
| 스킬이 나타나지 않음 | `SKILL.md`는 대문자; frontmatter에 `name`과 `description` 필수 |
| 스킬 이름 불일치 | 디렉토리 이름이 frontmatter의 `name`과 일치해야 함 |
| 중복 경고 | 같은 스킬 이름이 여러 위치에 존재 |
| 권한 거부 | 설정의 `permission.skill` 확인 |
| 번들 파일을 찾을 수 없음 | 파일이 SKILL.md와 같은 디렉토리 또는 하위 디렉토리에 있어야 함 |
| 스킬이 자동 로드되지 않음 | LLM이 매칭할 수 있도록 설명이 충분히 구체적이어야 함 |
