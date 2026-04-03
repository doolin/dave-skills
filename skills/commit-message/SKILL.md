---
name: commit-message
description: Conventions for writing commit messages. Commit messages are a Very Big Deal requiring balance across multiple constraints. Use when committing code, reviewing commits, or crafting git history.
---

# Commit Messages

Commit messages are a Very Big Deal. They are permanent documentation
baked into the project's history. They require balancing a number of
constraints, some of which may seem partially conflicting.

## Structure

```text
<context>: <summary>

<body>
```

- **First line**: A context prefix followed by a concise summary in
  imperative mood ("Add feature", not "Added feature")
- **Context prefix**: A word or two providing context — helps find
  commits in the reflog and scan history quickly
- **Body** (optional): Explain the *why*, not the *what*. The diff
  shows what changed; the message explains why it matters.
- **Keep the first line under 72 characters** when possible

## Principles

### Atomic

Each commit is one logical change — the Single Responsibility Principle
applied to commits. A commit should do one thing and one thing only.
If you can describe it with "and", it's probably two commits.

### Minimal

Include only what is necessary for the change. No drive-by cleanups,
no unrelated formatting, no "while I'm here" additions.

### Meaningful

Every commit on the public branch should deliver value. Each one should
be worth reading. If it's not worth explaining, question whether it's
worth committing separately.

### Context-providing

Always prefix with a word or two of context. This serves multiple
purposes:

- Scanning `git log --oneline` becomes useful
- Finding commits in the reflog is practical
- The scope of the change is immediately clear

Examples:

```text
auth: Add token refresh on session expiry
ci: Pin markdownlint action to commit SHA
docs: Clarify deployment prerequisites
test: Cover edge case in rate limiter
```

## Private vs public commits

- **Private history** (working branch): Commit early and often.
  Messages like "wip" and "fix typo" are fine here — this is your
  safety net. Use `git commit --amend --no-edit` to keep the working
  branch clean.
- **Public history** (after rebase/squash): Every commit is polished,
  atomic, and meaningful. No rough drafts. This is what gets merged
  and lives forever.

The transition from private to public is where the craft happens.
Rebase and squash to transform a messy working history into clean,
reviewable commits.

## Anti-patterns

- **"Fix"** with no context — fix what? where? why?
- **"Update files"** — which files? what changed?
- **"WIP"** on a public branch — this is private history leaking
- **Bundling unrelated changes** — one commit doing three things
- **Repeating the diff** — "Change X from Y to Z" when the diff
  already shows that. Explain *why* it changed.

## When Claude writes commit messages

Claude follows these conventions when committing:

1. Always include a context prefix
2. Imperative mood, concise first line
3. Body explains the why when the change isn't self-evident
4. One logical change per commit
5. Never commit to the default branch
