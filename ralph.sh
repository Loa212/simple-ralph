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

# Export FINDINGS_PATH so backends and subprocesses can use it
export RALPH_FINDINGS_PATH="$FINDINGS_PATH"

verbose_log "RALPH_DIR=$RALPH_DIR"
verbose_log "RALPH_BACKEND=$RALPH_BACKEND"
verbose_log "MAX_LOOPS=$MAX_LOOPS"
verbose_log "FINDINGS_PATH=$FINDINGS_PATH"
verbose_log "DRY_RUN=$DRY_RUN"
verbose_log "MAX_PARALLEL=$MAX_PARALLEL"
verbose_log "RATE_LIMIT_WAIT_MINUTES=$RATE_LIMIT_WAIT_MINUTES"
verbose_log "RALPH_NO_SPINNER=$RALPH_NO_SPINNER"
verbose_log "RALPH_NOW_CMD=$RALPH_NOW_CMD"
verbose_log "SLEEP_CMD=$SLEEP_CMD"

# Max tasks to complete (default: 1000 = effectively unlimited)
MAX_TASKS="${1:-1000}"
TOTAL_TASKS_COMPLETED=0

# Prompt file location
PROMPT_FILE="$RALPH_DIR/ralph-prompt.md"

# Initialize
init_tokens

echo -e "${BLUE}Using backend: $(get_backend_name)${NC}"

# Dry-run: show config and exit
if [[ "$DRY_RUN" == "true" || "$DRY_RUN" == "1" ]]; then
    echo -e "${YELLOW}Dry-run mode — showing config and exiting${NC}"
    echo "  RALPH_BACKEND=$RALPH_BACKEND"
    echo "  MAX_LOOPS=$MAX_LOOPS"
    echo "  MAX_TASKS=$MAX_TASKS"
    echo "  FINDINGS_PATH=$FINDINGS_PATH"
    echo "  MAX_PARALLEL=$MAX_PARALLEL"
    echo "  RATE_LIMIT_WAIT_MINUTES=$RATE_LIMIT_WAIT_MINUTES"
    echo "  RALPH_NO_SPINNER=$RALPH_NO_SPINNER"
    echo "  RALPH_NOW_CMD=$RALPH_NOW_CMD"
    echo "  SLEEP_CMD=$SLEEP_CMD"
    echo "  PROMPT_FILE=$PROMPT_FILE"
    echo "  VERBOSE=$VERBOSE"
    exit 0
fi

# Main loop (safety cap of 100 iterations)
for i in {1..100}; do
    # Respect MAX_LOOPS from config (env-driven)
    if [ "$i" -gt "$MAX_LOOPS" ]; then
        echo -e "${YELLOW}Reached loop limit ($MAX_LOOPS)${NC}"
        show_token_summary
        exit 0
    fi

    print_header "$i"

    # Check if PROMPT.md exists
    if [ ! -f "$PROMPT_FILE" ]; then
        echo -e "${RED}Error: ralph-prompt.md not found in $RALPH_DIR${NC}"
        exit 1
    fi

    verbose_log "Starting loop $i / $MAX_LOOPS"

    # Run backend and stream output
    run_backend "$PROMPT_FILE"

    echo ""

    # Handle rate limiting - wait and retry
    if [ "$BACKEND_RATE_LIMITED" = true ]; then
        handle_rate_limit "$BACKEND_RATE_LIMIT_MSG"
        continue
    fi

    # Extract and normalize status block
    status_block=$(normalize_status_block "$(extract_status "$BACKEND_OUTPUT")")

    print_status "$status_block"

    # Log progress and tokens
    log_progress "$i" "$status_block"
    log_tokens "$i" "$(get_status_field "$status_block" "STATUS")" "$BACKEND_INPUT_TOKENS" "$BACKEND_OUTPUT_TOKENS"

    # Track total tasks completed
    tasks_this_loop=$(get_status_field "$status_block" "TASKS_COMPLETED_THIS_LOOP")
    tasks_this_loop=${tasks_this_loop:-0}
    TOTAL_TASKS_COMPLETED=$((TOTAL_TASKS_COMPLETED + tasks_this_loop))

    # Stop on BLOCKED status
    status=$(get_status_field "$status_block" "STATUS")
    if [ "$status" = "BLOCKED" ]; then
        echo -e "${RED}✗ Blocked${NC}"
        show_token_summary
        exit 1
    fi

    # Check exit signal
    exit_signal=$(get_status_field "$status_block" "EXIT_SIGNAL")
    
    if [ "$exit_signal" = "true" ]; then
        convert_ok=true
        if [ -x "$RALPH_DIR/lib/convert-findings.sh" ]; then
            if ! "$RALPH_DIR/lib/convert-findings.sh" >/dev/null 2>&1; then
                convert_ok=false
                echo -e "${YELLOW}Warning: convert-findings failed; skipping cleanup${NC}"
            fi
        fi
        if [ "$convert_ok" = true ]; then
            cleanup_temp_files
        fi
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
