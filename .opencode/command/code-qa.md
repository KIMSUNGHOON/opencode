---
description: "Code QA 워크플로우 v4 (Environment + Git 통합)"
model: opencode/gpt-oss-120b
---

# Code QA Workflow v4

$ARGUMENTS

## 설정

```
MAX_RETRY = 3
QUALITY_THRESHOLD = 70
```

## 입력 옵션

- (기본값): `--working` (git diff)
- `--staged`: staged 변경만
- `--last`: 마지막 커밋
- `--branch`: 브랜치 전체
- `--range <a>..<b>`: 특정 범위

---

## Phase -1: Environment Setup

**먼저 @env-setup을 호출하여 실행 환경을 확인합니다.**

@env-setup에게 다음을 요청:
1. Shell 확인 (zsh/bash/sh)
2. 현재 활성화된 환경 확인
3. 환경이 없으면 사용자에게 선택 요청
4. Python, CUDA, PyTorch 버전 더블 체크

환경 설정이 완료되면 다음 Phase로 진행합니다.

---

## Phase 0: Git Input

@git-input을 호출하여:
1. 입력 모드 파싱 ($ARGUMENTS에서)
2. 변경 파일 추출
3. 검사 대상 목록 생성

---

## Phase 1-5: QA 파이프라인

순차적으로 호출:

1. **@pre-checker** - 자동 수정 (lint --fix, format)
2. **@code-reviewer** - 심층 코드 분석
3. **@code-fixer** - 발견된 이슈 수정
4. **@quality-checker** - 품질 점수 검사 (≥70% 필요)
5. **@build-tester** - 빌드 테스트
6. **@function-tester** - 기능 테스트

### 회귀 조건

- Quality Check < 70% → @code-fixer로 회귀 (최대 3회)
- Build 실패 → @code-fixer로 회귀
- Test 실패 → @code-fixer로 회귀

---

## Phase 6: Commit

@git-committer를 호출하여:
1. 수정 여부 확인 (`git status --porcelain`)
2. 수정 있으면:
   - 커밋 전 모드 (`--working`/`--staged`) → 새 커밋
   - 커밋 후 모드 (`--last`/`--branch`) → amend

---

## Phase 7: Summary Report

@summary-reporter를 호출하여:
1. 전체 QA 결과 수집
2. Markdown 형식 리포트 생성
3. 사용자에게 출력

---

## Phase 8: Push & PR

@git-pusher를 호출하여:
1. **사용자에게 Push 여부 확인** (필수)
2. Push 승인 시:
   - amend면 `--force-with-lease`
   - 일반이면 그냥 push
3. **사용자에게 PR 생성 여부 확인**
4. PR 승인 시 PR 정보 수집 및 생성

---

## 중요 규칙

1. **Phase -1은 항상 먼저 실행** - 환경 설정 없이 QA 진행 금지
2. **Phase 8의 모든 remote 작업은 사용자 확인 필수**
3. **강제 푸시 시 경고 표시**
4. **회귀 최대 3회**
