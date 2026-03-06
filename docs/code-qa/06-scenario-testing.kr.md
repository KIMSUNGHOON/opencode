# Code QA v4 시나리오 테스팅 & 케이스 리뷰

이 문서는 Code QA v4 시스템의 워크플로우 시나리오와 엣지 케이스 처리에 대한 종합적인 리뷰를 제공합니다.

---

## Part 1: 워크플로우 시나리오 매트릭스

### 1.1 캐시 상태 x 옵션 조합

| 시나리오 | 캐시 상태 | 옵션 | 예상 동작 | 검증 |
|----------|-----------|------|-----------|------|
| S1 | 유효한 캐시 존재 | (기본값) | 캐시 사용 | ✅ |
| S2 | 유효한 캐시 존재 | --skip-cache | 캐시 무시 | ✅ |
| S3 | 유효한 캐시 존재 | --with-analysis | 캐시 사용 (재분석 없음) | ✅ |
| S4 | 만료된 캐시 존재 | (기본값) | 경고 + 캐시 없이 진행 | ✅ |
| S5 | 만료된 캐시 존재 | --with-analysis | 재분석 실행 | ✅ |
| S6 | 캐시 없음 | (기본값) | 경고 + 캐시 없이 진행 | ✅ |
| S7 | 캐시 없음 | --with-analysis | 분석 실행 | ✅ |
| S8 | 캐시 없음 | --skip-cache | 캐시 무시 (분석 없음) | ✅ |

### 1.2 입력 모드 x 캐시 조합

| 시나리오 | 입력 모드 | 캐시 상태 | 예상 동작 | 검증 |
|----------|-----------|-----------|-----------|------|
| I1 | Git (--working) | 캐시 존재 | 캐시 컨텍스트 + git diff | ✅ |
| I2 | Git (--working) | 캐시 없음 | git diff만 | ✅ |
| I3 | Git (--staged) | 캐시 존재 | 캐시 컨텍스트 + staged | ✅ |
| I4 | Git (--last) | 캐시 존재 | 캐시 컨텍스트 + 마지막 커밋 | ✅ |
| I5 | Git (--branch) | 캐시 존재 | 캐시 컨텍스트 + 브랜치 diff | ✅ |
| I6 | --files | 캐시 존재 | 캐시 컨텍스트 + 지정된 파일 | ✅ |
| I7 | --files | 캐시 없음 | 지정된 파일만 | ✅ |

---

### 1.3 엣지 케이스 리뷰

#### 파일 관련 엣지 케이스

| 케이스 | 현재 처리 | 이슈 | 개선 필요 | 상태 |
|--------|-----------|------|-----------|------|
| 변경된 파일 0개 | ✅ 구현됨 | 빈 git diff | 아니오 | ✅ 해결됨 |
| 1000개 이상 변경된 파일 | ✅ 구현됨 | 파일 수 과다 | 아니오 | ✅ 해결됨 |
| 바이너리 파일만 변경 | ✅ 구현됨 | 분석할 코드 없음 | 아니오 | ✅ 해결됨 |
| 삭제된 파일 | ✅ 구현됨 | 읽기 불가 | 아니오 | ✅ 해결됨 |
| 이름 변경된 파일 | ✅ 구현됨 | 경로 추적 | 아니오 | ✅ 해결됨 |

#### Git 관련 엣지 케이스

| 케이스 | 현재 처리 | 이슈 | 개선 필요 | 상태 |
|--------|-----------|------|-----------|------|
| Git 리포지토리 아님 | ✅ 구현됨 | NO_GIT_REPO → 사용자 선택 | 아니오 | ✅ 해결됨 |
| Detached HEAD | ✅ 구현됨 | 브랜치 정보 없음 | 아니오 | ✅ 해결됨 |
| Merge conflict 상태 | ✅ 구현됨 | 커밋 불가 | 아니오 | ✅ 해결됨 |
| Rebase 진행 중 | ✅ 구현됨 | 커밋 불가 | 아니오 | ✅ 해결됨 |
| Dirty working tree | ⚠️ 부분적 | --last와 충돌 | 낮음 | - |
| Shallow clone | ⚠️ 부분적 | 히스토리 부족 | 낮음 | - |

