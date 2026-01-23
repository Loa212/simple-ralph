#!/usr/bin/env bash
set -e

# Ralph directory (all files are relative to this)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export RALPH_DIR="$SCRIPT_DIR"

# Load config and utilities
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/tokens.sh"
source "$SCRIPT_DIR/lib/ratelimit.sh"
source "$SCRIPT_DIR/lib/backend.sh"

# Validate backend selection
validate_backend

# Max tasks to complete (default: 1000 = effectively unlimited)
MAX_TASKS="${1:-1000}"
TOTAL_TASKS_COMPLETED=0

# Prompt file location
PROMPT_FILE="$RALPH_DIR/ralph-prompt.md"

# Initialize
init_tokens

echo -e "${BLUE}Using backend: $(get_backend_name)${NC}"

# Main loop (safety cap of 100 iterations)
for i in {1..100}; do
    print_header "$i"

    # Check if PROMPT.md exists
    if [ ! -f "$PROMPT_FILE" ]; then
        echo -e "${RED}Error: ralph-prompt.md not found in $RALPH_DIR${NC}"
        exit 1
    fi

    # Run backend and stream output
    run_backend "$PROMPT_FILE"

    echo ""

    # Handle rate limiting - wait and retry
    if [ "$BACKEND_RATE_LIMITED" = true ]; then
        handle_rate_limit "$BACKEND_RATE_LIMIT_MSG"
        continue
    fi

    # Extract status block
    status_block=$(extract_status "$BACKEND_OUTPUT")
    
    if [ -z "$status_block" ]; then
        echo -e "${RED}✗ No status block found${NC}"
        exit 1
    fi

    print_status "$status_block"

    # Log progress and tokens
    log_progress "$i" "$status_block"
    log_tokens "$i" "$(get_status_field "$status_block" "STATUS")" "$BACKEND_INPUT_TOKENS" "$BACKEND_OUTPUT_TOKENS"

    # Track total tasks completed
    tasks_this_loop=$(get_status_field "$status_block" "TASKS_COMPLETED_THIS_LOOP")
    tasks_this_loop=${tasks_this_loop:-0}
    TOTAL_TASKS_COMPLETED=$((TOTAL_TASKS_COMPLETED + tasks_this_loop))

    # Check exit signal
    exit_signal=$(get_status_field "$status_block" "EXIT_SIGNAL")
    
    if [ "$exit_signal" = "true" ]; then
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        show_token_summary
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}✓ Complete! ($TOTAL_TASKS_COMPLETED tasks)${NC}"
        exit 0
    fi

    # Check if we've hit the task limit
    if [ "$TOTAL_TASKS_COMPLETED" -ge "$MAX_TASKS" ]; then
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        show_token_summary
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}⏸ Paused after $TOTAL_TASKS_COMPLETED tasks (limit: $MAX_TASKS)${NC}"
        exit 0
    fi

done

echo ""
echo -e "${RED}Exhausted 100 loop iterations${NC}"
exit 1
