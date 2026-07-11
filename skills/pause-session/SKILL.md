---
name: pause-session
description: Capture session context before stepping away, keyed to the ticket or thread the work advances. In a full-form .development repo the active ticket file is the thread (update it in place); in the light form, write a threads/ file plus the next.md index; commit under the ticket's prefix. Scoped to the current repo only; degrades to chat output where there is no .development/.
---

# Pause Session

Freeze the current working context so a future session can pick
up without re-discovery. Run this before stepping away from a
project.

## Key the pause to the work, not the session

Name the artifact after the handle the operator will resume by —
human-meaningful and source-resident:

- **Ticketed project** (commits carry a `CSL-` / `OC-` / … ticket
  prefix): key on the **ticket the session advanced**. The ticket is
  the natural filename and the natural commit prefix in one. Where the
  file physically lives depends on the repo's `.development` form — see
  step 4.
- **Otherwise:** a short thread name —
  `.development/threads/the-commons.md`.
- **Never a session UUID.** It is canonical for the machine and
  useless to the operator doing the resuming.

Add a facet suffix only when one session carries several
independent resume points (`CSL-0034-migration`,
`CSL-0034-rollback`).

Two-tier structure, in the light form (why: an agent can't un-read
what it has loaded — context poisoning happens at Read time, so scope
is enforced at the file boundary):

- `.development/next.md` — a thin **index**: one pointer line per
  open thread, no narrative. Safe for any session to read.
- `.development/threads/<key>[-facet].md` — one file per thread,
  holding the narrative.

**Full-form `.development` is the exception.** A repo running the full
system — per-concern *directories*, an `active/` of ticket files —
already has a live thread per active ticket: the ticket file itself,
which carries its own State/Next. There the pause updates the active
ticket's file (`active/<TICKET>.md`) and commits under that ticket. Do
NOT add a `threads/` dir or `next.md` beside `active/` — that
duplicates what the ticket already holds. `threads/` + `next.md` is for
the light/non-ticketed form, which has no per-ticket file to carry
state.

## When to use

- End of a working session (switching tasks, done for the day).
- Before context gets lost — if you're about to close the
  terminal, run this first.
- When you know what's next but won't get to it right now.

## How to run

When the user invokes this skill:

1. Read the current project state — **this repo only. Never read a
   sibling project's working tree to pause the one you are in; a pause
   is scoped to the current repo.**
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

4. Write the pause where the repo's form keeps it:
   - **Full form** (`active/` dir of ticket files): update the active
     ticket's file (`active/<TICKET>.md`) — its State/Next — in place.
     No `threads/`, no `next.md`.
   - **Light + threads** (`threads/` and/or `next.md` present): write
     the thread file (template below) and refresh its line in
     `next.md`.
   - **Single `next.md`, no `threads/`:** write that snapshot.
   - **No `.development/`:** the brief is this skill's output — hand it
     to the operator; there is nothing to commit.

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

- **A pause is single-repo.** Read and write only the repo you are
  pausing. Never open a sibling project's working tree to do it.
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