#### 환경 관련 엣지 케이스

| 케이스 | 현재 처리 | 이슈 | 개선 필요 | 상태 |
|--------|-----------|------|-----------|------|
| Docker 사용 불가 | ✅ 구현됨 | --no-sandbox 폴백 | 아니오 | ✅ 해결됨 |
| Python/Node 미설치 | ⚠️ 부분적 | 빌드/테스트 실패 | 낮음 | - |
| 의존성 미설치 | ✅ 구현됨 | 빌드 실패 | 아니오 | ✅ 해결됨 |
| 네트워크 없음 | ⚠️ 부분적 | 푸시 실패 | 낮음 | - |

---

### 1.4 발견된 이슈 및 해결

#### CRITICAL: 변경된 파일 없음 처리 (해결됨)

**이슈**: git diff 결과가 비어있을 때 워크플로우 동작이 정의되지 않음

**구현된 해결책**:
- git-input이 `GIT_INPUT_RESULT: NO_CHANGES` 토큰 반환
- code-qa 오케스트레이터가 성공 메시지와 함께 정상 종료

#### CRITICAL: 삭제된 파일 처리 (해결됨)

**이슈**: code-reviewer가 삭제된 파일을 Read 시도

**구현된 해결책**:
- git-input이 `git diff --name-status`를 사용하여 파일 상태(A/M/D/R) 추적
- 삭제된 파일(D)은 분석에서 제외
- 결과에 `DELETED_FILES` 섹션 반환
- 모든 파일이 삭제된 경우 `GIT_INPUT_RESULT: DELETED_ONLY` 반환

#### HIGH: 대량 파일 수 처리 (해결됨)

**이슈**: 수백/수천 개의 변경된 파일에 대한 처리 없음

**구현된 해결책**:
- 100개 이상 파일 변경 시 경고
- 바이너리 파일 자동 필터링
- 소스 파일만 필터링하도록 권장

#### MEDIUM: Detached HEAD 처리 (해결됨)

**이슈**: CI/CD 환경에서 일반적이지만 처리가 정의되지 않음

**구현된 해결책**:
- git-input이 detached HEAD 상태 감지
- 사용자 옵션: 브랜치 생성, QA만 진행, 또는 종료
- `skip_commit_push` 플래그로 STEP 9와 11 건너뛰기

#### MEDIUM: 의존성 설치 안내 (해결됨)

**이슈**: 의존성이 설치되지 않았을 때 빌드 실패

**구현된 해결책**:
- build-tester가 오류 메시지 패턴으로 의존성 오류 감지
- `BUILD_RESULT: FAIL_DEPS` 토큰 반환
- 언어별 설치 제안 제공
- 사용자가 재시도 또는 건너뛰기 가능

#### MEDIUM: Merge Conflict 처리 (해결됨)

**이슈**: merge conflict가 있을 때 커밋 불가

**구현된 해결책**:
- git-input이 `git ls-files -u`로 merge conflict 상태 감지
- `GIT_INPUT_RESULT: MERGE_CONFLICT` 토큰 반환
- 해결 안내 제공

#### MEDIUM: Rebase 진행 중 처리 (해결됨)

**이슈**: rebase가 진행 중일 때 커밋 불가

**구현된 해결책**:
- git-input이 `.git/rebase-merge` 또는 `.git/rebase-apply` 확인으로 rebase 상태 감지
- `GIT_INPUT_RESULT: REBASE_IN_PROGRESS` 토큰 반환
- 해결 안내 제공

---

### 1.5 구현된 수정사항

#### git-input 에이전트 수정사항

