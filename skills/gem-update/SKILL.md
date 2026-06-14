---
name: gem-update
description: Run a Ruby gem stewardship pass following the DBB-0019 protocol. Reports outdated gems split into patch/minor/major buckets, batch-applies the low-risk patch bumps, and runs the verification gauntlet (bundler-audit, brakeman, rubocop, rspec). Use for the recurring "keep gems current" stewardship task in any Ruby/Rails repo.
disable-model-invocation: false
allowed-tools: Bash(*/gem-update*), Bash(gem-update*)
---

# Gem update (stewardship pass)

Codifies the recurring "keep Ruby gems current" stewardship task. The
guiding policy (from dbb's DBB-0019 ticket) is: **patch bumps are
batchable; minor and major bumps go one at a time with the suite run
between each.** The tool automates the safe, deterministic parts and
hands the judgement calls to you.

Run from a Ruby repo root:

```bash
~/.claude/skills/gem-update/gem-update            # report + patch bumps + gauntlet
~/.claude/skills/gem-update/gem-update --report   # just the buckets, no changes
~/.claude/skills/gem-update/gem-update --verify   # just the gauntlet, no changes
~/.claude/skills/gem-update/gem-update --quick    # apply + gauntlet, skip slow rspec
```

## What it does

1. **Buckets** every outdated gem into `patch` / `minor` / `major` /
   `other` by comparing installed vs latest (parses the Bundler table).
2. **Applies patch bumps** with `bundle update --conservative <gems>` --
   low-risk, within Gemfile constraints, in one batch.
3. **Lists** the minor/major bumps for you to do one at a time; it never
   applies them automatically.
4. **Runs the gauntlet**: `bundler-audit`, `brakeman`, `rubocop`,
   `rspec`. Each prefers a `bin/` binstub, falls back to `bundle exec`,
   and is skipped (noted) if the gem isn't bundled. Prints PASS/FAIL per
   step plus an overall verdict; exits non-zero if any step fails.

## Surface mode

It edits `Gemfile.lock` but **never commits**. Review the diff and
commit under the repo's stewardship ticket (dbb: `DBB-0019`), recording
the pass in the ticket's update log.

## Why this is global

Lives in the shared `dave-skills` collection, symlinked into
`~/.claude/skills/`, so every Ruby/Rails Straylight repo gets the same
stewardship pass. The gauntlet auto-detects each repo's tools, so no
per-repo configuration is needed; a non-Ruby repo (no `Gemfile`) exits
cleanly with a message.

## After a run

- Patch bumps applied and gauntlet green -> commit the `Gemfile.lock`
  diff under the stewardship ticket.
- Minor/major bumps remain -> tackle them one at a time (re-run
  `--verify` after each), or schedule a dedicated pass.
- A gauntlet step failed -> read `/tmp/gem-update-<step>.log`; the
  update is on disk, so you can revert `Gemfile.lock` if a bump caused it.
