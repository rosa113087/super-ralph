#!/usr/bin/env bats

# Tests for exit_detector.sh - Exit detection and config validation

setup() {
    export TEST_DIR="$BATS_TMPDIR/exit_det_test_$$"
    mkdir -p "$TEST_DIR"

    export SUPER_RALPH_DIR="$TEST_DIR/.ralph"
    mkdir -p "$SUPER_RALPH_DIR"

    export EXIT_SIGNALS_FILE="$SUPER_RALPH_DIR/.exit_signals"
    export RESPONSE_ANALYSIS_FILE="$SUPER_RALPH_DIR/.response_analysis"

    export MAX_CONSECUTIVE_TEST_LOOPS=3
    export MAX_CONSECUTIVE_DONE_SIGNALS=2
    export MAX_CALLS_PER_HOUR=100
    export CLAUDE_TIMEOUT_MINUTES=15
    export CLAUDE_OUTPUT_FORMAT="json"
    export CLAUDE_SESSION_EXPIRY_HOURS=24
    export MAX_CONSECUTIVE_TEST_LOOPS=3
    export MAX_CONSECUTIVE_DONE_SIGNALS=2

    # Stub functions
    log_status() { :; }
    export -f log_status
    all_tasks_complete() { return 1; }
    export -f all_tasks_complete
    validate_exit_signal() { echo "false"; }
    export -f validate_exit_signal

    source "$BATS_TEST_DIRNAME/../standalone/lib/exit_detector.sh"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# ============================================================================
# should_exit_gracefully tests
# ============================================================================

@test "exit_detector: returns empty when no exit signals file" {
    rm -f "$EXIT_SIGNALS_FILE"
    result=$(should_exit_gracefully)
    [ -z "$result" ]
}

@test "exit_detector: returns empty with zero-length arrays" {
    echo '{"test_only_loops": [], "done_signals": [], "completion_indicators": []}' > "$EXIT_SIGNALS_FILE"
    result=$(should_exit_gracefully)
    [ -z "$result" ]
}

@test "exit_detector: detects test_saturation at threshold" {
    echo '{"test_only_loops": [1,2,3], "done_signals": [], "completion_indicators": []}' > "$EXIT_SIGNALS_FILE"
    result=$(should_exit_gracefully)
    [ "$result" = "test_saturation" ]
}

@test "exit_detector: detects test_saturation above threshold" {
    echo '{"test_only_loops": [1,2,3,4,5], "done_signals": [], "completion_indicators": []}' > "$EXIT_SIGNALS_FILE"
    result=$(should_exit_gracefully)
    [ "$result" = "test_saturation" ]
}

@test "exit_detector: no test_saturation below threshold" {
    echo '{"test_only_loops": [1,2], "done_signals": [], "completion_indicators": []}' > "$EXIT_SIGNALS_FILE"
    result=$(should_exit_gracefully)
    [ -z "$result" ]
}

@test "exit_detector: detects completion_signals at threshold" {
    echo '{"test_only_loops": [], "done_signals": [1,2], "completion_indicators": []}' > "$EXIT_SIGNALS_FILE"
    result=$(should_exit_gracefully)
    [ "$result" = "completion_signals" ]
}

@test "exit_detector: detects completion_signals above threshold" {
    echo '{"test_only_loops": [], "done_signals": [1,2,3], "completion_indicators": []}' > "$EXIT_SIGNALS_FILE"
    result=$(should_exit_gracefully)
    [ "$result" = "completion_signals" ]
}

@test "exit_detector: no completion_signals below threshold" {
    echo '{"test_only_loops": [], "done_signals": [1], "completion_indicators": []}' > "$EXIT_SIGNALS_FILE"
    result=$(should_exit_gracefully)
    [ -z "$result" ]
}

@test "exit_detector: detects safety_circuit_breaker at 5 indicators" {
    echo '{"test_only_loops": [], "done_signals": [], "completion_indicators": [1,2,3,4,5]}' > "$EXIT_SIGNALS_FILE"
    result=$(should_exit_gracefully)
    [ "$result" = "safety_circuit_breaker" ]
}

@test "exit_detector: no circuit breaker below 5 indicators" {
    echo '{"test_only_loops": [], "done_signals": [], "completion_indicators": [1,2,3,4]}' > "$EXIT_SIGNALS_FILE"
    result=$(should_exit_gracefully)
    [ -z "$result" ]
}

@test "exit_detector: detects permission_denied" {
    echo '{"test_only_loops": [], "done_signals": [], "completion_indicators": []}' > "$EXIT_SIGNALS_FILE"
    echo '{"analysis": {"has_permission_denials": true, "denied_commands": ["git push"]}}' > "$RESPONSE_ANALYSIS_FILE"
    result=$(should_exit_gracefully)
    [ "$result" = "permission_denied" ]
}

@test "exit_detector: no permission_denied when false" {
    echo '{"test_only_loops": [], "done_signals": [], "completion_indicators": []}' > "$EXIT_SIGNALS_FILE"
    echo '{"analysis": {"has_permission_denials": false}}' > "$RESPONSE_ANALYSIS_FILE"
    result=$(should_exit_gracefully)
    [ -z "$result" ]
}

@test "exit_detector: permission_denied takes priority over test_saturation" {
    echo '{"test_only_loops": [1,2,3], "done_signals": [], "completion_indicators": []}' > "$EXIT_SIGNALS_FILE"
    echo '{"analysis": {"has_permission_denials": true, "denied_commands": ["sudo rm"]}}' > "$RESPONSE_ANALYSIS_FILE"
    result=$(should_exit_gracefully)
    [ "$result" = "permission_denied" ]
}

@test "exit_detector: detects project_complete with 2+ indicators and exit signal" {
    echo '{"test_only_loops": [], "done_signals": [], "completion_indicators": [1,2]}' > "$EXIT_SIGNALS_FILE"
    echo '{"analysis": {"exit_signal": true}}' > "$RESPONSE_ANALYSIS_FILE"
    result=$(should_exit_gracefully)
    [ "$result" = "project_complete" ]
}

@test "exit_detector: no project_complete with only 1 indicator and exit signal" {
    echo '{"test_only_loops": [], "done_signals": [], "completion_indicators": [1]}' > "$EXIT_SIGNALS_FILE"
    echo '{"analysis": {"exit_signal": true}}' > "$RESPONSE_ANALYSIS_FILE"
    result=$(should_exit_gracefully)
    [ -z "$result" ]
}

@test "exit_detector: detects plan_complete when all tasks done" {
    all_tasks_complete() { return 0; }
    export -f all_tasks_complete

    echo '{"test_only_loops": [], "done_signals": [], "completion_indicators": []}' > "$EXIT_SIGNALS_FILE"
    result=$(should_exit_gracefully)
    [ "$result" = "plan_complete" ]
}

@test "exit_detector: detects project_complete_verified when all tasks done and verified" {
    all_tasks_complete() { return 0; }
    export -f all_tasks_complete
    validate_exit_signal() { echo "true"; }
    export -f validate_exit_signal

    echo '{"test_only_loops": [], "done_signals": [], "completion_indicators": []}' > "$EXIT_SIGNALS_FILE"
    echo '{"analysis": {"exit_signal": true}}' > "$RESPONSE_ANALYSIS_FILE"
    result=$(should_exit_gracefully)
    [ "$result" = "project_complete_verified" ]
}

@test "exit_detector: falls back to plan_complete when verification fails" {
    all_tasks_complete() { return 0; }
    export -f all_tasks_complete
    validate_exit_signal() { echo "false"; }
    export -f validate_exit_signal

    echo '{"test_only_loops": [], "done_signals": [], "completion_indicators": []}' > "$EXIT_SIGNALS_FILE"
    echo '{"analysis": {"exit_signal": true}}' > "$RESPONSE_ANALYSIS_FILE"
    result=$(should_exit_gracefully)
    [ "$result" = "plan_complete" ]
}

@test "exit_detector: handles malformed JSON in signals file" {
    echo 'not json' > "$EXIT_SIGNALS_FILE"
    result=$(should_exit_gracefully)
    # jq fails, falls back to "0" for all counters, returns empty
    [ -z "$result" ]
}

@test "exit_detector: handles missing analysis file gracefully" {
    echo '{"test_only_loops": [], "done_signals": [], "completion_indicators": []}' > "$EXIT_SIGNALS_FILE"
    rm -f "$RESPONSE_ANALYSIS_FILE"
    result=$(should_exit_gracefully)
    [ -z "$result" ]
}

@test "exit_detector: handles malformed analysis JSON" {
    echo '{"test_only_loops": [], "done_signals": [], "completion_indicators": []}' > "$EXIT_SIGNALS_FILE"
    echo 'not json' > "$RESPONSE_ANALYSIS_FILE"
    result=$(should_exit_gracefully)
    [ -z "$result" ]
}

# ============================================================================
# validate_ralphrc tests
# ============================================================================

@test "validate_ralphrc: accepts all valid defaults" {
    run validate_ralphrc
    [ "$status" -eq 0 ]
}

@test "validate_ralphrc: rejects zero MAX_CALLS_PER_HOUR" {
    MAX_CALLS_PER_HOUR=0
    run validate_ralphrc
    [ "$status" -eq 1 ]
    [[ "$output" == *"MAX_CALLS_PER_HOUR"* ]]
}

@test "validate_ralphrc: rejects negative MAX_CALLS_PER_HOUR" {
    MAX_CALLS_PER_HOUR="-5"
    run validate_ralphrc
    [ "$status" -eq 1 ]
}

@test "validate_ralphrc: rejects non-numeric MAX_CALLS_PER_HOUR" {
    MAX_CALLS_PER_HOUR="abc"
    run validate_ralphrc
    [ "$status" -eq 1 ]
}

@test "validate_ralphrc: rejects zero CLAUDE_TIMEOUT_MINUTES" {
    CLAUDE_TIMEOUT_MINUTES=0
    run validate_ralphrc
    [ "$status" -eq 1 ]
}

@test "validate_ralphrc: rejects float CLAUDE_TIMEOUT_MINUTES" {
    CLAUDE_TIMEOUT_MINUTES="3.5"
    run validate_ralphrc
    [ "$status" -eq 1 ]
}

@test "validate_ralphrc: accepts json output format" {
    CLAUDE_OUTPUT_FORMAT="json"
    run validate_ralphrc
    [ "$status" -eq 0 ]
}

@test "validate_ralphrc: accepts text output format" {
    CLAUDE_OUTPUT_FORMAT="text"
    run validate_ralphrc
    [ "$status" -eq 0 ]
}

@test "validate_ralphrc: rejects xml output format" {
    CLAUDE_OUTPUT_FORMAT="xml"
    run validate_ralphrc
    [ "$status" -eq 1 ]
    [[ "$output" == *"CLAUDE_OUTPUT_FORMAT"* ]]
}

@test "validate_ralphrc: rejects zero CLAUDE_SESSION_EXPIRY_HOURS" {
    CLAUDE_SESSION_EXPIRY_HOURS=0
    run validate_ralphrc
    [ "$status" -eq 1 ]
}

@test "validate_ralphrc: rejects non-numeric MAX_CONSECUTIVE_TEST_LOOPS" {
    MAX_CONSECUTIVE_TEST_LOOPS="abc"
    run validate_ralphrc
    [ "$status" -eq 1 ]
}

@test "validate_ralphrc: rejects non-numeric MAX_CONSECUTIVE_DONE_SIGNALS" {
    MAX_CONSECUTIVE_DONE_SIGNALS="xyz"
    run validate_ralphrc
    [ "$status" -eq 1 ]
}

@test "validate_ralphrc: reports multiple errors at once" {
    MAX_CALLS_PER_HOUR="abc"
    CLAUDE_TIMEOUT_MINUTES="xyz"
    CLAUDE_OUTPUT_FORMAT="xml"
    run validate_ralphrc
    [ "$status" -eq 1 ]
    [[ "$output" == *"MAX_CALLS_PER_HOUR"* ]]
    [[ "$output" == *"CLAUDE_TIMEOUT_MINUTES"* ]]
    [[ "$output" == *"CLAUDE_OUTPUT_FORMAT"* ]]
}

@test "validate_ralphrc: accepts large valid MAX_CALLS_PER_HOUR" {
    MAX_CALLS_PER_HOUR=9999
    run validate_ralphrc
    [ "$status" -eq 0 ]
}

@test "validate_ralphrc: allows empty optional values (no validation)" {
    MAX_CALLS_PER_HOUR=""
    CLAUDE_TIMEOUT_MINUTES=""
    CLAUDE_OUTPUT_FORMAT=""
    CLAUDE_SESSION_EXPIRY_HOURS=""
    MAX_CONSECUTIVE_TEST_LOOPS=""
    MAX_CONSECUTIVE_DONE_SIGNALS=""
    run validate_ralphrc
    [ "$status" -eq 0 ]
}
