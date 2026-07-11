---
name: pause-session
description: Capture session context before stepping away, keyed to the ticket or thread the work advances. Writes a thread file under .development/threads/ (or the single next.md where that's the convention) and commits under the ticket's own prefix. Degrades to chat output in projects with no .development/.
---

# Pause Session

Freeze the current working context so a future session can pick
up without re-discovery. Run this before stepping away from a
project.

## Key the pause to the work, not the session

Name the artifact after the handle the operator will resume by —
human-meaningful and source-resident:

- **Ticketed project** (commits carry a `CSL-` / `OC-` / … ticket
  prefix): key on the **ticket the session advanced** —
  `.development/threads/CSL-0034.md`. The ticket is the natural
  filename and the natural commit prefix in one.
- **Otherwise:** a short thread name —
  `.development/threads/the-commons.md`.
- **Never a session UUID.** It is canonical for the machine and
  useless to the operator doing the resuming.

Add a facet suffix only when one session carries several
independent resume points (`CSL-0034-migration`,
`CSL-0034-rollback`).

Two-tier structure, where `.development/` exists (why: an agent
can't un-read what it has loaded — context poisoning happens at
Read time, so scope is enforced at the file boundary):

- `.development/next.md` — a thin **index**: one pointer line per
  open thread, no narrative. Safe for any session to read.
- `.development/threads/<key>[-facet].md` — one file per thread,
  holding the narrative.

## When to use

- End of a working session (switching tasks, done for the day).
- Before context gets lost — if you're about to close the
  terminal, run this first.
- When you know what's next but won't get to it right now.

## How to run

When the user invokes this skill:

1. Read the current project state:
   - `git status` and `git log --oneline -5`
   - `git branch` to see what branch we're on
   - `git stash list` for any stashed work
   - `.development/todo.md` for active/blocked items
   - `.development/backlog.md` for upcoming work
   - Check for open PRs (`gh pr list`) and MRs (`glab mr list`)
     if the tools are available

2. Identify the ticket or thread the session advanced — that is
   the file key. Ask the operator if it is not obvious; do not
   invent one, and never fall back to a session UUID.

3. Ask the user what the next concrete step is if it's not
   obvious from context. Don't guess — the user knows what
   matters.

4. Write or update the thread file (template below) and refresh
   that thread's line in the `next.md` index. Where the project
   keeps a single `.development/next.md` and no `threads/` dir,
   write that snapshot instead. Where there is no `.development/`
   at all, the brief is this skill's output — hand it to the
   operator; there is nothing to commit.

## Committing the pause

A pause is state, not a task — but in a ticketed project it is
state *about a ticket*, so it inherits that ticket and never
lacks a prefix.

- **Ticketed project:** commit the pause under the ticket it
  advances — `CSL-0034 <state / next summary>` — as its own
  atomic commit. A ticket-prefixed state commit is ordinary
  history (`CSL-0031 Record rubocop grant decisions`), not the
  clutter the operator objects to. If the session's own work is
  still uncommitted, fold the pause into that same-ticket commit
  rather than making two.
- **Non-ticketed project:** ride the pause along with the
  session's work commit. Do not mint a bare `Pause session:`
  commit — an unprefixed session-state entry in the log is the
  thing to avoid.

## Resuming (the other half of the contract)

- Orient from `next.md`; then read ONLY the thread file for the
  work you were asked to do. Never bulk-read `threads/`.
- When a key maps to more than one facet file (no bijection),
  ASK the operator which facet to pursue before reading any of
  them. Never guess, never load both.

## Template (thread file)

```markdown
# Thread: <what this thread is>

_Updated: YYYY-MM-DD_

## State

(What is done and where it lives — files, tools, parameters,
decisions. Durable facts, not session narrative.)

## Next

(One concrete action. Not a goal — an action. "Run terraform
apply for the GitLab OIDC role" not "finish GitLab setup".)

## Blockers

(Anything that prevents the next action, or "None".)

## Re-entry

(The commands/files that re-enter the working loop fastest.)
```

## Principles

- **Concrete over abstract.** "Add the attest job to
  `.gitlab-ci.yml`" not "work on CI."
- **One next step per thread.** If there are multiple, pick the
  most important one. The rest belong in `todo.md`.
- **Overwrite, don't append.** A thread file is a snapshot of
  right now, not a journal.
- **Index stays thin.** One line per thread in `next.md`;
  narrative belongs only in the thread file.
- **Commit under the ticket, never as bare chatter.** The pause
  inherits the prefix of the work it describes; an unprefixed
  `Pause session:` commit is what the operator considers clutter.
- **The re-entry section is the product.** If the next session
  can start working in under a minute from the thread file
  alone, the skill did its job.
