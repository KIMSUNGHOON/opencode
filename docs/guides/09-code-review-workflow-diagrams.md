# Code Review 워크플로우 다이어그램

> ⚠️ **참고:** 이 문서는 Code QA v2 기준입니다.
> 최신 버전은 [Code QA v4 (Environment + Sandbox)](./12-environment-setup-workflow.md)를 참조하세요.
>
> **v4 주요 변경사항:**
> - **Phase -1: Environment Setup** - Shell/conda/venv 환경 자동 감지
> - **Docker Sandbox** - Build/Test를 격리된 컨테이너에서 실행 (기본값)
> - **10단계 파이프라인** - Phase -1 ~ Phase 9

---

## 1. 전체 워크플로우 (회귀 루프 포함)

```mermaid
flowchart TB
    START([시작]) --> INPUT[소스 코드 입력]

    INPUT --> REVIEW

    subgraph REVIEW["Phase 1: Code Review 🔍"]
        R1[코드 분석]
        R2[이슈 발견]
        R3[리포트 생성]
        R1 --> R2 --> R3
    end

    REVIEW --> FIX

    subgraph FIX["Phase 2: Code Fix 🔧"]
        F1[이슈 수정]
        F2[리팩토링]
        F3[변경사항 저장]
        F1 --> F2 --> F3
    end

    FIX --> QUALITY

    subgraph QUALITY["Phase 3: Quality Check 📋"]
        Q1[Lint 검사]
        Q2[Type 검사]
        Q3[Format 검사]
        Q4[점수 계산]
        Q1 --> Q2 --> Q3 --> Q4
    end

    QUALITY --> Q_CHECK{품질 점수<br/>≥ 70%?}

    Q_CHECK -->|No| Q_NOTIFY[/"⚠️ 품질 미달 알림<br/>(점수: XX%)"/]
    Q_NOTIFY --> Q_DECISION{사용자 결정}
    Q_DECISION -->|재검토| REVIEW
    Q_DECISION -->|수정만| FIX
    Q_DECISION -->|무시| BUILD

    Q_CHECK -->|Yes| BUILD

    subgraph BUILD["Phase 4: Build Test 🏗️"]
        B1[의존성 설치]
        B2[컴파일/번들링]
        B3[아티팩트 생성]
        B1 --> B2 --> B3
    end

    BUILD --> B_CHECK{빌드<br/>성공?}

    B_CHECK -->|No| B_NOTIFY[/"❌ 빌드 실패 알림<br/>(에러 로그 표시)"/]
    B_NOTIFY --> B_DECISION{사용자 결정}
    B_DECISION -->|재검토| REVIEW
    B_DECISION -->|수정만| FIX
    B_DECISION -->|중단| ABORT([중단])

    B_CHECK -->|Yes| TEST

    subgraph TEST["Phase 5: Function Test 🧪"]
        T1[Unit Test]
        T2[Integration Test]
        T3[결과 집계]
        T1 --> T2 --> T3
    end

    TEST --> T_CHECK{테스트<br/>통과?}

    T_CHECK -->|No| T_NOTIFY[/"❌ 테스트 실패 알림<br/>(실패 케이스 표시)"/]
    T_NOTIFY --> T_DECISION{사용자 결정}
    T_DECISION -->|재검토| REVIEW
    T_DECISION -->|수정만| FIX
    T_DECISION -->|무시| REPORT

    T_CHECK -->|Yes| REPORT

    REPORT[/"📊 최종 리포트 생성"/]
    REPORT --> END([완료])

    style REVIEW fill:#3498DB22,stroke:#3498DB
    style FIX fill:#27AE6022,stroke:#27AE60
    style QUALITY fill:#9B59B622,stroke:#9B59B6
    style BUILD fill:#E67E2222,stroke:#E67E22
    style TEST fill:#E74C3C22,stroke:#E74C3C
    style Q_NOTIFY fill:#F39C1222,stroke:#F39C12
    style B_NOTIFY fill:#E74C3C22,stroke:#E74C3C
    style T_NOTIFY fill:#E74C3C22,stroke:#E74C3C
```

---

## 2. 상태 다이어그램