```
확장된 결과 토큰:
- GIT_INPUT_RESULT: SUCCESS (파일 존재)
- GIT_INPUT_RESULT: NO_CHANGES (변경사항 없음)
- GIT_INPUT_RESULT: DELETED_ONLY (삭제된 파일만)
- GIT_INPUT_RESULT: NO_CODE_FILES (설정/문서만)
- GIT_INPUT_RESULT: NO_GIT_REPO (Git 리포지토리 아님)
- GIT_INPUT_RESULT: DETACHED_HEAD (detached HEAD 상태)
- GIT_INPUT_RESULT: MERGE_CONFLICT (merge conflict)
- GIT_INPUT_RESULT: REBASE_IN_PROGRESS (rebase 진행 중)
- GIT_INPUT_RESULT: ABORTED (사용자 취소)

확장된 FILE_LIST 형식:
FILE_LIST: file1.py, file2.py, ...
DELETED_FILES: deleted1.py, deleted2.py, ...
RENAMED_FILES: old→new, ...
```

#### code-qa 오케스트레이터 수정사항

```
STEP 2 결과 처리:
- NO_CHANGES → 워크플로우 종료 (성공)
- DELETED_ONLY → STEP 9로 건너뛰기
- NO_CODE_FILES → 워크플로우 종료 (성공)
- DETACHED_HEAD → 사용자 선택, skip_commit_push 플래그 설정
- MERGE_CONFLICT → 워크플로우 종료 (차단)
- REBASE_IN_PROGRESS → 워크플로우 종료 (차단)

STEP 2.5 파일 검증:
- 바이너리 파일 자동 필터링
- 대량 파일 수 경고 (100개 초과)

STEP 7 빌드 실패 처리:
- FAIL_DEPS → 의존성 설치 안내 표시
```

#### build-tester 에이전트 수정사항

```
확장된 빌드 실패 토큰:
- BUILD_RESULT: FAIL (일반 실패)
- BUILD_RESULT: FAIL_DEPS (의존성 문제)

의존성 오류 감지 패턴:
- Python: ModuleNotFoundError, ImportError, No module named
- Node.js: Cannot find module, MODULE_NOT_FOUND
- Go: cannot find package
- Rust: can't find crate
- Java: package does not exist
```

---

## Part 2: 상세 시나리오 분석

### 2.1 환경 설정 시나리오

#### 시나리오: 활성 Conda 환경

```
사용자 상태: 이미 "ml-dev" conda 환경에 있음
예상 흐름:
  1. env-setup이 $CONDA_DEFAULT_ENV = "ml-dev" 감지
  2. 표시: "현재 환경 'ml-dev'를 사용하시겠습니까? [Y/n/list]"
  3. 사용자가 Enter 또는 Y 입력
  4. SUCCESS (1회 상호작용)
```

**상태**: ✅ 간소화된 env-setup으로 처리됨

#### 시나리오: 활성 venv 환경

```
사용자 상태: 이미 .venv 활성화됨
예상 흐름:
  1. env-setup이 $VIRTUAL_ENV = "/path/to/.venv" 감지
  2. 표시: "현재 환경 '.venv'를 사용하시겠습니까? [Y/n/list]"
  3. 사용자가 Enter 입력
  4. SUCCESS (1회 상호작용)
```

**상태**: ✅ 간소화된 env-setup으로 처리됨

#### 시나리오: 활성 환경 없음

```
사용자 상태: conda/venv 활성화되지 않음
예상 흐름:
  1. env-setup이 ACTIVE_TYPE: none 감지
  2. conda 환경 목록 + 옵션 표시
  3. 사용자가 환경 선택
  4. SUCCESS (2회 상호작용)
```

**상태**: ✅ 간소화된 env-setup으로 처리됨

#### 시나리오: 사용자가 다른 환경을 원함

