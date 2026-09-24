# Bringing a Ruby repo to a clean RuboCop

Take a Ruby repo from "RuboCop fails everywhere" to "RuboCop passes
with no exclusion list" without changing behavior along the way.
RuboCop is Ruby's linter: each rule is a *cop* (`Style/StringLiterals`,
`Metrics/MethodLength`), grouped into departments (`Style`, `Metrics`,
`Lint`, `RSpec`, …).

Reference run: `~/src/highlight-extractor` (github.com/doolin/highlight-extractor),
2026-09-24. RuboCop 1.91, rubocop-rspec 3.x, SimpleCov 1.3, Ruby 4.0.
Starting point: no `.rubocop.yml`, so RuboCop ran on its defaults and
`bundle exec rake` (specs, then RuboCop) failed on every file. End
point: 165 recorded offenses in 30 cops drained to zero, the todo file
deleted, `lib/` at 100% line and branch coverage (from 86.60% and
59.34%), and CLI output byte-identical before and after. Commits
`47e31d5` (config and todo) through `6ddb559` (last cop).

**The method in one line:** record every offense in a generated todo
file so the build passes today, then remove the todo one cop per
commit — and put full test coverage in front of any cop that needs a
refactor, so the specs can prove the refactor changed nothing.

## Stage 1 — Fix the inputs before generating anything

The todo file is a snapshot of the config you generate it under. Get
the config right first, or the todo records noise and has to be
regenerated.

1. **Target Ruby version = the gemspec's floor.** `TargetRubyVersion`
   in `.rubocop.yml` and `required_ruby_version` in the gemspec must
   agree. If they don't, RuboCop suggests syntax the oldest supported
   Ruby can't parse, and `Gemspec/RequiredRubyVersion` flags the
   mismatch. Raising the floor is the operator's call; ask, then make
   it its own commit *before* the RuboCop config.
2. **House style goes in the config, not the todo.** If the codebase
   consistently does something the defaults dislike (the reference run:
   double-quoted strings everywhere), set that style in
   `.rubocop.yml`. Otherwise the todo carries hundreds of offenses
   that are not debt.
3. **Plugins: only what the Gemfile already has.** The reference run
   loaded `rubocop-rspec` because it was already a dependency. Adding
   plugin gems is a separate decision.

