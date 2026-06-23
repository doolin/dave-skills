---
name: git-orient
description: One-shot read-only orientation for the git repo in the current directory — branch, upstream tracking with ahead/behind counts, unpushed commits, working-tree status, and recent commits. Use at session start (especially post-compaction or post-restart) to answer "where does this repo stand?" in a single allowlistable command.
disable-model-invocation: false
allowed-tools: Bash(*/git-orient*), Bash(git-orient*)
---

# Git orient

Get your bearings in a repo in one read-only call.

Run the bundled script from the repo root:

```bash
~/.claude/skills/git-orient/git-orient
```

It reports, in order:

- **Branch** — current branch (or `(detached @ <sha>)`).
- **Upstream** — the tracking branch with `ahead`/`behind` counts, or a
  note that the branch tracks nothing.
- **Unpushed commits** — `<upstream>..HEAD` one-liners, shown only when
  the branch is ahead.
- **Working tree** — `clean`, or the `git status --short` listing when
  dirty.
- **Recent commits** — the last N one-liners (default 5; `-n N` to
  change).

```text
Branch:   main
Upstream: origin/main  (ahead 0, behind 0)

Working tree: clean

Recent commits (last 5):
6a57db7 CSL-0005 Establish .gitignore and untrack local Claude settings
...
```

## Why this is a tool, not a chain

The session-start question "where does this repo stand?" used to be an
ad-hoc chain — `git rev-parse` + `git log origin/main..HEAD` +
`git status` + `git log -n`. A novel chain matches no allowlist prefix,
so it re-prompts the operator every session. One named command with a
stable invocation allowlists once (via the `allowed-tools` frontmatter
above) and travels with the skill to every repo.

## Why this is global

Lives in the shared `dave-skills` collection and is symlinked into
`~/.claude/skills/`, so every Straylight agent has it in every repo. It
takes no per-repo configuration — it reads whatever git reports for the
current directory.

## Notes

- **Read-only.** It never writes, fetches, or mutates state. `ahead`/
  `behind` are computed against the last `git fetch`; it does not fetch
  for you (that would be a network side effect — keep orientation cheap
  and offline).
- Exits `12` if run outside a git work tree.
