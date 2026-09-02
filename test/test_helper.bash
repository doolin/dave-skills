#!/usr/bin/env bash
# Shared bats fixtures for this repo's test suites (hooks/test/*.bats,
# skills/<name>/test/*.bats).
#
# Load with a path relative to the test file, e.g.
#   load ../../test/test_helper          # from hooks/test/
#   load ../../../test/test_helper       # from skills/<name>/test/
#
# Each test gets a fresh $TEST_TMPDIR, REPO_ROOT pointing at it (so a
# tool that defaults to the git toplevel reads the fixture tree instead
# of this repo), and $SUBJECT_DIR: the directory holding the code under
# test, i.e. the parent of the test directory.

setup() {
  TEST_TMPDIR="$(mktemp -d -t bats-dave-skills.XXXXXX)"
  SUBJECT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  REPO_ROOT="$TEST_TMPDIR"
  export TEST_TMPDIR SUBJECT_DIR REPO_ROOT
}

teardown() {
  if [ -n "${TEST_TMPDIR:-}" ] && [ -d "$TEST_TMPDIR" ]; then
    rm -rf "$TEST_TMPDIR"
  fi
}

# Create the full-form .development/ subdirs without any tickets.
fixture_dev_tree() {
  mkdir -p "$TEST_TMPDIR/.development"/{backlog,active,done,stewardship}
}

# Drop a minimal ticket fixture: $1 numeric id, $2 dir, $3 title.
fixture_ticket() {
  local id="$1"
  local dir="${2:-active}"
  local title="${3:-Test ticket}"
  local padded
  printf -v padded '%04d' "$id"
  mkdir -p "$TEST_TMPDIR/.development/$dir"
  cat > "$TEST_TMPDIR/.development/$dir/DBB-${padded}-test.md" <<EOF
---
id: DBB-${padded}
title: ${title}
type: task
status: in_progress
---

## Why
Test fixture.
EOF
}

# Assert that $output (set by `run`) contains a substring.
# shellcheck disable=SC2154  # bats assigns $output
assert_output_contains() {
  local needle="$1"
  [[ "$output" == *"$needle"* ]] || {
    echo "expected output to contain: $needle"
    echo "actual output:"
    echo "$output"
    return 1
  }
}
