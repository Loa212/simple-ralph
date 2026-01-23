#!/usr/bin/env bash
# Backend dispatcher - unified interface for AI backends

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load backends
source "$SCRIPT_DIR/backends/claude.sh"
source "$SCRIPT_DIR/backends/codex.sh"

# Backend selection: claude | codex
RALPH_BACKEND="${RALPH_BACKEND:-claude}"

# Validate backend
validate_backend() {
    case "$RALPH_BACKEND" in
        claude|codex)
            return 0
            ;;
        *)
            echo -e "${RED}Error: Unknown backend '$RALPH_BACKEND'. Use 'claude' or 'codex'.${NC}" >&2
            exit 1
            ;;
    esac
}

# Run the selected backend
# Usage: run_backend <prompt_file>
# Sets: BACKEND_OUTPUT, BACKEND_INPUT_TOKENS, BACKEND_OUTPUT_TOKENS, BACKEND_RATE_LIMITED, BACKEND_RATE_LIMIT_MSG
run_backend() {
    local prompt_file="$1"
    
    case "$RALPH_BACKEND" in
        claude)
            run_claude "$prompt_file"
            ;;
        codex)
            run_codex "$prompt_file"
            ;;
    esac
}

# Get current backend name (for display)
get_backend_name() {
    echo "$RALPH_BACKEND"
}
