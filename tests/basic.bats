#!/usr/bin/env bats

setup() {
  ROOT_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  export RALPH_DIR="$ROOT_DIR"
  export RALPH_NO_SPINNER=1
  export RALPH_NOW_CMD="printf '2000-01-01T00:00:00Z'"
  export SLEEP_CMD=":"
}

@test "claude backend fake fixture produces status and exits cleanly" {
  export RALPH_BACKEND=claude
  export CLAUDE_CMD="$ROOT_DIR/tests/bin/fake-claude"
  export FIXTURE="$ROOT_DIR/tests/fixtures/claude/valid-stream.jsonl"

  run "$ROOT_DIR/ralph.sh" 1

  [ "$status" -eq 0 ]
  [[ "$output" == *"Using backend: claude"* ]]
  [[ "$output" == *"STATUS: COMPLETE"* ]]
  [[ "$output" == *"✓ Complete!"* ]]
}

@test "codex backend fake fixture produces status and exits cleanly" {
  export RALPH_BACKEND=codex
  export CODEX_CMD="$ROOT_DIR/tests/bin/fake-codex"
  export FIXTURE="$ROOT_DIR/tests/fixtures/codex/valid-stream.jsonl"

  run "$ROOT_DIR/ralph.sh" 1

  [ "$status" -eq 0 ]
  [[ "$output" == *"Using backend: codex"* ]]
  [[ "$output" == *"STATUS: COMPLETE"* ]]
  [[ "$output" == *"✓ Complete!"* ]]
}

@test "missing status block returns error" {
  export RALPH_BACKEND=claude
  export CLAUDE_CMD="$ROOT_DIR/tests/bin/fake-claude"
  export FIXTURE="$ROOT_DIR/tests/fixtures/claude/missing-status.jsonl"

  run "$ROOT_DIR/ralph.sh" 1

  [ "$status" -eq 1 ]
  [[ "$output" == *"No status block found"* ]]
}
