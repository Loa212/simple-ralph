#!/usr/bin/env bats

setup() {
  ROOT_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  if [[ "${RUN_LIVE_TESTS:-}" != "1" ]]; then
    skip "RUN_LIVE_TESTS not set"
  fi
  export RALPH_NO_SPINNER=1
  export RALPH_LOOP_LIMIT=1
  export RALPH_PROMPT_FILE="$ROOT_DIR/tests/fixtures/common/smoke-prompt.md"
}

run_with_timeout() {
  local timeout_sec="$1"
  shift

  if command -v timeout >/dev/null 2>&1; then
    timeout "$timeout_sec" "$@"
    return $?
  fi

  if command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$timeout_sec" "$@"
    return $?
  fi

  perl -e 'alarm shift; exec @ARGV' "$timeout_sec" "$@"
}

preflight_cli() {
  local name="$1"
  shift

  if ! command -v "$1" >/dev/null 2>&1; then
    skip "$name CLI not found"
  fi

  local timeout_sec="${PREFLIGHT_TIMEOUT_SECONDS:-15}"
  run run_with_timeout "$timeout_sec" "$@" --version
  if [[ "$status" -ne 0 ]]; then
    echo "$output"
    fail "$name CLI preflight failed or timed out"
  fi
}

@test "live smoke claude produces status block" {
  export RALPH_BACKEND=claude
  preflight_cli "Claude" claude
  run run_with_timeout "${SMOKE_TIMEOUT_SECONDS:-60}" "$ROOT_DIR/ralph.sh" 1

  if [ "$status" -ne 0 ]; then
    echo "$output"
  fi
  [ "$status" -eq 0 ]
  [[ "$output" == *"---RALPH_STATUS---"* ]]
}

@test "live smoke codex produces status block" {
  export RALPH_BACKEND=codex
  preflight_cli "Codex" codex
  run run_with_timeout "${SMOKE_TIMEOUT_SECONDS:-60}" "$ROOT_DIR/ralph.sh" 1

  if [ "$status" -ne 0 ]; then
    echo "$output"
  fi
  [ "$status" -eq 0 ]
  [[ "$output" == *"---RALPH_STATUS---"* ]]
}
