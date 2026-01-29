#!/usr/bin/env bash
# Utility functions

ralph_now() {
    if [[ -n "${RALPH_NOW_CMD:-}" ]]; then
        # Allow custom command for deterministic timestamps in tests.
        # shellcheck disable=SC2086,SC2294
        eval "$RALPH_NOW_CMD"
    else
        date -u +%Y-%m-%dT%H:%M:%SZ
    fi
}

ralph_sleep() {
    local duration="${1:-}"
    if [[ -n "${SLEEP_CMD:-}" ]]; then
        # Allow injected sleep command for tests (e.g., SLEEP_CMD=":").
        # shellcheck disable=SC2086,SC2294
        eval "$SLEEP_CMD" "$duration"
    else
        sleep "$duration"
    fi
}

# Start spinner with rotating words
start_spinner() {
    local phase_desc="${1:-Processing...}"

    if [[ "${RALPH_NO_SPINNER:-}" == "true" || "${RALPH_NO_SPINNER:-}" == "1" ]]; then
        return
    fi
    
    if [[ -n "$SPINNER_PID" ]] && kill -0 "$SPINNER_PID" 2>/dev/null; then
        return
    fi
    
    (
        local i=0
        local word_idx=$((RANDOM % ${#SPINNER_WORDS[@]}))
        local last_word_change=$SECONDS
        local word_count=${#SPINNER_WORDS[@]}
        
        while true; do
            if (( SECONDS - last_word_change >= 3 )); then
                word_idx=$((RANDOM % word_count))
                last_word_change=$SECONDS
            fi
            
            local char="${SPINNER_CHARS:i++%${#SPINNER_CHARS}:1}"
            local action="${SPINNER_WORDS[$word_idx]}"
            printf "\r${GREEN}%s${NC} %s %s" "$char" "$action" "$phase_desc"
            ralph_sleep 0.1
        done
    ) &
    SPINNER_PID=$!
    
    trap 'stop_spinner' EXIT
}

# Stop spinner
stop_spinner() {
    if [[ -n "$SPINNER_PID" ]]; then
        kill "$SPINNER_PID" 2>/dev/null || true
        wait "$SPINNER_PID" 2>/dev/null || true
        SPINNER_PID=""
        printf "\r\033[K"
    fi
}

# Extract RALPH_STATUS block
extract_status() {
    local output="$1"
    echo "$output" | sed -n '/---RALPH_STATUS---/,/---END_RALPH_STATUS---/p'
}

# Get status field
get_status_field() {
    local status_block="$1"
    local field="$2"
    echo "$status_block" | grep "^$field:" | cut -d' ' -f2- | tr -d ' '
}

# Print header
print_header() {
    local loop_num="$1"
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}LOOP $loop_num${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Print status
print_status() {
    local status_block="$1"
    local status
    local tasks
    local files
    local tests
    local rec
    status=$(get_status_field "$status_block" "STATUS")
    tasks=$(get_status_field "$status_block" "TASKS_COMPLETED_THIS_LOOP")
    files=$(get_status_field "$status_block" "FILES_MODIFIED")
    tests=$(get_status_field "$status_block" "TESTS_STATUS")
    rec=$(get_status_field "$status_block" "RECOMMENDATION")

    local status_color=$YELLOW
    [ "$status" = "COMPLETE" ] && status_color=$GREEN
    [ "$status" = "BLOCKED" ] && status_color=$RED

    echo ""
    echo -e "Status: ${status_color}${status}${NC}"
    echo "Tasks: $tasks | Files: $files | Tests: $tests"
    echo "Next: $rec"
    echo ""
}

# Log progress
log_progress() {
    local loop_num="$1"
    local status_block="$2"
    
    # Ensure RALPH_DIR is set - never default to current directory
    if [[ -z "$RALPH_DIR" ]]; then
        echo -e "${RED}Error: RALPH_DIR not set${NC}" >&2
        return 1
    fi
    local progress_file="${RALPH_DIR}/progress.txt"
    
    {
        echo "=== Loop $loop_num ==="
        echo "Time: $(ralph_now)"
        echo "$status_block"
        echo ""
    } >> "$progress_file"
}

# Remove temporary files created during loop execution.
cleanup_temp_files() {
    local findings_path="${FINDINGS_PATH:-${RALPH_DIR}/findings.txt}"
    local findings_dir
    findings_dir="$(dirname "$findings_path")"
    local -a temp_files=(
        "${RALPH_DIR}/progress.txt"
        "${findings_path}"
        "${findings_dir}/findings.fragments.yaml"
        "${findings_dir}/findings.fragments.json"
    )

    for temp_file in "${temp_files[@]}"; do
        if [[ -f "$temp_file" ]]; then
            verbose_log "Removing temp file: $temp_file"
            rm -f "$temp_file"
        fi
    done
}
