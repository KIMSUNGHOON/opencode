# Code QA Workflow Case Review

이 문서는 Code QA 워크플로우의 다양한 시나리오를 검토하고, 누락된 케이스와 개선점을 식별합니다.

---

## 1. 워크플로우 시나리오 매트릭스

### 1.1 캐시 상태 × 옵션 조합

| 시나리오 | 캐시 상태 | 옵션 | 예상 동작 | 검증 |
|----------|----------|------|----------|------|
| S1 | 유효한 캐시 있음 | (기본) | 캐시 사용 | ✅ |
| S2 | 유효한 캐시 있음 | --skip-cache | 캐시 무시 | ✅ |
| S3 | 유효한 캐시 있음 | --with-analysis | 캐시 사용 (재분석 안 함) | ✅ |
| S4 | 오래된 캐시 있음 | (기본) | 경고 + 캐시 없이 진행 | ✅ |
| S5 | 오래된 캐시 있음 | --with-analysis | 재분석 실행 | ✅ |
| S6 | 캐시 없음 | (기본) | 경고 + 캐시 없이 진행 | ✅ |
| S7 | 캐시 없음 | --with-analysis | 분석 실행 | ✅ |
| S8 | 캐시 없음 | --skip-cache | 캐시 무시 (분석 안 함) | ✅ |

### 1.2 입력 모드 × 캐시 조합

| 시나리오 | 입력 모드 | 캐시 상태 | 예상 동작 | 검증 |
|----------|----------|----------|----------|------|
| I1 | Git (--working) | 캐시 있음 | 캐시 컨텍스트 + git diff | ✅ |
| I2 | Git (--working) | 캐시 없음 | git diff만 | ✅ |
| I3 | Git (--staged) | 캐시 있음 | 캐시 컨텍스트 + staged | ✅ |
| I4 | Git (--last) | 캐시 있음 | 캐시 컨텍스트 + last commit | ✅ |
| I5 | Git (--branch) | 캐시 있음 | 캐시 컨텍스트 + branch diff | ✅ |
| I6 | --files | 캐시 있음 | 캐시 컨텍스트 + 지정 파일 | ✅ |
| I7 | --files | 캐시 없음 | 지정 파일만 | ✅ |

---

## 2. Edge Case 검토

### 2.1 파일 관련 Edge Cases

| 케이스 | 현재 처리 | 문제점 | 개선 필요 |
|--------|----------|--------|----------|
| 변경 파일 0개 | ⚠️ 미정의 | git diff가 비어있으면? | **YES** |
| 변경 파일 1000개+ | ⚠️ 미정의 | 너무 많은 파일 | **YES** |
| 바이너리 파일만 변경 | ⚠️ 미정의 | 분석할 코드 없음 | **YES** |
| 삭제된 파일 | ⚠️ 미정의 | 읽을 수 없음 | **YES** |
| 이름 변경된 파일 | ⚠️ 미정의 | 경로 추적 | **YES** |

### 2.2 Git 관련 Edge Cases

| 케이스 | 현재 처리 | 문제점 | 개선 필요 |
|--------|----------|--------|----------|
| Git 저장소 아님 | ✅ 처리됨 | NO_GIT_REPO → 사용자 선택 | NO |
| Detached HEAD | ⚠️ 미정의 | 브랜치 정보 없음 | **YES** |
| Merge conflict 상태 | ⚠️ 미정의 | 커밋 불가 | **YES** |
| Dirty working tree | ⚠️ 미정의 | --last 실행 시 충돌 | **YES** |
| Shallow clone | ⚠️ 미정의 | 히스토리 부족 | **YES** |

### 2.3 환경 관련 Edge Cases

| 케이스 | 현재 처리 | 문제점 | 개선 필요 |
|--------|----------|--------|----------|
| Docker 없음 | ⚠️ 부분 처리 | --no-sandbox로 대체 | NO |
| Python/Node 없음 | ⚠️ 미정의 | 빌드/테스트 실패 | **YES** |
| 의존성 미설치 | ⚠️ 미정의 | 빌드 실패 | **YES** |
| 네트워크 없음 | ⚠️ 미정의 | push 실패 | **YES** |

---

## 3. 발견된 문제점

### 3.1 CRITICAL: 변경 파일 0개 처리 누락

**문제**: git diff 결과가 비어있을 때 워크플로우가 어떻게 동작하는지 정의되지 않음

**현재 상태**:
```
STEP 2: git-input → FILE_LIST 반환
STEP 3: pre-checker 호출 (빈 파일 목록으로?)
STEP 4: code-reviewer 호출 (분석할 파일 없음?)
```

**필요한 처리**:
```
IF changed_files.length == 0:
    → 경고 출력: "변경된 파일이 없습니다."
    → 워크플로우 종료 (성공)
```

### 3.2 CRITICAL: 삭제된 파일 처리 누락

**문제**: git diff에 삭제된 파일이 포함될 수 있음

**현재 상태**:
- code-reviewer가 삭제된 파일을 Read하려고 시도
- 파일이 없어서 에러 발생

**필요한 처리**:
```
git diff 결과에서:
- 추가된 파일 (A): 분석 대상
- 수정된 파일 (M): 분석 대상
- 삭제된 파일 (D): 분석 제외
- 이름 변경 (R): 새 경로로 분석
```

