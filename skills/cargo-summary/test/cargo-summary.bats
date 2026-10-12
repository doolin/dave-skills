#!/usr/bin/env bats
# Tests for skills/cargo-summary/cargo-summary.rb — the cargo digest.
# Logs are synthetic; a run goes to a stub `cargo` on PATH, never the
# real one.

load ../../../test/test_helper

script() {
  echo "$SUBJECT_DIR/cargo-summary.rb"
}

write_log() {
  cat > "$TEST_TMPDIR/cargo.log" <<'EOF'
   Compiling dreader-core v0.1.0
warning: unused variable: `x`
 --> src/lib.rs:3:9
  |
3 |     let x = 1;
  |         ^ help: prefix it with an underscore: `_x`

warning: unused variable: `x`
 --> src/lib.rs:3:9
  |
3 |     let x = 1;
  |         ^ help: prefix it with an underscore: `_x`

    Finished `test` profile [unoptimized + debuginfo] target(s) in 4.2s
     Running unittests src/lib.rs

running 3 tests
test index::tests::opens ... ok
test index::tests::searches ... FAILED
test index::tests::skips ... ignored

failures:

---- index::tests::searches stdout ----

thread 'index::tests::searches' panicked at src/index/tests.rs:40:5:
assertion `left == right` failed
  left: 1
 right: 2
note: run with `RUST_BACKTRACE=1` environment variable to display a backtrace

failures:
    index::tests::searches

test result: FAILED. 1 passed; 1 failed; 1 ignored; 0 measured; 0 filtered out; finished in 0.01s

     Running tests/cli.rs

running 2 tests
test result: ok. 2 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.00s

error: test failed, to rerun pass `-p dreader-core --lib`
EOF
}

@test "--help exits 0 with usage" {
  run "$(script)" --help
  [ "$status" -eq 0 ]
  assert_output_contains "Usage: cargo-summary.rb"
}

@test "no cargo arguments exits 10" {
  run "$(script)"
  [ "$status" -eq 10 ]
  assert_output_contains "nothing to run"
}

@test "a flag without its value exits 10" {
  run "$(script)" --log
  [ "$status" -eq 10 ]
  assert_output_contains "--log needs a value"
}

@test "--from with cargo arguments exits 10" {
  run "$(script)" --from x.log test
  [ "$status" -eq 10 ]
}

@test "--from a missing log exits 11" {
  run "$(script)" --from "$TEST_TMPDIR/absent.log"
  [ "$status" -eq 11 ]
  assert_output_contains "no log at"
}

@test "a broken policy exits 12" {
  echo "no_such_verb 1" > "$TEST_TMPDIR/policy.rb"
  write_log
  run "$(script)" --policy "$TEST_TMPDIR/policy.rb" --from "$TEST_TMPDIR/cargo.log"
  [ "$status" -eq 12 ]
  assert_output_contains "cannot read policy"
}

@test "a warning cargo printed twice is shown once, whole" {
  write_log
  run "$(script)" --from "$TEST_TMPDIR/cargo.log"
  [ "$status" -eq 0 ]
  [ "$(grep -c 'unused variable' <<< "$output")" -eq 1 ]
  assert_output_contains "help: prefix it with an underscore"
}

@test "the failed test, its panic, and the error line are shown" {
  write_log
  run "$(script)" --from "$TEST_TMPDIR/cargo.log"
  assert_output_contains "test index::tests::searches ... FAILED"
  assert_output_contains "panicked at src/index/tests.rs:40:5"
  assert_output_contains "  left: 1"
  assert_output_contains "error: test failed, to rerun pass"
}

@test "test results are tallied across binaries" {
  write_log
  run "$(script)" --from "$TEST_TMPDIR/cargo.log"
  assert_output_contains "tests: 3 passed, 1 failed, 1 ignored (2 test binaries)"
}

@test "passing tests and progress lines are left out" {
  write_log
  run "$(script)" --from "$TEST_TMPDIR/cargo.log"
  [[ "$output" != *"opens ... ok"* ]]
  [[ "$output" != *"Compiling"* ]]
  assert_output_contains "Finished \`test\` profile"
}

@test "blocks past the policy's limit are counted, not printed" {
  write_log
  cat > "$TEST_TMPDIR/policy.rb" <<'EOF'
block_from(/\A(error|warning): /)
show_at_most 1, lines_per_block: 2
EOF
  run "$(script)" --policy "$TEST_TMPDIR/policy.rb" --from "$TEST_TMPDIR/cargo.log"
  [ "$status" -eq 0 ]
  assert_output_contains "… 1 more"
  [[ "$output" != *"3 |"* ]]
}

stub_cargo() {
  mkdir -p "$TEST_TMPDIR/bin"
  cat > "$TEST_TMPDIR/bin/cargo" <<'EOF'
#!/usr/bin/env bash
echo "args: $* color=$CARGO_TERM_COLOR"
echo "error[E0425]: cannot find value \`y\` in this scope" >&2
echo " --> src/lib.rs:4:5" >&2
echo "" >&2
exit 101
EOF
  chmod +x "$TEST_TMPDIR/bin/cargo"
}

@test "a run passes the arguments, keeps the log, and mirrors failure as 1" {
  stub_cargo
  cd "$TEST_TMPDIR"
  PATH="$TEST_TMPDIR/bin:$PATH" run "$(script)" build -p core
  [ "$status" -eq 1 ]
  grep -q "args: build -p core color=never" "$TEST_TMPDIR/tmp/cargo-summary.log"
  assert_output_contains "error[E0425]: cannot find value"
  assert_output_contains "full log: tmp/cargo-summary.log"
  assert_output_contains "cargo exit: 101"
}

@test "--log puts the full output where it is told" {
  stub_cargo
  cd "$TEST_TMPDIR"
  PATH="$TEST_TMPDIR/bin:$PATH" run "$(script)" --log out/c.log check
  [ -f "$TEST_TMPDIR/out/c.log" ]
}
