#!/usr/bin/env bats
# Tests for hooks/session-resume.sh — the SessionStart resume banner.
# Always exits 0. test_helper exports REPO_ROOT as the scratch dir, so
# the hook reads $TEST_TMPDIR/.development/active.

load test_helper

hook() {
  echo "$HOOKS_DIR/session-resume.sh"
}

@test "no active/ directory → says so, exit 0" {
  run "$(hook)"
  [ "$status" -eq 0 ]
  assert_output_contains "no active/ directory"
}

@test "empty active/ → 'no active tickets', exit 0" {
  fixture_dev_tree
  run "$(hook)"
  [ "$status" -eq 0 ]
  assert_output_contains "no active tickets"
}

@test "active ticket without ## Next → header line plus placeholder" {
  fixture_ticket 398 active "LS deck refinement"
  run "$(hook)"
  [ "$status" -eq 0 ]
  assert_output_contains "resume: DBB-0398  LS deck refinement  (updated ?)"
  assert_output_contains "no ## Next section"
}

@test "active ticket with ## Next → section body indented, stops at next H2" {
  fixture_ticket 63 active "Framework laptop build log"
  f="$TEST_TMPDIR/.development/active/DBB-0063-test.md"
  {
    echo
    echo "## Next"
    echo
    echo "Export DBB-0067 to static Markdown."
    echo
    echo "## Notes"
    echo
    echo "Not part of the resume."
  } >> "$f"
  run "$(hook)"
  [ "$status" -eq 0 ]
  assert_output_contains "  Export DBB-0067 to static Markdown."
  [[ "$output" != *"Not part of the resume."* ]]
}

@test "updated field read from frontmatter, comment stripped" {
  fixture_dev_tree
  cat > "$TEST_TMPDIR/.development/active/DBB-0113-test.md" <<'EOF'
---
id: DBB-0113
title: Agent tooling
status: in_progress
updated: 2026-07-26   # last pass
---
EOF
  run "$(hook)"
  [ "$status" -eq 0 ]
  assert_output_contains "(updated 2026-07-26)"
}

@test "several active tickets → one header each, sorted by filename" {
  fixture_ticket 398 active "Second"
  fixture_ticket 63 active "First"
  run "$(hook)"
  [ "$status" -eq 0 ]
  first_line=$(echo "$output" | grep -n 'resume: DBB-0063' | cut -d: -f1)
  second_line=$(echo "$output" | grep -n 'resume: DBB-0398' | cut -d: -f1)
  [ "$first_line" -lt "$second_line" ]
}

@test "stewardship ticket listed only while it carries ## Next" {
  fixture_dev_tree
  fixture_ticket 19 stewardship "Gem stewardship"
  fixture_ticket 113 stewardship "Agent tooling"
  {
    echo
    echo "## Next"
    echo
    echo "Teach commit-message-precommit to reject the session trailer."
  } >> "$TEST_TMPDIR/.development/stewardship/DBB-0113-test.md"
  run "$(hook)"
  [ "$status" -eq 0 ]
  assert_output_contains "resume: DBB-0113  Agent tooling"
  assert_output_contains "  Teach commit-message-precommit to reject the session trailer."
  [[ "$output" != *"DBB-0019"* ]]
}

@test "paused stewardship ticket shows even when active/ is empty" {
  fixture_dev_tree
  fixture_ticket 113 stewardship "Agent tooling"
  printf '\n## Next\n\nDo the thing.\n' >> "$TEST_TMPDIR/.development/stewardship/DBB-0113-test.md"
  run "$(hook)"
  [ "$status" -eq 0 ]
  assert_output_contains "resume: DBB-0113"
  [[ "$output" != *"no active tickets"* ]]
}

@test "CLAUDE_ACTIVE_DIR overrides the default location" {
  mkdir -p "$TEST_TMPDIR/elsewhere"
  cat > "$TEST_TMPDIR/elsewhere/OC-0007-thing.md" <<'EOF'
---
id: OC-0007
title: Other prefix
status: in_progress
---
EOF
  CLAUDE_ACTIVE_DIR="$TEST_TMPDIR/elsewhere" run "$(hook)"
  [ "$status" -eq 0 ]
  assert_output_contains "resume: OC-0007  Other prefix"
}
