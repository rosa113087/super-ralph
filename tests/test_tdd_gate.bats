#!/usr/bin/env bats

# Tests for tdd_gate.sh - TDD Enforcement Gate

setup() {
    export SUPER_RALPH_DIR="$BATS_TMPDIR/ralph_test_$$"
    mkdir -p "$SUPER_RALPH_DIR"
    source "$BATS_TEST_DIRNAME/../standalone/lib/tdd_gate.sh"
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
# check_tdd_compliance tests
# ============================================================================

@test "check_tdd_compliance: passes when no output file" {
    run check_tdd_compliance "/nonexistent/file"
    [ "$status" -eq 0 ]
}

@test "check_tdd_compliance: passes with RED phase indicators" {
    local file
    file=$(create_output "I'll write a failing test first to verify the behavior")
    run check_tdd_compliance "$file"
    [ "$status" -eq 0 ]
}

@test "check_tdd_compliance: passes with GREEN phase indicators" {
    local file
    file=$(create_output "All tests pass now. Moving to refactor phase.")
    run check_tdd_compliance "$file"
    [ "$status" -eq 0 ]
}

@test "check_tdd_compliance: fails with violation - skip test" {
    local file
    file=$(create_output "Let's skip testing for this simple change")
    run check_tdd_compliance "$file"
    [ "$status" -eq 1 ]
}

@test "check_tdd_compliance: fails with violation - implement first" {
    local file
    file=$(create_output "I'll implement first then test it afterwards")
    run check_tdd_compliance "$file"
    [ "$status" -eq 1 ]
}

@test "check_tdd_compliance: fails with violation - no test needed" {
    local file
    file=$(create_output "This is so simple, no test needed for it")
    run check_tdd_compliance "$file"
    [ "$status" -eq 1 ]
}

@test "check_tdd_compliance: fails with violation - test later" {
    local file
    file=$(create_output "We can add testing later when we have time")
    run check_tdd_compliance "$file"
    [ "$status" -eq 1 ]
}

@test "check_tdd_compliance: fails with violation - too simple to test" {
    local file
    file=$(create_output "This is too simple for a test case")
    run check_tdd_compliance "$file"
    [ "$status" -eq 1 ]
}

@test "check_tdd_compliance: passes with neutral content" {
    local file
    file=$(create_output "Implementing the database connection pool")
    run check_tdd_compliance "$file"
    [ "$status" -eq 0 ]
}

@test "check_tdd_compliance: fails with violation - without tests" {
    local file
    file=$(create_output "I'll just implement this without tests")
    run check_tdd_compliance "$file"
    [ "$status" -eq 1 ]
}

# ============================================================================
# analyze_tdd_status tests
# ============================================================================

@test "analyze_tdd_status: creates compliance report for clean output" {
    local file
    file=$(create_output "Writing a failing test first for the new feature")
    analyze_tdd_status "$file"

    [ -f "$SUPER_RALPH_DIR/.tdd_compliance" ]

    local compliant
    compliant=$(jq -r '.compliant' "$SUPER_RALPH_DIR/.tdd_compliance")
    [ "$compliant" = "true" ]

    local red
    red=$(jq -r '.red_indicators' "$SUPER_RALPH_DIR/.tdd_compliance")
    [ "$red" -gt 0 ]
}

@test "analyze_tdd_status: creates compliance report for violation" {
    local file
    file=$(create_output "Let me skip testing and implement first then test later")
    analyze_tdd_status "$file"

    [ -f "$SUPER_RALPH_DIR/.tdd_compliance" ]

    local compliant
    compliant=$(jq -r '.compliant' "$SUPER_RALPH_DIR/.tdd_compliance")
    [ "$compliant" = "false" ]

    local violations
    violations=$(jq -r '.violations' "$SUPER_RALPH_DIR/.tdd_compliance")
    [ "$violations" -gt 0 ]
}

@test "analyze_tdd_status: creates empty report for missing file" {
    analyze_tdd_status "/nonexistent/file"

    [ -f "$SUPER_RALPH_DIR/.tdd_compliance" ]

    local compliant
    compliant=$(jq -r '.compliant' "$SUPER_RALPH_DIR/.tdd_compliance")
    [ "$compliant" = "true" ]
}

@test "analyze_tdd_status: counts both RED and GREEN indicators" {
    local file
    file=$(create_output "Writing test first. Watch it fail. Then minimal code to make tests pass. All tests passing now.")
    analyze_tdd_status "$file"

    local red
    red=$(jq -r '.red_indicators' "$SUPER_RALPH_DIR/.tdd_compliance")
    [ "$red" -gt 0 ]

    local green
    green=$(jq -r '.green_indicators' "$SUPER_RALPH_DIR/.tdd_compliance")
    [ "$green" -gt 0 ]
}

# ============================================================================
# get_tdd_enforcement_context tests
# ============================================================================

@test "get_tdd_enforcement_context: returns enforcement text" {
    result=$(get_tdd_enforcement_context)
    [[ "$result" == *"MANDATORY"* ]]
    [[ "$result" == *"TDD"* ]]
    [[ "$result" == *"failing test"* ]]
}
