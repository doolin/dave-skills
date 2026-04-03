---
name: commit-message
description: Conventions for writing commit messages. Commit messages are a Very Big Deal requiring balance across multiple constraints. Use when committing code, reviewing commits, or crafting git history.
---

# Commit Messages

Commit messages are a Very Big Deal. They are permanent documentation
baked into the project's history. They require balancing a number of
constraints, some of which may seem partially conflicting.

## Pre-staging

Before committing, ensure tests, linting, and CI pipelines pass.
Address any issues related to the current change before staging.

## Structure

```text
<summary line, 52-57 characters ideal>

<body, wrapped at 52-57 characters>

Co-Authored-By: <model> (<tool>) <email>
```

### Summary line

- **52-57 characters** ideal, 72 maximum
- Imperative mood: "Add", "Fix", "Refactor" — not past tense
- No period at the end
- Specific about what changed
- Prefix with a word or two of context when it aids scanning

### Body

- Wrap at **52-57 characters**
- Separated from summary by one blank line
- Explain the *why*, not the *what* — the diff shows what changed
- Keep it focused on reasoning and intent

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

Prefixing with context serves multiple purposes:

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

## Templates by change type

### Bug fix

```text
Fix <what was broken>

Previous behavior: <what happened>
Root cause: <why it happened>
Correction: <what this change does>
```

### New feature

```text
Add <what was introduced>

<Why this feature exists and what it supports>
```

### Refactor

```text
Refactor <what was restructured>

<Why the restructuring was needed>
- <area 1>
- <area 2>
```

### Cleanup

```text
Clean up <area>

- <item 1>
- <item 2>
```

### Chore / config / deps

```text
<Brief description of change>

<Brief rationale>
```

### Documentation

```text
docs: <what was documented>

<What was missing or outdated>
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

1. Gather context first: run `git diff --staged`, `git log --oneline -10`,
   and `git diff --staged --stat` in parallel
2. Summary line within 52-57 characters, imperative mood
3. Body wrapped at 52-57 characters, explains the why
4. One logical change per commit
5. Never commit to the default branch
6. Present the draft message for confirmation before committing
7. Commit using a HEREDOC and verify with `git log -1`
8. End with co-author credit:
   `Co-Authored-By: Claude Opus 4.6 (Claude Code) <noreply@anthropic.com>`
