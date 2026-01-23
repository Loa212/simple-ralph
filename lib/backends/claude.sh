#!/usr/bin/env bash
# Claude backend - stream parser

# Claude command
CLAUDE_CMD="claude --dangerously-skip-permissions --print --verbose --output-format stream-json"

# Run Claude and parse streaming JSON output
# Sets: BACKEND_OUTPUT, BACKEND_INPUT_TOKENS, BACKEND_OUTPUT_TOKENS, BACKEND_RATE_LIMITED, BACKEND_RATE_LIMIT_MSG
run_claude() {
    local prompt_file="$1"
    
    BACKEND_OUTPUT=""
    BACKEND_INPUT_TOKENS=0
    BACKEND_OUTPUT_TOKENS=0
    BACKEND_RATE_LIMITED=false
    BACKEND_RATE_LIMIT_MSG=""

    while IFS= read -r line; do
        # Check for rate limit error
        if echo "$line" | jq -e '.type == "assistant" and .error == "rate_limit"' &>/dev/null 2>&1; then
            BACKEND_RATE_LIMITED=true
            BACKEND_RATE_LIMIT_MSG=$(echo "$line" | jq -r '.message.content[]? | select(.type == "text").text // "Rate limited"' 2>/dev/null)
        fi

        # Stream text content in real-time and accumulate it
        if echo "$line" | jq -e '.type == "assistant"' &>/dev/null 2>&1; then
            text=$(echo "$line" | jq -r '.message.content[]? | select(.type == "text").text // empty' 2>/dev/null)
            if [ -n "$text" ]; then
                printf "%s\n" "$text"
                BACKEND_OUTPUT+="$text"$'\n'
            fi
        fi

        # Capture token usage from result message
        if echo "$line" | jq -e '.type == "result"' &>/dev/null 2>&1; then
            BACKEND_INPUT_TOKENS=$(echo "$line" | jq -r '.usage.input_tokens // 0' 2>/dev/null)
            BACKEND_OUTPUT_TOKENS=$(echo "$line" | jq -r '.usage.output_tokens // 0' 2>/dev/null)
        fi
    done < <($CLAUDE_CMD < "$prompt_file" 2>&1)
}
