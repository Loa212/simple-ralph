#!/usr/bin/env bash
# Token tracking - backend-aware pricing

# Use RALPH_DIR for token file (set by config.sh)
TOKEN_FILE="${RALPH_DIR:-.}/.tokens.json"

# Pricing (all USD):
# Claude Opus 4.5: $15/M input, $75/M output (per-token)
# Codex: credit-based (~5 credits/local task, ~25 credits/cloud task)
#        1 credit ≈ $0.045

get_pricing() {
    local backend="${RALPH_BACKEND:-claude}"
    case "$backend" in
        claude)
            # Per-token pricing (USD per 1K tokens)
            INPUT_PRICE_PER_1K=0.015
            OUTPUT_PRICE_PER_1K=0.075
            MODEL_NAME="claude-opus-4-5"
            PRICING_MODE="per_token"
            ;;
        codex)
            # Credit-based pricing: ~5 credits per local exec task
            # 1 credit ≈ $0.045 (~€0.042)
            CREDITS_PER_CALL=5
            CREDIT_PRICE_USD=0.045
            MODEL_NAME="codex-gpt-5.2"
            PRICING_MODE="per_credit"
            ;;
        *)
            INPUT_PRICE_PER_1K=0.015
            OUTPUT_PRICE_PER_1K=0.075
            MODEL_NAME="unknown"
            PRICING_MODE="per_token"
            ;;
    esac
}

# Initialize token file
init_tokens() {
    get_pricing
    if [ ! -f "$TOKEN_FILE" ]; then
        if [ "$PRICING_MODE" = "per_credit" ]; then
            cat > "$TOKEN_FILE" << EOF
{
  "total_tokens": 0,
  "total_credits": 0,
  "total_cost_usd": 0,
  "backend": "$RALPH_BACKEND",
  "model": "$MODEL_NAME",
  "pricing_mode": "per_credit",
  "pricing": {
    "credits_per_call": $CREDITS_PER_CALL,
    "credit_price_usd": $CREDIT_PRICE_USD
  },
  "loops": []
}
EOF
        else
            # Per-token pricing (Claude)
            cat > "$TOKEN_FILE" << EOF
{
  "total_tokens": 0,
  "total_cost_usd": 0,
  "backend": "$RALPH_BACKEND",
  "model": "$MODEL_NAME",
  "pricing_mode": "per_token",
  "pricing": {
    "input_per_1k_usd": $INPUT_PRICE_PER_1K,
    "output_per_1k_usd": $OUTPUT_PRICE_PER_1K
  },
  "loops": []
}
EOF
        fi
    fi
}

