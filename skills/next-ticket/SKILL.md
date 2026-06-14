---
name: next-ticket
description: Return the next available ticket number for the repo in the current directory. Auto-detects the repo's ticket prefix (DBB, CSL, OC, ...) by scanning .development/, so it works in any Straylight repo without configuration. Use whenever you need the next ticket id to file new work.
disable-model-invocation: false
allowed-tools: Bash(*/next-ticket*), Bash(next-ticket*)
---

# Next ticket

Find the next available ticket number for the repo you are currently in.

Run the bundled script from the repo root:

```bash
~/.claude/skills/next-ticket/next-ticket
```

It scans every subdirectory of `.development/` for `<PREFIX>-NNNN-*.md`
ticket files, auto-detects the repo's ticket prefix, and reports the
next number zero-padded to four digits:

```text
Next ticket: DBB-0461
```

## How prefix detection works

Each Straylight repo carries its own ticket prefix (dbb -> `DBB`,
clubstraylight.com -> `CSL`, openclose -> `OC`) alongside the shared
document-artifact prefixes `ADR` / `PRD` / `DES` / `RFC`. The script
treats the artifact prefixes as not-tickets; whatever single prefix
remains is the ticket prefix. No per-repo configuration needed.

## New repos and disambiguation

- A repo with a `.development/` tree but no tickets yet has nothing to
  detect. Mint the first one explicitly:

  ```bash
  ~/.claude/skills/next-ticket/next-ticket --prefix=FOO   # -> Next ticket: FOO-0001
  ```

- If a repo somehow has more than one non-document prefix, the script
  exits non-zero and asks you to pass `--prefix=XXX`.

## Why this is global

This skill lives in the shared `dave-skills` collection and is symlinked
into `~/.claude/skills/`, so every Straylight agent has it in every repo.
The detection logic is what makes that safe: one tool, many repos, no
hardcoded prefix.

Report the result as: **Next ticket: PREFIX-NNNN**
