#!/usr/bin/env bats

setup() {
  ROOT_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  if [[ "${RUN_LIVE_TESTS:-}" != "1" ]]; then
    skip "RUN_LIVE_TESTS not set"
  fi
  export RALPH_NO_SPINNER=1
  export RALPH_LOOP_LIMIT=1
}

@test "live smoke claude produces status block" {
  export RALPH_BACKEND=claude
  run "$ROOT_DIR/ralph.sh" 1

  [ "$status" -eq 0 ]
  [[ "$output" == *"---RALPH_STATUS---"* ]]
}

@test "live smoke codex produces status block" {
  export RALPH_BACKEND=codex
  run "$ROOT_DIR/ralph.sh" 1

  [ "$status" -eq 0 ]
  [[ "$output" == *"---RALPH_STATUS---"* ]]
}
