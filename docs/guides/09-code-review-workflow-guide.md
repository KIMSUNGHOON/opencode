# Code Review 워크플로우 가이드

> ⚠️ **참고:** 이 문서는 Code QA v2 기준입니다.
> 최신 버전은 [Code QA v4 (Environment + Sandbox)](./12-environment-setup-workflow.md)를 참조하세요.
>
> **v4 주요 변경사항:**
> - **Phase -1: Environment Setup** - Shell/conda/venv 환경 자동 감지
> - **Docker Sandbox** - Build/Test를 격리된 컨테이너에서 실행 (기본값)
> - **Git 통합** - diff/commit 기반 입력, 자동 amend, Push/PR 지원

---

## 개요

이 가이드는 OpenCode Agent를 활용하여 **Code Review → Code Fix → Quality Check → Build Test → Function Test** 파이프라인을 구성하는 방법을 설명합니다.

---

## 목차

1. [워크플로우 개요](#1-워크플로우-개요)
2. [디렉토리 구조](#2-디렉토리-구조)
3. [Agent 설정](#3-agent-설정)
4. [Command 설정](#4-command-설정)
5. [사용 방법](#5-사용-방법)
6. [다이어그램](#6-다이어그램)
7. [커스터마이징](#7-커스터마이징)

---

## 1. 워크플로우 개요

### 1.1 파이프라인 흐름

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│  Review  │───▶│   Fix    │───▶│ Quality  │───▶│  Build   │───▶│   Test   │
│          │    │          │    │  Check   │    │          │    │          │
└──────────┘    └──────────┘    └──────────┘    └──────────┘    └──────────┘
     🔍              🔧              📋              🏗️              🧪
```

### 1.2 각 단계 역할

| Phase | Agent | 역할 | 실패 시 |
|-------|-------|------|---------|
| 1. Review | `code-reviewer` | 코드 분석, 이슈 발견 | Fix로 전달 |
| 2. Fix | `code-fixer` | 이슈 자동 수정 | 사용자 개입 |
| 3. Quality | `quality-checker` | Lint, Type, Format 검사 | Fix로 회귀 |
| 4. Build | `build-tester` | 컴파일, 번들링 | Fix로 회귀 |
| 5. Test | `function-tester` | Unit/Integration 테스트 | 리포트 생성 |

### 1.3 단일 모델 환경

GPT-OSS-120B 단일 모델 환경에서는:
- 모든 Agent가 동일 모델 사용
- 순차적 처리로 서버 부하 관리
- 명확한 역할 분담으로 효율성 확보

---

## 2. 디렉토리 구조

프로젝트 루트에 다음 구조로 생성합니다:

```
your-project/
├── .opencode/
│   ├── agent/
│   │   ├── code-reviewer.md      # 코드 리뷰 Agent
│   │   ├── code-fixer.md         # 코드 수정 Agent
│   │   ├── quality-checker.md    # 품질 검사 Agent
│   │   ├── build-tester.md       # 빌드 테스트 Agent
│   │   └── function-tester.md    # 기능 테스트 Agent
│   │
│   └── command/
│       ├── code-qa.md            # 전체 워크플로우
│       ├── review.md             # 리뷰만
│       ├── fix.md                # 수정만
│       ├── quality.md            # 품질 검사만
│       ├── build.md              # 빌드만
│       └── test.md               # 테스트만
│
├── src/
├── package.json
└── ...
```

---

## 3. Agent 설정

### 3.1 Code Reviewer

`.opencode/agent/code-reviewer.md`:

```markdown
---
description: 코드 리뷰 및 이슈 분석 전문가
mode: subagent
model: vllm/gpt-oss-120b
color: "#3498DB"
permission:
  bash:
    "*": deny
  read: allow
  edit: deny
  glob: allow
  grep: allow
---

# Code Reviewer

당신은 시니어 코드 리뷰어입니다. 코드를 분석하고 개선점을 찾아 보고합니다.

## 역할

1. **코드 분석**
   - 로직 오류 검출
   - 잠재적 버그 식별
   - 성능 이슈 발견

2. **보안 검토**
   - 보안 취약점 검사
   - 민감 정보 노출 확인
   - 입력 검증 확인

3. **코드 품질**
   - 가독성 평가
   - 중복 코드 탐지
   - 네이밍 컨벤션 검사
   - 복잡도 분석

4. **베스트 프랙티스**
   - 디자인 패턴 적용 여부
   - SOLID 원칙 준수
   - 에러 핸들링 검토

## 분석 절차

1. 파일/디렉토리 구조 파악
2. 주요 로직 분석
3. 이슈 분류 및 우선순위 지정
4. 개선 제안 작성

## 출력 형식

### 리뷰 리포트

**파일:** `[파일 경로]`

**심각도 분류:**
- 🔴 Critical: 즉시 수정 필요
- 🟠 High: 빠른 수정 권장
- 🟡 Medium: 개선 권장
- 🟢 Low: 선택적 개선

**발견된 이슈:**

| # | 심각도 | 라인 | 이슈 | 제안 |
|---|--------|------|------|------|
| 1 | 🔴 | 42 | ... | ... |

**요약:**
- Critical: N개
- High: N개
- Medium: N개
- Low: N개
```

### 3.2 Code Fixer

`.opencode/agent/code-fixer.md`:

```markdown
---
description: 코드 수정 및 리팩토링 전문가
mode: subagent
model: vllm/gpt-oss-120b
color: "#27AE60"
permission:
  bash:
    "git diff *": allow
    "git status": allow
    "*": deny
  read: allow
  edit: allow
  glob: allow
  grep: allow
---

# Code Fixer

당신은 코드 수정 전문가입니다. 리뷰 결과를 바탕으로 코드를 수정합니다.

## 역할

1. **버그 수정**
   - 로직 오류 수정
   - 예외 처리 추가
   - 타입 오류 수정

2. **리팩토링**
   - 중복 코드 제거
   - 함수/클래스 분리
   - 복잡도 감소

3. **스타일 통일**
   - 네이밍 컨벤션 적용
   - 포맷팅 정리
   - 주석 개선

## 수정 원칙

### 필수
- 수정 전 반드시 파일 읽기
- 최소한의 변경으로 문제 해결
- 기존 코드 스타일 유지

### 금지
- 불필요한 리팩토링
- 요청되지 않은 기능 추가
- 관련 없는 코드 수정

## 수정 절차

1. 리뷰 이슈 확인
2. 관련 코드 읽기
3. 수정 계획 수립
4. 코드 수정
5. 변경사항 요약

## 출력 형식

### 수정 완료 리포트

**수정된 파일:**
| # | 파일 | 수정 내용 | 라인 |
|---|------|----------|------|
| 1 | src/... | ... | 42-45 |

**변경 요약:**
```diff
- 이전 코드
+ 수정된 코드
```

**확인 필요 사항:**
- [ ] 테스트 실행 필요
- [ ] 추가 리뷰 필요
```

### 3.3 Quality Checker

`.opencode/agent/quality-checker.md`:

```markdown
---
description: 코드 품질 검사 전문가
mode: subagent
model: vllm/gpt-oss-120b
color: "#9B59B6"
permission:
  bash:
    "bun run lint *": allow
    "bun run typecheck *": allow
    "bun run format *": allow
    "npm run lint *": allow
    "npm run typecheck *": allow
    "npm run format *": allow
    "eslint *": allow
    "tsc *": allow
    "prettier *": allow
    "*": deny
  read: allow
  edit: deny
  glob: allow
  grep: allow
---

# Quality Checker

당신은 코드 품질 검사 전문가입니다. 정적 분석 도구를 실행하고 결과를 분석합니다.

## 역할

1. **Lint 검사**
   - ESLint / TSLint 실행
   - 규칙 위반 검출
   - auto-fix 가능 항목 식별

2. **타입 검사**
   - TypeScript 컴파일러 검사
   - 타입 오류 검출
   - 타입 안정성 확인

3. **포맷 검사**
   - Prettier 검사
   - 코드 스타일 일관성
   - 포맷팅 필요 파일 식별

## 검사 명령어

```bash
# Lint
bun run lint
# 또는
npm run lint
# 또는
eslint src/

# Type Check
bun run typecheck
# 또는
npm run typecheck
# 또는
tsc --noEmit

# Format Check
bun run format:check
# 또는
prettier --check "src/**/*.{ts,tsx}"
```

## 출력 형식

### 품질 검사 리포트

**Lint 결과:**
- [ ] 통과 / ❌ 실패
- 에러: N개
- 경고: N개

**타입 검사 결과:**
- [ ] 통과 / ❌ 실패
- 에러: N개

**포맷 검사 결과:**
- [ ] 통과 / ❌ 실패
- 수정 필요 파일: N개

**상세 오류:**
| # | 유형 | 파일 | 라인 | 메시지 |
|---|------|------|------|--------|
| 1 | lint | ... | 42 | ... |

**권장 조치:**
- [ ] `bun run lint --fix` 실행
- [ ] 타입 오류 수동 수정 필요
```

### 3.4 Build Tester

`.opencode/agent/build-tester.md`:

```markdown
---
description: 빌드 및 컴파일 테스트 전문가
mode: subagent
model: vllm/gpt-oss-120b
color: "#E67E22"
permission:
  bash:
    "bun install": allow
    "bun run build *": allow
    "npm install": allow
    "npm run build *": allow
    "yarn install": allow
    "yarn build *": allow
    "make *": allow
    "go build *": allow
    "cargo build *": allow
    "*": deny
  read: allow
  edit: deny
  glob: allow
  grep: allow
---

# Build Tester

당신은 빌드 테스트 전문가입니다. 프로젝트 빌드를 실행하고 결과를 분석합니다.

## 역할

1. **의존성 설치**
   - 패키지 설치 확인
   - 버전 호환성 검증

2. **빌드 실행**
   - 컴파일 테스트
   - 번들링 테스트
   - 빌드 아티팩트 확인

3. **에러 분석**
   - 빌드 에러 분석
   - 해결 방안 제시

## 빌드 명령어

```bash
# Node.js (Bun)
bun install
bun run build

# Node.js (npm)
npm install
npm run build

# Go
go build ./...

# Rust
cargo build

# Make
make build
```

## 출력 형식

### 빌드 테스트 리포트

**의존성 설치:**
- [ ] 성공 / ❌ 실패
- 설치 시간: Xs

**빌드 결과:**
- [ ] 성공 / ❌ 실패
- 빌드 시간: Xs
- 출력 디렉토리: dist/

**빌드 에러 (실패 시):**
```
에러 메시지
```

**원인 분석:**
- 예상 원인: ...
- 해결 방안: ...

**아티팩트:**
| 파일 | 크기 |
|------|------|
| dist/index.js | XXX KB |
```

### 3.5 Function Tester

`.opencode/agent/function-tester.md`:

```markdown
---
description: 기능 테스트 전문가
mode: subagent
model: vllm/gpt-oss-120b
color: "#E74C3C"
permission:
  bash:
    "bun test *": allow
    "bun run test *": allow
    "npm test *": allow
    "npm run test *": allow
    "jest *": allow
    "vitest *": allow
    "go test *": allow
    "cargo test *": allow
    "pytest *": allow
    "*": deny
  read: allow
  edit: deny
  glob: allow
  grep: allow
---

# Function Tester

당신은 기능 테스트 전문가입니다. 테스트를 실행하고 결과를 분석합니다.

## 역할

1. **Unit 테스트**
   - 개별 함수/모듈 테스트
   - 경계 조건 테스트
   - 예외 케이스 테스트

2. **Integration 테스트**
   - 모듈 간 연동 테스트
   - API 테스트
   - E2E 테스트

3. **결과 분석**
   - 실패 테스트 분석
   - 커버리지 확인
   - 개선 제안

## 테스트 명령어

```bash
# Bun
bun test
bun test --coverage

# npm (Jest/Vitest)
npm test
npm run test:coverage

# Go
go test ./...
go test -cover ./...

# Rust
cargo test

# Python
pytest
pytest --cov
```

## 출력 형식

### 테스트 리포트

**테스트 결과:**
- 전체: N개
- ✅ 통과: N개
- ❌ 실패: N개
- ⏭️ 스킵: N개

**커버리지:**
- 라인: XX%
- 브랜치: XX%
- 함수: XX%

**실패한 테스트:**
| # | 테스트명 | 파일 | 에러 |
|---|----------|------|------|
| 1 | test_xxx | ... | ... |

**실패 원인 분석:**
```
테스트: test_xxx
예상: ...
실제: ...
원인: ...
해결: ...
```

**권장 조치:**
- [ ] 코드 수정 필요
- [ ] 테스트 케이스 수정 필요
```

---

## 4. Command 설정

### 4.1 전체 워크플로우 Command

`.opencode/command/code-qa.md`:

```markdown
---
description: "전체 코드 품질 보증 워크플로우 실행"
model: vllm/gpt-oss-120b
---

# Code QA 워크플로우

$ARGUMENTS

## 실행 단계

### Phase 1: Code Review
@code-reviewer를 호출하여:
1. 지정된 파일/디렉토리 분석
2. 이슈 발견 및 분류
3. 리뷰 리포트 생성

### Phase 2: Code Fix
@code-fixer를 호출하여:
1. 리뷰에서 발견된 이슈 수정
2. Critical/High 우선 처리
3. 변경사항 요약

### Phase 3: Quality Check
@quality-checker를 호출하여:
1. Lint 검사
2. Type 검사
3. Format 검사
4. 실패 시 @code-fixer에게 수정 요청

### Phase 4: Build Test
@build-tester를 호출하여:
1. 의존성 설치
2. 빌드 실행
3. 실패 시 원인 분석

### Phase 5: Function Test
@function-tester를 호출하여:
1. 테스트 실행
2. 결과 분석
3. 최종 리포트 생성

## 중요 규칙

- 각 단계 완료 후 결과 보고
- Critical 이슈 발견 시 즉시 알림
- 테스트 실패 시 상세 분석 제공
```

### 4.2 개별 Command들

`.opencode/command/review.md`:

```markdown
---
description: "코드 리뷰만 실행"
model: vllm/gpt-oss-120b
---

# Code Review

@code-reviewer를 호출하여 코드를 분석합니다.

$ARGUMENTS

대상:
- 파일 또는 디렉토리 경로
- 또는 git diff 결과
```

`.opencode/command/fix.md`:

```markdown
---
description: "코드 수정만 실행"
model: vllm/gpt-oss-120b
---

# Code Fix

@code-fixer를 호출하여 코드를 수정합니다.

$ARGUMENTS

수정 대상:
- 리뷰 리포트 기반
- 또는 직접 지정된 이슈
```

`.opencode/command/quality.md`:

```markdown
---
description: "품질 검사만 실행"
model: vllm/gpt-oss-120b
---

# Quality Check

@quality-checker를 호출하여 품질을 검사합니다.

$ARGUMENTS

검사 항목:
- Lint
- Type Check
- Format
```

`.opencode/command/build.md`:

```markdown
---
description: "빌드 테스트만 실행"
model: vllm/gpt-oss-120b
---

# Build Test

@build-tester를 호출하여 빌드를 테스트합니다.

$ARGUMENTS
```

`.opencode/command/test.md`:

```markdown
---
description: "기능 테스트만 실행"
model: vllm/gpt-oss-120b
---

# Function Test

@function-tester를 호출하여 테스트를 실행합니다.

$ARGUMENTS

옵션:
- 특정 테스트 파일
- 커버리지 포함
```

---

## 5. 사용 방법

### 5.1 기본 사용법

```bash
# OpenCode 시작
opencode

# 전체 워크플로우 실행
> /code-qa src/ 디렉토리 전체 검사

# 특정 파일만 검사
> /code-qa src/utils/helper.ts 파일 검사

# 변경된 파일만 검사
> /code-qa git diff로 변경된 파일 검사
```

### 5.2 개별 단계 실행

```bash
# 리뷰만 실행
> /review src/components/ 컴포넌트 리뷰

# 수정만 실행
> /fix 위에서 발견된 이슈 수정해줘

# 품질 검사만
> /quality 전체 프로젝트 품질 검사

# 빌드만
> /build 프로덕션 빌드 테스트

# 테스트만
> /test 전체 테스트 실행
```

### 5.3 Agent 직접 호출

```bash
# 리뷰어 직접 호출
> @code-reviewer src/api/handler.ts 파일의 에러 핸들링을 분석해줘

# 픽서 직접 호출
> @code-fixer 위에서 발견된 null 체크 이슈를 수정해줘

# 테스터 직접 호출
> @function-tester src/utils/__tests__/ 디렉토리 테스트 실행해줘
```

### 5.4 실제 사용 예시

#### 예시 1: PR 전 전체 검사

```
> /code-qa src/ 디렉토리를 PR 전에 전체 검사해줘

🔍 Phase 1: Code Review 시작...
[code-reviewer가 분석 진행]

📋 리뷰 결과:
- 🔴 Critical: 2개
- 🟠 High: 5개
- 🟡 Medium: 8개

🔧 Phase 2: Code Fix 시작...
[code-fixer가 수정 진행]

✅ 수정 완료: 7개 이슈 수정됨

📋 Phase 3: Quality Check...
- Lint: ✅ 통과
- Type: ✅ 통과
- Format: ✅ 통과

🏗️ Phase 4: Build Test...
- 빌드: ✅ 성공 (12.3s)

🧪 Phase 5: Function Test...
- 전체: 156개
- 통과: 156개
- 실패: 0개

✅ 모든 검사 통과!
```

#### 예시 2: 특정 파일 리뷰 후 수정

```
> /review src/services/auth.ts 인증 로직 리뷰

🔍 리뷰 결과:
| # | 심각도 | 라인 | 이슈 |
|---|--------|------|------|
| 1 | 🔴 | 45 | 비밀번호 평문 저장 |
| 2 | 🟠 | 78 | 토큰 만료 미체크 |

> /fix 위 이슈 수정해줘

🔧 수정 완료:
1. ✅ 비밀번호 해싱 적용 (bcrypt)
2. ✅ 토큰 만료 검증 로직 추가

변경된 파일: src/services/auth.ts
```

#### 예시 3: 테스트 실패 분석

```
> /test 전체 테스트 실행

🧪 테스트 결과:
- 전체: 156개
- ✅ 통과: 154개
- ❌ 실패: 2개

실패한 테스트:
1. test_user_login - 예상: 200, 실제: 401
2. test_token_refresh - 타임아웃

> @code-fixer 테스트 실패 원인을 분석하고 수정해줘
```

---

## 6. 다이어그램

### 6.1 전체 흐름도

```mermaid
flowchart TB
    subgraph INPUT["입력"]
        I1[소스 코드]
        I2[변경된 파일]
    end

    subgraph PHASE1["Phase 1: Review"]
        R1["🔍 code-reviewer"]
        R2[이슈 분석]
        R3[리포트 생성]
        R1 --> R2 --> R3
    end

    subgraph PHASE2["Phase 2: Fix"]
        F1["🔧 code-fixer"]
        F2[이슈 수정]
        F3[코드 변경]
        F1 --> F2 --> F3
    end

    subgraph PHASE3["Phase 3: Quality"]
        Q1["📋 quality-checker"]
        Q2[Lint/Type/Format]
        Q3{통과?}
        Q1 --> Q2 --> Q3
    end

    subgraph PHASE4["Phase 4: Build"]
        B1["🏗️ build-tester"]
        B2[빌드 실행]
        B3{성공?}
        B1 --> B2 --> B3
    end

    subgraph PHASE5["Phase 5: Test"]
        T1["🧪 function-tester"]
        T2[테스트 실행]
        T3[결과 리포트]
        T1 --> T2 --> T3
    end

    I1 & I2 --> PHASE1
    PHASE1 --> PHASE2
    PHASE2 --> PHASE3
    Q3 -->|Yes| PHASE4
    Q3 -->|No| PHASE2
    B3 -->|Yes| PHASE5
    B3 -->|No| PHASE2
    PHASE5 --> OUTPUT[최종 리포트]

    style PHASE1 fill:#3498DB22,stroke:#3498DB
    style PHASE2 fill:#27AE6022,stroke:#27AE60
    style PHASE3 fill:#9B59B622,stroke:#9B59B6
    style PHASE4 fill:#E67E2222,stroke:#E67E22
    style PHASE5 fill:#E74C3C22,stroke:#E74C3C
```

### 6.2 Agent 권한 매트릭스

```mermaid
block-beta
    columns 6

    space:6

    block:header:6
        H1["Agent"]
        H2["read"]
        H3["edit"]
        H4["bash"]
        H5["glob/grep"]
    end

    block:row1:6
        A1["🔍 code-reviewer"]
        A2["✅"]
        A3["❌"]
        A4["❌"]
        A5["✅"]
    end

    block:row2:6
        B1["🔧 code-fixer"]
        B2["✅"]
        B3["✅"]
        B4["git only"]
        B5["✅"]
    end

    block:row3:6
        C1["📋 quality-checker"]
        C2["✅"]
        C3["❌"]
        C4["lint/type"]
        C5["✅"]
    end

    block:row4:6
        D1["🏗️ build-tester"]
        D2["✅"]
        D3["❌"]
        D4["build"]
        D5["✅"]
    end

    block:row5:6
        E1["🧪 function-tester"]
        E2["✅"]
        E3["❌"]
        E4["test"]
        E5["✅"]
    end
```

---

## 7. 커스터마이징

### 7.1 프로젝트별 명령어 수정

프로젝트의 `package.json` 스크립트에 맞게 Agent 설정을 수정합니다:

```json
// package.json
{
  "scripts": {
    "lint": "eslint src/",
    "typecheck": "tsc --noEmit",
    "format": "prettier --check src/",
    "build": "vite build",
    "test": "vitest run"
  }
}
```

### 7.2 언어별 커스터마이징

#### Go 프로젝트

```markdown
# quality-checker 수정
permission:
  bash:
    "go vet *": allow
    "golint *": allow
    "staticcheck *": allow
```

#### Python 프로젝트

```markdown
# quality-checker 수정
permission:
  bash:
    "flake8 *": allow
    "mypy *": allow
    "black --check *": allow
    "pylint *": allow
```

#### Rust 프로젝트

```markdown
# quality-checker 수정
permission:
  bash:
    "cargo clippy *": allow
    "cargo fmt -- --check": allow
```

### 7.3 추가 Agent 예시

#### Security Scanner

```markdown
---
description: 보안 취약점 스캔 전문가
mode: subagent
model: vllm/gpt-oss-120b
color: "#C0392B"
permission:
  bash:
    "npm audit": allow
    "bun audit": allow
    "snyk *": allow
    "*": deny
  read: allow
  edit: deny
---

# Security Scanner

보안 취약점을 스캔하고 보고합니다.

## 검사 항목
- 의존성 취약점
- 하드코딩된 시크릿
- OWASP Top 10
```

---

## 요약

| 항목 | 위치 | 용도 |
|------|------|------|
| Agent 설정 | `.opencode/agent/*.md` | 각 Agent 역할/권한 정의 |
| Command 설정 | `.opencode/command/*.md` | 워크플로우 오케스트레이션 |
| 전체 실행 | `/code-qa [대상]` | 전체 파이프라인 실행 |
| 개별 실행 | `/review`, `/fix`, etc. | 단계별 실행 |
| Agent 호출 | `@agent-name [요청]` | 직접 Agent 호출 |

---

## 관련 문서

- [Code QA v3 (Git 통합)](./11-code-qa-workflow-v3-git-integrated.md)
- [**Code QA v4 (Environment + Sandbox)** ⭐](./12-environment-setup-workflow.md)
- [Custom Agent 가이드](./02-custom-agent-guide.md)
- [Git Rebase 워크플로우](./04-git-rebase-porting-workflow.md)
- [통합 설정 가이드](./05-integrated-configuration.md)
