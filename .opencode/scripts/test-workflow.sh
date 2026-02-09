#!/bin/bash
# Code QA Workflow Test Script
# Tests each step of the workflow.
# P2-3: Fixed file references, permission validation, JSON structure checks.

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
    PASSED=$((PASSED + 1))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    FAILED=$((FAILED + 1))
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
    SKIPPED=$((SKIPPED + 1))
}

log_section() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${BLUE}$1${NC}"
    echo "═══════════════════════════════════════════════════════════════"
}

# =============================================================================
# 1. Config File Tests
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

    # Check context-schema.md (structured context passing definitions)
    if [ -f ".opencode/config/context-schema.md" ]; then
        log_success "context-schema.md exists"
    else
        log_fail "context-schema.md missing"
    fi

    # Check mode/code-qa.md
    if [ -f ".opencode/mode/code-qa.md" ]; then
        log_success "mode/code-qa.md exists"
    else
        log_fail "mode/code-qa.md missing"
    fi

    # Check command/code-qa.md
    if [ -f ".opencode/command/code-qa.md" ]; then
        log_success "command/code-qa.md exists"
    else
        log_fail "command/code-qa.md missing"
    fi
}

# =============================================================================
# 2. Agent File Tests
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

            # Check YAML frontmatter has tools section
            if grep -q "^tools:" ".opencode/agent/${agent}.md"; then
                log_success "  └─ tools section exists"
            else
                log_fail "  └─ tools section missing"
            fi

            # Check YAML frontmatter has permission section
            if grep -q "^permission:" ".opencode/agent/${agent}.md"; then
                log_success "  └─ permission section exists"
            else
                log_fail "  └─ permission section missing"
            fi

            # Check model field exists in frontmatter
            if grep -q "^model:" ".opencode/agent/${agent}.md"; then
                log_success "  └─ model field exists"
            else
                log_fail "  └─ model field missing"
            fi
        else
            log_fail "Agent: ${agent}.md missing"
        fi
    done
}

# =============================================================================
# 3. Tool Permission Tests
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
# 4. Result Token Format Tests
# =============================================================================

test_result_tokens() {
    log_section "4. Result Token Format Validation"

    # Check if each Agent outputs result tokens (parallel arrays for bash 3.x compat)
    TOKEN_AGENTS=(
        "env-setup" "workspace-analyzer" "git-input" "file-input"
        "pre-checker" "code-reviewer" "code-fixer" "quality-checker"
        "build-tester" "function-tester" "git-committer" "git-pusher"
    )
    TOKEN_VALUES=(
        "ENV_SETUP_RESULT:" "WORKSPACE_ANALYSIS_RESULT:" "FILE_LIST:" "FILE_LIST:"
        "PRE_CHECK_RESULT:" "ISSUE_LIST:" "FIX_RESULT:" "QUALITY_SCORE:"
        "BUILD_RESULT:" "TEST_RESULT:" "COMMIT_RESULT:" "PUSH_RESULT:"
    )

    for i in "${!TOKEN_AGENTS[@]}"; do
        agent="${TOKEN_AGENTS[$i]}"
        token="${TOKEN_VALUES[$i]}"
        if grep -q "$token" ".opencode/agent/${agent}.md"; then
            log_success "${agent}: ${token} token defined"
        else
            log_fail "${agent}: ${token} token missing"
        fi
    done
}

# =============================================================================
# 5. Structured JSON Output Tests (P2-3: validates JSON format requirements)
# =============================================================================

test_structured_output() {
    log_section "5. Structured JSON Output Validation"

    # Agents that MUST output structured JSON (per context-schema.md)
    JSON_AGENTS=("code-reviewer" "code-fixer" "quality-checker" "build-tester" "function-tester")
    JSON_KEYS=('"review"' '"fix"' '"quality"' '"build"' '"test"')

    for i in "${!JSON_AGENTS[@]}"; do
        agent="${JSON_AGENTS[$i]}"
        key="${JSON_KEYS[$i]}"
        if grep -q "$key" ".opencode/agent/${agent}.md"; then
            log_success "${agent}: structured JSON key ${key} documented"
        else
            log_fail "${agent}: structured JSON key ${key} not found in agent prompt"
        fi
    done

    # Check context-schema.md has schema definitions for all structured agents
    SCHEMA_FILE=".opencode/config/context-schema.md"
    if [ -f "$SCHEMA_FILE" ]; then
        for agent in "code-reviewer" "code-fixer" "quality-checker" "build-tester" "function-tester"; do
            if grep -q "$agent" "$SCHEMA_FILE"; then
                log_success "context-schema: ${agent} schema defined"
            else
                log_fail "context-schema: ${agent} schema missing"
            fi
        done

        # Check error format is defined
        if grep -q '"error"' "$SCHEMA_FILE"; then
            log_success "context-schema: explicit error format defined"
        else
            log_fail "context-schema: explicit error format missing"
        fi
    else
        log_fail "context-schema.md not found (cannot validate schemas)"
    fi
}

