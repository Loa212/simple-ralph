#!/usr/bin/env bash
# Codex backend - stream parser

# Codex command
CODEX_CMD="codex exec --json --full-auto -"

# Run Codex and parse streaming JSONL output
# Sets: BACKEND_OUTPUT, BACKEND_INPUT_TOKENS, BACKEND_OUTPUT_TOKENS, BACKEND_RATE_LIMITED, BACKEND_RATE_LIMIT_MSG
run_codex() {
    local prompt_file="$1"
    
    BACKEND_OUTPUT=""
    BACKEND_INPUT_TOKENS=0
    BACKEND_OUTPUT_TOKENS=0
    BACKEND_RATE_LIMITED=false
    BACKEND_RATE_LIMIT_MSG=""

    while IFS= read -r line; do
        # Check for error events (including rate limits / auth issues)
        if echo "$line" | jq -e '.type == "error"' &>/dev/null 2>&1; then
            local error_msg=$(echo "$line" | jq -r '.message // "Unknown error"' 2>/dev/null)
            # Check if it's a rate limit or auth error
            if echo "$error_msg" | grep -qi "rate\|limit\|token\|auth\|expired"; then
                BACKEND_RATE_LIMITED=true
                BACKEND_RATE_LIMIT_MSG="$error_msg"
            fi
        fi

        # Check for turn.failed events
        if echo "$line" | jq -e '.type == "turn.failed"' &>/dev/null 2>&1; then
            local error_msg=$(echo "$line" | jq -r '.error.message // "Turn failed"' 2>/dev/null)
            if echo "$error_msg" | grep -qi "rate\|limit\|token\|auth\|expired"; then
                BACKEND_RATE_LIMITED=true
                BACKEND_RATE_LIMIT_MSG="$error_msg"
            fi
        fi

        # Stream agent messages in real-time
        if echo "$line" | jq -e '.type == "item.completed" and .item.type == "agent_message"' &>/dev/null 2>&1; then
            text=$(echo "$line" | jq -r '.item.text // empty' 2>/dev/null)
            if [ -n "$text" ]; then
                printf "%s\n" "$text"
                BACKEND_OUTPUT+="$text"$'\n'
            fi
        fi

        # Also capture reasoning (optional - for verbose mode)
        # if echo "$line" | jq -e '.type == "item.completed" and .item.type == "reasoning"' &>/dev/null 2>&1; then
        #     text=$(echo "$line" | jq -r '.item.text // empty' 2>/dev/null)
        #     if [ -n "$text" ]; then
        #         printf "${YELLOW}[reasoning]${NC} %s\n" "$text"
        #     fi
        # fi

        # Capture token usage from turn.completed
        if echo "$line" | jq -e '.type == "turn.completed"' &>/dev/null 2>&1; then
            BACKEND_INPUT_TOKENS=$(echo "$line" | jq -r '.usage.input_tokens // 0' 2>/dev/null)
            BACKEND_OUTPUT_TOKENS=$(echo "$line" | jq -r '.usage.output_tokens // 0' 2>/dev/null)
        fi
    done < <($CODEX_CMD < "$prompt_file" 2>&1)
}