```
사용자 상태: "base"에 있지만 "ml-dev"를 원함
예상 흐름:
  1. env-setup 표시: "'base'를 사용하시겠습니까? [Y/n/list]"
  2. 사용자가 "n" 입력
  3. 전체 환경 목록 표시
  4. 사용자가 "ml-dev" 선택
  5. SUCCESS (2회 상호작용)
```

**상태**: ✅ 간소화된 env-setup으로 처리됨

#### 시나리오: auto_confirm 설정

```
사용자 상태: .opencode/env-config.yaml에 auto_confirm: true
예상 흐름:
  1. env-setup이 설정 읽기
  2. 환경 일치 확인
  3. SUCCESS (0회 상호작용)
```

**상태**: ✅ 간소화된 env-setup으로 처리됨

---

### 2.2 Git 입력 시나리오

#### 시나리오: 정상 작업 디렉토리 변경사항

```
사용자 상태: 작업 디렉토리에 커밋되지 않은 변경사항 있음
명령: /code-qa (기본 --working)
예상 흐름:
  1. git-input이 git diff 실행
  2. 변경된 파일로 FILE_LIST 반환
  3. GIT_INPUT_RESULT: SUCCESS
  4. STEP 3으로 진행
```

**상태**: ✅ 처리됨

#### 시나리오: 변경된 파일 없음

```
사용자 상태: 깨끗한 작업 디렉토리
명령: /code-qa
예상 흐름:
  1. git-input이 git diff 실행
  2. 반환된 파일 없음
  3. GIT_INPUT_RESULT: NO_CHANGES
  4. 메시지와 함께 워크플로우 정상 종료
```

**상태**: ✅ 처리됨

#### 시나리오: 삭제된 파일만 있음

```
사용자 상태: git rm file.py
명령: /code-qa --staged
예상 흐름:
  1. git-input이 D 상태 파일 감지
  2. GIT_INPUT_RESULT: DELETED_ONLY
  3. STEP 9(Git Commit)으로 건너뛰기
```

**상태**: ✅ 처리됨

#### 시나리오: Detached HEAD

```
사용자 상태: git checkout HEAD~1 (CI/CD에서 일반적)
명령: /code-qa
예상 흐름:
  1. git-input이 detached HEAD 감지
  2. GIT_INPUT_RESULT: DETACHED_HEAD
  3. 사용자 옵션:
     - 브랜치 이름 입력 → 브랜치 생성, 계속
     - "qa-only" → skip_commit_push=true, QA만 진행
     - "exit" → 워크플로우 종료
```

**상태**: ✅ 처리됨

#### 시나리오: Merge Conflict

```
사용자 상태: git merge feature (충돌 존재)
명령: /code-qa
예상 흐름:
  1. git-input이 git ls-files -u로 merge conflict 감지
  2. GIT_INPUT_RESULT: MERGE_CONFLICT
  3. 워크플로우 차단, 사용자에게 해결 안내
```

**상태**: ✅ 처리됨

#### 시나리오: Rebase 진행 중

```
사용자 상태: git rebase main (중간에 멈춤)
명령: /code-qa
예상 흐름:
  1. git-input이 .git/rebase-merge 또는 .git/rebase-apply 감지
  2. GIT_INPUT_RESULT: REBASE_IN_PROGRESS
  3. 워크플로우 차단, 사용자에게 계속/중단 안내
```

**상태**: ✅ 처리됨

#### 시나리오: Git 리포지토리가 아님

```
사용자 상태: git이 아닌 디렉토리에 있음
명령: /code-qa
예상 흐름:
  1. git-input이 git 리포지토리가 아님을 감지
  2. GIT_INPUT_RESULT: NO_GIT_REPO
  3. 사용자 옵션:
     - "git init" → 리포지토리 초기화
     - 파일 경로 → file-input 모드로 전환
     - "exit" → 워크플로우 종료
```

**상태**: ✅ 처리됨

#### 시나리오: 대량 파일 수 (100개 이상)

