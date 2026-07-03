---
name: self-host-development-light
description: Lightweight self-hosted project management using markdown files in a .development directory — one file per concern: roadmap, backlog, todo, changelog, decisions, requirements, design, stewardship, lessons learned, and an operator capture inbox, plus saved plans. Includes provisioning stubs and the rule for growing any concern into its full directory form.
disable-model-invocation: true
---

# Self-Host Development Light

Keep all project management artifacts in the repo as plain
markdown. No external tools, no ticket numbers, no heavy
process. This is the light form of the self-hosted development
system, for a solo developer or a small team working with
agents.

**The unifying rule: light form = one file per concern; full
form = one directory per concern.** This skill provisions the
light form. Every file below can grow independently into its
directory counterpart (see [Growing a
concern](#growing-a-concern)); a repo at full form for every
concern is running the complete `.development` architecture.

Features and components are `##` sections within these files —
never separate files, never IDs. The one exception to the
no-directories rule is `plans/`, a filing cabinet for saved
task-scoped plans.

## Setup (run once)

Before doing any work, check whether setup has already been
completed — if the scaffold below exists, skip to
[Ongoing usage](#ongoing-usage).

Provision **all** files from day one, each as the populated
stub below. No file is optional and none is deferred until
needed: the stub text is part of the deliverable. It teaches
the workflow to whoever — human or agent — opens the file
next.

### 1. Create the directory structure

```text
.development/
├── roadmap.md         direction and milestones
├── backlog.md         planned, not yet scheduled
├── todo.md            active and blocked work
├── changelog.md       shipped work
├── adr.md             decisions
├── prd.md             requirements
├── design.md          how the system is put together
├── stewardship.md     recurring maintenance
├── lessons-learned.md traps and techniques, in hindsight
├── CAPTURE.md         operator inbox (operator-owned)
└── plans/             saved task-scoped plans
    └── .gitkeep
```

### 2. Initialize roadmap.md

```markdown
# Roadmap

Project direction: where this is going, the shape it is
converging on, and the milestones on the way. One per
project. Current priorities live here; backlog items should
trace to something in this file. Update when the destination
changes, not for every step.

## Direction

<!-- Where the project is going and why. -->

## Milestones

<!-- Coarse and ordered. Date them when they land. -->
```

### 3. Initialize backlog.md

```markdown
# Backlog

Items not yet scheduled. Add new work here. Move to `todo.md`
when it becomes active.

<!-- Newest items at the top. -->
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

### 5. Initialize changelog.md

```markdown
# Changelog

Shipped work worth recording — one dated line per item,
newest first. When an item leaves `todo.md` finished, note it
here. Not every completion needs an entry; record the ones a
future reader would want to find.
```

### 6. Initialize adr.md

```markdown
# Decisions

Significant decisions — architecture, tooling, direction —
one `##` section per decision, newest first: the context, the
decision, and its consequences. No numbering; sections are
the unit.

## Open questions

<!-- Decisions that need input before work can proceed. -->

<!-- Decided: "## YYYY-MM-DD — Title" sections below, newest
     first. -->
```

### 7. Initialize prd.md

```markdown
# Requirements

What the project must do, one `##` section per feature or
component. Keep each section to observable behavior — what a
user or caller can verify — not implementation.
```

### 8. Initialize design.md

```markdown
# Design

How the system is put together: structure, key mechanisms,
and the reasoning behind them. One `##` section per area.
Task-scoped implementation plans go in `plans/`, not here;
when a plan ships, promote its durable outcome into a
section.
```

### 9. Initialize stewardship.md

```markdown
# Stewardship

Standing maintenance — recurring, identical-in-kind work
(dependency updates, consistency sweeps, doc-drift checks).
One `##` section per activity: what it covers, its
guardrails, and a dated log line per pass. These sections are
never "done."
```

### 10. Initialize lessons-learned.md

```markdown
# Lessons learned

Traps and techniques from doing the work — the things
that were only obvious in hindsight, and the methods
worth reusing. One `##` section per theme, concrete
enough to lift: playbooks and skills harvest this file.
```

### 11. Initialize CAPTURE.md

```markdown
# Capture

Operator inbox: quick notes, ideas, and requests jotted by
the human between sessions. Operator-owned — agents read this
file and may triage items into `backlog.md` when asked, but
never author entries here.
```

### 12. Wire the agent contract

Add a pointer in the repo root `AGENTS.md` (create it if
absent) so any visiting agent finds the system:

```markdown
## Development tracking

Project management is self-hosted in `.development/` — flat
markdown, one file per concern, no ticket IDs. Orient by
reading `todo.md`, `roadmap.md`, and `backlog.md`. Record
decisions in `adr.md` and shipped work in `changelog.md`.
```

### 12. Verify setup

Confirm every file exists and contains its stub, and that
`plans/` is present with a `.gitkeep`. Commit the scaffold
with a message like `Scaffold .development for project
management`.

## Migrating existing documents

Setup often lands in a repo that already has
planning-flavored markdown at the root — `PLANNING.md`,
`NOTES.md`, `TODO.md`, `ROADMAP.md`, working-notes files.
Migrate them as their own commit, after the scaffold
commit: the scaffold is mechanical, the migration is
judgment, and a reviewer should see them separately.

For each candidate document:

1. **Classify by scope**, the same rule that separates the
   working files: direction → `roadmap.md`, requirements →
   `prd.md`, system structure → `design.md`, a single
   task's approach → `plans/<name>.md`. Most working notes
   are task-scoped and land in `plans/` intact.
2. **Move, don't copy.** Use `git mv` so history survives
   the migration, and one source of truth holds.
3. **Extract the live work.** Unchecked checklists and
   "to explore" lists inside a document are backlog items
   in hiding — pull each into `backlog.md` with a pointer
   back to the plan. The plan stays reference material;
   the backlog is where work gets scheduled from.
4. **Harvest the lessons.** A trap or technique buried in
   working notes ("X renders blank when exported through
   Y — do Z instead") belongs in `lessons-learned.md`,
   where the next project can find it.
5. **Fix inbound references.** Grep for the old filename
   before committing — `README.md` and `AGENTS.md` often
   point at it.

Not everything migrates. `README.md`, `AGENTS.md` /
`CLAUDE.md`, and product documentation describe the
artifact, not the work — they stay where they are.

Commit the whole migration as one commit, e.g. `Migrate
planning docs into .development`.

## Ongoing usage

### Orientation

At the start of each session, read three files to orient:

1. `todo.md` — what's active and what's blocked
2. `roadmap.md` — direction and current priorities
3. `backlog.md` — what's waiting

Glance at `CAPTURE.md` for new operator notes. Present a
short summary to the human before starting work. This pairs
with the What's Next checklist in `AGENTS.md`.

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
`todo.md`. Don't copy — move. The item should exist in
exactly one place.

### Completing work

Remove the item from `todo.md`. If it's worth recording, add
a dated line to `changelog.md`. If completing it settled a
decision, record that in `adr.md` — the changelog says what
shipped, the decision log says why it went the way it did.
If the work taught something a future project needs — a trap
that was only obvious in hindsight, a technique worth reusing
— capture it in `lessons-learned.md`.

### Blocking and unblocking

Move blocked items to the **Blocked** section of `todo.md`
with a note explaining what they're waiting on. When the
blocker clears, move back to **Active**.

### Recording decisions

When a significant decision is made — architecture, tooling,
scope, direction — add a `## YYYY-MM-DD — Title` section to
`adr.md` with the context, the decision, and its
consequences. Questions still awaiting a decision sit in the
**Open questions** section at the top; move them down into a
dated section once decided.

### Saving plans

When a session produces a plan worth preserving — an
implementation approach, an architecture sketch, a multi-step
breakdown — save it as a file in `.development/plans/` with a
descriptive name:

```text
.development/plans/terraform-s3-backend.md
.development/plans/oidc-role-remediation.md
```

Plans are reference material. They don't replace the working
files.

Because `plans/` is the one place documents accumulate, it is
also where staleness hides. When it grows past a handful of
files, adopt the **index-drift-audit** skill: an
auditor-managed `INDEX.md` manifest plus a deterministic
reconciler that flags orphaned, missing, and stale documents
on a recurring schedule.

### Roadmap, design, and plans

Three artifacts carry "how and where," at different scopes —
don't let the terms collide:

- **`roadmap.md`** carries project scope: direction and
  milestones. It changes when the destination changes.
- **`design.md`** carries system scope: how the thing is put
  together and why. It changes when the structure changes.
- **`plans/`** carries task scope: a single implementation
  approach. Many per project, cheap to save, superseded
  freely.

When a plan ships, its durable residue belongs in `design.md`
(structure) or `adr.md` (the decision), not in the plan file.

## Growing a concern

Any concern can grow to full form independently: explode the
file's sections into the matching directory — `adr.md` →
`adr/` with one file per decision, `backlog.md` → `backlog/`
with one file per item — minting numbering or ticket IDs only
at that point. It is one mechanical operation per concern, in
any order; a repo can run `adr/` alongside `backlog.md`.

Signals that a concern has outgrown its file: you scan the
file to find things, sections need to be referenced by name
from elsewhere, or more than one person or agent works the
concern concurrently.

**Exactly one form per concern.** A file and its directory
both present (`prd.md` and `prd/`) is drift — finish the
migration or revert it. `CAPTURE.md` and `plans/` are exempt:
they have one form only.

## Principles

- **One source of truth per item.** An item lives in exactly
  one file at a time.
- **Short todo list.** If `todo.md` grows past five or six
  active items, push lower-priority work back to the backlog.
- **Backlog is append-only until pruned.** Don't over-organize
  the backlog. Newest items go at the top. Prune periodically
  by removing items that are no longer relevant.
- **Plans are cheap.** Save any plan worth revisiting. The
  plans directory is a filing cabinet, not a commitment.
- **Stubs teach.** Every file is provisioned from day one
  with text that explains its own use. An empty scaffold is a
  puzzle; a stubbed one is documentation.
- **Keep it current.** Stale planning docs are worse than no
  planning docs.
- **Process follows the work.** If this structure stops
  fitting, change it — or grow the crowded concern to its
  directory form. The point is to support the work, not to
  maintain the process.