```mermaid
stateDiagram-v2
    [*] --> CodeReview: 시작

    state "🔍 Code Review" as CodeReview
    state "🔧 Code Fix" as CodeFix
    state "📋 Quality Check" as QualityCheck
    state "🏗️ Build Test" as BuildTest
    state "🧪 Function Test" as FunctionTest
    state "📊 Report" as Report

    state quality_check <<choice>>
    state build_check <<choice>>
    state test_check <<choice>>

    state "⚠️ Quality Failed" as QualityFailed
    state "❌ Build Failed" as BuildFailed
    state "❌ Test Failed" as TestFailed

    CodeReview --> CodeFix: 이슈 발견
    CodeFix --> QualityCheck: 수정 완료

    QualityCheck --> quality_check
    quality_check --> BuildTest: ≥70%
    quality_check --> QualityFailed: <70%

    QualityFailed --> CodeReview: 재검토
    QualityFailed --> CodeFix: 수정만
    QualityFailed --> BuildTest: 무시

    BuildTest --> build_check
    build_check --> FunctionTest: 성공
    build_check --> BuildFailed: 실패

    BuildFailed --> CodeReview: 재검토
    BuildFailed --> CodeFix: 수정만
    BuildFailed --> [*]: 중단

    FunctionTest --> test_check
    test_check --> Report: 통과
    test_check --> TestFailed: 실패

    TestFailed --> CodeReview: 재검토
    TestFailed --> CodeFix: 수정만
    TestFailed --> Report: 무시

    Report --> [*]: 완료
```

---

## 3. 시퀀스 다이어그램 (사용자 상호작용 포함)

```mermaid
sequenceDiagram
    autonumber

    actor User as 👤 User
    participant CMD as Command
    participant REV as 🔍 Reviewer
    participant FIX as 🔧 Fixer
    participant QUA as 📋 Quality
    participant BLD as 🏗️ Builder
    participant TST as 🧪 Tester

    User->>CMD: /code-qa src/

    rect rgb(52, 152, 219, 0.1)
        Note over REV: Phase 1
        CMD->>REV: 코드 분석 요청
        REV->>REV: 이슈 발견
        REV-->>CMD: 리뷰 리포트
    end

    rect rgb(39, 174, 96, 0.1)
        Note over FIX: Phase 2
        CMD->>FIX: 이슈 수정 요청
        FIX->>FIX: 코드 수정
        FIX-->>CMD: 수정 완료
    end

    rect rgb(155, 89, 182, 0.1)
        Note over QUA: Phase 3
        CMD->>QUA: 품질 검사 요청
        QUA->>QUA: Lint/Type/Format
        QUA-->>CMD: 점수: 65%
    end

    CMD-->>User: ⚠️ 품질 미달 (65% < 70%)

    alt 재검토 선택
        User->>CMD: 재검토 요청
        CMD->>REV: 재분석
        Note over REV,FIX: Loop 반복
    else 수정만 선택
        User->>CMD: 수정만 요청
        CMD->>FIX: 재수정
        Note over FIX,QUA: Fix → Quality 반복
    else 무시 선택
        User->>CMD: 무시하고 진행
    end

    rect rgb(230, 126, 34, 0.1)
        Note over BLD: Phase 4
        CMD->>BLD: 빌드 요청
        BLD->>BLD: 컴파일
        BLD-->>CMD: ❌ 빌드 실패
    end

    CMD-->>User: ❌ 빌드 에러 로그

    alt 재검토 선택
        User->>CMD: 재검토 요청
        CMD->>REV: 재분석
    else 수정만 선택
        User->>CMD: 수정만 요청
        CMD->>FIX: 에러 수정
    else 중단 선택
        User->>CMD: 중단
        CMD-->>User: 워크플로우 중단
    end

    rect rgb(231, 76, 60, 0.1)
        Note over TST: Phase 5
        CMD->>TST: 테스트 요청
        TST->>TST: Unit/Integration
        TST-->>CMD: 2개 실패
    end

    CMD-->>User: ❌ 테스트 실패 리포트

    alt 재검토 선택
        User->>CMD: 재검토 요청
        CMD->>REV: 재분석
    else 수정만 선택
        User->>CMD: 수정만 요청
        CMD->>FIX: 테스트 수정
    else 무시 선택
        User->>CMD: 무시하고 완료
    end

    CMD-->>User: 📊 최종 리포트
```