```
사용자 상태: 200개 파일이 변경된 대규모 리팩토링
명령: /code-qa
예상 흐름:
  1. git-input이 200개 파일로 FILE_LIST 반환
  2. STEP 2.5 검증에서 경고 표시
  3. 바이너리 파일 자동 필터링
  4. 소스 파일 필터링 권장
```

**상태**: ✅ 처리됨

#### 시나리오: 이름 변경된 파일

```
사용자 상태: git mv old.py new.py
명령: /code-qa --staged
예상 흐름:
  1. git-input이 R 상태 감지
  2. FILE_LIST에 new.py 포함 (old.py 아님)
  3. RENAMED_FILES: old.py→new.py 기록
```

**상태**: ✅ 처리됨

---

### 2.3 캐시 시나리오

#### 시나리오: 유효한 캐시 존재

```
사용자 상태: /analyze를 최근(24시간 이내)에 실행
명령: /code-qa
예상 흐름:
  1. STEP 0이 .opencode/workspace-cache/analysis.json 읽기
  2. 타임스탬프가 24시간 이내
  3. workspace_cache = 로드된 데이터
  4. 캐시 컨텍스트와 함께 진행
```

**상태**: ✅ 처리됨

#### 시나리오: 만료된 캐시 (24시간 초과)

```
사용자 상태: /analyze를 3일 전에 실행
명령: /code-qa
예상 흐름:
  1. STEP 0이 캐시 읽기, 타임스탬프 확인
  2. 캐시가 만료됨 (24시간 초과)
  3. 경고: "캐시가 만료되었습니다. /analyze를 먼저 실행하세요."
  4. workspace_cache = null
  5. 캐시 없이 진행
```

**상태**: ✅ 처리됨

#### 시나리오: --with-analysis로 만료된 캐시

```
사용자 상태: /analyze를 3일 전에 실행
명령: /code-qa --with-analysis
예상 흐름:
  1. STEP 0이 만료된 캐시 감지
  2. auto_analyze = true
  3. workspace-analyzer 호출하여 재분석
  4. workspace_cache = 새 데이터
  5. 새로운 캐시와 함께 진행
```

**상태**: ✅ 처리됨

#### 시나리오: 캐시 없음

```
사용자 상태: /analyze를 실행한 적 없음
명령: /code-qa
예상 흐름:
  1. STEP 0이 캐시 읽기 시도
  2. 파일 없음
  3. 안내: "워크스페이스 캐시가 없습니다. 캐시 없이 진행합니다."
  4. workspace_cache = null
  5. 캐시 없이 진행
```

**상태**: ✅ 처리됨

#### 시나리오: --with-analysis로 캐시 없음

```
사용자 상태: /analyze를 실행한 적 없음
명령: /code-qa --with-analysis
예상 흐름:
  1. STEP 0이 캐시 없음 감지
  2. auto_analyze = true
  3. workspace-analyzer 호출
  4. workspace_cache = 새 데이터
  5. 캐시와 함께 진행
```

**상태**: ✅ 처리됨

#### 시나리오: 명시적 캐시 건너뛰기

```
사용자 상태: 유효한 캐시 있음
명령: /code-qa --skip-cache
예상 흐름:
  1. use_cache = false
  2. STEP 0 캐시 확인 완전히 건너뛰기
  3. workspace_cache = null
  4. 캐시 없이 진행
```

**상태**: ✅ 처리됨

---

### 2.4 빌드/테스트 시나리오

#### 시나리오: 빌드 성공

```
예상 흐름:
  1. build-tester가 빌드 명령 실행
  2. BUILD_RESULT: SUCCESS
  3. STEP 8로 진행
```

**상태**: ✅ 처리됨

#### 시나리오: 빌드 실패 (코드 문제)

```
예상 흐름:
  1. build-tester가 빌드 실행
  2. 컴파일 오류
  3. BUILD_RESULT: FAIL
  4. STEP 5(code-fixer)로 회귀
  5. 최대 3회 재시도
```

**상태**: ✅ 처리됨

