#!/bin/bash
# Code QA Workflow Test Script
# 워크플로우의 각 단계를 테스트합니다.

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 테스트 결과 카운터
PASSED=0
FAILED=0
SKIPPED=0

# =============================================================================
# 유틸리티 함수
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED++))
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
    ((SKIPPED++))
}

log_section() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${BLUE}$1${NC}"
    echo "═══════════════════════════════════════════════════════════════"
}

# =============================================================================
# 설정 파일 테스트
# =============================================================================

test_config_files() {
    log_section "1. 설정 파일 검증"

    # workflow-settings.yaml 확인
    if [ -f ".opencode/config/workflow-settings.yaml" ]; then
        log_success "workflow-settings.yaml 존재"
    else
        log_fail "workflow-settings.yaml 없음"
    fi

    # permission-templates.yaml 확인
    if [ -f ".opencode/config/permission-templates.yaml" ]; then
        log_success "permission-templates.yaml 존재"
    else
        log_fail "permission-templates.yaml 없음"
    fi

    # logging-format.md 확인
    if [ -f ".opencode/config/logging-format.md" ]; then
        log_success "logging-format.md 존재"
    else
        log_fail "logging-format.md 없음"
    fi

    # mode/code-qa.md 확인
    if [ -f ".opencode/mode/code-qa.md" ]; then
        log_success "mode/code-qa.md 존재"
    else
        log_fail "mode/code-qa.md 없음"
    fi
}

# =============================================================================
# Agent 파일 테스트
# =============================================================================

test_agent_files() {
    log_section "2. Agent 파일 검증"

    AGENTS=(
        "env-setup"
        "git-input"
        "pre-checker"
        "code-reviewer"
        "code-fixer"
        "quality-checker"
        "build-tester"
        "function-tester"
        "git-committer"
        "summary-reporter"
        "git-pusher"
    )

    for agent in "${AGENTS[@]}"; do
        if [ -f ".opencode/agent/${agent}.md" ]; then
            log_success "Agent: ${agent}.md 존재"

            # tools 섹션 확인
            if grep -q "^tools:" ".opencode/agent/${agent}.md"; then
                log_success "  └─ tools 섹션 존재"
            else
                log_fail "  └─ tools 섹션 없음"
            fi

            # permission 섹션 확인
            if grep -q "^permission:" ".opencode/agent/${agent}.md"; then
                log_success "  └─ permission 섹션 존재"
            else
                log_fail "  └─ permission 섹션 없음"
            fi
        else
            log_fail "Agent: ${agent}.md 없음"
        fi
    done
}

# =============================================================================
# Tool 권한 테스트
# =============================================================================

test_tool_permissions() {
    log_section "3. Tool 권한 검증"

    # code-reviewer가 Read tool을 가지고 있는지 확인
    if grep -q '"Read": true' ".opencode/agent/code-reviewer.md"; then
        log_success "code-reviewer: Read tool 활성화"
    else
        log_fail "code-reviewer: Read tool 비활성화"
    fi

    # summary-reporter가 Bash tool을 가지고 있는지 확인
    if grep -q '"Bash": true' ".opencode/agent/summary-reporter.md"; then
        log_success "summary-reporter: Bash tool 활성화"
    else
        log_fail "summary-reporter: Bash tool 비활성화"
    fi

    # code-fixer가 Edit/Write tool을 가지고 있는지 확인
    if grep -q '"Edit": true' ".opencode/agent/code-fixer.md" && \
       grep -q '"Write": true' ".opencode/agent/code-fixer.md"; then
        log_success "code-fixer: Edit/Write tool 활성화"
    else
        log_fail "code-fixer: Edit/Write tool 비활성화"
    fi
}

# =============================================================================
# 결과 토큰 형식 테스트
# =============================================================================

test_result_tokens() {
    log_section "4. 결과 토큰 형식 검증"

    # 각 Agent가 결과 토큰을 출력하는지 확인
    declare -A TOKENS
    TOKENS["env-setup"]="ENV_SETUP_RESULT:"
    TOKENS["git-input"]="FILE_LIST:"
    TOKENS["pre-checker"]="PRE_CHECK_RESULT:"
    TOKENS["code-reviewer"]="ISSUE_LIST:"
    TOKENS["code-fixer"]="FIX_RESULT:"
    TOKENS["quality-checker"]="QUALITY_SCORE:"
    TOKENS["build-tester"]="BUILD_RESULT:"
    TOKENS["function-tester"]="TEST_RESULT:"
    TOKENS["git-committer"]="COMMIT_RESULT:"
    TOKENS["git-pusher"]="PUSH_RESULT:"

    for agent in "${!TOKENS[@]}"; do
        token="${TOKENS[$agent]}"
        if grep -q "$token" ".opencode/agent/${agent}.md"; then
            log_success "${agent}: ${token} 토큰 정의됨"
        else
            log_fail "${agent}: ${token} 토큰 없음"
        fi
    done
}

