#!/usr/bin/env bats

setup() {
  ROOT_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  export RALPH_DIR="$BATS_TEST_TMPDIR/ralph"
  export RALPH_BACKEND=claude
  export RALPH_NOW_CMD="printf '2000-01-01T00:00:00Z'"
  mkdir -p "$RALPH_DIR"
  source "$ROOT_DIR/lib/config.sh"
  source "$ROOT_DIR/lib/utils.sh"
  source "$ROOT_DIR/lib/tokens.sh"
}

@test "init_tokens creates token file" {
  rm -f "$TOKEN_FILE"
  init_tokens

  [ -f "$TOKEN_FILE" ]
  run jq -e . "$TOKEN_FILE"
  [ "$status" -eq 0 ]
}

@test "log_tokens appends valid JSON" {
  rm -f "$TOKEN_FILE"
  init_tokens
  log_tokens 1 "COMPLETE" 10 5

  run jq -e '.loops | length == 1' "$TOKEN_FILE"
  [ "$status" -eq 0 ]
}

@test "log_tokens rebuilds invalid token file" {
  printf 'not json' > "$TOKEN_FILE"
  log_tokens 2 "COMPLETE" 4 6

  run jq -e '.loops | length == 1' "$TOKEN_FILE"
  [ "$status" -eq 0 ]
}

@test "log_tokens uses atomic write" {
  rm -f "$TOKEN_FILE" "$TOKEN_FILE.tmp"
  init_tokens
  log_tokens 3 "COMPLETE" 2 3

  [ ! -f "$TOKEN_FILE.tmp" ]
}
