#!/usr/bin/env bash
# Rate limiting utilities

# Check if a line indicates a rate limit error
# Returns 0 if rate limited, 1 otherwise
# Sets RATE_LIMIT_MSG variable with the error message
check_rate_limit() {
    local line="$1"
    RATE_LIMIT_MSG=""
    
    if echo "$line" | jq -e '.type == "assistant" and .error == "rate_limit"' &>/dev/null 2>&1; then
        RATE_LIMIT_MSG=$(echo "$line" | jq -r '.message.content[]? | select(.type == "text").text // "Rate limited"' 2>/dev/null)
        return 0
    fi
    return 1
}

# Handle rate limiting - display message and wait
handle_rate_limit() {
    local msg="${1:-Rate limited}"
    
    echo -e "${YELLOW}⏳ Rate limited: $msg${NC}"
    echo -e "${YELLOW}   Waiting $RATE_LIMIT_WAIT_MINUTES minutes before retrying...${NC}"
    sleep $((RATE_LIMIT_WAIT_MINUTES * 60))
    echo -e "${GREEN}   Resuming...${NC}"
}
