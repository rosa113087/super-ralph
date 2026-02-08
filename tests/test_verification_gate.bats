#!/usr/bin/env bats

# Tests for verification_gate.sh - Verification Before Completion Gate

setup() {
    export SUPER_RALPH_DIR="$BATS_TMPDIR/ralph_test_$$"
    mkdir -p "$SUPER_RALPH_DIR"
    source "$BATS_TEST_DIRNAME/../standalone/lib/verification_gate.sh"
}

teardown() {
    rm -rf "$SUPER_RALPH_DIR"
}

# Helper to create an output file with given content
create_output() {
    local file="$SUPER_RALPH_DIR/test_output.log"
    echo "$1" > "$file"
    echo "$file"
}

# ============================================================================
# check_verification tests
# ============================================================================

@test "check_verification: passes when no file" {
    run check_verification "/nonexistent/file"
    [ "$status" -eq 0 ]
}

@test "check_verification: passes with verified claims" {
    local file
    file=$(create_output "Ran the test suite: 42 tests passed. Exit code 0. All good.")
    run check_verification "$file"
    [ "$status" -eq 0 ]
}

@test "check_verification: passes with no claims at all" {
    local file
    file=$(create_output "Implementing the database connection module")
    run check_verification "$file"
    [ "$status" -eq 0 ]
}

@test "check_verification: fails with 'should pass' and no evidence" {
    local file
    file=$(create_output "The tests should pass now after my changes")
    run check_verification "$file"
    [ "$status" -eq 1 ]
}

@test "check_verification: fails with 'probably works' and no evidence" {
    local file
    file=$(create_output "This probably works correctly now")
    run check_verification "$file"
    [ "$status" -eq 1 ]
}

@test "check_verification: fails with 'looks correct' and no evidence" {
    local file
    file=$(create_output "The implementation looks correct to me")
    run check_verification "$file"
    [ "$status" -eq 1 ]
}

@test "check_verification: fails with 'seems to work' and no evidence" {
    local file
    file=$(create_output "It seems to work fine now")
    run check_verification "$file"
    [ "$status" -eq 1 ]
}

@test "check_verification: fails with 'I'm confident' and no evidence" {
    local file
    file=$(create_output "I'm confident this fixes the issue")
    run check_verification "$file"
    [ "$status" -eq 1 ]
}

@test "check_verification: passes when unverified claim has evidence too" {
    local file
    file=$(create_output "The tests should pass now. Ran test suite: 15 tests passed with exit code 0")
    run check_verification "$file"
    [ "$status" -eq 0 ]
}

@test "check_verification: passes with '0 failures' evidence" {
    local file
    file=$(create_output "Build completed: 0 failures, 0 errors")
    run check_verification "$file"
    [ "$status" -eq 0 ]
}

@test "check_verification: passes with 'build success' evidence" {
    local file
    file=$(create_output "Build successful! All modules compiled.")
    run check_verification "$file"
    [ "$status" -eq 0 ]
}

@test "check_verification: detects 'that should fix' as unverified" {
    local file
    file=$(create_output "That should fix the problem")
    run check_verification "$file"
    [ "$status" -eq 1 ]
}

# ============================================================================
# analyze_verification_status tests
# ============================================================================

@test "analyze_verification_status: creates report for verified output" {
    local file
    file=$(create_output "All 25 tests passed. Build exit 0.")
    analyze_verification_status "$file"

    [ -f "$SUPER_RALPH_DIR/.verification_status" ]

    local verified
    verified=$(jq -r '.verified' "$SUPER_RALPH_DIR/.verification_status")
    [ "$verified" = "true" ]
}

@test "analyze_verification_status: creates report for unverified output" {
    local file
    file=$(create_output "This should work and looks correct")
    analyze_verification_status "$file"

    [ -f "$SUPER_RALPH_DIR/.verification_status" ]

    local verified
    verified=$(jq -r '.verified' "$SUPER_RALPH_DIR/.verification_status")
    [ "$verified" = "false" ]

    local claims
    claims=$(jq -r '.unverified_claims' "$SUPER_RALPH_DIR/.verification_status")
    [ "$claims" -gt 0 ]
}

@test "analyze_verification_status: creates default report for missing file" {
    analyze_verification_status "/nonexistent/file"

    [ -f "$SUPER_RALPH_DIR/.verification_status" ]

    local verified
    verified=$(jq -r '.verified' "$SUPER_RALPH_DIR/.verification_status")
    [ "$verified" = "true" ]
}

# ============================================================================
# get_verification_enforcement_context tests
# ============================================================================

@test "get_verification_enforcement_context: returns enforcement text" {
    result=$(get_verification_enforcement_context)
    [[ "$result" == *"MANDATORY"* ]]
    [[ "$result" == *"verification"* ]]
}

# ============================================================================
# validate_exit_signal tests
# ============================================================================

@test "validate_exit_signal: returns false when no analysis file" {
    result=$(validate_exit_signal "/nonexistent/file" || true)
    [ "$result" = "false" ]
}

@test "validate_exit_signal: returns false when exit_signal is false" {
    echo '{"analysis": {"exit_signal": false}}' > "$SUPER_RALPH_DIR/.response_analysis"
    result=$(validate_exit_signal "$SUPER_RALPH_DIR/.response_analysis" || true)
    [ "$result" = "false" ]
}

@test "validate_exit_signal: returns true when exit_signal true and verified" {
    local output_file
    output_file=$(create_output "All 10 tests passed. Exit code 0.")
    jq -n --arg f "$output_file" '{"analysis": {"exit_signal": true}, "output_file": $f}' > "$SUPER_RALPH_DIR/.response_analysis"
    result=$(validate_exit_signal "$SUPER_RALPH_DIR/.response_analysis")
    [ "$result" = "true" ]
}

@test "validate_exit_signal: returns false when exit_signal true but unverified" {
    local output_file
    output_file=$(create_output "This should work now, I think it's done")
    jq -n --arg f "$output_file" '{"analysis": {"exit_signal": true}, "output_file": $f}' > "$SUPER_RALPH_DIR/.response_analysis"
    result=$(validate_exit_signal "$SUPER_RALPH_DIR/.response_analysis" || true)
    [ "$result" = "false" ]
}
