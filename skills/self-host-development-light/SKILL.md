---
name: self-host-development-light
description: Lightweight self-hosted project management using markdown files in a .development directory. Covers backlog, planning, todo, and saved plans — everything an agent needs to orient and start working.
disable-model-invocation: true
---

# Self-Host Development Light

Keep all project management artifacts in the repo as plain markdown.
No external tools, no heavy process. Three files and a plans directory
are enough for a solo developer or a small team working with agents.

## Setup (run once)

Create the `.development/` directory and its initial files. Before
doing any work, check whether setup has already been completed —
if all four items below exist, skip to [Ongoing usage](#ongoing-usage).

### 1. Create the directory structure

```text
.development/
├── backlog.md
├── planning.md
├── todo.md
└── plans/
    └── .gitkeep
```

### 2. Initialize backlog.md

```markdown
# Backlog

Items not yet scheduled. Add new work here. Move to `todo.md`
when it becomes active.

<!-- Newest items at the top. -->
```

### 3. Initialize planning.md

```markdown
# Planning

High-level direction, priorities, and open questions. Update
this when the project's focus shifts or after significant
milestones.

## Current priorities

<!-- What matters most right now and why. -->

## Open questions

<!-- Decisions that need input before work can proceed. -->

## Recent decisions

<!-- Decided items, with brief rationale, newest first. -->
```

### 4. Initialize todo.md

```markdown
# Todo

Work in progress. Keep this short — if it grows beyond a
handful of items, move deferred work back to `backlog.md`.

## Active

<!-- Items currently being worked on. -->

## Blocked

<!-- Items waiting on something. Note what they're waiting on. -->
```

### 5. Verify setup

Confirm all files exist and contain their templates. The
`.development/plans/` directory should be present with a
`.gitkeep`. Commit the scaffold with a message like
`Scaffold .development for project management`.

## Ongoing usage

### Orientation

At the start of each session, read all three files to orient:

1. `todo.md` — what's active and what's blocked
2. `planning.md` — current priorities and open questions
3. `backlog.md` — what's waiting

Present a short summary to the human before starting work.
This pairs with the What's Next checklist in `AGENTS.md`.

### Adding work

New items go into `backlog.md` at the top. Each item is a
short description — one or two sentences. Add context if the
item isn't self-explanatory, but keep it brief.

```markdown
- **Terraform import for dave-skills repo** — Run terraform
  import for the existing repo and branch protection before
  first apply. See terraform/main.tf TODOs.
```

### Starting work

Move the item from `backlog.md` to the **Active** section of
`todo.md`. Don't copy — move. The item should exist in exactly
one place.

### Completing work

Remove the item from `todo.md`. If it's worth recording, add a
one-line entry to the **Recent decisions** section of
`planning.md` with the date and outcome.

### Blocking and unblocking

Move blocked items to the **Blocked** section of `todo.md` with
a note explaining what they're waiting on. When the blocker
clears, move back to **Active**.

### Saving plans

When a session produces a plan worth preserving — an
implementation approach, an architecture sketch, a multi-step
breakdown — save it as a file in `.development/plans/` with a
descriptive name:

```text
.development/plans/terraform-s3-backend.md
.development/plans/oidc-role-remediation.md
```

Plans are reference material. They don't replace the three
working files.

### Updating planning.md

Revise `planning.md` when:

- Priorities shift
- A significant decision is made
- An open question gets resolved
- The project's direction changes after a milestone

Keep it current. Stale planning docs are worse than no planning
docs.

## Principles

- **One source of truth per item.** An item lives in exactly one
  file at a time.
- **Short todo list.** If `todo.md` grows past five or six
  active items, push lower-priority work back to the backlog.
- **Backlog is append-only until groomed.** Don't over-organize
  the backlog. Newest items go at the top. Groom periodically
  by removing items that are no longer relevant.
- **Plans are cheap.** Save any plan worth revisiting. The
  plans directory is a filing cabinet, not a commitment.
- **Process follows the work.** If this structure stops fitting,
  change it. The point is to support the work, not to maintain
  the process.
