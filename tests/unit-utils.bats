#!/usr/bin/env bats

setup() {
  ROOT_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  source "$ROOT_DIR/lib/config.sh"
  source "$ROOT_DIR/lib/utils.sh"
}

# --- ralph_now ---

@test "ralph_now uses RALPH_NOW_CMD override" {
  export RALPH_NOW_CMD="printf '2025-06-15T12:00:00Z'"
  result="$(ralph_now)"

  [ "$result" = "2025-06-15T12:00:00Z" ]
}

@test "ralph_now returns ISO8601 UTC without override" {
  unset RALPH_NOW_CMD
  result="$(ralph_now)"

  [[ "$result" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}

# --- ralph_sleep ---

@test "ralph_sleep uses SLEEP_CMD override" {
  export SLEEP_CMD="printf 'slept'"
  result="$(ralph_sleep 5)"

  [ "$result" = "slept" ]
}

@test "ralph_sleep passes duration argument to SLEEP_CMD" {
  export SLEEP_CMD="printf 'dur=%s'"
  result="$(ralph_sleep 42)"

  [ "$result" = "dur=42" ]
}

# --- trim ---

@test "trim removes leading and trailing whitespace" {
  result="$(trim "   hello world  ")"

  [ "$result" = "hello world" ]
}

@test "trim removes leading whitespace only" {
  result="$(trim "   hello")"

  [ "$result" = "hello" ]
}

@test "trim removes trailing whitespace only" {
  result="$(trim "hello   ")"

  [ "$result" = "hello" ]
}

@test "trim preserves string with no extra whitespace" {
  result="$(trim "hello")"

  [ "$result" = "hello" ]
}

@test "trim returns empty for whitespace-only input" {
  result="$(trim "   ")"

  [ "$result" = "" ]
}

# --- normalize_enum ---

@test "normalize_enum trims and uppercases input" {
  result="$(normalize_enum "  MiXeD  ")"

  [ "$result" = "MIXED" ]
}

@test "normalize_enum uppercases lowercase input" {
  result="$(normalize_enum "passing")"

  [ "$result" = "PASSING" ]
}

@test "normalize_enum returns non-zero on empty input" {
  run normalize_enum ""

  [ "$status" -ne 0 ]
}

@test "normalize_enum returns non-zero on whitespace-only input" {
  run normalize_enum "   "

  [ "$status" -ne 0 ]
}

# --- is_allowed_value ---

@test "is_allowed_value returns success when value matches" {
  run is_allowed_value "B" "A" "B" "C"

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "is_allowed_value returns failure when value does not match" {
  run is_allowed_value "D" "A" "B" "C"

  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

@test "is_allowed_value matches single allowed value" {
  is_allowed_value "OK" "OK"
}

@test "is_allowed_value returns failure for empty allowed list" {
  run is_allowed_value "ANYTHING"

  [ "$status" -eq 1 ]
}