# Log token usage
log_tokens() {
    local loop_num="$1"
    local task="$2"
    local input_tokens="$3"
    local output_tokens="$4"
    local timestamp
    timestamp="$(ralph_now)"
    
    # Get backend-specific pricing
    get_pricing
    
    local total_tokens=$((input_tokens + output_tokens))
    
    if [ "$PRICING_MODE" = "per_credit" ]; then
        # Credit-based pricing (Codex)
        local credits=$CREDITS_PER_CALL
        local cost_usd
        cost_usd=$(echo "scale=4; $credits * $CREDIT_PRICE_USD" | bc)
        
        if [ -f "$TOKEN_FILE" ]; then
            jq \
                --arg loop "$loop_num" \
                --arg task "$task" \
                --arg tokens "$total_tokens" \
                --arg credits "$credits" \
                --arg cost "$cost_usd" \
                --arg backend "$RALPH_BACKEND" \
                --arg timestamp "$timestamp" \
                '.loops += [{
                    "loop_num": ($loop | tonumber),
                    "task": $task,
                    "tokens_used": ($tokens | tonumber),
                    "credits_used": ($credits | tonumber),
                    "cost_usd": ($cost | tonumber),
                    "backend": $backend,
                    "timestamp": $timestamp
                }] |
                .total_tokens += ($tokens | tonumber) |
                .total_credits += ($credits | tonumber) |
                .total_cost_usd += ($cost | tonumber)' \
                "$TOKEN_FILE" > "${TOKEN_FILE}.tmp" && mv "${TOKEN_FILE}.tmp" "$TOKEN_FILE"
        fi
    else
        # Per-token pricing (Claude)
        local input_cost
        local output_cost
        local total_cost_usd
        input_cost=$(echo "scale=6; $input_tokens * $INPUT_PRICE_PER_1K / 1000" | bc)
        output_cost=$(echo "scale=6; $output_tokens * $OUTPUT_PRICE_PER_1K / 1000" | bc)
        total_cost_usd=$(echo "$input_cost + $output_cost" | bc)
        
        if [ -f "$TOKEN_FILE" ]; then
            jq \
                --arg loop "$loop_num" \
                --arg task "$task" \
                --arg tokens "$total_tokens" \
                --arg cost_usd "$total_cost_usd" \
                --arg backend "$RALPH_BACKEND" \
                --arg timestamp "$timestamp" \
                '.loops += [{
                    "loop_num": ($loop | tonumber),
                    "task": $task,
                    "tokens_used": ($tokens | tonumber),
                    "cost_usd": ($cost_usd | tonumber),
                    "backend": $backend,
                    "timestamp": $timestamp
                }] |
                .total_tokens += ($tokens | tonumber) |
                .total_cost_usd += ($cost_usd | tonumber)' \
                "$TOKEN_FILE" > "${TOKEN_FILE}.tmp" && mv "${TOKEN_FILE}.tmp" "$TOKEN_FILE"
        fi
    fi
}

# Show summary
show_summary() {
    if [ ! -f "$TOKEN_FILE" ]; then
        echo "Token file not found"
        return
    fi

    get_pricing
    echo "=== Token Usage Summary ==="
    
    if [ "$PRICING_MODE" = "per_credit" ]; then
        jq '.total_tokens as $total | .total_credits as $credits | .total_cost_usd as $cost | .backend as $backend | .loops |
            "Backend: \($backend // "unknown")\n" +
            "Total: \($total) tokens | \($credits) credits ($\($cost))\n" +
            "Loops: \(length)\n" +
            (if length > 0 then
                "Recent:\n" + (.[-3:] | map("  Loop \(.loop_num): \(.tokens_used) tokens | \(.credits_used) credits ($\(.cost_usd)) [\(.backend // "?")]") | join("\n"))
            else empty end)' \
            "$TOKEN_FILE"
    else
        jq '.total_tokens as $total | .total_cost_usd as $usd | .backend as $backend | .loops |
            "Backend: \($backend // "unknown")\n" +
            "Total: \($total) tokens ($\($usd))\n" +
            "Loops: \(length)\n" +
            (if length > 0 then
                "Recent:\n" + (.[-3:] | map("  Loop \(.loop_num): \(.tokens_used) tokens ($\(.cost_usd)) [\(.backend // "?")]") | join("\n"))
            else empty end)' \
            "$TOKEN_FILE"
    fi
}

# Show token summary for terminal (compact)
show_token_summary() {
    if [ ! -f "$TOKEN_FILE" ]; then
        return
    fi

    get_pricing
    local total_tokens
    local loop_count
    local total_usd
    total_tokens=$(jq -r '.total_tokens' "$TOKEN_FILE")
    loop_count=$(jq -r '.loops | length' "$TOKEN_FILE")
    total_usd=$(jq -r '.total_cost_usd | . * 100 | round / 100' "$TOKEN_FILE")

    if [ "$PRICING_MODE" = "per_credit" ]; then
        local total_credits
        total_credits=$(jq -r '.total_credits // 0' "$TOKEN_FILE")
        echo "Tokens: $total_tokens | Credits: $total_credits | Cost: \$${total_usd} | Loops: $loop_count"
    else
        echo "Tokens: $total_tokens | Cost: \$${total_usd} | Loops: $loop_count"
    fi
}