# =============================================================================
# 오케스트레이터 테스트
# =============================================================================

test_orchestrator() {
    log_section "5. 오케스트레이터 검증"

    MODE_FILE=".opencode/mode/code-qa.md"

    # 상태 관리 섹션 확인
    if grep -q "## 워크플로우 상태 관리" "$MODE_FILE"; then
        log_success "상태 관리 섹션 존재"
    else
        log_fail "상태 관리 섹션 없음"
    fi

    # 토큰 파싱 규칙 확인
    if grep -q "### 결과 토큰 파싱 규칙" "$MODE_FILE"; then
        log_success "토큰 파싱 규칙 존재"
    else
        log_fail "토큰 파싱 규칙 없음"
    fi

    # 에러 핸들링 섹션 확인
    if grep -q "## 에러 핸들링" "$MODE_FILE"; then
        log_success "에러 핸들링 섹션 존재"
    else
        log_fail "에러 핸들링 섹션 없음"
    fi

    # 에러 코드 정의 확인
    if grep -q "### 에러 코드 정의" "$MODE_FILE"; then
        log_success "에러 코드 정의 존재"
    else
        log_fail "에러 코드 정의 없음"
    fi

    # 설정 파일 참조 확인
    if grep -q "workflow-settings.yaml" "$MODE_FILE"; then
        log_success "설정 파일 참조 존재"
    else
        log_fail "설정 파일 참조 없음"
    fi
}

# =============================================================================
# 문서 동기화 테스트
# =============================================================================

test_documentation() {
    log_section "6. 문서 동기화 검증"

    QUICK_START="docs/guides/14-code-qa-v4-quick-start.md"

    if [ -f "$QUICK_START" ]; then
        log_success "Quick Start 문서 존재"

        # Agent Tool 권한 매트릭스 확인
        if grep -q "Agent Tool 권한 매트릭스" "$QUICK_START"; then
            log_success "  └─ Agent Tool 권한 매트릭스 존재"
        else
            log_fail "  └─ Agent Tool 권한 매트릭스 없음"
        fi

        # 결과 토큰 및 상태 관리 확인
        if grep -q "결과 토큰 및 상태 관리" "$QUICK_START"; then
            log_success "  └─ 결과 토큰 및 상태 관리 섹션 존재"
        else
            log_fail "  └─ 결과 토큰 및 상태 관리 섹션 없음"
        fi
    else
        log_fail "Quick Start 문서 없음"
    fi

    DIAGRAM="docs/guides/13-code-qa-v4-complete-diagram.md"

    if [ -f "$DIAGRAM" ]; then
        log_success "Complete Diagram 문서 존재"
    else
        log_fail "Complete Diagram 문서 없음"
    fi
}

# =============================================================================
# Git 상태 테스트
# =============================================================================

test_git_status() {
    log_section "7. Git 상태 검증"

    # Git 저장소 확인
    if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        log_success "Git 저장소 확인됨"

        # 현재 브랜치
        BRANCH=$(git branch --show-current)
        log_info "현재 브랜치: $BRANCH"

        # 변경 사항 확인
        if git diff --quiet && git diff --staged --quiet; then
            log_success "변경 사항 없음 (clean)"
        else
            CHANGED=$(git diff --name-only | wc -l)
            STAGED=$(git diff --staged --name-only | wc -l)
            log_info "변경된 파일: $CHANGED개, Staged: $STAGED개"
        fi
    else
        log_fail "Git 저장소가 아님"
    fi
}

# =============================================================================
# 종합 결과
# =============================================================================

print_summary() {
    log_section "테스트 결과 요약"

    echo ""
    echo "┌──────────────┬──────────────┐"
    echo "│ 결과         │ 개수         │"
    echo "├──────────────┼──────────────┤"
    printf "│ ${GREEN}PASSED${NC}       │ %-12s │\n" "$PASSED"
    printf "│ ${RED}FAILED${NC}       │ %-12s │\n" "$FAILED"
    printf "│ ${YELLOW}SKIPPED${NC}      │ %-12s │\n" "$SKIPPED"
    echo "├──────────────┼──────────────┤"
    printf "│ TOTAL        │ %-12s │\n" "$((PASSED + FAILED + SKIPPED))"
    echo "└──────────────┴──────────────┘"
    echo ""

    if [ $FAILED -eq 0 ]; then
        echo -e "${GREEN}✅ 모든 테스트 통과!${NC}"
        exit 0
    else
        echo -e "${RED}❌ $FAILED개의 테스트 실패${NC}"
        exit 1
    fi
}

# =============================================================================
# 메인 실행
# =============================================================================

main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║           Code QA Workflow Test Suite                        ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""

    # 프로젝트 루트로 이동
    cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

    log_info "작업 디렉토리: $(pwd)"

    # 테스트 실행
    test_config_files
    test_agent_files
    test_tool_permissions
    test_result_tokens
    test_orchestrator
    test_documentation
    test_git_status

    # 결과 출력
    print_summary
}

# 스크립트 실행
main "$@"