# =============================================================================
# 6. Model ID Validation Tests (P2-3: validates model assignment consistency)
# =============================================================================

test_model_ids() {
    log_section "6. Model ID Validation"

    SETTINGS_FILE=".opencode/config/workflow-settings.yaml"

    if [ ! -f "$SETTINGS_FILE" ]; then
        log_fail "workflow-settings.yaml missing (cannot validate model IDs)"
        return
    fi

    # Extract expected model IDs from workflow-settings.yaml
    THINKING_MODEL=$(grep "^  thinking:" "$SETTINGS_FILE" | sed 's/.*"\(.*\)"/\1/')
    CODER_MODEL=$(grep "^  coder:" "$SETTINGS_FILE" | sed 's/.*"\(.*\)"/\1/')

    if [ -n "$THINKING_MODEL" ]; then
        log_success "Thinking model defined: $THINKING_MODEL"
    else
        log_fail "Thinking model not defined in workflow-settings.yaml"
    fi

    if [ -n "$CODER_MODEL" ]; then
        log_success "Coder model defined: $CODER_MODEL"
    else
        log_fail "Coder model not defined in workflow-settings.yaml"
    fi

    # Validate Thinking agents use Thinking model
    THINKING_AGENTS=("code-reviewer" "quality-checker" "summary-reporter")
    for agent in "${THINKING_AGENTS[@]}"; do
        if [ -f ".opencode/agent/${agent}.md" ]; then
            AGENT_MODEL=$(grep "^model:" ".opencode/agent/${agent}.md" | sed 's/model: *//')
            if [ "$AGENT_MODEL" = "$THINKING_MODEL" ]; then
                log_success "${agent}: model matches Thinking ($AGENT_MODEL)"
            else
                log_fail "${agent}: model mismatch (got '$AGENT_MODEL', expected '$THINKING_MODEL')"
            fi
        fi
    done

    # Validate Coder agents use Coder model
    CODER_AGENTS=("env-setup" "git-input" "workspace-analyzer" "file-input" "pre-checker" "code-fixer" "build-tester" "function-tester" "git-committer" "git-pusher")
    for agent in "${CODER_AGENTS[@]}"; do
        if [ -f ".opencode/agent/${agent}.md" ]; then
            AGENT_MODEL=$(grep "^model:" ".opencode/agent/${agent}.md" | sed 's/model: *//')
            if [ "$AGENT_MODEL" = "$CODER_MODEL" ]; then
                log_success "${agent}: model matches Coder ($AGENT_MODEL)"
            else
                log_fail "${agent}: model mismatch (got '$AGENT_MODEL', expected '$CODER_MODEL')"
            fi
        fi
    done

    # Validate orchestrator uses Coder model (switched from Thinking for tool call stability)
    if [ -f ".opencode/mode/code-qa.md" ]; then
        ORCH_MODEL=$(grep "^model:" ".opencode/mode/code-qa.md" | sed 's/model: *//')
        if [ "$ORCH_MODEL" = "$CODER_MODEL" ]; then
            log_success "orchestrator (mode): model matches Coder ($ORCH_MODEL)"
        else
            log_fail "orchestrator (mode): model mismatch (got '$ORCH_MODEL', expected '$CODER_MODEL')"
        fi
    fi
}

# =============================================================================
# 7. Permission Template Consistency Tests (P2-3: cross-validates templates)
# =============================================================================

test_permission_templates() {
    log_section "7. Permission Template Consistency"

    TEMPLATE_FILE=".opencode/config/permission-templates.yaml"

    if [ ! -f "$TEMPLATE_FILE" ]; then
        log_fail "permission-templates.yaml missing"
        return
    fi

    # Check all QA agents are listed in agent_permissions section
    QA_AGENTS=(
        "env-setup" "workspace-analyzer" "git-input" "file-input"
        "pre-checker" "code-reviewer" "code-fixer" "quality-checker"
        "build-tester" "function-tester" "git-committer" "summary-reporter"
        "git-pusher"
    )

    for agent in "${QA_AGENTS[@]}"; do
        if grep -q "  ${agent}:" "$TEMPLATE_FILE"; then
            log_success "template: ${agent} entry exists"
        else
            log_fail "template: ${agent} entry missing from agent_permissions"
        fi
    done

    # Check required base templates exist
    BASE_TEMPLATES=("base_exploration" "file_discovery" "git_read_only" "dangerous_commands_deny")
    for tmpl in "${BASE_TEMPLATES[@]}"; do
        if grep -q "  ${tmpl}:" "$TEMPLATE_FILE"; then
            log_success "template: base '${tmpl}' exists"
        else
            log_fail "template: base '${tmpl}' missing"
        fi
    done

    # Check all agents include dangerous_commands_deny
    for agent in "${QA_AGENTS[@]}"; do
        if grep -A 20 "  ${agent}:" "$TEMPLATE_FILE" | grep -q "dangerous_commands_deny"; then
            log_success "  └─ ${agent}: includes dangerous_commands_deny"
        else
            log_fail "  └─ ${agent}: missing dangerous_commands_deny"
        fi
    done
}

