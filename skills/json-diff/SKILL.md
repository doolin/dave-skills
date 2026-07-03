---
name: json-diff
description: Structural (semantic) diff of two JSON files in Ruby — parses both and compares as data, so key order, whitespace, and formatting never register as differences. Reports changed/added/removed paths with values. Use whenever comparing JSON files or checking whether two JSON documents are semantically identical (config drift, dashboard JSON, API fixtures).
disable-model-invocation: false
allowed-tools: Bash(*/json-diff*), Bash(json-diff*)
---

# JSON diff

Compare two JSON files as data, not text.

Run the bundled script:

```bash
~/.claude/skills/json-diff/json-diff A.json B.json
```

Output is one line per differing path, then a summary:

```text
~ .panels[2].title: "Old title" -> "New title"
+ .templating: {"list":[]}
- .rows: [...]

1 changed, 1 added (only in B), 1 removed (only in A)
```

Markers: `~` changed value, `+` present only in the second file,
`-` present only in the first. Long values are truncated to keep
lines scannable. Arrays are compared index-wise.

## Exit codes

- `0` — semantically identical (prints `Semantically identical.`)
- `1` — files differ
- `12` — usage error, missing file, or invalid JSON

Pass `-q` / `--quiet` to suppress output and use the exit code
alone (e.g. as a guard in a script).

## Why this is a tool, not a one-liner

Comparing JSON by eye or with `diff` drowns real changes in
formatting noise (key order, indentation, trailing whitespace),
and ad-hoc `python3 -c`/`ruby -e` normalization one-liners match
no allowlist prefix, so they re-prompt the operator every time.
One named command with a stable invocation allowlists once and
gives a path-level report a text diff can't.

## Why this is global

Lives in the shared `dave-skills` collection and is symlinked into
`~/.claude/skills/`, so every Straylight agent has it in every
repo. Pure Ruby stdlib (`json`) — no gems, no per-repo setup.
