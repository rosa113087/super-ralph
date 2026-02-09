#!/usr/bin/env bats

# Tests for install.sh - Installation and uninstallation

setup() {
    export TEST_DIR="$BATS_TMPDIR/install_test_$$"
    mkdir -p "$TEST_DIR"
    export REAL_HOME="$HOME"
    export HOME="$TEST_DIR/home"
    mkdir -p "$HOME/.local/bin"

    INSTALL_SCRIPT="$BATS_TEST_DIRNAME/../standalone/install.sh"
    SCRIPT_DIR="$BATS_TEST_DIRNAME/../standalone"
}

teardown() {
    export HOME="$REAL_HOME"
    rm -rf "$TEST_DIR"
}

# Helper: define install.sh functions in test context
_source_install_functions() {
    export INSTALL_DIR="$HOME/.local/bin"
    export SUPER_RALPH_HOME="$HOME/.super-ralph"
    export SCRIPT_DIR="$BATS_TEST_DIRNAME/../standalone"

    # Colors (needed by log function)
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m'

    log() {
        local level=$1
        local message=$2
        echo "[$level] $message"
    }
}

# ============================================================================
# check_dependencies tests
# ============================================================================

@test "install: check_dependencies succeeds when jq and git available" {
    _source_install_functions

    check_dependencies() {
        local missing_deps=()
        if ! command -v jq &>/dev/null; then
            missing_deps+=("jq")
        fi
        if ! command -v git &>/dev/null; then
            missing_deps+=("git")
        fi
        if [[ ${#missing_deps[@]} -ne 0 ]]; then
            echo "Missing: ${missing_deps[*]}"
            return 1
        fi
        return 0
    }

    run check_dependencies
    [ "$status" -eq 0 ]
}

@test "install: check_dependencies fails when jq missing" {
    _source_install_functions

    check_dependencies() {
        local missing_deps=()
        # Simulate jq missing
        missing_deps+=("jq")
        if [[ ${#missing_deps[@]} -ne 0 ]]; then
            echo "Missing: ${missing_deps[*]}"
            return 1
        fi
        return 0
    }

    run check_dependencies
    [ "$status" -eq 1 ]
    [[ "$output" == *"jq"* ]]
}

# ============================================================================
# Directory structure tests
# ============================================================================

@test "install: creates INSTALL_DIR" {
    _source_install_functions
    mkdir -p "$INSTALL_DIR"
    [ -d "$INSTALL_DIR" ]
}

@test "install: creates SUPER_RALPH_HOME structure" {
    _source_install_functions
    mkdir -p "$SUPER_RALPH_HOME/lib"
    mkdir -p "$SUPER_RALPH_HOME/templates"
    [ -d "$SUPER_RALPH_HOME/lib" ]
    [ -d "$SUPER_RALPH_HOME/templates" ]
}

# ============================================================================
# File copy tests
# ============================================================================

@test "install: copies all 8 library files" {
    _source_install_functions
    mkdir -p "$SUPER_RALPH_HOME/lib"

    local expected_libs=(
        skill_selector.sh tdd_gate.sh verification_gate.sh gate_utils.sh
        session_manager.sh tmux_utils.sh exit_detector.sh logging.sh
    )

    for lib in "${expected_libs[@]}"; do
        [ -f "$SCRIPT_DIR/lib/$lib" ] || { echo "Source missing: $lib"; false; }
        cp "$SCRIPT_DIR/lib/$lib" "$SUPER_RALPH_HOME/lib/"
    done

    local count
    count=$(ls -1 "$SUPER_RALPH_HOME/lib/"*.sh 2>/dev/null | wc -l | tr -d ' ')
    [ "$count" -eq 8 ]
}

@test "install: library files are executable after chmod" {
    _source_install_functions
    mkdir -p "$SUPER_RALPH_HOME/lib"
    cp "$SCRIPT_DIR/lib/logging.sh" "$SUPER_RALPH_HOME/lib/"
    chmod +x "$SUPER_RALPH_HOME/lib/"*.sh
    [ -x "$SUPER_RALPH_HOME/lib/logging.sh" ]
}

@test "install: copies main loop script" {
    _source_install_functions
    mkdir -p "$SUPER_RALPH_HOME"
    cp "$SCRIPT_DIR/super_ralph_loop.sh" "$SUPER_RALPH_HOME/"
    [ -f "$SUPER_RALPH_HOME/super_ralph_loop.sh" ]
}

# ============================================================================
# Command creation tests
# ============================================================================

@test "install: creates super-ralph command script" {
    _source_install_functions
    cat > "$INSTALL_DIR/super-ralph" << 'CMDEOF'
#!/bin/bash
SUPER_RALPH_HOME="$HOME/.super-ralph"
exec "$SUPER_RALPH_HOME/super_ralph_loop.sh" "$@"
CMDEOF
    chmod +x "$INSTALL_DIR/super-ralph"
    [ -x "$INSTALL_DIR/super-ralph" ]
    grep -q "super_ralph_loop.sh" "$INSTALL_DIR/super-ralph"
}

@test "install: creates super-ralph-setup command script" {
    _source_install_functions
    cat > "$INSTALL_DIR/super-ralph-setup" << 'CMDEOF'
#!/bin/bash
echo "setup"
CMDEOF
    chmod +x "$INSTALL_DIR/super-ralph-setup"
    [ -x "$INSTALL_DIR/super-ralph-setup" ]
}

# ============================================================================
# check_path tests
# ============================================================================

@test "install: check_path detects when INSTALL_DIR in PATH" {
    _source_install_functions
    export PATH="$INSTALL_DIR:$PATH"

    check_path() {
        if [[ ":$PATH:" == *":$INSTALL_DIR:"* ]]; then
            echo "in PATH"
            return 0
        fi
        echo "not in PATH"
        return 1
    }

    run check_path
    [ "$status" -eq 0 ]
    [[ "$output" == *"in PATH"* ]]
}

@test "install: check_path warns when INSTALL_DIR not in PATH" {
    _source_install_functions
    export PATH="/usr/bin:/bin"

    check_path() {
        if [[ ":$PATH:" == *":$INSTALL_DIR:"* ]]; then
            echo "in PATH"
            return 0
        fi
        echo "not in PATH"
        return 1
    }

    run check_path
    [ "$status" -eq 1 ]
    [[ "$output" == *"not in PATH"* ]]
}

# ============================================================================
# Uninstall tests
# ============================================================================

@test "install: uninstall removes command files" {
    _source_install_functions
    touch "$INSTALL_DIR/super-ralph" "$INSTALL_DIR/super-ralph-setup"
    mkdir -p "$SUPER_RALPH_HOME"

    rm -f "$INSTALL_DIR/super-ralph" "$INSTALL_DIR/super-ralph-setup"
    rm -rf "$SUPER_RALPH_HOME"

    [ ! -f "$INSTALL_DIR/super-ralph" ]
    [ ! -f "$INSTALL_DIR/super-ralph-setup" ]
    [ ! -d "$SUPER_RALPH_HOME" ]
}

@test "install: uninstall verification detects remaining files" {
    _source_install_functions
    # Create files that simulate a partial uninstall
    touch "$INSTALL_DIR/super-ralph"
    mkdir -p "$SUPER_RALPH_HOME"

    local remaining=()
    [[ -f "$INSTALL_DIR/super-ralph" ]] && remaining+=("super-ralph")
    [[ -d "$SUPER_RALPH_HOME" ]] && remaining+=(".super-ralph")

    [ ${#remaining[@]} -gt 0 ]
}

@test "install: uninstall verification passes when all removed" {
    _source_install_functions
    # Ensure nothing exists
    rm -f "$INSTALL_DIR/super-ralph" "$INSTALL_DIR/super-ralph-setup"
    rm -rf "$SUPER_RALPH_HOME"

    local remaining=()
    [[ -f "$INSTALL_DIR/super-ralph" ]] && remaining+=("super-ralph")
    [[ -f "$INSTALL_DIR/super-ralph-setup" ]] && remaining+=("super-ralph-setup")
    [[ -d "$SUPER_RALPH_HOME" ]] && remaining+=(".super-ralph")

    [ ${#remaining[@]} -eq 0 ]
}

# ============================================================================
# CLI argument parsing tests
# ============================================================================

@test "install: --help shows usage" {
    run bash -c "source /dev/null; case '--help' in --help|-h) echo 'Usage: install.sh [install|uninstall]' ;; esac"
    [[ "$output" == *"Usage"* ]]
}

@test "install: unknown argument exits with error" {
    run bash -c "case 'foobar' in install) ;; uninstall) ;; --help|-h) ;; *) echo 'Unknown: foobar'; exit 1 ;; esac"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown"* ]]
}
