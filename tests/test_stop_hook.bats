#!/usr/bin/env bats

# Tests for stop-hook.sh - Ralph Loop Stop Hook
# Tests the self-referential loop controller behavior

HOOK_SCRIPT="$BATS_TEST_DIRNAME/../plugins/super-ralph/hooks/stop-hook.sh"

setup() {
    export TEST_DIR="$BATS_TMPDIR/stop_hook_test_$$"
    mkdir -p "$TEST_DIR/.claude"
    cd "$TEST_DIR"
}

teardown() {
    cd /
    rm -rf "$TEST_DIR"
}

# Helper to create a state file with frontmatter
create_state_file() {
    local iteration="${1:-1}"
    local max_iterations="${2:-0}"
    local completion_promise="${3:-null}"
    local prompt="${4:-Do the work}"

    cat > "$TEST_DIR/.claude/super-ralph-loop.local.md" << EOF
---
iteration: $iteration
max_iterations: $max_iterations
completion_promise: $completion_promise
---
$prompt
EOF
}

# Helper to create a minimal transcript JSONL file
create_transcript() {
    local text="${1:-I completed the work}"
    local transcript_file="$TEST_DIR/transcript.jsonl"

    # Write a minimal assistant message in JSONL format
    echo '{"role":"user","message":{"content":[{"type":"text","text":"Do the work"}]}}' > "$transcript_file"
    printf '{"role":"assistant","message":{"content":[{"type":"text","text":"%s"}]}}\n' "$text" >> "$transcript_file"

    echo "$transcript_file"
}

# Helper to create hook input JSON
create_hook_input() {
    local transcript_path="${1:-$TEST_DIR/transcript.jsonl}"
    echo "{\"transcript_path\": \"$transcript_path\"}"
}

# ============================================================================
# Exit behavior tests
# ============================================================================

@test "stop-hook: exits 0 (allows exit) when no state file" {
    local hook_input
    hook_input=$(create_hook_input)
    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]
    # No JSON output means exit was allowed
    ! echo "$output" | jq -e '.decision' 2>/dev/null
}

@test "stop-hook: blocks exit when state file present" {
    create_state_file 1 0
    local transcript
    transcript=$(create_transcript "Working on it")
    local hook_input
    hook_input=$(create_hook_input "$transcript")

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    # Should output JSON with decision: block
    local decision
    decision=$(echo "$output" | jq -r '.decision' 2>/dev/null)
    [ "$decision" = "block" ]
}

@test "stop-hook: increments iteration counter" {
    create_state_file 3 0
    local transcript
    transcript=$(create_transcript "Working on it")
    local hook_input
    hook_input=$(create_hook_input "$transcript")

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    # Check the state file was updated
    local new_iteration
    new_iteration=$(grep '^iteration:' "$TEST_DIR/.claude/super-ralph-loop.local.md" | sed 's/iteration: *//')
    [ "$new_iteration" = "4" ]
}

@test "stop-hook: allows exit at max iterations" {
    create_state_file 5 5
    local transcript
    transcript=$(create_transcript "Done")
    local hook_input
    hook_input=$(create_hook_input "$transcript")

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    # Should NOT output block decision (max reached)
    if echo "$output" | jq -e '.decision' 2>/dev/null; then
        local decision
        decision=$(echo "$output" | jq -r '.decision' 2>/dev/null)
        [ "$decision" != "block" ]
    fi

    # State file should be removed
    [ ! -f "$TEST_DIR/.claude/super-ralph-loop.local.md" ]
}

@test "stop-hook: continues when iteration < max_iterations" {
    create_state_file 3 10
    local transcript
    transcript=$(create_transcript "Continuing work")
    local hook_input
    hook_input=$(create_hook_input "$transcript")

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    local decision
    decision=$(echo "$output" | jq -r '.decision' 2>/dev/null)
    [ "$decision" = "block" ]
}

# ============================================================================
# Completion promise tests
# ============================================================================

@test "stop-hook: stops when completion promise matches" {
    create_state_file 1 0 "All tests pass"
    local transcript
    transcript=$(create_transcript "I've verified: <promise>All tests pass</promise>")
    local hook_input
    hook_input=$(create_hook_input "$transcript")

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    # State file should be removed (promise matched)
    [ ! -f "$TEST_DIR/.claude/super-ralph-loop.local.md" ]
}

@test "stop-hook: continues when promise doesn't match" {
    create_state_file 1 0 "All tests pass"
    local transcript
    transcript=$(create_transcript "I think tests might pass")
    local hook_input
    hook_input=$(create_hook_input "$transcript")

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    local decision
    decision=$(echo "$output" | jq -r '.decision' 2>/dev/null)
    [ "$decision" = "block" ]
}

@test "stop-hook: continues with max_iterations=0 (infinite)" {
    create_state_file 100 0
    local transcript
    transcript=$(create_transcript "Still working")
    local hook_input
    hook_input=$(create_hook_input "$transcript")

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    local decision
    decision=$(echo "$output" | jq -r '.decision' 2>/dev/null)
    [ "$decision" = "block" ]
}

# ============================================================================
# Error handling tests
# ============================================================================

@test "stop-hook: handles corrupted iteration (non-numeric)" {
    cat > "$TEST_DIR/.claude/super-ralph-loop.local.md" << 'EOF'
---
iteration: abc
max_iterations: 10
completion_promise: null
---
Do work
EOF
    local transcript
    transcript=$(create_transcript "Working")
    local hook_input
    hook_input=$(create_hook_input "$transcript")

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    # State file should be removed (corrupted)
    [ ! -f "$TEST_DIR/.claude/super-ralph-loop.local.md" ]
}

@test "stop-hook: handles missing transcript path" {
    create_state_file 1 0
    local hook_input='{"transcript_path": null}'

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    # State file should be removed
    [ ! -f "$TEST_DIR/.claude/super-ralph-loop.local.md" ]
}

@test "stop-hook: handles nonexistent transcript file" {
    create_state_file 1 0
    local hook_input='{"transcript_path": "/nonexistent/transcript.jsonl"}'

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    # State file should be removed
    [ ! -f "$TEST_DIR/.claude/super-ralph-loop.local.md" ]
}

# ============================================================================
# Output format tests
# ============================================================================

@test "stop-hook: block output includes prompt text" {
    create_state_file 1 0 "null" "Build the feature"
    local transcript
    transcript=$(create_transcript "Working on it")
    local hook_input
    hook_input=$(create_hook_input "$transcript")

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    local reason
    reason=$(echo "$output" | jq -r '.reason' 2>/dev/null)
    [[ "$reason" == *"Build the feature"* ]]
}

@test "stop-hook: block output includes system message with iteration" {
    create_state_file 5 0
    local transcript
    transcript=$(create_transcript "Working")
    local hook_input
    hook_input=$(create_hook_input "$transcript")

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    local sys_msg
    sys_msg=$(echo "$output" | jq -r '.systemMessage' 2>/dev/null)
    [[ "$sys_msg" == *"iteration 6"* ]]
}

@test "stop-hook: system message includes methodology context" {
    create_state_file 1 0
    local transcript
    transcript=$(create_transcript "Working")
    local hook_input
    hook_input=$(create_hook_input "$transcript")

    run bash -c "echo '$hook_input' | bash '$HOOK_SCRIPT'"
    [ "$status" -eq 0 ]

    local sys_msg
    sys_msg=$(echo "$output" | jq -r '.systemMessage' 2>/dev/null)
    [[ "$sys_msg" == *"Super-Ralph"* ]]
    [[ "$sys_msg" == *"sr-"* ]]
}
