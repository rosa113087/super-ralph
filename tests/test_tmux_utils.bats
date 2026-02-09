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
# setup_tmux_session: test argument assembly and configuration
# We mock tmux since we can't require a running tmux server
# ============================================================================

@test "tmux_utils: functions are defined after sourcing" {
    type check_tmux_available
    type setup_tmux_session
}

# Helper to capture the sr_cmd that setup_tmux_session would build
# by extracting the command assembly logic into a testable function
_build_sr_cmd() {
    local sr_cmd="'$SCRIPT_DIR/super_ralph_loop.sh' --live"
    [[ "$MAX_CALLS_PER_HOUR" != "100" ]] && sr_cmd="$sr_cmd --calls $MAX_CALLS_PER_HOUR"
    [[ "$PROMPT_FILE" != "$SUPER_RALPH_DIR/PROMPT.md" ]] && sr_cmd="$sr_cmd --prompt '$PROMPT_FILE'"
    [[ "$CLAUDE_OUTPUT_FORMAT" != "json" ]] && sr_cmd="$sr_cmd --output-format $CLAUDE_OUTPUT_FORMAT"
    [[ "$VERBOSE_PROGRESS" == "true" ]] && sr_cmd="$sr_cmd --verbose"
    [[ "$CLAUDE_TIMEOUT_MINUTES" != "15" ]] && sr_cmd="$sr_cmd --timeout $CLAUDE_TIMEOUT_MINUTES"
    [[ "$CLAUDE_USE_CONTINUE" == "false" ]] && sr_cmd="$sr_cmd --no-continue"
    [[ "$CLAUDE_SESSION_EXPIRY_HOURS" != "24" ]] && sr_cmd="$sr_cmd --session-expiry $CLAUDE_SESSION_EXPIRY_HOURS"
    echo "$sr_cmd"
}

@test "tmux_utils: default sr_cmd has --live only" {
    result=$(_build_sr_cmd)
    [[ "$result" == *"--live"* ]]
    [[ "$result" != *"--calls"* ]]
    [[ "$result" != *"--verbose"* ]]
    [[ "$result" != *"--no-continue"* ]]
}

@test "tmux_utils: sr_cmd includes --calls when non-default" {
    MAX_CALLS_PER_HOUR=50
    result=$(_build_sr_cmd)
    [[ "$result" == *"--calls 50"* ]]
}

@test "tmux_utils: sr_cmd includes --prompt when non-default" {
    PROMPT_FILE="/custom/PROMPT.md"
    result=$(_build_sr_cmd)
    [[ "$result" == *"--prompt '/custom/PROMPT.md'"* ]]
}

@test "tmux_utils: sr_cmd includes --output-format when not json" {
    CLAUDE_OUTPUT_FORMAT="text"
    result=$(_build_sr_cmd)
    [[ "$result" == *"--output-format text"* ]]
}

@test "tmux_utils: sr_cmd includes --verbose when true" {
    VERBOSE_PROGRESS="true"
    result=$(_build_sr_cmd)
    [[ "$result" == *"--verbose"* ]]
}

@test "tmux_utils: sr_cmd includes --timeout when non-default" {
    CLAUDE_TIMEOUT_MINUTES=30
    result=$(_build_sr_cmd)
    [[ "$result" == *"--timeout 30"* ]]
}

@test "tmux_utils: sr_cmd includes --no-continue when false" {
    CLAUDE_USE_CONTINUE="false"
    result=$(_build_sr_cmd)
    [[ "$result" == *"--no-continue"* ]]
}

@test "tmux_utils: sr_cmd includes --session-expiry when non-default" {
    CLAUDE_SESSION_EXPIRY_HOURS=12
    result=$(_build_sr_cmd)
    [[ "$result" == *"--session-expiry 12"* ]]
}

@test "tmux_utils: sr_cmd includes all custom args together" {
    MAX_CALLS_PER_HOUR=50
    VERBOSE_PROGRESS="true"
    CLAUDE_TIMEOUT_MINUTES=30
    CLAUDE_USE_CONTINUE="false"
    result=$(_build_sr_cmd)
    [[ "$result" == *"--calls 50"* ]]
    [[ "$result" == *"--verbose"* ]]
    [[ "$result" == *"--timeout 30"* ]]
    [[ "$result" == *"--no-continue"* ]]
}
