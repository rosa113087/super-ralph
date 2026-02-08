#!/usr/bin/env bats

# Tests for tmux_utils.sh - TMUX Utilities Library
# Note: These tests don't require tmux to be installed (they test function behavior)

setup() {
    export TEST_DIR="$BATS_TMPDIR/tmux_test_$$"
    mkdir -p "$TEST_DIR"

    export SCRIPT_DIR="$BATS_TEST_DIRNAME/../standalone"
    export SUPER_RALPH_DIR="$TEST_DIR/.ralph"
    export LIVE_LOG_FILE="$TEST_DIR/live.log"
    export STATUS_FILE="$TEST_DIR/status.json"
    export MAX_CALLS_PER_HOUR=100
    export PROMPT_FILE="$SUPER_RALPH_DIR/PROMPT.md"
    export CLAUDE_OUTPUT_FORMAT="json"
    export VERBOSE_PROGRESS="false"
    export CLAUDE_TIMEOUT_MINUTES=15
    export CLAUDE_USE_CONTINUE="true"
    export CLAUDE_SESSION_EXPIRY_HOURS=24

    # Stub log_status
    log_status() { :; }
    export -f log_status

    source "$BATS_TEST_DIRNAME/../standalone/lib/tmux_utils.sh"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# ============================================================================
# check_tmux_available tests
# ============================================================================

@test "check_tmux_available: exits 1 when tmux not found" {
    # Use a PATH with no tmux; function exits 1 and prints install hint
    run bash -c '
        log_status() { :; }
        export -f log_status
        PATH=/nonexistent
        source "'"$BATS_TEST_DIRNAME"'/../standalone/lib/tmux_utils.sh"
        check_tmux_available
    '
    [ "$status" -eq 1 ]
    [[ "$output" == *"tmux"* ]]
}

@test "check_tmux_available: succeeds when tmux is in PATH" {
    if ! command -v tmux &>/dev/null; then
        skip "tmux not installed"
    fi
    run check_tmux_available
    [ "$status" -eq 0 ]
}

# ============================================================================
# setup_tmux_session: we can only test argument assembly logic
# since actual tmux commands require a running tmux server
# ============================================================================

@test "tmux_utils: functions are defined after sourcing" {
    type check_tmux_available
    type setup_tmux_session
}