### 3.3 HIGH: 대량 파일 변경 처리 누락

**문제**: 수백~수천 개 파일이 변경된 경우 처리 방법 없음

**필요한 처리**:
```
IF changed_files.length > 100:
    → 경고 출력: "변경 파일이 {N}개입니다. 주요 파일만 분석합니다."
    → 소스 파일만 필터링 (테스트, 설정 파일 제외)
    → 또는 사용자에게 범위 축소 요청
```

### 3.4 MEDIUM: Detached HEAD 처리 누락

**문제**: CI/CD에서 detached HEAD 상태가 흔함

**필요한 처리**:
```
IF git branch --show-current 결과가 비어있음:
    → detached HEAD 상태임을 알림
    → 커밋/푸시 단계에서 적절히 처리
```

### 3.5 MEDIUM: 의존성 미설치 시 빌드 실패

**문제**: 의존성이 설치되지 않은 상태에서 빌드 시도

**필요한 처리**:
```
빌드 실패 시:
IF 에러 메시지에 "ModuleNotFoundError" 또는 "Cannot find module" 포함:
    → 의존성 설치 안내: "npm install 또는 pip install -r requirements.txt 실행"
    → 사용자에게 재시도 또는 스킵 선택
```

---

## 4. 권장 수정 사항

### 4.1 git-input 에이전트 수정

```
결과 토큰 확장:
- GIT_INPUT_RESULT: SUCCESS (파일 있음)
- GIT_INPUT_RESULT: NO_CHANGES (변경 없음) ← 새로 추가
- GIT_INPUT_RESULT: NO_GIT_REPO (Git 아님)
- GIT_INPUT_RESULT: ABORTED (사용자 취소)

FILE_LIST 형식 확장:
FILE_LIST:
  added: [file1.py, file2.py]
  modified: [file3.py]
  deleted: [file4.py]        ← 삭제된 파일 표시
  renamed: [{old: x.py, new: y.py}]
```

### 4.2 code-qa 오케스트레이터 수정

```
STEP 2 이후 추가 체크:

IF changed_files 전체 길이 == 0:
    → "변경된 파일이 없습니다. 워크플로우를 종료합니다."
    → 워크플로우 종료

IF 분석 가능한 파일 == 0 (모두 삭제됨):
    → "분석할 파일이 없습니다. (삭제된 파일만 있음)"
    → STEP 9로 건너뛰기 (커밋 단계)

IF changed_files.length > 100:
    → 사용자 경고 및 확인 요청
```

### 4.3 build-tester 에이전트 수정

```
빌드 실패 시 에러 분류:
- BUILD_RESULT: FAIL_DEPS (의존성 문제)
- BUILD_RESULT: FAIL_SYNTAX (문법 오류)
- BUILD_RESULT: FAIL_RUNTIME (런타임 오류)
- BUILD_RESULT: FAIL_UNKNOWN (기타)

의존성 문제 시:
→ 자동으로 의존성 설치 시도 또는 사용자에게 안내
```

---

## 5. 테스트 시나리오

### 5.1 Happy Path 테스트

```bash
# T1: 기본 Git 모드
/code-qa

# T2: Staged 변경만
git add src/app.py
/code-qa --staged

# T3: 파일 직접 지정
/code-qa --files src/

# T4: 캐시 사용
/analyze
/code-qa

# T5: 캐시 + 분석 동시
/code-qa --with-analysis
```

### 5.2 Edge Case 테스트

```bash
# T6: 변경 없음
git status  # clean
/code-qa    # → "변경 파일 없음" 메시지 기대

# T7: 파일 삭제만
git rm old_file.py
/code-qa --staged  # → 삭제 처리 확인

# T8: 대량 파일
# 100+ 파일 변경 후
/code-qa  # → 경고 및 필터링 확인

# T9: Non-Git 디렉토리
cd /tmp/non-git-project
/code-qa  # → NO_GIT_REPO 처리 확인

# T10: 빈 프로젝트
/analyze  # → EMPTY 결과 확인
```

### 5.3 에러 시나리오 테스트

```bash
# T11: 의존성 미설치
rm -rf node_modules
/code-qa  # → 빌드 실패 + 안내 메시지

# T12: Docker 없음
# Docker 중지 후
/code-qa  # → --no-sandbox 대체 안내

# T13: 네트워크 없음
# 오프라인 상태에서
/code-qa  # → Push 단계에서 적절한 에러 처리
```

---

## 6. 결론

### 발견된 Critical Issues (즉시 수정 필요)

1. **변경 파일 0개 처리 누락** - 워크플로우가 비정상 동작 가능
2. **삭제된 파일 처리 누락** - code-reviewer 에러 발생 가능

### 발견된 High Priority Issues

3. **대량 파일 변경 처리 없음** - 성능 문제 및 타임아웃 가능
4. **파일 상태 구분 없음** - added/modified/deleted 구분 필요

### 발견된 Medium Priority Issues

5. Detached HEAD 처리
6. 의존성 미설치 시 안내
7. Merge conflict 상태 처리

---

## 변경 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|----------|
| 1.0 | 2024-01-15 | 초기 케이스 리뷰 문서 |
