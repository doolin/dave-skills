---
name: software-engineering
description: Software engineering as a professional discipline. Principles for writing code that is atomic, minimal, and meaningful. Covers commit hygiene, public vs private history, testing, and the craft of building software that lasts.
---

# Software Engineering

Software engineering is a professional discipline, not just writing code
that works. These principles apply to every change, every commit, every
review.

## Atomic and minimal

Every change should do one thing and one thing only. This is the Single
Responsibility Principle applied to commits, PRs, and refactors.

- **Atomic**: A change is self-contained. It doesn't depend on a future
  change to make sense, and it doesn't bundle unrelated work.
- **Minimal**: A change includes only what is necessary. No drive-by
  cleanups, no speculative additions, no "while I'm here" extras.

If a change can be split into two meaningful changes, it should be.

## Commit hygiene

Commits are communication. A well-crafted commit history is a
professional asset.

- **Commit early and often** on your working branch — this is your
  safety net during development
- **Clean up before publishing** — rebase and squash private history
  into meaningful, atomic commits before merging
- **Every public commit passes CI** — no broken commits on the
  production branch
- **Imperative mood, explain the why** — the diff shows what changed;
  the message explains why it matters

Merging raw private history into the public branch is publishing a
book with all its rough drafts. Don't do it.

## Public vs private history

A git repository's public history is an asset. Treat it as one.

- **Private history** is for exploration: experiments, false starts,
  checkpoint saves. This is where you work freely.
- **Public history** is for communication: every commit should record
  a meaningful increment of change that delivers business value.
- **Rebase and squash** to transform private history into clean public
  history. High-performing teams rebase onto head of master, then
  fast-forward merge for a clean linear history.
- **Semantic overload** from messy history is a real cost. Future
  engineers (including you) will read this history to understand
  decisions. Make it worth reading.

## Testing

Tests are not optional. They are how you prove the code works and
how you prevent regressions.

- Write the test first when fixing a bug — prove the bug exists
  before fixing it
- Tests document behavior — a test suite is a living specification
- A change without tests is incomplete unless it's provably untestable
- Run the full test suite before publishing, not just the new tests

## Code quality

- Follow existing patterns in the codebase — consistency beats
  personal preference
- Leave the code better than you found it, but only in the area
  you're working in
- Name things precisely — if you can't name it clearly, you don't
  understand it yet
- Delete dead code — commented-out code and unused functions are
  noise, not safety nets

## Professional practice

- Read before you write — understand the existing code before
  changing it
- Measure twice, cut once — think through the approach before
  implementing
- Own your mistakes — when something breaks, fix it and understand
  why it broke
- CI is non-negotiable — if CI fails, the work isn't done