Skeleton (the reference run's, after the todo was gone):

```yaml
plugins:
  - rubocop-rspec
AllCops:
  NewCops: enable        # new cops arrive on gem upgrade instead of being silently off
  TargetRubyVersion: 4.0
Style/StringLiterals:
  EnforcedStyle: double_quotes
```

Model class: Sonnet.

## Stage 2 — Generate the todo

```sh
bundle exec rubocop --auto-gen-config --no-auto-gen-timestamp
```

and put `inherit_from: .rubocop_todo.yml` at the top of `.rubocop.yml`.

- `--no-auto-gen-timestamp` keeps a regenerated todo from producing a
  diff when nothing but the date changed.
- For a cop with offenses in more than 15 files the generator writes
  `Enabled: false` rather than a file list (the default
  `--exclude-limit`). Metrics cops get a `Max:` equal to the worst
  current offender.
- Commit config and todo together. `bundle exec rake` should pass.

Model class: Haiku.

## Stage 3 — Safe autocorrects, one commit

Cops the todo marks `This cop supports safe autocorrection` may share
one commit; everything else is one commit per cop.

```sh
bundle exec rubocop -a --only Cop/One,Cop/Two,...
```

Delete those entries from the todo first, run the command, then
**read the diff**. `--only` runs *only* those cops, so the Layout cops
that would re-indent the corrected code never run. In the reference
run this left:

- a `lines << if … else … end` rewrite (`Style/ConditionalAssignment`)
  with `else`/`end` at the wrong indentation;
- a guard clause (`Style/GuardClause`) with the old body still indented
  under a vanished `if`, plus a trailing whitespace line;
- `spec.metadata['rubygems_mfa_required'] = 'true'` appended to the
  gemspec at column 0 with single quotes (`Gemspec/RequireMFA`);
- `puts(CSV.generate { |csv| … })`, which then tripped
  `Style/BlockDelimiters` — rewritten by hand as a `do…end` block
  assigned to a local.

`Lint/ScriptPermission` does not autocorrect by editing text; the
script needs `chmod +x`. Model class: Haiku to run, Sonnet to fix up.

## Stage 4 — One commit per cop, and ask about the judgment calls

Remove the cop's entry from the todo in the same commit that fixes
its last offense. Commit message names the cop.

**Seeing what the todo hides.** With the todo inherited, `rubocop
--only X` reports nothing for cops the todo silences. Keep a scratch
config that copies `.rubocop.yml` minus the `inherit_from` line and run
`rubocop -c scratch.yml --only X` to list the real offenses.

**Decisions that belong to the operator** — ask, with a recommended
option, rather than choose:

| Cop | The question | Reference-run ruling |
| --- | --- | --- |
| `Naming/PredicatePrefix` | rename a public `has_x?` to `x?`? | rename (gem unpublished) |
| `RSpec/DescribeClass` | integration specs describe a behavior, not a class | exclude `spec/integration/**/*` |
| `Style/Documentation` | write class comments, or disable? | write them, as brief ADRs: `Decision:` / `Why:` pairs; tiny classes name their callers |
| `RSpec/ExampleLength`, `MultipleExpectations`, `MultipleMemoizedHelpers` | refactor specs to defaults, or set limits? | limits in `.rubocop.yml` at the current maximum, reason commented |
| All `Metrics/*` | refactor to defaults, or keep ceilings? | refactor `lib/` to defaults |

A limit moved from the todo into `.rubocop.yml` with its reason in a
comment is policy; the same number in the todo is debt. The move is
worth a commit even when the number doesn't change.

Model class: Sonnet for single-cop fixes; Fable/Opus-class for the
policy questions and for writing the ADR-style class comments, which
require knowing *why* the code is the way it is.

## Stage 5 — Coverage before any refactor

Any cop whose fix restructures code (the Metrics department,
interface renames) waits until every file it touches is at **100%
line and branch coverage**. Without that, "the specs still pass"
proves nothing about the lines the specs never ran.

1. Add SimpleCov with branch coverage, started before the gem loads:

   ```ruby
   require "simplecov"
   SimpleCov.start do
     enable_coverage :branch
     skip "/spec/"          # SimpleCov 1.3 renamed add_filter to skip
   end
   require "the_gem"
   ```

   Ignore `coverage/` (and `tmp/`, where `rspec-summary` writes its log).
2. Measure: `~/.claude/skills/rspec-summary/rspec-summary.rb --run`.
3. List gaps per file: `ruby ~/src/dbb/scripts/coverage-gaps.rb --lines --all`
   (reads `coverage/.resultset.json`; works on any repo with a `lib/`).
4. Close gaps with **spec-only commits**, one per area of code.
5. A branch no input can reach is a code defect, not a spec gap. The
   reference run had `"*#{book&.author}*" if book&.author`: inside the
   line the guard already proved `book` non-nil, so the inner `&.`'s
   nil branch was dead. Fix it in its own code-only commit.

Model class: Sonnet.

## Stage 6 — Refactor, proving behavior unchanged twice

**Never change specs and code in the same refactoring commit.** A
refactor that edits its own specs cannot show the specs held unchanged
across it.

Proof one: the specs pass untouched at 100% coverage.

Proof two: real output, before and after. Make a baseline worktree at
the last pre-refactor commit and run the same commands through both
trees against real data (the reference run: 14 CLI invocations against
the operator's Apple Books library, plus every generated HTML page),
comparing stdout, stderr, and exit status. Two traps in building this:

- **Run each tree under its own Gemfile** (`BUNDLE_GEMFILE=<tree>/Gemfile
  bundle exec ruby <tree>/bin/<exe>`). A Gemfile containing `gemspec`
  loads that tree's `lib/`; running the baseline under the main
  Gemfile mixes the two trees and every command "differs".
- If `Gemfile.lock` is gitignored the worktree has none; copy it in so
  both trees resolve the same gems.

**Interface changes take three commits**, each green:

1. code: add the new name, move every caller, keep the old name as an
   alias;
2. specs: move to the new name;
3. code: remove the alias.

**Replacing explicit keywords with `**opts` drops Ruby's
unknown-keyword check.** Pin the rejection with a spec against the old
code first (spec-only commit), then make the new code reject unknown
keys explicitly.

**Complexity cops overlap.** `CyclomaticComplexity` and
`PerceivedComplexity` usually flag the same methods; one refactor clears
both, and that commit may close both todo entries — say so in the
message.

Model class: Fable/Opus-class for refactor design; Sonnet to execute a
designed split.

## Stage 7 — Finish

When the last entry goes, delete `.rubocop_todo.yml` and the
`inherit_from` line in the same commit. Run the full gate
(`bundle exec rake`). Record the work in the project's changelog,
naming any interface change a caller of the gem would meet.

Then lock the coverage in with a floor: `SimpleCov.minimum_coverage(line:
100, branch: 100)`, set in an `after(:suite)` hook **only when every
example in every spec file ran**. A single-file, `-e`, or focused run
covers part of `lib/` by design; an unconditional floor fails all of
them. "Every file" is `config.files_to_run` against a glob of
`spec/**/*_spec.rb`; "every example" is `RSpec.world.example_count`
(counted after filtering) against the sum of each group's `examples`
(counted before). The rake task's `--pattern` run counts as full.

Prove the floor trips before trusting it: add an uncovered method to a
file SimpleCov measures, run the full suite, expect exit 2 and a
`minimum coverage` message, then restore the file. The probe method
needs a body on its own line: a one-line `def m = :x` counts as
covered when the method is defined. And a file loaded before
`SimpleCov.start` is never measured: the gemspec's `require_relative`
of `version.rb` loads it first, so a probe placed there proves nothing.

## Configured rules worth reusing

Each carries its reason as a comment in `.rubocop.yml`:

- **`Metrics/MethodLength: CountAsOne: [array, hash, heredoc, method_call]`**
  — a multi-line hash, array, or call counts as one line. Constructors
  that list fields (`new(a: row["A"], b: row["B"], …)`), serializers,
  and spec factories are long because they list data, not because they
  hold logic. In the reference run this cleared four of five offenders;
  the fifth was real and was split.
- **Exclude data scripts from `Metrics`.** A fixture generator whose
  methods are lists of `INSERT` rows set the todo's `MethodLength`
  ceiling at 112 lines by itself, which let every other method grow to
  ten times the default of 10 unnoticed. Excluded with a reason, the
  ceiling dropped to 22 — the longest method in `lib/`.
- **rubocop-rspec treats every file under `spec/` as a spec**, including
  scripts that merely live there. Exclude them at department level
  (`RSpec: Exclude:`), then confirm the department still applies to real
  specs by piping a small offending spec through
  `rubocop --stdin spec/probe_spec.rb --only RSpec/Output`.

## What bites

**A cop can find a real bug.** `Lint/ConstantDefinitionInBlock`
flagged `COLORS = {…}` inside a `Data.define(…) do … end` block. A
constant assigned in a block belongs to the enclosing *lexical* scope,
so it was `Models::COLORS`, not `Annotation::COLORS`: any other model
defining `COLORS` would have overwritten it. Verify before fixing:
`Models.const_defined?(:COLORS, false)` returned `true`. Fixed with
`const_set(:COLORS, …)` in the block and `self::COLORS` at the use site.

**Wrapping long lines can break a Metrics ceiling.** Splitting five
long fixture quotations for `Layout/LineLength` pushed a method from
112 lines to 117, over the todo's ceiling. Don't raise a ceiling to
absorb it; find out what set it.

**Regenerated fixtures differ in bytes, not content.** SQLite fixture
files rebuilt from an unchanged script are byte-different every time.
Compare `sqlite3 file .dump` output, then restore the committed file so
the commit holds no binary noise.

**`spec/support/` is loaded on every run.** A fixture generator that
lived there rewrote the committed databases every time the suite ran.
Scripts belong beside what they build, with a rake task to invoke them.

**A lazy `let` evaluated under a stub gets the stub.** A spec that stubs
`Configuration.new` and builds its own "missing database" configuration
in a `let` receives the stubbed return value. Use `let!` so it is built
before the stub.

**An option parser can make a branch unreachable from the command
line.** Thor's `enum:` rejects an out-of-range value before the command
runs, so a `case` over that option has an `else` branch no CLI
invocation reaches. Cover it by calling the command on an instance:
`described_class.new([], { format: "xml" }).books`.

**Refactoring for a cop exposes duplication.** Two entry points built
the same filter with the same five guarded calls; the complexity fix
was one shared builder, not two smaller copies.

## Tools

- `~/.claude/skills/rspec-summary/rspec-summary.rb --run` — tally and
  coverage totals in five lines.
- `~/src/dbb/scripts/coverage-gaps.rb` — uncovered lines and branches
  per file from SimpleCov's resultset.
- `~/.claude/skills/index-audit/index-audit` — staged files and leftovers
  before every commit; checks a refactor commit holds only `lib/` or
  only `spec/`.
- `scripts/compare-output [REV]` in highlight-extractor (added at
  `a62d8e8`) — the Stage 6 output comparison as a tool: checks REV out
  into a temporary worktree, runs a fixed command list through both
  trees against real data, and reports the first differing line.
  Adapt its command list to another repo's CLI.
- `spec/support/coverage_floor.rb` in highlight-extractor (added at
  `0cf046e`) — the Stage 7 floor.
