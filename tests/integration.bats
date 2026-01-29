#!/usr/bin/env bats

setup() {
  ROOT_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  export RALPH_BACKEND=claude
  export CLAUDE_CMD="$ROOT_DIR/tests/bin/fake-claude"
  export RALPH_NO_SPINNER=1
  export RALPH_NOW_CMD="printf '2000-01-01T00:00:00Z'"
  export SLEEP_CMD=":"
  export RALPH_LOOP_LIMIT=5
  export RALPH_FINDINGS_PATH="$BATS_TEST_TMPDIR/findings.txt"
}

progress_count() {
  local progress_file="$ROOT_DIR/progress.txt"
  if [[ -f "$progress_file" ]]; then
    grep -c "^=== Loop" "$progress_file" || true
  else
    printf '0'
  fi
}

@test "happy path exits before max loops and logs progress" {
  local before after
  local fixture_state="$BATS_TEST_TMPDIR/fixture_state_happy"
  rm -f "$fixture_state"

  export FIXTURE_SEQUENCE="$ROOT_DIR/tests/fixtures/claude/in-progress.jsonl:$ROOT_DIR/tests/fixtures/claude/complete.jsonl:$ROOT_DIR/tests/fixtures/claude/exit-signal.jsonl"
  export FIXTURE_STATE_FILE="$fixture_state"

  before="$(progress_count)"
  run "$ROOT_DIR/ralph.sh" 100
  after="$(progress_count)"

  [ "$status" -eq 0 ]
  [[ "$output" == *"LOOP 1"* ]]
  [[ "$output" == *"LOOP 2"* ]]
  [[ "$output" == *"LOOP 3"* ]]
  [[ "$output" != *"LOOP 4"* ]]
  [ $((after - before)) -eq 3 ]
}

@test "rate limit recovery resumes and logs once" {
  local before after
  local fixture_state="$BATS_TEST_TMPDIR/fixture_state_rate"
  rm -f "$fixture_state"

  export FIXTURE_SEQUENCE="$ROOT_DIR/tests/fixtures/claude/rate-limit.jsonl:$ROOT_DIR/tests/fixtures/claude/exit-signal.jsonl"
  export FIXTURE_STATE_FILE="$fixture_state"

  before="$(progress_count)"
  run "$ROOT_DIR/ralph.sh" 100
  after="$(progress_count)"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Rate limited"* ]]
  [[ "$output" == *"Resuming"* ]]
  [[ "$output" == *"STATUS: COMPLETE"* ]]
  [ $((after - before)) -eq 1 ]
}

@test "missing status block marks blocked" {
  export FIXTURE="$ROOT_DIR/tests/fixtures/claude/missing-status.jsonl"

  run "$ROOT_DIR/ralph.sh" 1

  [ "$status" -eq 1 ]
  [[ "$output" == *"STATUS: BLOCKED"* ]]
  [[ "$output" == *"Missing status block"* ]]
}

@test "malformed backend output fails gracefully" {
  export FIXTURE="$ROOT_DIR/tests/fixtures/claude/malformed.jsonl"

  run "$ROOT_DIR/ralph.sh" 1

  [ "$status" -eq 1 ]
  [[ "$output" == *"STATUS: BLOCKED"* ]]
  [[ "$output" != *"PASSING"* ]]
}

@test "exit signal respected immediately" {
  export FIXTURE="$ROOT_DIR/tests/fixtures/claude/exit-signal.jsonl"

  run "$ROOT_DIR/ralph.sh" 100

  [ "$status" -eq 0 ]
  [[ "$output" == *"LOOP 1"* ]]
  [[ "$output" != *"LOOP 2"* ]]
}
