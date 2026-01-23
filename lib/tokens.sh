#!/usr/bin/env bash
# Token tracking

TOKEN_FILE=".tokens.json"

# Initialize token file
init_tokens() {
    if [ ! -f "$TOKEN_FILE" ]; then
        cat > "$TOKEN_FILE" << 'EOF'
{
  "total_tokens": 0,
  "total_cost_usd": 0,
  "model": "claude-opus-4-5",
  "pricing": {
    "input_per_1k": 0.015,
    "output_per_1k": 0.075
  },
  "loops": []
}
EOF
    fi
}

# Log token usage
log_tokens() {
    local loop_num="$1"
    local task="$2"
    local input_tokens="$3"
    local output_tokens="$4"
    
    # Calculate cost
    local input_cost=$(echo "scale=6; $input_tokens * 0.015 / 1000" | bc)
    local output_cost=$(echo "scale=6; $output_tokens * 0.075 / 1000" | bc)
    local total_cost=$(echo "$input_cost + $output_cost" | bc)
    local total_tokens=$((input_tokens + output_tokens))
    
    # Update JSON
    if [ -f "$TOKEN_FILE" ]; then
        jq \
            --arg loop "$loop_num" \
            --arg task "$task" \
            --arg tokens "$total_tokens" \
            --arg cost "$total_cost" \
            '.loops += [{
                "loop_num": ($loop | tonumber),
                "task": $task,
                "tokens_used": ($tokens | tonumber),
                "cost_usd": ($cost | tonumber),
                "timestamp": now | strftime("%Y-%m-%dT%H:%M:%SZ")
            }] |
            .total_tokens += ($tokens | tonumber) |
            .total_cost_usd += ($cost | tonumber)' \
            "$TOKEN_FILE" > "${TOKEN_FILE}.tmp" && mv "${TOKEN_FILE}.tmp" "$TOKEN_FILE"
    fi
}

# Show summary
show_summary() {
    if [ ! -f "$TOKEN_FILE" ]; then
        echo "Token file not found"
        return
    fi

    echo "=== Token Usage Summary ==="
    jq '.total_tokens as $total | .total_cost_usd as $cost | .loops |
        "Total: \($total) tokens (\($cost) USD)\n" +
        "Loops: \(length)\n" +
        (if length > 0 then
            "Recent:\n" + (.[-3:] | map("  Loop \(.loop_num): \(.tokens_used) tokens (\(.cost_usd) USD)") | join("\n"))
        else empty end)' \
        "$TOKEN_FILE"
}

# Show token summary for terminal (compact)
show_token_summary() {
    if [ ! -f "$TOKEN_FILE" ]; then
        return
    fi

    local total_tokens=$(jq -r '.total_tokens' "$TOKEN_FILE")
    local total_cost=$(jq -r '.total_cost_usd | . * 100 | round / 100' "$TOKEN_FILE")
    local loop_count=$(jq -r '.loops | length' "$TOKEN_FILE")

    echo "Tokens: $total_tokens | Cost: \$${total_cost} | Loops: $loop_count"
}
