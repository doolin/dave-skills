---
name: document-drift
description: Audit a repo for stale documentation — broken cross-references, outdated lists, orphaned mentions, and drift between docs and the actual codebase. Produces a report and optional fixes.
disable-model-invocation: true
---

# Document Drift

Systematically find and fix places where documentation has fallen
out of sync with the code it describes. Run this on any repo where
docs coexist with source — the checks are language-agnostic.

## When to use

- After a burst of feature work or refactoring
- Before a release or handoff
- When onboarding reveals confusion traceable to stale docs
- As a periodic hygiene pass (quarterly or after major milestones)

## Process

### 1. Inventory documentation files

Collect every file that functions as documentation:

- `README.md`, `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`,
  `CHANGELOG.md`, and similar top-level docs
- Skill or module descriptions (`SKILL.md`, `docs/**/*.md`)
- Inline doc comments that reference external structure (file
  paths, config keys, API endpoints)
- CI workflow descriptions or comments

Build a list. This is the audit surface.

### 2. Cross-reference accuracy

For every doc file, check references against reality:

| Reference type | How to verify |
| --- | --- |
| File paths | `test -e <path>` or glob for it |
| Directory listings | Compare stated contents to `ls` |
| Function/class names | `grep` the codebase for the symbol |
| CLI commands or flags | Run with `--help` or read the arg parser |
| Config keys | Search for the key in config loaders |
| URLs (internal links) | Verify the target file/anchor exists |
| Dependency names | Check `package.json`, `Gemfile`, `Cargo.toml`, etc. |

Flag anything that points to something that no longer exists
or has been renamed.

### 3. Index and registry sync

Many repos maintain an index — a list of skills, modules,
endpoints, or components. These drift the fastest.

- Compare the index entries against what actually exists on
  disk (directories, files, exports)
- Flag entries in the index that have no matching artifact
- Flag artifacts that exist but are missing from the index
- Verify descriptions match the artifact's own self-description
  (frontmatter, docstring, header comment)

### 4. Stale content detection

Look for signs that content describes a previous state:

- **Removed features still documented** — references to files,
  flags, or behaviors deleted in recent commits
- **TODO/FIXME in docs** — often outlive the work they describe
- **Version-pinned references** — stated versions that no longer
  match lockfiles or CI config
- **Conditional language about completed work** — "we plan to",
  "will be added", "coming soon" for things already shipped
  (or abandoned)
- **Dead links** — internal anchors that no longer resolve,
  external URLs that 404
- **Orphaned screenshots or diagrams** — image files referenced
  nowhere, or references to images that no longer exist

### 5. Consistency checks

- **Terminology** — the same concept should use the same name
  everywhere. Flag synonyms that could confuse a reader
  (e.g., "bundle" vs "package" vs "archive" for the same thing)
- **Structural consistency** — if most modules have a doc
  section and one doesn't, flag the gap
- **Date references** — relative dates ("last month", "recently")
  rot immediately. Flag any that aren't absolute

### 6. Produce a report

Summarize findings before making changes. Group by severity:

- **Broken** — references to things that don't exist (will
  actively mislead a reader)
- **Stale** — content that describes a previous state (may
  confuse but won't break anything)
- **Missing** — artifacts that exist but lack documentation
  (gaps in coverage)
- **Style** — inconsistencies that reduce clarity but don't
  misinform

### 7. Apply fixes

For each finding, decide:

- **Fix** — update the reference, remove the stale content,
  add the missing entry. Most broken and stale items fall here.
- **Flag** — leave a comment or note for the human when the
  correct fix isn't obvious (e.g., should a removed feature's
  docs be deleted or replaced with a migration note?)
- **Skip** — intentional divergence (e.g., docs for an upcoming
  release). Note why it was skipped.

Commit fixes in a single commit with a clear message. Don't
mix drift fixes with feature work.

## Adapting to the repo

This skill is repo-agnostic. Adapt the checks to what the repo
actually contains:

- **Monorepo with packages** — treat each package's README as
  a separate audit surface; also check the root index
- **API project** — add endpoint documentation vs route
  definitions as a cross-reference category
- **Skill repo (like dave-skills)** — check AGENTS.md skill
  index against `skills/*/SKILL.md` on disk
- **App with config** — check documented env vars against
  what the app actually reads

## What not to do

- Don't rewrite prose style while fixing drift — stay focused
  on accuracy, not aesthetics
- Don't add documentation for undocumented code unless asked —
  the audit surfaces what's missing, the human decides what
  to document
- Don't delete docs for features you're unsure about — flag
  them instead
