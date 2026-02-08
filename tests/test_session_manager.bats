#!/usr/bin/env bats

# Tests for session_manager.sh - Session Management Library

setup() {
    export SUPER_RALPH_DIR="$BATS_TMPDIR/session_test_$$"
    mkdir -p "$SUPER_RALPH_DIR"

    export CLAUDE_SESSION_FILE="$SUPER_RALPH_DIR/.claude_session_id"
    export RALPH_SESSION_FILE="$SUPER_RALPH_DIR/.ralph_session"
    export CLAUDE_SESSION_EXPIRY_HOURS=24

    # Stub log_status and get_iso_timestamp
    log_status() { :; }
    get_iso_timestamp() { date -u +"%Y-%m-%dT%H:%M:%S+00:00"; }
    export -f log_status get_iso_timestamp

    source "$BATS_TEST_DIRNAME/../standalone/lib/session_manager.sh"
}

teardown() {
    rm -rf "$SUPER_RALPH_DIR"
}

# ============================================================================
# get_session_file_age_hours tests
# ============================================================================

@test "get_session_file_age_hours: returns 0 for nonexistent file" {
    result=$(get_session_file_age_hours "/nonexistent/file")
    [ "$result" = "0" ]
}

@test "get_session_file_age_hours: returns 0 for recently created file" {
    touch "$SUPER_RALPH_DIR/recent_file"
    result=$(get_session_file_age_hours "$SUPER_RALPH_DIR/recent_file")
    [ "$result" = "0" ]
}

@test "get_session_file_age_hours: returns numeric value" {
    touch "$SUPER_RALPH_DIR/test_file"
    result=$(get_session_file_age_hours "$SUPER_RALPH_DIR/test_file")
    [[ "$result" =~ ^-?[0-9]+$ ]]
}

# ============================================================================
# init_claude_session tests
# ============================================================================

@test "init_claude_session: returns empty when no session file" {
    result=$(init_claude_session)
    [ -z "$result" ]
}

@test "init_claude_session: returns session id from existing file" {
    echo "test-session-12345" > "$CLAUDE_SESSION_FILE"
    result=$(init_claude_session)
    [ "$result" = "test-session-12345" ]
}

@test "init_claude_session: clears expired session" {
    echo "old-session" > "$CLAUDE_SESSION_FILE"
    # Set expiry to 0 hours to force expiration
    CLAUDE_SESSION_EXPIRY_HOURS=0
    result=$(init_claude_session)
    [ -z "$result" ]
    [ ! -f "$CLAUDE_SESSION_FILE" ]
}

@test "init_claude_session: returns empty for empty session file" {
    touch "$CLAUDE_SESSION_FILE"
    result=$(init_claude_session)
    [ -z "$result" ]
}

# ============================================================================
# save_claude_session tests
# ============================================================================

@test "save_claude_session: saves session id from json output" {
    local output_file="$SUPER_RALPH_DIR/output.json"
    echo '{"session_id": "saved-session-abc"}' > "$output_file"
    save_claude_session "$output_file"
    [ -f "$CLAUDE_SESSION_FILE" ]
    result=$(cat "$CLAUDE_SESSION_FILE")
    [ "$result" = "saved-session-abc" ]
}

@test "save_claude_session: handles missing output file" {
    save_claude_session "/nonexistent/output.json"
    [ ! -f "$CLAUDE_SESSION_FILE" ]
}

@test "save_claude_session: ignores null session id" {
    local output_file="$SUPER_RALPH_DIR/output.json"
    echo '{"session_id": null}' > "$output_file"
    save_claude_session "$output_file"
    [ ! -f "$CLAUDE_SESSION_FILE" ]
}

# ============================================================================
# init_session_tracking tests
# ============================================================================

@test "init_session_tracking: creates ralph session file" {
    init_session_tracking
    [ -f "$RALPH_SESSION_FILE" ]
    local session_id
    session_id=$(jq -r '.session_id' "$RALPH_SESSION_FILE")
    [ "$session_id" = "" ]
}

@test "init_session_tracking: does not overwrite existing session" {
    echo '{"session_id": "existing", "created_at": "2026-01-01T00:00:00+00:00"}' > "$RALPH_SESSION_FILE"
    init_session_tracking
    local session_id
    session_id=$(jq -r '.session_id' "$RALPH_SESSION_FILE")
    [ "$session_id" = "existing" ]
}

# ============================================================================
# update_session_last_used tests
# ============================================================================

@test "update_session_last_used: updates timestamp" {
    echo '{"session_id": "", "last_used": "2026-01-01T00:00:00+00:00"}' > "$RALPH_SESSION_FILE"
    update_session_last_used
    local last_used
    last_used=$(jq -r '.last_used' "$RALPH_SESSION_FILE")
    [ "$last_used" != "2026-01-01T00:00:00+00:00" ]
}

@test "update_session_last_used: no-op when no session file" {
    update_session_last_used
    [ ! -f "$RALPH_SESSION_FILE" ]
}

# ============================================================================
# reset_session tests
# ============================================================================

@test "reset_session: clears session files" {
    echo "some-session" > "$CLAUDE_SESSION_FILE"
    echo '{"session_id": "some-session"}' > "$RALPH_SESSION_FILE"
    reset_session "test_reset"
    [ ! -f "$CLAUDE_SESSION_FILE" ]
    local reason
    reason=$(jq -r '.reset_reason' "$RALPH_SESSION_FILE")
    [ "$reason" = "test_reset" ]
}

@test "reset_session: uses default reason" {
    echo '{}' > "$RALPH_SESSION_FILE"
    reset_session
    local reason
    reason=$(jq -r '.reset_reason' "$RALPH_SESSION_FILE")
    [ "$reason" = "manual_reset" ]
}
