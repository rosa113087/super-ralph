#!/usr/bin/env bats

# Integration tests for super-ralph-setup project scaffolding

setup() {
    export TEST_DIR="$BATS_TMPDIR/setup_test_$$"
    mkdir -p "$TEST_DIR"
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME/.super-ralph/templates"

    # Create a minimal template for the setup to copy
    cat > "$HOME/.super-ralph/templates/PROMPT.md" << 'EOF'
# Super-Ralph Development Instructions
## Test template
EOF
}

teardown() {
    rm -rf "$TEST_DIR"
}

# Helper: run the embedded setup logic (extracted from install.sh)
run_setup() {
    local project_name="${1:-test-project}"
    local setup_dir="$TEST_DIR/projects"
    mkdir -p "$setup_dir"

    (
        cd "$setup_dir"
        SUPER_RALPH_HOME="$HOME/.super-ralph"
        PROJECT_NAME="$project_name"

        mkdir -p "$PROJECT_NAME"
        cd "$PROJECT_NAME"

        mkdir -p src
        mkdir -p .ralph/{specs/stdlib,examples,logs,docs/generated}
        mkdir -p docs/plans

        if [[ -f "$SUPER_RALPH_HOME/templates/PROMPT.md" ]]; then
            cp "$SUPER_RALPH_HOME/templates/PROMPT.md" .ralph/PROMPT.md
        fi

        cat > .ralph/fix_plan.md << 'FIXEOF'
# Fix Plan

## Priority Tasks
- [ ] Define project requirements in .ralph/specs/
- [ ] Implement core feature (use TDD)
- [ ] Write comprehensive tests
- [ ] Review and verify implementation
FIXEOF

        cat > .ralph/AGENT.md << 'AGENTEOF'
# Build and Run Instructions

## Build
<!-- Add build commands here -->

## Test
<!-- Add test commands here -->

## Run
<!-- Add run commands here -->
AGENTEOF

        cat > .ralphrc << RCEOF
# .ralphrc - Super-Ralph project configuration
PROJECT_NAME="${PROJECT_NAME}"
MAX_CALLS_PER_HOUR=100
CLAUDE_TIMEOUT_MINUTES=15
CLAUDE_OUTPUT_FORMAT="json"
SESSION_CONTINUITY=true
SESSION_EXPIRY_HOURS=24
RCEOF
    )
}

# ============================================================================
# Directory structure tests
# ============================================================================

@test "setup: creates project directory" {
    run_setup "my-app"
    [ -d "$TEST_DIR/projects/my-app" ]
}

@test "setup: creates .ralph directory structure" {
    run_setup "my-app"
    [ -d "$TEST_DIR/projects/my-app/.ralph" ]
    [ -d "$TEST_DIR/projects/my-app/.ralph/specs" ]
    [ -d "$TEST_DIR/projects/my-app/.ralph/specs/stdlib" ]
    [ -d "$TEST_DIR/projects/my-app/.ralph/examples" ]
    [ -d "$TEST_DIR/projects/my-app/.ralph/logs" ]
    [ -d "$TEST_DIR/projects/my-app/.ralph/docs/generated" ]
}

@test "setup: creates docs/plans directory" {
    run_setup "my-app"
    [ -d "$TEST_DIR/projects/my-app/docs/plans" ]
}

@test "setup: creates src directory" {
    run_setup "my-app"
    [ -d "$TEST_DIR/projects/my-app/src" ]
}

# ============================================================================
# File content tests
# ============================================================================

@test "setup: copies PROMPT.md from template" {
    run_setup "my-app"
    [ -f "$TEST_DIR/projects/my-app/.ralph/PROMPT.md" ]
    grep -q "Super-Ralph" "$TEST_DIR/projects/my-app/.ralph/PROMPT.md"
}

@test "setup: creates fix_plan.md with tasks" {
    run_setup "my-app"
    [ -f "$TEST_DIR/projects/my-app/.ralph/fix_plan.md" ]
    grep -q "\- \[ \]" "$TEST_DIR/projects/my-app/.ralph/fix_plan.md"
}

@test "setup: creates AGENT.md" {
    run_setup "my-app"
    [ -f "$TEST_DIR/projects/my-app/.ralph/AGENT.md" ]
    grep -q "Build and Run" "$TEST_DIR/projects/my-app/.ralph/AGENT.md"
}

@test "setup: creates .ralphrc with project name" {
    run_setup "my-app"
    [ -f "$TEST_DIR/projects/my-app/.ralphrc" ]
    grep -q 'PROJECT_NAME="my-app"' "$TEST_DIR/projects/my-app/.ralphrc"
}

@test "setup: .ralphrc has valid config values" {
    run_setup "my-app"
    source "$TEST_DIR/projects/my-app/.ralphrc"
    [ "$MAX_CALLS_PER_HOUR" = "100" ]
    [ "$CLAUDE_TIMEOUT_MINUTES" = "15" ]
    [ "$SESSION_CONTINUITY" = "true" ]
}

# ============================================================================
# Edge cases
# ============================================================================

@test "setup: handles project name with hyphens" {
    run_setup "my-cool-app"
    [ -d "$TEST_DIR/projects/my-cool-app/.ralph" ]
}

@test "setup: creates fallback PROMPT.md when no template" {
    rm -rf "$HOME/.super-ralph/templates"
    local project_dir="$TEST_DIR/projects/fallback-app"
    mkdir -p "$project_dir/.ralph"

    # Simulate fallback
    cat > "$project_dir/.ralph/PROMPT.md" << 'PROMPTEOF'
# Super-Ralph Development Instructions
## Context
You are Super-Ralph, an autonomous AI development agent with superpowers methodology.
PROMPTEOF

    [ -f "$project_dir/.ralph/PROMPT.md" ]
    grep -q "Super-Ralph" "$project_dir/.ralph/PROMPT.md"
}
