#!/usr/bin/env bats
# Tests for skills/index-audit/index-audit. Each test builds a throwaway
# git repo in $TEST_TMPDIR.

load ../../../test/test_helper

script() {
  echo "$SUBJECT_DIR/index-audit"
}

# A repo with one committed file, cwd inside it.
init_repo() {
  cd "$TEST_TMPDIR"
  git init -q -b main
  git config user.email test@example.com
  git config user.name test
  echo one > committed.txt
  git add committed.txt
  git commit -qm init
}

@test "--help exits 0 with usage" {
  run "$(script)" --help
  [ "$status" -eq 0 ]
  assert_output_contains "Usage:"
}

@test "unknown argument exits 12" {
  run "$(script)" --bogus
  [ "$status" -eq 12 ]
}

@test "outside a git work tree exits 12" {
  cd "$TEST_TMPDIR"
  run "$(script)"
  [ "$status" -eq 12 ]
  assert_output_contains "not inside a git work tree"
}

@test "nothing staged exits 3 and still lists what is outside the index" {
  init_repo
  echo two > loose.txt
  run "$(script)"
  [ "$status" -eq 3 ]
  assert_output_contains "Index: nothing staged"
  assert_output_contains "?? loose.txt"
}

@test "staged file listed with diffstat; unstaged and untracked listed outside" {
  init_repo
  echo staged > staged.txt
  git add staged.txt
  echo edit >> committed.txt
  echo loose > loose.txt
  run "$(script)"
  [ "$status" -eq 0 ]
  assert_output_contains "Staged:"
  assert_output_contains "staged.txt"
  assert_output_contains "1 file changed"
  assert_output_contains "Outside the index:"
  assert_output_contains " M committed.txt"
  assert_output_contains "?? loose.txt"
}

@test "clean tree apart from the index says so" {
  init_repo
  echo staged > staged.txt
  git add staged.txt
  run "$(script)"
  [ "$status" -eq 0 ]
  assert_output_contains "Outside the index: (nothing)"
}

@test "a file both staged and further modified appears in both lists" {
  init_repo
  echo edit >> committed.txt
  git add committed.txt
  echo more >> committed.txt
  run "$(script)"
  [ "$status" -eq 0 ]
  assert_output_contains "committed.txt |"
  assert_output_contains "MM committed.txt"
}

@test "staged .env and log draw warnings but exit 0 without --strict" {
  init_repo
  echo SECRET=1 > .env
  mkdir -p tmp
  echo x > tmp/run.log
  git add -f .env tmp/run.log
  run "$(script)"
  [ "$status" -eq 0 ]
  assert_output_contains "WARN: staged .env (environment file)"
  assert_output_contains "WARN: staged tmp/run.log (log file)"
}

@test "--strict turns a warning into exit 4" {
  init_repo
  echo SECRET=1 > .env
  git add -f .env
  run "$(script)" --strict
  [ "$status" -eq 4 ]
  assert_output_contains "WARN: staged .env"
}

@test "--strict without warnings still exits 0" {
  init_repo
  echo staged > staged.txt
  git add staged.txt
  run "$(script)" --strict
  [ "$status" -eq 0 ]
}

@test "a staged deletion counts as staged" {
  init_repo
  git rm -q committed.txt
  run "$(script)"
  [ "$status" -eq 0 ]
  assert_output_contains "committed.txt"
}

@test "-C audits another directory without changing the caller's cwd" {
  init_repo
  echo staged > staged.txt
  git add staged.txt
  cd /
  run "$(script)" -C "$TEST_TMPDIR"
  [ "$status" -eq 0 ]
  assert_output_contains "staged.txt"
}
