#!/usr/bin/env bash
set -e

# Load config and utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/tokens.sh"
source "$SCRIPT_DIR/lib/ratelimit.sh"

# Max tasks to complete (default: 1000 = effectively unlimited)
MAX_TASKS="${1:-1000}"
TOTAL_TASKS_COMPLETED=0

# Initialize
init_tokens

# Main loop (safety cap of 100 iterations)
for i in {1..100}; do
    print_header "$i"

    # Check if PROMPT.md exists
    if [ ! -f "ralph-prompt.md" ]; then
        echo -e "${RED}Error: ralph-prompt.md not found${NC}"
        exit 1
    fi

    # Run claude and stream output directly (no spinner)
    out=""
    input_tokens=0
    output_tokens=0
    rate_limited=false

    while IFS= read -r line; do
        # Check for rate limit error
        if check_rate_limit "$line"; then
            rate_limited=true
            rate_limit_msg="$RATE_LIMIT_MSG"
        fi

        # Stream text content in real-time and accumulate it
        if echo "$line" | jq -e '.type == "assistant"' &>/dev/null 2>&1; then
            text=$(echo "$line" | jq -r '.message.content[]? | select(.type == "text").text // empty' 2>/dev/null)
            if [ -n "$text" ]; then
                printf "%s\n" "$text"
                out+="$text"$'\n'
            fi
        fi

        # Capture token usage from result message
        if echo "$line" | jq -e '.type == "result"' &>/dev/null 2>&1; then
            input_tokens=$(echo "$line" | jq -r '.usage.input_tokens // 0' 2>/dev/null)
            output_tokens=$(echo "$line" | jq -r '.usage.output_tokens // 0' 2>/dev/null)
        fi
    done < <($CLAUDE_CMD < ralph-prompt.md 2>&1)

    echo ""

    # Handle rate limiting - wait and retry
    if [ "$rate_limited" = true ]; then
        handle_rate_limit "$rate_limit_msg"
        continue
    fi

    # Extract status block
    status_block=$(extract_status "$out")
    
    if [ -z "$status_block" ]; then
        echo -e "${RED}✗ No status block found${NC}"
        exit 1
    fi

    print_status "$status_block"

    # Log progress and tokens
    log_progress "$i" "$status_block"
    log_tokens "$i" "$(get_status_field "$status_block" "STATUS")" "$input_tokens" "$output_tokens"

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
