#!/bin/bash
# Code QA Workflow Test Script
# Tests each step of the workflow.

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test result counters
PASSED=0
FAILED=0
SKIPPED=0

# =============================================================================
# Utility Functions
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
# Config File Tests
# =============================================================================

test_config_files() {
    log_section "1. Config File Validation"

    # Check workflow-settings.yaml
    if [ -f ".opencode/config/workflow-settings.yaml" ]; then
        log_success "workflow-settings.yaml exists"
    else
        log_fail "workflow-settings.yaml missing"
    fi

    # Check permission-templates.yaml
    if [ -f ".opencode/config/permission-templates.yaml" ]; then
        log_success "permission-templates.yaml exists"
    else
        log_fail "permission-templates.yaml missing"
    fi

    # Check logging-format.md
    if [ -f ".opencode/config/logging-format.md" ]; then
        log_success "logging-format.md exists"
    else
        log_fail "logging-format.md missing"
    fi

    # Check mode/code-qa.md
    if [ -f ".opencode/mode/code-qa.md" ]; then
        log_success "mode/code-qa.md exists"
    else
        log_fail "mode/code-qa.md missing"
    fi
}

# =============================================================================
# Agent File Tests
# =============================================================================

test_agent_files() {
    log_section "2. Agent File Validation"

    AGENTS=(
        "env-setup"
        "workspace-analyzer"
        "git-input"
        "file-input"
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
            log_success "Agent: ${agent}.md exists"

            # Check tools section
            if grep -q "^tools:" ".opencode/agent/${agent}.md"; then
                log_success "  └─ tools section exists"
            else
                log_fail "  └─ tools section missing"
            fi

            # Check permission section
            if grep -q "^permission:" ".opencode/agent/${agent}.md"; then
                log_success "  └─ permission section exists"
            else
                log_fail "  └─ permission section missing"
            fi
        else
            log_fail "Agent: ${agent}.md missing"
        fi
    done
}

# =============================================================================
# Tool Permission Tests
# =============================================================================

test_tool_permissions() {
    log_section "3. Tool Permission Validation"

    # Check if code-reviewer has Read tool
    if grep -q '"Read": true' ".opencode/agent/code-reviewer.md"; then
        log_success "code-reviewer: Read tool enabled"
    else
        log_fail "code-reviewer: Read tool disabled"
    fi

    # Check if summary-reporter has Bash tool
    if grep -q '"Bash": true' ".opencode/agent/summary-reporter.md"; then
        log_success "summary-reporter: Bash tool enabled"
    else
        log_fail "summary-reporter: Bash tool disabled"
    fi

    # Check if code-fixer has Edit/Write tools
    if grep -q '"Edit": true' ".opencode/agent/code-fixer.md" && \
       grep -q '"Write": true' ".opencode/agent/code-fixer.md"; then
        log_success "code-fixer: Edit/Write tools enabled"
    else
        log_fail "code-fixer: Edit/Write tools disabled"
    fi
}

# =============================================================================
# Result Token Format Tests
# =============================================================================

test_result_tokens() {
    log_section "4. Result Token Format Validation"

    # Check if each Agent outputs result tokens
    declare -A TOKENS
    TOKENS["env-setup"]="ENV_SETUP_RESULT:"
    TOKENS["workspace-analyzer"]="WORKSPACE_ANALYSIS_RESULT:"
    TOKENS["git-input"]="FILE_LIST:"
    TOKENS["file-input"]="FILE_LIST:"
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
            log_success "${agent}: ${token} token defined"
        else
            log_fail "${agent}: ${token} token missing"
        fi
    done
}

# =============================================================================
# Orchestrator Tests
# =============================================================================

test_orchestrator() {
    log_section "5. Orchestrator Validation"

    MODE_FILE=".opencode/mode/code-qa.md"

    # Check state management section
    if grep -q "## Workflow State Management" "$MODE_FILE"; then
        log_success "State management section exists"
    else
        log_fail "State management section missing"
    fi

    # Check token parsing rules
    if grep -q "### Result Token Parsing Rules" "$MODE_FILE"; then
        log_success "Token parsing rules exist"
    else
        log_fail "Token parsing rules missing"
    fi

    # Check error handling section
    if grep -q "## Error Handling" "$MODE_FILE"; then
        log_success "Error handling section exists"
    else
        log_fail "Error handling section missing"
    fi

    # Check error code definitions
    if grep -q "### Error Code Definitions" "$MODE_FILE"; then
        log_success "Error code definitions exist"
    else
        log_fail "Error code definitions missing"
    fi

    # Check config file reference
    if grep -q "workflow-settings.yaml" "$MODE_FILE"; then
        log_success "Config file reference exists"
    else
        log_fail "Config file reference missing"
    fi
}

# =============================================================================
# Documentation Sync Tests
# =============================================================================

test_documentation() {
    log_section "6. Documentation Sync Validation"

    QUICK_START="docs/guides/14-code-qa-v4-quick-start.md"

    if [ -f "$QUICK_START" ]; then
        log_success "Quick Start document exists"

        # Check Agent Tool Permission Matrix
        if grep -q "Agent Tool" "$QUICK_START"; then
            log_success "  └─ Agent Tool Permission Matrix exists"
        else
            log_fail "  └─ Agent Tool Permission Matrix missing"
        fi

        # Check Result Token and State Management
        if grep -q "Result Token" "$QUICK_START" || grep -q "State Management" "$QUICK_START"; then
            log_success "  └─ Result Token and State Management section exists"
        else
            log_fail "  └─ Result Token and State Management section missing"
        fi
    else
        log_fail "Quick Start document missing"
    fi

    DIAGRAM="docs/guides/13-code-qa-v4-complete-diagram.md"

    if [ -f "$DIAGRAM" ]; then
        log_success "Complete Diagram document exists"
    else
        log_fail "Complete Diagram document missing"
    fi
}

# =============================================================================
# Git Status Tests
# =============================================================================

test_git_status() {
    log_section "7. Git Status Validation"

    # Check Git repository
    if git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
        log_success "Git repository confirmed"

        # Current branch
        BRANCH=$(git branch --show-current)
        log_info "Current branch: $BRANCH"

        # Check for changes
        if git diff --quiet && git diff --staged --quiet; then
            log_success "No changes (clean)"
        else
            CHANGED=$(git diff --name-only | wc -l)
            STAGED=$(git diff --staged --name-only | wc -l)
            log_info "Changed files: $CHANGED, Staged: $STAGED"
        fi
    else
        log_fail "Not a Git repository"
    fi
}

# =============================================================================
# Summary Results
# =============================================================================

print_summary() {
    log_section "Test Results Summary"

    echo ""
    echo "┌──────────────┬──────────────┐"
    echo "│ Result       │ Count        │"
    echo "├──────────────┼──────────────┤"
    printf "│ ${GREEN}PASSED${NC}       │ %-12s │\n" "$PASSED"
    printf "│ ${RED}FAILED${NC}       │ %-12s │\n" "$FAILED"
    printf "│ ${YELLOW}SKIPPED${NC}      │ %-12s │\n" "$SKIPPED"
    echo "├──────────────┼──────────────┤"
    printf "│ TOTAL        │ %-12s │\n" "$((PASSED + FAILED + SKIPPED))"
    echo "└──────────────┴──────────────┘"
    echo ""

    if [ $FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}$FAILED test(s) failed${NC}"
        exit 1
    fi
}

# =============================================================================
# Main Execution
# =============================================================================

main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║           Code QA Workflow Test Suite                        ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""

    # Navigate to project root
    cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

    log_info "Working directory: $(pwd)"

    # Run tests
    test_config_files
    test_agent_files
    test_tool_permissions
    test_result_tokens
    test_orchestrator
    test_documentation
    test_git_status

    # Print results
    print_summary
}

# Execute script
main "$@"
