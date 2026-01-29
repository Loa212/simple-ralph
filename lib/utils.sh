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

# Extract last RALPH_STATUS block
extract_status() {
    local output="$1"
    awk '
        /---RALPH_STATUS---/ {block=""; in_block=1}
        in_block {block=block $0 ORS}
        /---END_RALPH_STATUS---/ {in_block=0; last=block}
        END {printf "%s", last}
    ' <<< "$output"
}

# Get status field (preserve internal spaces)
get_status_field() {
    local status_block="$1"
    local field="$2"
    echo "$status_block" | sed -n "s/^$field:[[:space:]]*//p" | head -n 1
}

trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

normalize_enum() {
    local raw
    raw="$(trim "$1")"
    if [[ -z "$raw" ]]; then
        return 1
    fi
    printf '%s' "$raw" | tr '[:lower:]' '[:upper:]'
}

is_allowed_value() {
    local value="$1"
    shift
    local allowed
    for allowed in "$@"; do
        if [[ "$value" == "$allowed" ]]; then
            return 0
        fi
    done
    return 1
}

build_status_block() {
    local status="$1"
    local tasks="$2"
    local files="$3"
    local tests="$4"
    local work_type="$5"
    local exit_signal="$6"
    local recommendation="$7"

    cat <<EOF
---RALPH_STATUS---
STATUS: $status
TASKS_COMPLETED_THIS_LOOP: $tasks
FILES_MODIFIED: $files
TESTS_STATUS: $tests
WORK_TYPE: $work_type
EXIT_SIGNAL: $exit_signal
RECOMMENDATION: $recommendation
---END_RALPH_STATUS---
EOF
}

normalize_status_block() {
    local status_block="$1"
    local -a errors=()
    local status tasks files tests work_type exit_signal recommendation

    if [[ -z "$status_block" ]]; then
        errors+=("STATUS_BLOCK")
    else
        status=$(normalize_enum "$(get_status_field "$status_block" "STATUS")") || status=""
        tasks="$(trim "$(get_status_field "$status_block" "TASKS_COMPLETED_THIS_LOOP")")"
        files="$(trim "$(get_status_field "$status_block" "FILES_MODIFIED")")"
        tests=$(normalize_enum "$(get_status_field "$status_block" "TESTS_STATUS")") || tests=""
        work_type=$(normalize_enum "$(get_status_field "$status_block" "WORK_TYPE")") || work_type=""
        exit_signal="$(trim "$(get_status_field "$status_block" "EXIT_SIGNAL")")"
        recommendation="$(trim "$(get_status_field "$status_block" "RECOMMENDATION")")"

        if [[ -z "$status" ]] || ! is_allowed_value "$status" "IN_PROGRESS" "COMPLETE" "BLOCKED"; then
            errors+=("STATUS")
        fi

        if [[ -z "$tests" ]] || ! is_allowed_value "$tests" "PASSING" "FAILING" "NOT_RUN"; then
            errors+=("TESTS_STATUS")
        fi

        if [[ -z "$work_type" ]] || ! is_allowed_value "$work_type" "IMPLEMENTATION" "TESTING" "DOCUMENTATION" "REFACTORING"; then
            errors+=("WORK_TYPE")
        fi

        if [[ -z "$exit_signal" ]]; then
            errors+=("EXIT_SIGNAL")
        else
            exit_signal="$(echo "$exit_signal" | tr '[:upper:]' '[:lower:]')"
            if [[ "$exit_signal" != "true" && "$exit_signal" != "false" ]]; then
                errors+=("EXIT_SIGNAL")
            fi
        fi

        if [[ -z "$recommendation" ]]; then
            errors+=("RECOMMENDATION")
        fi

        if [[ -z "$tasks" || ! "$tasks" =~ ^[0-9]+$ ]]; then
            errors+=("TASKS_COMPLETED_THIS_LOOP")
        fi

        if [[ -z "$files" || ! "$files" =~ ^[0-9]+$ ]]; then
            errors+=("FILES_MODIFIED")
        fi
    fi

    if [[ "${#errors[@]}" -gt 0 ]]; then
        status="BLOCKED"
        tasks=0
        files=0
        tests="NOT_RUN"
        work_type="TESTING"
        exit_signal="false"
        if [[ "${errors[0]}" == "STATUS_BLOCK" ]]; then
            recommendation="Missing status block"
        else
            recommendation="Invalid status fields: ${errors[*]}"
        fi
    else
        tasks="${tasks:-0}"
        files="${files:-0}"
    fi

    build_status_block "$status" "$tasks" "$files" "$tests" "$work_type" "$exit_signal" "$recommendation"
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
    echo -e "${status_color}STATUS: ${status}${NC}"
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
