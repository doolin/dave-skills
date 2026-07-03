---
name: pr-watch-check
description: Watch ALL GitHub checks on the current branch's PR (every workflow, not just the latest run), then keep watching until the PR is merged or closed — one background task covers the whole checks-to-merge arc. Use instead of watch-ci whenever the branch has an open PR. Launch in the background right after git push; on wake, checks failed (exit 1) means fix and re-push, merged (exit 0) means close the ticket and sync master.
disable-model-invocation: false
allowed-tools: Bash(*/pr-watch-check*), Bash(pr-watch-check*)
---

# pr-watch-check

Post-push watcher for the whole check suite. `watch-ci` watches one
workflow run — on repos where a push triggers several workflows
(production-at-home: Ruby Actions + Shellcheck), it latches onto
whichever run registered last and the rest go unwatched, forcing a
manual `gh run list` + second watch. This tool waits for **every**
check on the PR.

## Run

```bash
~/.claude/skills/pr-watch-check/pr-watch-check [pr-number] [--initial-wait N]
```

Typically launched as a background task immediately after `git push`
to a branch with an open PR. No arguments needed for the common case
(PR resolved from the current branch).

## Behavior

1. Waits `--initial-wait` seconds (default 8) for the pushed checks to
   register, retrying the listing up to a minute (gh errors when no
   checks are reported yet).
2. `gh pr checks --watch --interval 10` until every check settles.
3. Re-lists the final check table authoritatively before exiting —
   same distrust of the watcher's exit code that watch-ci applies to
   `gh run watch`.
4. Checks green → keeps polling (30s) until the PR is merged or
   closed, so the merge itself wakes the watcher. The operator merges
   by hand; this is how the agent learns to close the ticket and sync.
   `--no-merge-wait` restores checks-only behavior.

## Exit codes

- `0` every check passed and the PR merged (with `--no-merge-wait`:
  checks passed)
- `1` at least one check failed — the final table names it
- `2` PR closed without merging
- `10` bad input; `11` no PR / checks never registered

## When to use which

- **pr-watch-check** — branch has an open PR (the normal ticket flow).
- **watch-ci** — no PR yet, or you care about one specific run id.

## Conventions

Pairs with the watch-ci-after-push convention; same requirement that
`gh` is authenticated for the repo's remote. Born in production-at-home
during PAH-89 after three ad-hoc `gh run list` + second-watch dances in
one session; the merge-wait phase followed the same day, so one
background task wakes the agent for both fix-and-repush (exit 1) and
close-the-ticket (exit 0). Canonical copy lives here in dave-skills;
consumed via symlink from ~/.claude/skills/.