# =============================================================================
# 8. Orchestrator Tests
# =============================================================================

test_orchestrator() {
    log_section "8. Orchestrator Validation"

    MODE_FILE=".opencode/mode/code-qa.md"
    CMD_FILE=".opencode/command/code-qa.md"

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

    # Check model health check section (P2-1)
    if grep -q "Model Server Health Check" "$MODE_FILE"; then
        log_success "Model health check section exists"
    else
        log_fail "Model health check section missing"
    fi

    # Check explicit cache error handling (P2-2)
    if grep -q "E004" "$MODE_FILE"; then
        log_success "Explicit error codes used in cache handling"
    else
        log_fail "Explicit error codes missing from cache handling"
    fi

    # Check fallback/degraded mode state (M1)
    if grep -q "degraded_mode" "$MODE_FILE"; then
        log_success "Fallback degraded_mode state variable defined"
    else
        log_fail "Fallback degraded_mode state variable missing"
    fi

    # Check post-fix regression validation (M4)
    if grep -q "Post-Fix Regression Validation" "$MODE_FILE"; then
        log_success "Post-fix regression validation section exists"
    else
        log_fail "Post-fix regression validation section missing"
    fi

    # Check regression timeout guard (M7)
    if grep -q "Regression Timeout" "$MODE_FILE"; then
        log_success "Regression timeout handling exists"
    else
        log_fail "Regression timeout handling missing"
    fi

    # Check catch-all error handling for unrecognized results (M5)
    if grep -q "Catch-all for unrecognized results" "$MODE_FILE"; then
        log_success "Catch-all error handling exists"
    else
        log_fail "Catch-all error handling missing"
    fi

    # Check command/code-qa.md is thin wrapper pointing to mode/code-qa.md
    if [ -f "$CMD_FILE" ]; then
        if grep -q "subtask: true" "$CMD_FILE"; then
            log_success "cmd: subtask flag set (thin wrapper)"
        else
            log_fail "cmd: subtask flag missing"
        fi

        if grep -q "mode/code-qa" "$CMD_FILE"; then
            log_success "cmd: references mode/code-qa (single source of truth)"
        else
            log_fail "cmd: missing reference to mode/code-qa"
        fi

        # Validate model matches orchestrator
        CMD_MODEL=$(grep "^model:" "$CMD_FILE" | sed 's/model: *//')
        ORCH_MODEL=$(grep "^model:" "$MODE_FILE" | sed 's/model: *//')
        if [ "$CMD_MODEL" = "$ORCH_MODEL" ]; then
            log_success "cmd: model matches orchestrator ($CMD_MODEL)"
        else
            log_fail "cmd: model mismatch (cmd='$CMD_MODEL', mode='$ORCH_MODEL')"
        fi
    else
        log_fail "command/code-qa.md not found"
    fi
}

# =============================================================================
# 8b. Context Schema Completeness Tests
# =============================================================================

test_context_schema_completeness() {
    log_section "8b. Context Schema Completeness"

    SCHEMA_FILE=".opencode/config/context-schema.md"

    if [ ! -f "$SCHEMA_FILE" ]; then
        log_fail "context-schema.md missing"
        return
    fi

    # All agents that should have schemas
    SCHEMA_AGENTS=(
        "env-setup" "workspace-analyzer" "git-input" "pre-checker"
        "code-reviewer" "code-fixer" "quality-checker"
        "build-tester" "function-tester" "git-committer" "git-pusher"
    )

    for agent in "${SCHEMA_AGENTS[@]}"; do
        if grep -qi "$agent" "$SCHEMA_FILE"; then
            log_success "schema: ${agent} output schema defined"
        else
            log_fail "schema: ${agent} output schema missing"
        fi
    done

    # Check regression history schema
    if grep -q "Regression History" "$SCHEMA_FILE"; then
        log_success "schema: regression history schema defined"
    else
        log_fail "schema: regression history schema missing"
    fi

    # Check context store reference
    if grep -q "context_store" "$SCHEMA_FILE" || grep -q "Context Store" "$SCHEMA_FILE"; then
        log_success "schema: context store documented"
    else
        log_fail "schema: context store not documented"
    fi

    # Check single source of truth note
    if grep -q "Single Source of Truth" "$SCHEMA_FILE" || grep -q "authoritative" "$SCHEMA_FILE"; then
        log_success "schema: model assignment single-source-of-truth note exists"
    else
        log_fail "schema: model assignment single-source-of-truth note missing"
    fi

    # Check workflow-settings timeout_guard config
    SETTINGS_FILE=".opencode/config/workflow-settings.yaml"
    if [ -f "$SETTINGS_FILE" ]; then
        if grep -q "timeout_guard" "$SETTINGS_FILE"; then
            log_success "settings: regression timeout_guard configured"
        else
            log_fail "settings: regression timeout_guard missing"
        fi
    fi
}

