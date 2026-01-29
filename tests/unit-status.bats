#!/usr/bin/env bats

setup() {
  ROOT_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
  source "$ROOT_DIR/lib/config.sh"
  source "$ROOT_DIR/lib/utils.sh"
}

@test "extract_status prefers last status block" {
  output=$'---RALPH_STATUS---\nSTATUS: IN_PROGRESS\nTASKS_COMPLETED_THIS_LOOP: 0\nFILES_MODIFIED: 0\nTESTS_STATUS: NOT_RUN\nWORK_TYPE: TESTING\nEXIT_SIGNAL: false\nRECOMMENDATION: keep going\n---END_RALPH_STATUS---\n---RALPH_STATUS---\nSTATUS: COMPLETE\nTASKS_COMPLETED_THIS_LOOP: 1\nFILES_MODIFIED: 1\nTESTS_STATUS: PASSING\nWORK_TYPE: IMPLEMENTATION\nEXIT_SIGNAL: true\nRECOMMENDATION: stop\n---END_RALPH_STATUS---'
  result="$(extract_status "$output")"

  [[ "$result" == *"STATUS: COMPLETE"* ]]
  [[ "$result" != *"STATUS: IN_PROGRESS"* ]]
}

@test "normalize_status_block coerces enum casing" {
  raw_block=$'---RALPH_STATUS---\nSTATUS: complete\nTASKS_COMPLETED_THIS_LOOP: 2\nFILES_MODIFIED: 3\nTESTS_STATUS: passing\nWORK_TYPE: implementation\nEXIT_SIGNAL: false\nRECOMMENDATION: all good\n---END_RALPH_STATUS---'
  normalized="$(normalize_status_block "$raw_block")"

  [ "$(get_status_field "$normalized" "STATUS")" = "COMPLETE" ]
  [ "$(get_status_field "$normalized" "TESTS_STATUS")" = "PASSING" ]
  [ "$(get_status_field "$normalized" "WORK_TYPE")" = "IMPLEMENTATION" ]
  [ "$(get_status_field "$normalized" "EXIT_SIGNAL")" = "false" ]
}

@test "normalize_status_block blocks invalid enums" {
  raw_block=$'---RALPH_STATUS---\nSTATUS: DONE\nTASKS_COMPLETED_THIS_LOOP: 1\nFILES_MODIFIED: 1\nTESTS_STATUS: NOT_RUN\nWORK_TYPE: TESTING\nEXIT_SIGNAL: false\nRECOMMENDATION: nope\n---END_RALPH_STATUS---'
  normalized="$(normalize_status_block "$raw_block")"

  [ "$(get_status_field "$normalized" "STATUS")" = "BLOCKED" ]
  [[ "$(get_status_field "$normalized" "RECOMMENDATION")" == *"Invalid status fields"* ]]
}

@test "normalize_status_block enforces strict exit signal" {
  raw_block=$'---RALPH_STATUS---\nSTATUS: COMPLETE\nTASKS_COMPLETED_THIS_LOOP: 1\nFILES_MODIFIED: 1\nTESTS_STATUS: PASSING\nWORK_TYPE: IMPLEMENTATION\nEXIT_SIGNAL: YES\nRECOMMENDATION: stop\n---END_RALPH_STATUS---'
  normalized="$(normalize_status_block "$raw_block")"

  [ "$(get_status_field "$normalized" "STATUS")" = "BLOCKED" ]
  [[ "$(get_status_field "$normalized" "RECOMMENDATION")" == *"EXIT_SIGNAL"* ]]
}

@test "normalize_status_block marks missing block as blocked" {
  normalized="$(normalize_status_block "")"

  [ "$(get_status_field "$normalized" "STATUS")" = "BLOCKED" ]
  [[ "$(get_status_field "$normalized" "RECOMMENDATION")" == *"Missing status block"* ]]
}