#### 시나리오: 빌드 실패 (의존성 누락)

```
사용자 상태: node_modules 삭제 또는 의존성 미설치
예상 흐름:
  1. build-tester가 빌드 실행
  2. "Cannot find module" 오류 감지
  3. BUILD_RESULT: FAIL_DEPS
  4. 의존성 설치 안내 표시
  5. 사용자가 설치 후 재시도 또는 건너뛰기
```

**상태**: ✅ 처리됨

#### 시나리오: 테스트 실패

```
예상 흐름:
  1. function-tester가 테스트 실행
  2. 일부 테스트 실패
  3. TEST_RESULT: FAIL
  4. STEP 5(code-fixer)로 회귀
  5. 최대 3회 재시도
```

**상태**: ✅ 처리됨

#### 시나리오: 테스트를 찾을 수 없음

```
사용자 상태: 프로젝트에 테스트 파일 없음
예상 흐름:
  1. function-tester가 테스트 검색
  2. 테스트 파일 없음
  3. TEST_RESULT: NO_TESTS
  4. STEP 9로 진행 (테스트 건너뛰기)
```

**상태**: ✅ 처리됨

#### 시나리오: 사용자가 테스트 건너뛰기

```
예상 흐름:
  1. function-tester가 감지된 테스트 표시
  2. 사용자가 "skip/n" 입력
  3. TEST_RESULT: SKIPPED
  4. STEP 9로 진행
```

**상태**: ✅ 처리됨

---

### 2.5 Git Commit/Push 시나리오

#### 시나리오: 정상 커밋 및 푸시

```
예상 흐름:
  1. git-committer가 커밋 정보 표시
  2. 사용자 확인
  3. COMMIT_RESULT: SUCCESS
  4. git-pusher가 푸시
  5. PUSH_RESULT: SUCCESS
```

**상태**: ✅ 처리됨

#### 시나리오: 사용자가 커밋 취소

```
예상 흐름:
  1. git-committer가 커밋 정보 표시
  2. 사용자가 "cancel/n" 입력
  3. COMMIT_RESULT: SKIPPED
  4. STEP 10(요약)으로 진행
```

**상태**: ✅ 처리됨

#### 시나리오: 푸시 인증 오류 (SSH)

```
사용자 상태: SSH 키 미설정
예상 흐름:
  1. git-pusher가 푸시 시도
  2. SSH 인증 오류
  3. PUSH_RESULT: AUTH_ERROR
  4. SSH 키 설정 안내
  5. 사용자가 재시도 또는 건너뛰기
```

**상태**: ✅ 처리됨

#### 시나리오: 푸시 인증 오류 (HTTPS)

```
사용자 상태: 토큰 만료 또는 잘못된 자격 증명
예상 흐름:
  1. git-pusher가 푸시 시도
  2. HTTPS 인증 오류
  3. PUSH_RESULT: AUTH_ERROR
  4. 자격 증명 갱신 안내
  5. 사용자가 재시도 또는 건너뛰기
```

**상태**: ✅ 처리됨

#### 시나리오: Detached HEAD (Commit/Push 건너뛰기)

```
사용자 상태: Detached HEAD, "qa-only" 선택
예상 흐름:
  1. skip_commit_push = true
  2. STEP 9 메시지와 함께 건너뛰기
  3. STEP 11 메시지와 함께 건너뛰기
  4. 요약 후 워크플로우 종료
```

**상태**: ✅ 처리됨

#### 시나리오: Non-Git 모드 (--files)

```
명령: /code-qa --files src/
예상 흐름:
  1. use_git_mode = false
  2. STEP 9 건너뛰기 (Git 없음)
  3. STEP 11 건너뛰기 (Git 없음)
  4. 요약 후 워크플로우 종료
```

**상태**: ✅ 처리됨

---

### 2.6 파일 입력 모드 시나리오

#### 시나리오: 단일 파일

