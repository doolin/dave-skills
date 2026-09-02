#!/usr/bin/env bats
# Tests for skills/rspec-summary/rspec-summary.rb — the full-run digest.
# Every test feeds a synthetic rspec log; --run is never exercised
# against a real suite.

load ../../../test/test_helper

script() {
  echo "$SUBJECT_DIR/rspec-summary.rb"
}

write_log() {
  cat > "$TEST_TMPDIR/rspec.log" <<'EOF'
Randomized with seed 4242

Failures:

  1) Thing does stuff
     Failure/Error: expect(1).to eq(2)

Finished in 12.3 seconds (files took 1.9 seconds to load)
3361 examples, 24 failures, 81 pending

Failed examples:

rspec ./spec/e2e/page_cancel_spec.rb:12 # cancel
rspec ./spec/e2e/page_cancel_spec.rb:30 # cancel again
rspec ./spec/e2e/project_board_spec.rb:8 # board
rspec ./spec/models/page_spec.rb:44 # page

Coverage report generated for RSpec to coverage/index.html
Line coverage: 5625 / 5625 (100.00%)
Branch coverage: 1397 / 1397 (100.00%)
EOF
}

@test "--help exits 0 with usage" {
  run "$(script)" --help
  [ "$status" -eq 0 ]
  assert_output_contains "Usage: rspec-summary.rb"
}

@test "unknown option exits 10" {
  run "$(script)" --bogus
  [ "$status" -eq 10 ]
  assert_output_contains "unknown option"
}

@test "two positional args exits 10" {
  run "$(script)" a.log b.log
  [ "$status" -eq 10 ]
}

@test "missing log exits 11 with a hint" {
  run "$(script)" "$TEST_TMPDIR/absent.log"
  [ "$status" -eq 11 ]
  assert_output_contains "no log at"
}

@test "log without a summary line exits 11" {
  echo "Randomized with seed 1" > "$TEST_TMPDIR/partial.log"
  run "$(script)" "$TEST_TMPDIR/partial.log"
  [ "$status" -eq 11 ]
  assert_output_contains "no rspec summary line"
}

@test "prints tally, both coverage lines, and failures by directory" {
  write_log
  run "$(script)" "$TEST_TMPDIR/rspec.log"
  [ "$status" -eq 0 ]
  assert_output_contains "3361 examples, 24 failures, 81 pending"
  assert_output_contains "Line coverage: 5625 / 5625 (100.00%)"
  assert_output_contains "Branch coverage: 1397 / 1397 (100.00%)"
  assert_output_contains "   3  spec/e2e"
  assert_output_contains "   1  spec/models"
}

@test "directories sorted by failure count, then name" {
  write_log
  run "$(script)" "$TEST_TMPDIR/rspec.log"
  e2e_line=$(echo "$output" | grep -n 'spec/e2e' | cut -d: -f1)
  models_line=$(echo "$output" | grep -n 'spec/models' | cut -d: -f1)
  [ "$e2e_line" -lt "$models_line" ]
}

@test "--files adds per-file counts" {
  write_log
  run "$(script)" --files "$TEST_TMPDIR/rspec.log"
  [ "$status" -eq 0 ]
  assert_output_contains "Failures by file:"
  assert_output_contains "   2  spec/e2e/page_cancel_spec.rb"
}

@test "without --files the per-file section is absent" {
  write_log
  run "$(script)" "$TEST_TMPDIR/rspec.log"
  [[ "$output" != *"Failures by file:"* ]]
}

@test "coverage floor breach is surfaced as FLOOR" {
  write_log
  echo "Line coverage (98.40%) is below the expected minimum coverage (100.00%)." >> "$TEST_TMPDIR/rspec.log"
  run "$(script)" "$TEST_TMPDIR/rspec.log"
  assert_output_contains "FLOOR: Line coverage (98.40%) is below"
}

@test "SimpleCov abort is surfaced as ABORTED" {
  write_log
  echo "Stopped processing SimpleCov as a previous error not related to SimpleCov has been detected" >> "$TEST_TMPDIR/rspec.log"
  run "$(script)" "$TEST_TMPDIR/rspec.log"
  assert_output_contains "ABORTED: Stopped processing SimpleCov"
}

# --run against a stub `bundle` on PATH: proves the log is written,
# the stale resultset is cleared, the summary is printed, and the
# suite's exit status is mirrored.
stub_bundle() {
  mkdir -p "$TEST_TMPDIR/bin"
  cat > "$TEST_TMPDIR/bin/bundle" <<'EOF'
#!/usr/bin/env bash
echo "Finished in 0.1 seconds"
echo "2 examples, 1 failure"
echo "rspec ./spec/e2e/x_spec.rb:1 # x"
echo "Line coverage: 1 / 2 (50.00%)"
echo "Branch coverage: 0 / 1 (0.00%)"
exit 1
EOF
  chmod +x "$TEST_TMPDIR/bin/bundle"
}

@test "--run writes the log, clears the resultset, summarizes, mirrors exit 1" {
  stub_bundle
  mkdir -p "$TEST_TMPDIR/coverage"
  echo '{}' > "$TEST_TMPDIR/coverage/.resultset.json"
  cd "$TEST_TMPDIR"
  PATH="$TEST_TMPDIR/bin:$PATH" run "$(script)" --run
  [ "$status" -eq 1 ]
  [ -f "$TEST_TMPDIR/tmp/rspec-full.log" ]
  [ ! -f "$TEST_TMPDIR/coverage/.resultset.json" ]
  assert_output_contains "2 examples, 1 failure"
  assert_output_contains "   1  spec/e2e"
  assert_output_contains "rspec exit: 1"
}

@test "a green log prints no failure section" {
  cat > "$TEST_TMPDIR/green.log" <<'EOF'
Finished in 1.0 seconds
12 examples, 0 failures
Line coverage: 10 / 10 (100.00%)
Branch coverage: 2 / 2 (100.00%)
EOF
  run "$(script)" "$TEST_TMPDIR/green.log"
  [ "$status" -eq 0 ]
  assert_output_contains "12 examples, 0 failures"
  [[ "$output" != *"Failures by"* ]]
}
