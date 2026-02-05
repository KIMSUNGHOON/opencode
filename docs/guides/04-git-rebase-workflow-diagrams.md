> **Note**: This document references `sglang/gpt-oss-120b` model IDs which are outdated. See [14-code-qa-v4-quick-start.md](./14-code-qa-v4-quick-start.md) for current model configuration.

# Git Rebase/Porting Workflow - Agent 다이어그램

이 문서는 Git Rebase/Porting 워크플로우의 Agent 구성과 데이터 흐름을 시각화합니다.

---

## 1. Agent Architecture Block Diagram (TB)

```mermaid
block-beta
    columns 3

    %% Title Row
    space:3

    %% User Layer
    block:user_layer:3
        columns 1
        User["👤 User / Developer"]
    end

    space:3

    %% Command Layer
    block:command_layer:3
        columns 3
        CMD1["/port-commits"]
        CMD2["/git-analyze"]
        CMD3["/git-backup"]
    end

    space:3

    %% Orchestrator
    block:orchestrator:3
        columns 1
        ORCH["🎯 OpenCode Orchestrator<br/>Model: sglang/gpt-oss-120b"]
    end

    space:3

    %% Agent Layer
    block:agent_layer:3
        columns 4
        A1["🔍 git-analyzer<br/>#3498DB"]
        A2["💾 git-backup<br/>#27AE60"]
        A3["🔄 git-porter<br/>#E74C3C"]
        A4["✅ git-verifier<br/>#9B59B6"]
    end

    space:3

    %% Permission Layer
    block:permission_layer:3
        columns 4
        P1["bash: git *<br/>read: allow<br/>edit: deny"]
        P2["bash: git branch/tag<br/>format-patch<br/>stash"]
        P3["bash: git rebase (ask)<br/>read/edit: allow<br/>push: deny"]
        P4["bash: bun/npm<br/>read: allow<br/>edit: deny"]
    end

    space:3

    %% Git Repository
    block:git_layer:3
        columns 1
        GIT["📁 Git Repository<br/>upstream/main ↔ your-branch"]
    end

    %% Connections
    User --> CMD1
    User --> CMD2
    User --> CMD3
    CMD1 --> ORCH
    CMD2 --> ORCH
    CMD3 --> ORCH
    ORCH --> A1
    ORCH --> A2
    ORCH --> A3
    ORCH --> A4
    A1 --> P1
    A2 --> P2
    A3 --> P3
    A4 --> P4
    P1 --> GIT
    P2 --> GIT
    P3 --> GIT
    P4 --> GIT
```

---

## 2. Flowchart Block Diagram (TB)

```mermaid
flowchart TB
    subgraph USER["👤 User Interface"]
        U1[User Request]
        U2[Conflict Resolution Input]
        U3[Final Approval]
    end

    subgraph COMMANDS["📋 Commands Layer"]
        C1["/port-commits<br/>Full Workflow"]
        C2["/git-analyze<br/>Analysis Only"]
        C3["/git-backup<br/>Backup Only"]
    end

    subgraph ORCHESTRATOR["🎯 OpenCode Orchestrator"]
        direction TB
        O1[Task Router]
        O2[State Manager]
        O3[Error Handler]
    end

    subgraph PHASE1["Phase 1: Analysis"]
        direction TB
        A1["🔍 git-analyzer"]
        A1_1[Fetch Upstream]
        A1_2[Identify Commits]
        A1_3[Detect Conflicts]
        A1_4[Generate Report]
        A1 --> A1_1 --> A1_2 --> A1_3 --> A1_4
    end

    subgraph PHASE2["Phase 2: Backup"]
        direction TB
        A2["💾 git-backup"]
        A2_1[Create Branch]
        A2_2[Create Tag]
        A2_3[Export Patches]
        A2 --> A2_1 --> A2_2 --> A2_3
    end

    subgraph PHASE3["Phase 3: Porting"]
        direction TB
        A3["🔄 git-porter"]
        A3_1[Start Rebase]
        A3_2{Conflict?}
        A3_3[Report to User]
        A3_4[Apply Resolution]
        A3_5[Continue Rebase]
        A3 --> A3_1 --> A3_2
        A3_2 -->|Yes| A3_3 --> A3_4 --> A3_5
        A3_2 -->|No| A3_5
        A3_5 --> A3_2
    end

    subgraph PHASE4["Phase 4: Verification"]
        direction TB
        A4["✅ git-verifier"]
        A4_1[Build Test]
        A4_2[Run Tests]
        A4_3[Compare Backup]
        A4_4[Generate Report]
        A4 --> A4_1 --> A4_2 --> A4_3 --> A4_4
    end

    subgraph REPOSITORY["📁 Git Repository"]
        R1[(upstream/main)]
        R2[(your-branch)]
        R3[(backup/branch)]
        R4[(.patches/)]
    end

    U1 --> C1 & C2 & C3
    C1 & C2 & C3 --> O1
    O1 --> PHASE1
    PHASE1 --> PHASE2
    PHASE2 --> PHASE3
    U2 -.-> A3_4
    PHASE3 --> PHASE4
    PHASE4 --> U3

    A1_1 -.-> R1
    A2_1 -.-> R3
    A2_3 -.-> R4
    A3_1 -.-> R2
    A4_3 -.-> R3

    style PHASE1 fill:#3498DB22,stroke:#3498DB
    style PHASE2 fill:#27AE6022,stroke:#27AE60
    style PHASE3 fill:#E74C3C22,stroke:#E74C3C
    style PHASE4 fill:#9B59B622,stroke:#9B59B6
```