```
명령: /code-qa --files src/main.py
예상 흐름:
  1. use_git_mode = false
  2. file-input이 경로 파싱
  3. FILE_INPUT_RESULT: SUCCESS
  4. 단일 파일로 진행
```

**상태**: ✅ 처리됨

#### 시나리오: 디렉토리

```
명령: /code-qa --files src/
예상 흐름:
  1. file-input이 src/ 내 모든 코드 파일 찾기
  2. FILE_INPUT_RESULT: SUCCESS
  3. 발견된 모든 파일로 진행
```

**상태**: ✅ 처리됨

#### 시나리오: Glob 패턴

```
명령: /code-qa --files "src/**/*.py"
예상 흐름:
  1. file-input이 glob 확장
  2. FILE_INPUT_RESULT: SUCCESS
  3. 일치하는 파일로 진행
```

**상태**: ✅ 처리됨

#### 시나리오: 잘못된 경로

```
명령: /code-qa --files nonexistent/
예상 흐름:
  1. file-input이 경로를 찾을 수 없음
  2. FILE_INPUT_RESULT: INVALID_PATH
  3. 오류와 함께 워크플로우 종료
```

**상태**: ✅ 처리됨

#### 시나리오: 코드 파일을 찾을 수 없음

```
명령: /code-qa --files images/
예상 흐름:
  1. file-input이 .png, .jpg 파일만 발견
  2. 바이너리 파일 필터링
  3. FILE_INPUT_RESULT: NO_FILES
  4. 메시지와 함께 워크플로우 종료
```

**상태**: ✅ 처리됨

---

### 2.7 품질/회귀 시나리오

#### 시나리오: 첫 번째 시도에서 품질 통과

```
예상 흐름:
  1. quality-checker가 QUALITY_SCORE: 85/100 반환
  2. score >= 70
  3. STEP 7로 진행
```

**상태**: ✅ 처리됨

#### 시나리오: 품질 실패 → 수정 → 통과

```
예상 흐름:
  1. quality-checker: QUALITY_SCORE: 55/100
  2. STEP 5(code-fixer)로 회귀
  3. retry_count = 1
  4. code-fixer가 이슈 수정
  5. quality-checker: QUALITY_SCORE: 78/100
  6. 통과, STEP 7로 진행
```

**상태**: ✅ 처리됨

#### 시나리오: 최대 재시도 초과

```
예상 흐름:
  1. quality-checker가 3회 실패
  2. retry_count = 3
  3. 여전히 실패
  4. "최대 재시도 초과"로 워크플로우 중지
```

**상태**: ✅ 처리됨

---

### 2.8 워크스페이스 분석 시나리오

#### 시나리오: 일반 프로젝트

```
명령: /analyze
예상 흐름:
  1. workspace-analyzer가 프로젝트 스캔
  2. WORKSPACE_ANALYSIS_RESULT: COMPLETE
  3. 캐시 저장
```

**상태**: ✅ 처리됨

#### 시나리오: 대규모 프로젝트 (10,000개 이상 파일)

```
예상 흐름:
  1. workspace-analyzer가 파일 제한에 도달
  2. 축소된 분석
  3. WORKSPACE_ANALYSIS_RESULT: TIMEOUT
  4. truncated: true와 함께 부분 캐시 저장
```

**상태**: ✅ 처리됨

#### 시나리오: 빈 프로젝트

```
예상 흐름:
  1. workspace-analyzer가 소스 파일을 찾지 못함
  2. WORKSPACE_ANALYSIS_RESULT: EMPTY
  3. workspace_cache = null
```

**상태**: ✅ 처리됨

#### 시나리오: 알 수 없는 프로젝트 타입

```
예상 흐름:
  1. workspace-analyzer가 매니페스트 파일을 찾지 못함
  2. project.type = "unknown"
  3. 확장자에서 언어 추론
  4. WORKSPACE_ANALYSIS_RESULT: COMPLETE
```

**상태**: ✅ 처리됨

---

## 3. 테스트 시나리오

