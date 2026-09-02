---
name: rspec-summary
description: Digest a full rspec run into the lines that decide the pre-commit gate — example tally, SimpleCov line and branch totals, any coverage-floor breach, and failures grouped by spec directory, so known local-only failures are told apart from a real one at a glance. Use after every full `bundle exec rspec` in any rspec + SimpleCov repo, or run the suite through it with --run. Replaces the grep/awk pair over a captured log.
allowed-tools: Bash(~/.claude/skills/rspec-summary/rspec-summary.rb*)
---

# rspec-summary

The full suite prints two thousand lines; five of them answer the
pre-commit question. This reads those five.

## Run

From the repo root:

```bash
~/.claude/skills/rspec-summary/rspec-summary.rb --run            # run, tee to tmp/rspec-full.log, summarize
~/.claude/skills/rspec-summary/rspec-summary.rb                  # summarize tmp/rspec-full.log
~/.claude/skills/rspec-summary/rspec-summary.rb --files some.log # per-file failure counts too
```

Output:

```text
3361 examples, 24 failures, 81 pending
Line coverage: 5625 / 5625 (100.00%)
Branch coverage: 1397 / 1397 (100.00%)
Failures by directory:
    24  spec/e2e
rspec exit: 1
```

## Reading it

- **Failures confined to a directory the repo already knows fails
  locally** (dbb: `spec/e2e`, DBB-0389) is the expected local state.
  Any other directory in the list is a real failure.
- **`FLOOR:`** means a SimpleCov `minimum_coverage` gate tripped. In
  dbb, find the gap with `scripts/coverage-gaps.rb`.
- **`ABORTED:`** is SimpleCov's "Stopped processing SimpleCov as a
  previous error ... has been detected". It prints whenever the
  process exits non-zero, including an ordinary failed suite. In that
  path SimpleCov still formats the report, so the coverage lines above
  it are a measurement of what ran, but it **skips the
  `minimum_coverage` check**. A failed local run therefore never
  exercises the floor; only a passing run does.
- The local figure is for the gate. For a number to quote in a
  ticket, use the repo's CI-side reader (dbb: the `ci-coverage` skill).

## Exit codes

| Code | Meaning |
|------|---------|
| 0    | summary printed (a summarize-only call never mirrors the suite) |
| 1    | `--run` and the suite failed |
| 10   | bad arguments |
| 11   | log missing, or no rspec summary line in it |

## Why --run clears the resultset

SimpleCov merges results within a time window. A narrow run left in
`coverage/.resultset.json` blends into the full run and moves the
figure with no code change. `--run` deletes it first.

## Tests

```bash
bats skills/rspec-summary/test/
```

## Why this is global

Lives in `dave-skills` and is symlinked into `~/.claude/skills/`, so
every agent has it in every rspec repo. It reads nothing repo-specific:
rspec's own summary line, SimpleCov's own totals, and the `rspec
./spec/...` re-run lines.
