---
name: cargo-summary
description: Run cargo (build, test, clippy, check) and print only the lines that decide the next step — each distinct error and warning whole, each panic with its left/right, the tests that failed, and one tally of the test results — keeping the full output in a log. Use in place of `cargo … 2>&1 | grep … | head` in any Rust repo, or with --from on a log already written.
allowed-tools: Bash(~/.claude/skills/cargo-summary/cargo-summary.rb*)
---

# cargo-summary

`cargo test` in a workspace prints hundreds of lines; a handful say
whether to go on. The pipeline that picked them out (`2>&1 | grep -E
"^(error|warning)|FAILED|panicked" -A8 | head -60`) matched no
allowlist prefix, so it prompted every time, and `head` dropped
whatever fell past its count without saying so.

## Run

From the directory cargo would run in:

```bash
~/.claude/skills/cargo-summary/cargo-summary.rb test -p dreader-core index::
~/.claude/skills/cargo-summary/cargo-summary.rb build -p dreader-app
~/.claude/skills/cargo-summary/cargo-summary.rb --log tmp/clippy.log clippy --all-targets
~/.claude/skills/cargo-summary/cargo-summary.rb --from tmp/cargo-summary.log
```

Our options come first; the first word that is not one of them begins
cargo's arguments. The full output goes to `tmp/cargo-summary.log`
(or `--log PATH`), with `CARGO_TERM_COLOR=never`.

Output:

```text
warning: unused variable: `x`
 --> src/lib.rs:3:9
  |
3 |     let x = 1;
  |         ^ help: prefix it with an underscore: `_x`

    Finished `test` profile [unoptimized + debuginfo] target(s) in 4.2s

test index::tests::searches ... FAILED

thread 'index::tests::searches' panicked at src/index/tests.rs:40:5:
assertion `left == right` failed
  left: 1
 right: 2

error: test failed, to rerun pass `-p dreader-core --lib`

tests: 3 passed, 1 failed, 1 ignored (2 test binaries)

full log: tmp/cargo-summary.log
cargo exit: 101
```

## Reading it

- Items come in the order cargo printed them, each distinct one once:
  cargo repeats a warning for every target that compiles the file.
- `… N more` means the policy's limit cut the list; the rest is in the
  log, which is read with the Read tool.
- The tally adds up every `test result:` line, so a workspace run is
  one line, not one per test binary.

## The policy

`policy.rb` beside the script holds what is shown, in three verbs:

```ruby
block_from(/\A(error|warning)(\[\w+\])?: /)   # to the next blank line
line_matching(/\Atest \S+ \.\.\. FAILED\z/)   # one line
show_at_most 12, lines_per_block: 25
```

`--policy PATH` points the tool at another file. A line the DSL does
not understand stops the run with exit 12.

## Exit codes

| Code | Meaning |
|------|---------|
| 0    | summary printed; cargo succeeded, or `--from` |
| 1    | cargo failed (its own code is printed as `cargo exit:`) |
| 10   | bad arguments |
| 11   | `--from` log missing |
| 12   | policy file unreadable or not understood |

## Tests

```bash
bats skills/cargo-summary/test/
```