### 3.1 정상 경로 테스트

```bash
# T1: 기본 Git 모드
/code-qa

# T2: Staged 변경사항만
git add src/app.py
/code-qa --staged

# T3: 직접 파일 지정
/code-qa --files src/

# T4: 캐시 활용
/analyze
/code-qa

# T5: 캐시 + 분석 동시 실행
/code-qa --with-analysis
```

### 3.2 엣지 케이스 테스트

```bash
# T6: 변경사항 없음
git status  # clean
/code-qa    # → "변경된 파일 없음" 메시지 예상

# T7: 삭제된 파일만 존재
git rm old_file.py
/code-qa --staged  # → 삭제된 파일 처리 확인

# T8: 대량 파일 수
# 100개 이상 파일 변경 후
/code-qa  # → 경고 및 필터링 확인

# T9: Git이 아닌 디렉토리
cd /tmp/non-git-project
/code-qa  # → NO_GIT_REPO 처리 확인

# T10: 빈 프로젝트
/analyze  # → EMPTY 결과 확인

# T11: Detached HEAD
git checkout HEAD~1
/code-qa  # → DETACHED_HEAD 처리 확인

# T12: Merge conflict
git merge feature --no-commit  # 충돌 생성
/code-qa  # → MERGE_CONFLICT 처리 확인
```

### 3.3 오류 시나리오 테스트

```bash
# T13: 의존성 미설치
rm -rf node_modules
/code-qa  # → 빌드 실패 + 안내 메시지

# T14: Docker 사용 불가
# Docker 중지 후
/code-qa  # → --no-sandbox 폴백 안내

# T15: 네트워크 없음
# 오프라인 상태에서
/code-qa  # → Push 단계에서 적절한 오류 처리
```

---

## 4. 요약

### 검증된 시나리오: 40개 이상

모든 주요 워크플로우 시나리오가 적절히 처리됩니다:
- ✅ 환경 설정 (5개 시나리오 전체)
- ✅ Git 입력 (9개 시나리오 전체)
- ✅ 캐시 처리 (6개 시나리오 전체)
- ✅ 빌드/테스트 (6개 시나리오 전체)
- ✅ Git commit/push (6개 시나리오 전체)
- ✅ 파일 입력 모드 (5개 시나리오 전체)
- ✅ 품질/회귀 (3개 시나리오 전체)
- ✅ 워크스페이스 분석 (4개 시나리오 전체)

### 해결된 Critical 이슈

1. **변경된 파일 없음 처리** - 워크플로우 정상 종료
2. **삭제된 파일 처리** - 분석에서 적절히 제외

### 해결된 High Priority 이슈

3. **대량 파일 수 처리** - 경고 및 필터링
4. **파일 상태 구분** - A/M/D/R 상태 추적

### 해결된 Medium Priority 이슈

5. **Detached HEAD 처리** - 사용자 옵션 제공
6. **의존성 설치 안내** - FAIL_DEPS 토큰 및 제안
7. **Merge conflict 처리** - 감지 및 차단
8. **Rebase 진행 중 처리** - 감지 및 차단

### 남은 Low Priority 이슈

- Dirty working tree 처리 (부분적)
- Shallow clone 처리 (부분적)
- Python/Node 미설치 (부분적)
- 네트워크 없음 (부분적)

---

## 변경 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|-----------|
| 1.0 | 2024-01-15 | 초기 케이스 리뷰 문서 |
| 2.0 | 2025-02-04 | 모든 critical/high/medium 이슈 해결, 영문 번역 |
| 3.0 | 2025-02-04 | 시나리오 분석과 케이스 리뷰를 통합 문서로 병합 |

---

## 관련 문서

- [아키텍처 다이어그램](./02-architecture.kr.md)
- [빠른 시작](./01-quick-start.kr.md)
- [환경 설정](./03-environment-setup.kr.md)
- [구현 요약](./05-implementation-summary.kr.md)