---

## 3. Data Flow Diagram

```mermaid
flowchart LR
    subgraph INPUT["📥 Input Data"]
        I1[("upstream/main<br/>commits")]
        I2[("your-branch<br/>custom commits")]
        I3[("User<br/>decisions")]
    end

    subgraph ANALYZER["🔍 git-analyzer"]
        direction TB
        AN1[git fetch]
        AN2[git merge-base]
        AN3[git log]
        AN4[git diff --stat]
        AN5[conflict detection]
    end

    subgraph BACKUP["💾 git-backup"]
        direction TB
        BK1[git branch backup/*]
        BK2[git tag pre-rebase-*]
        BK3[git format-patch]
        BK4[git stash]
    end

    subgraph PORTER["🔄 git-porter"]
        direction TB
        PT1[git rebase]
        PT2[conflict handling]
        PT3[git add]
        PT4[git rebase --continue]
    end

    subgraph VERIFIER["✅ git-verifier"]
        direction TB
        VF1[bun install]
        VF2[bun run build]
        VF3[bun test]
        VF4[git diff comparison]
    end

    subgraph OUTPUT["📤 Output Data"]
        O1[("Analysis<br/>Report")]
        O2[("Backup<br/>References")]
        O3[("Rebased<br/>Branch")]
        O4[("Verification<br/>Report")]
    end

    I1 --> AN1
    I2 --> AN2 & AN3
    AN1 --> AN4 --> AN5
    AN2 & AN3 --> AN5
    AN5 --> O1

    O1 --> BK1 & BK2 & BK3
    BK1 & BK2 & BK3 --> O2

    O2 --> PT1
    I3 --> PT2
    PT1 --> PT2 --> PT3 --> PT4
    PT4 --> O3

    O3 --> VF1 --> VF2 --> VF3 --> VF4
    VF4 --> O4

    style ANALYZER fill:#3498DB22,stroke:#3498DB
    style BACKUP fill:#27AE6022,stroke:#27AE60
    style PORTER fill:#E74C3C22,stroke:#E74C3C
    style VERIFIER fill:#9B59B622,stroke:#9B59B6
```

---

## 4. Sequence Diagram (Data Flow Timeline)

```mermaid
sequenceDiagram
    autonumber

    actor User
    participant CMD as Commands
    participant ORCH as Orchestrator
    participant ANA as 🔍 git-analyzer
    participant BAK as 💾 git-backup
    participant POR as 🔄 git-porter
    participant VER as ✅ git-verifier
    participant GIT as 📁 Git Repo

    User->>CMD: /port-commits upstream/main
    CMD->>ORCH: Initialize workflow

    rect rgb(52, 152, 219, 0.1)
        Note over ANA: Phase 1: Analysis
        ORCH->>ANA: Start analysis
        ANA->>GIT: git fetch upstream
        GIT-->>ANA: upstream data
        ANA->>GIT: git merge-base, git log
        GIT-->>ANA: commit info
        ANA->>GIT: conflict detection (dry-run)
        GIT-->>ANA: potential conflicts
        ANA-->>ORCH: Analysis Report
    end

    rect rgb(39, 174, 96, 0.1)
        Note over BAK: Phase 2: Backup
        ORCH->>BAK: Create backup
        BAK->>GIT: git branch backup/*
        BAK->>GIT: git tag pre-rebase-*
        BAK->>GIT: git format-patch
        GIT-->>BAK: backup created
        BAK-->>ORCH: Backup References
    end

    rect rgb(231, 76, 60, 0.1)
        Note over POR: Phase 3: Porting
        ORCH->>POR: Start rebase
        POR->>GIT: git rebase upstream/main

        loop For each conflict
            GIT-->>POR: Conflict detected
            POR-->>User: ⚠️ Conflict Report
            User->>POR: Resolution decision
            POR->>GIT: git add & continue
        end

        GIT-->>POR: Rebase complete
        POR-->>ORCH: Rebased Branch
    end

    rect rgb(155, 89, 182, 0.1)
        Note over VER: Phase 4: Verification
        ORCH->>VER: Verify changes
        VER->>GIT: bun install
        VER->>GIT: bun run build
        VER->>GIT: bun test
        VER->>GIT: git diff backup..HEAD
        GIT-->>VER: verification data
        VER-->>ORCH: Verification Report
    end

    ORCH-->>User: ✅ Workflow Complete
```

---

## 5. Agent Permission Matrix