---

## 4. 회귀 루프 상세 다이어그램

```mermaid
flowchart LR
    subgraph LOOP["회귀 루프 시스템"]
        direction TB

        subgraph TRIGGER["실패 트리거"]
            T1["Quality < 70%"]
            T2["Build Failed"]
            T3["Test Failed"]
        end

        subgraph NOTIFY["사용자 알림"]
            N1[/"📊 품질 점수 표시"/]
            N2[/"📋 에러 로그 표시"/]
            N3[/"📋 실패 케이스 표시"/]
        end

        subgraph DECISION["사용자 결정"]
            D1{선택}
        end

        subgraph ACTION["액션"]
            A1["🔍 Code Review로"]
            A2["🔧 Code Fix로"]
            A3["➡️ 다음 단계로"]
            A4["⏹️ 중단"]
        end

        T1 --> N1
        T2 --> N2
        T3 --> N3

        N1 & N2 & N3 --> D1

        D1 -->|재검토| A1
        D1 -->|수정만| A2
        D1 -->|무시/계속| A3
        D1 -->|중단| A4
    end

    style T1 fill:#F39C1222,stroke:#F39C12
    style T2 fill:#E74C3C22,stroke:#E74C3C
    style T3 fill:#E74C3C22,stroke:#E74C3C
```

---

## 5. 데이터 플로우 다이어그램

```mermaid
flowchart TB
    subgraph INPUT["📥 입력"]
        I1[(소스 코드)]
        I2[(설정 파일)]
    end

    subgraph REVIEW_DATA["🔍 Review 데이터"]
        RD1[이슈 목록]
        RD2[심각도 분류]
        RD3[개선 제안]
    end

    subgraph FIX_DATA["🔧 Fix 데이터"]
        FD1[수정된 코드]
        FD2[변경 diff]
    end

    subgraph QUALITY_DATA["📋 Quality 데이터"]
        QD1[Lint 결과]
        QD2[Type 에러]
        QD3[Format 이슈]
        QD4[품질 점수]
    end

    subgraph BUILD_DATA["🏗️ Build 데이터"]
        BD1[빌드 로그]
        BD2[에러 메시지]
        BD3[아티팩트]
    end

    subgraph TEST_DATA["🧪 Test 데이터"]
        TD1[테스트 결과]
        TD2[실패 케이스]
        TD3[커버리지]
    end

    subgraph OUTPUT["📤 출력"]
        O1[/"최종 리포트"/]
        O2[/"품질 대시보드"/]
    end

    subgraph FEEDBACK["🔄 피드백 루프"]
        FB1{{품질 < 70%}}
        FB2{{빌드 실패}}
        FB3{{테스트 실패}}
    end

    I1 --> REVIEW_DATA
    I2 --> REVIEW_DATA

    REVIEW_DATA --> FIX_DATA
    FIX_DATA --> QUALITY_DATA

    QUALITY_DATA --> QD4
    QD4 --> FB1
    FB1 -->|Yes| REVIEW_DATA
    FB1 -->|No| BUILD_DATA

    QUALITY_DATA --> BUILD_DATA
    BUILD_DATA --> FB2
    FB2 -->|Yes| REVIEW_DATA
    FB2 -->|No| TEST_DATA

    BUILD_DATA --> TEST_DATA
    TEST_DATA --> FB3
    FB3 -->|Yes| REVIEW_DATA
    FB3 -->|No| OUTPUT

    TEST_DATA --> OUTPUT

    style FB1 fill:#F39C1222,stroke:#F39C12
    style FB2 fill:#E74C3C22,stroke:#E74C3C
    style FB3 fill:#E74C3C22,stroke:#E74C3C
```

---

## 6. 컴포넌트 블록 다이어그램

