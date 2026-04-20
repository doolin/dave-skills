---
name: pause-session
description: Capture session context and next steps before stepping away. Writes a resume brief to .development/next.md with a ready-to-paste starter prompt for the next session.
---

# Pause Session

Freeze the current working context so a future session can pick
up without re-discovery. Run this before stepping away from a
project.

## When to use

- End of a working session (switching tasks, done for the day).
- Before context gets lost — if you're about to close the
  terminal, run this first.
- When you know what's next but won't get to it right now.

## What it produces

A file at `.development/next.md` containing:

1. **What was done** — brief summary of this session's work.
2. **Current state** — branch, uncommitted changes, open
   PRs/MRs, anything in flight.
3. **What's next** — the single most important next action,
   stated concretely enough to act on without re-reading
   the whole codebase.
4. **Blockers** — anything waiting on external input, CI
   results, deploys, other people.
5. **Starter prompt** — a ready-to-paste prompt that gives
   the next Claude session enough context to start working
   immediately.

The file is overwritten each time — it's a snapshot, not a log.

## How to run

When the user invokes this skill:

1. Read the current project state:
   - `git status` and `git log --oneline -5`
   - `git branch` to see what branch we're on
   - `git stash list` for any stashed work
   - `.development/todo.md` for active/blocked items
   - `.development/planning.md` for current priorities
   - `.development/backlog.md` for upcoming work
   - Check for open PRs (`gh pr list`) and MRs (`glab mr list`)
     if the tools are available

2. Ask the user what the next concrete step is if it's not
   obvious from context. Don't guess — the user knows what
   matters.

3. Write `.development/next.md` with the template below.

4. Stage and commit `.development/next.md` with the message
   `Pause session: <one-line summary of next step>`.

## Template

```markdown
# Next

_Paused: YYYY-MM-DD HH:MM_

## What was done this session

- (bulleted summary of work completed)

## Current state

- **Branch:** `<branch>`
- **Uncommitted changes:** (yes/no, what)
- **Open PRs/MRs:** (links or "none")
- **Waiting on:** (CI results, deploys, reviews, or "nothing")

## What's next

(One concrete action. Not a goal — an action. "Run terraform
apply for the GitLab OIDC role" not "finish GitLab setup".)

## Blockers

(Anything that prevents the next action, or "None".)

## Starter prompt

> (A ready-to-paste prompt for the next Claude session. Include
> the project path, what was done, what to do next, and any
> files or context the next session will need. Keep it under
> 5 sentences.)
```

## Principles

- **Concrete over abstract.** "Add the attest job to
  `.gitlab-ci.yml`" not "work on CI."
- **One next step.** If there are multiple, pick the most
  important one. The rest belong in `todo.md`.
- **Overwrite, don't append.** `next.md` is a snapshot of
  right now, not a journal.
- **Commit it.** The file should be in git so it survives
  branch switches and is visible on any machine.
- **The starter prompt is the product.** If the user can
  paste it into a new session and start working in under
  a minute, the skill did its job.
