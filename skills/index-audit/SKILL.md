---
name: index-audit
description: One-shot, read-only audit of the git index before every commit — the staged files with diffstat, a warning for any staged path that should never be committed (env files, keys, logs, coverage, tmp), and the working-tree changes left outside the index. Run it immediately before each `git commit` in any repo, in place of the `git diff --cached --stat` + `git status --short` pair.
allowed-tools: Bash(~/.claude/skills/index-audit/index-audit*)
---

# Index audit

What am I about to commit, and what am I leaving behind? One call.

## Run

From the repo root, right before `git commit`:

```bash
~/.claude/skills/index-audit/index-audit
~/.claude/skills/index-audit/index-audit -C ~/src/other-repo   # a sibling repo, no cd chain
~/.claude/skills/index-audit/index-audit --strict              # exit 4 on any warning
```

Output:

```text
Staged:
 lib/foo.rb           | 12 +++++---
 spec/lib/foo_spec.rb |  8 ++++++
 2 files changed, 17 insertions(+), 3 deletions(-)
WARN: staged tmp/rspec-full.log (log file)

Outside the index:
 M .development/prd/PRD-0001.md
?? notes.md
```

## Reading it

- **Staged** is the commit. If a file you expected is missing here
  and present under *Outside the index*, stage it; if a file you did
  not expect is here, unstage it. Either way, do not commit yet.
- **WARN** names a staged path from the never-commit list. The list
  is deliberately small and universal: `.env*`, key material, `*.log`,
  `coverage/`, `tmp/`, `node_modules/`, `.DS_Store`, SimpleCov
  resultsets. Extend it in the script, not per repo.
- **Outside the index** is what this commit leaves behind. Empty is
  the common case for a single-concern commit; non-empty is fine when
  the leftovers belong to the next commit, and a smell otherwise.

## Exit codes

| Code | Meaning |
|------|---------|
| 0    | staged changes listed; warnings printed but not fatal |
| 3    | nothing staged, a commit now would be empty |
| 4    | `--strict` and at least one warning |
| 12   | not a git work tree, or bad arguments |

## Why this is a tool

The audit-before-commit rule existed as a habit ("`git diff --cached
--stat` before every commit") and was carried out as two ad-hoc
commands, each a separate permission prompt and a separate read. A
habit enforced by vigilance decays; a named command with one
allowlist line does not, and it can carry the never-commit check the
habit never had.

## Tests

```bash
bats skills/index-audit/test/
shellcheck skills/index-audit/index-audit
```
