#!/usr/bin/env bats

setup() {
  ROOT_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  export RALPH_RATE_LIMIT_WAIT=2
  export SLEEP_CMD=":"
  source "$ROOT_DIR/lib/config.sh"
  source "$ROOT_DIR/lib/utils.sh"
  source "$ROOT_DIR/lib/ratelimit.sh"
}

@test "check_rate_limit detects rate limit" {
  line='{"type":"assistant","error":"rate_limit","message":{"content":[{"type":"text","text":"Rate limited for tests"}]}}'

  check_rate_limit "$line"
  [ "$?" -eq 0 ]
  [ "$RATE_LIMIT_MSG" = "Rate limited for tests" ]
}

@test "handle_rate_limit uses sleep override" {
  run handle_rate_limit "Rate limited for tests"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Waiting 2 minutes"* ]]
  [[ "$output" == *"Resuming"* ]]
}