| Agent | Phase | bash | read | edit | glob | grep | 특별 제한 |
|-------|-------|------|------|------|------|------|-----------|
| **git-analyzer** | 1 | `git *` ✅ | ✅ | ❌ | ✅ | ✅ | 읽기 전용 |
| **git-backup** | 2 | `git branch/tag` ✅ | ✅ | ❌ | - | - | `external_directory: ask` |
| **git-porter** | 3 | `git rebase` 🔶ask | ✅ | ✅ | ✅ | ✅ | `push: deny`, `push --force: deny` |
| **git-verifier** | 4 | `bun/npm/yarn` ✅ | ✅ | ❌ | ✅ | ✅ | 빌드/테스트만 |

---

## 6. State Machine Diagram

```mermaid
stateDiagram-v2
    [*] --> Idle: Start

    Idle --> Analyzing: /port-commits

    state Phase1 {
        Analyzing --> FetchingUpstream
        FetchingUpstream --> IdentifyingCommits
        IdentifyingCommits --> DetectingConflicts
        DetectingConflicts --> ReportGenerated
    }

    ReportGenerated --> BackingUp: Analysis OK
    ReportGenerated --> Idle: User Cancel

    state Phase2 {
        BackingUp --> CreatingBranch
        CreatingBranch --> CreatingTag
        CreatingTag --> ExportingPatches
        ExportingPatches --> BackupComplete
    }

    BackupComplete --> Rebasing: Backup OK

    state Phase3 {
        Rebasing --> ApplyingCommit
        ApplyingCommit --> ConflictCheck

        state ConflictCheck <<choice>>
        ConflictCheck --> WaitingUserInput: Conflict
        ConflictCheck --> ApplyingCommit: No Conflict
        ConflictCheck --> RebaseComplete: All Done

        WaitingUserInput --> ResolvingConflict: User Input
        ResolvingConflict --> ApplyingCommit
    }

    RebaseComplete --> Verifying: Rebase OK
    Rebasing --> Idle: Abort

    state Phase4 {
        Verifying --> BuildTesting
        BuildTesting --> RunningTests
        RunningTests --> ComparingBackup
        ComparingBackup --> VerificationComplete
    }

    VerificationComplete --> [*]: Success ✅
    VerificationComplete --> Idle: Failure ❌

    note right of Phase1: 🔍 git-analyzer
    note right of Phase2: 💾 git-backup
    note right of Phase3: 🔄 git-porter
    note right of Phase4: ✅ git-verifier
```

---

## 7. Component Interaction Block Diagram

```mermaid
flowchart TB
    subgraph SYSTEM["OpenCode Rebase/Porting System"]
        direction TB

        subgraph INTERFACE["Interface Layer"]
            CLI["CLI Interface"]
            HOOK["Hook System"]
        end

        subgraph CORE["Core Layer"]
            direction LR
            ROUTER["Command Router"]
            STATE["State Manager"]
            ERROR["Error Handler"]
        end

        subgraph AGENTS["Agent Layer"]
            direction TB

            subgraph GA["git-analyzer"]
                GA1["Upstream Fetcher"]
                GA2["Commit Identifier"]
                GA3["Conflict Predictor"]
            end

            subgraph GB["git-backup"]
                GB1["Branch Creator"]
                GB2["Tag Creator"]
                GB3["Patch Exporter"]
            end

            subgraph GP["git-porter"]
                GP1["Rebase Controller"]
                GP2["Conflict Resolver"]
                GP3["Progress Tracker"]
            end

            subgraph GV["git-verifier"]
                GV1["Build Runner"]
                GV2["Test Runner"]
                GV3["Diff Comparator"]
            end
        end

        subgraph EXTERNAL["External Layer"]
            GIT["Git Commands"]
            PKG["Package Manager"]
            FS["File System"]
        end
    end

    CLI --> ROUTER
    HOOK --> STATE

    ROUTER --> GA & GB & GP & GV
    STATE --> GA & GB & GP & GV
    ERROR --> GA & GB & GP & GV

    GA1 & GA2 & GA3 --> GIT
    GB1 & GB2 --> GIT
    GB3 --> GIT & FS
    GP1 & GP2 & GP3 --> GIT
    GV1 & GV2 --> PKG
    GV3 --> GIT

    style GA fill:#3498DB22,stroke:#3498DB
    style GB fill:#27AE6022,stroke:#27AE60
    style GP fill:#E74C3C22,stroke:#E74C3C
    style GV fill:#9B59B622,stroke:#9B59B6
```

---

## 8. Summary Table

| 구성 요소 | 설명 | 색상 코드 |
|-----------|------|-----------|
| **git-analyzer** | 상태 분석, 충돌 예측, 보고서 생성 | `#3498DB` (Blue) |
| **git-backup** | 백업 브랜치/태그 생성, 패치 추출 | `#27AE60` (Green) |
| **git-porter** | Rebase 수행, 충돌 해결 지원 | `#E74C3C` (Red) |
| **git-verifier** | 빌드/테스트 실행, 결과 검증 | `#9B59B6` (Purple) |

---

## 관련 문서

- [Git Rebase/Porting 워크플로우 가이드](./04-git-rebase-porting-workflow.md)
- [Custom Agent 가이드](./02-custom-agent-guide.md)
- [Code QA v4 Quick Start](./14-code-qa-v4-quick-start.md)