# =============================================================================
# 9. Documentation Sync Tests
# =============================================================================

test_documentation() {
    log_section "9. Documentation Sync Validation"

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

        # Check per-source retry counter documentation (P0 sync)
        if grep -q "retry_counters" "$QUICK_START" || grep -q "per_source" "$QUICK_START"; then
            log_success "  └─ Per-source retry counters documented"
        else
            log_fail "  └─ Per-source retry counters not documented (outdated?)"
        fi

        # Check context_store documentation (P0 sync)
        if grep -q "context_store" "$QUICK_START"; then
            log_success "  └─ Structured context store documented"
        else
            log_fail "  └─ Structured context store not documented (outdated?)"
        fi
    else
        log_fail "Quick Start document missing"
    fi

    DIAGRAM="docs/guides/13-code-qa-v4-complete-diagram.md"

    if [ -f "$DIAGRAM" ]; then
        log_success "Complete Diagram document exists"
    else
        log_skip "Complete Diagram document missing (optional)"
    fi
}

# =============================================================================
# 10. Workspace Cache & ENV_STATE Tests
# =============================================================================

test_workspace_cache() {
    log_section "10. Workspace Cache & ENV_STATE Validation"

    # Check workspace-cache directory exists or can be created
    if [ -d ".opencode/workspace-cache" ]; then
        log_success "workspace-cache directory exists"
    else
        # Try creating it (orchestrator does mkdir -p)
        mkdir -p .opencode/workspace-cache 2>/dev/null
        if [ -d ".opencode/workspace-cache" ]; then
            log_success "workspace-cache directory created successfully"
            rmdir .opencode/workspace-cache 2>/dev/null
        else
            log_fail "workspace-cache directory cannot be created"
        fi
    fi

    # Check .opencode/ is in filter.exclude
    if grep -q '".opencode/"' ".opencode/config/workflow-settings.yaml" 2>/dev/null || \
       grep -q "\.opencode/" ".opencode/config/workflow-settings.yaml" 2>/dev/null; then
        log_success ".opencode/ in filter.exclude (cache is ephemeral)"
    else
        log_fail ".opencode/ not in filter.exclude"
    fi

    # Validate ENV_STATE fields in build-tester
    if grep -q "ENV_STATE is missing or incomplete" ".opencode/agent/build-tester.md" 2>/dev/null; then
        log_success "build-tester: ENV_STATE fallback documented"
    else
        log_fail "build-tester: ENV_STATE fallback missing"
    fi

    # Validate ENV_STATE fields in function-tester
    if grep -q "ENV_STATE is missing or incomplete" ".opencode/agent/function-tester.md" 2>/dev/null; then
        log_success "function-tester: ENV_STATE fallback documented"
    else
        log_fail "function-tester: ENV_STATE fallback missing"
    fi

    # Validate regression counter config in workflow-settings
    SETTINGS_FILE=".opencode/config/workflow-settings.yaml"
    if [ -f "$SETTINGS_FILE" ]; then
        if grep -q "per_source_max:" "$SETTINGS_FILE" && grep -q "total_cap:" "$SETTINGS_FILE"; then
            log_success "Regression counters configured (per_source_max + total_cap)"
        else
            log_fail "Regression counter config incomplete"
        fi
    fi
}

# =============================================================================
# 11. Git Status Tests
# =============================================================================

test_git_status() {
    log_section "10. Git Status Validation"

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
    echo "║           Code QA Workflow Test Suite v3                     ║"
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
    test_structured_output
    test_model_ids
    test_permission_templates
    test_orchestrator
    test_context_schema_completeness
    test_documentation
    test_workspace_cache
    test_git_status

    # Print results
    print_summary
}

# Execute script
main "$@"