```mermaid
block-beta
    columns 5

    space:5

    block:user_block:5
        columns 1
        USER["👤 User"]
    end

    space:5

    block:command_block:5
        columns 5
        CMD1["/code-qa"]
        CMD2["/review"]
        CMD3["/fix"]
        CMD4["/build"]
        CMD5["/test"]
    end

    space:5

    block:orchestrator_block:5
        columns 1
        ORCH["🎯 Orchestrator<br/>워크플로우 제어 + 회귀 루프 관리"]
    end

    space:5

    block:agent_block:5
        columns 5
        A1["🔍<br/>code-reviewer"]
        A2["🔧<br/>code-fixer"]
        A3["📋<br/>quality-checker"]
        A4["🏗️<br/>build-tester"]
        A5["🧪<br/>function-tester"]
    end

    space:5

    block:check_block:5
        columns 5
        space
        space
        C1{{"≥70%?"}}
        C2{{"성공?"}}
        C3{{"통과?"}}
    end

    space:5

    block:feedback_block:5
        columns 1
        FB["🔄 Feedback Loop<br/>실패 시 Review/Fix로 회귀"]
    end

    USER --> CMD1
    CMD1 --> ORCH
    ORCH --> A1
    ORCH --> A2
    ORCH --> A3
    ORCH --> A4
    ORCH --> A5
    A3 --> C1
    A4 --> C2
    A5 --> C3
    C1 --> FB
    C2 --> FB
    C3 --> FB
    FB --> ORCH

    style A1 fill:#3498DB22,stroke:#3498DB
    style A2 fill:#27AE6022,stroke:#27AE60
    style A3 fill:#9B59B622,stroke:#9B59B6
    style A4 fill:#E67E2222,stroke:#E67E22
    style A5 fill:#E74C3C22,stroke:#E74C3C
    style FB fill:#F39C1222,stroke:#F39C12
```

---

## 7. 회귀 조건 요약

| Phase | 조건 | 회귀 대상 | 사용자 옵션 |
|-------|------|-----------|-------------|
| **Quality Check** | 점수 < 70% | Review 또는 Fix | 재검토 / 수정만 / 무시 |
| **Build Test** | 빌드 실패 | Review 또는 Fix | 재검토 / 수정만 / 중단 |
| **Function Test** | 테스트 실패 | Review 또는 Fix | 재검토 / 수정만 / 무시 |

---

## 8. 의사결정 플로우

```mermaid
flowchart TB
    subgraph DECISION_FLOW["의사결정 흐름"]
        direction TB

        FAIL[실패 감지] --> ANALYZE[원인 분석]

        ANALYZE --> SHOW[/"사용자에게 표시<br/>• 에러 로그<br/>• 실패 원인<br/>• 권장 조치"/]

        SHOW --> ASK{사용자 선택?}

        ASK -->|"재검토<br/>(처음부터)"| REVIEW["🔍 Code Review<br/>전체 재분석"]

        ASK -->|"수정만<br/>(빠른 수정)"| FIX["🔧 Code Fix<br/>해당 이슈만 수정"]

        ASK -->|"무시<br/>(리스크 감수)"| CONTINUE["➡️ 다음 단계<br/>경고와 함께 진행"]

        ASK -->|"중단<br/>(빌드만)"| ABORT["⏹️ 워크플로우 중단<br/>현재 상태 저장"]

        REVIEW --> LOOP["다음 Phase로"]
        FIX --> RETRY["현재 Phase 재시도"]
        CONTINUE --> NEXT["다음 Phase로<br/>(경고 포함)"]
        ABORT --> SAVE["리포트 저장"]
    end

    style FAIL fill:#E74C3C22,stroke:#E74C3C
    style REVIEW fill:#3498DB22,stroke:#3498DB
    style FIX fill:#27AE6022,stroke:#27AE60
    style CONTINUE fill:#F39C1222,stroke:#F39C12
    style ABORT fill:#7F8C8D22,stroke:#7F8C8D
```

---

## 관련 문서

- [Code Review 워크플로우 가이드](./09-code-review-workflow-guide.md)
- [Code QA v3 (Git 통합)](./11-code-qa-workflow-v3-git-integrated.md)
- [**Code QA v4 (Environment + Sandbox)** ⭐](./12-environment-setup-workflow.md)
- [Git Rebase 워크플로우 다이어그램](./04-git-rebase-workflow-diagrams.md)
