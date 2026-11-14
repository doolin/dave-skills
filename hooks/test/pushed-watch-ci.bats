#!/usr/bin/env bats
# Tests for hooks/pushed-watch-ci.rb -- the UserPromptSubmit hook that
# turns a reported push into a watch-ci run. Always exits 0.

hook() {
  echo "$BATS_TEST_DIRNAME/../pushed-watch-ci.rb"
}

@test "a prompt that says pushed → additionalContext for watch-ci, exit 0" {
  run bash -c "printf '%s' '{\"prompt\":\"I pushed.\"}' | $(hook)"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"hookEventName":"UserPromptSubmit"'* ]]
  [[ "$output" == *"watch-ci/watch-ci with run_in_background"* ]]
}

@test "case does not matter" {
  run bash -c "printf '%s' '{\"prompt\":\"Pushed\"}' | $(hook)"
  [ "$status" -eq 0 ]
  [[ "$output" == *"additionalContext"* ]]
}

@test "push, pushing, or no mention → nothing, exit 0" {
  for prompt in "push it" "Are you pushing these?" "commit"; do
    run bash -c "printf '%s' '{\"prompt\":\"$prompt\"}' | $(hook)"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  done
}

@test "unreadable input → nothing, exit 0" {
  run bash -c "printf '%s' 'not json' | $(hook)"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
