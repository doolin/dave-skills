---
name: prd-trace
description: Derive the PRD → requirement → ticket map for the repo in the current directory from ticket frontmatter, never from a hand-kept table — each requirement with the tickets against it, the requirements with no ticket yet, and the tickets that cite a PRD without naming a requirement. Run it before proposing the next ticket against a PRD, and at a PRD version bump to emit the traceability appendix. Any full-form .development repo.
allowed-tools: Bash(~/.claude/skills/prd-trace/prd-trace*)
---

# PRD trace

Which requirements have work against them, and which have none?
One call, derived from the tickets themselves.

## The convention it reads

A ticket names the requirement it serves in its `links:` field,
in the form `PRD-0001 FR-004`. Several requirements on one line
are fine (`PRD-0001 FR-004, FR-005`). A bare `PRD-0001` still
counts as citing the PRD and is reported separately, so the old
habit is visible rather than lost. Nothing else is written
anywhere: the map is computed each time.

## Run

From the repo root, or with `-C` for a sibling:

```bash
~/.claude/skills/prd-trace/prd-trace                 # every PRD
~/.claude/skills/prd-trace/prd-trace PRD-0001        # one PRD
~/.claude/skills/prd-trace/prd-trace -C ~/src/dbb    # another repo
~/.claude/skills/prd-trace/prd-trace --table         # Appendix D table
~/.claude/skills/prd-trace/prd-trace --json          # edges, for the graph
```

Output:

```text
PRD-0001  Knowledge graph construction from the real world
  FR-001  The graph model must be representable in a file...   CSL-0057 done
  FR-002  The edge schema must distinguish at minimum: owne...  (no ticket yet)
  FR-004  The construction workflow must be executable by ...   CSL-0060 done, CSL-0064 blocked
  No ticket yet: FR-002, FR-003, FR-005
  Cites the PRD, no requirement: CSL-0055 done, CSL-0056 backlog
```

## Reading it

- **A requirement line** lists every ticket citing it with the
  ticket's own status. The rollup used by `--table` is: done when
  all are done, blocked if any is blocked, in_progress if any is,
  planned otherwise, none with no ticket.
- **No ticket yet** is the forward pointer: the next ticket against
  this PRD comes from this list. Propose one, wait for go, file it.
  Never file the list.
- **Cites the PRD, no requirement** is the backward gap: work that
  happened under the PRD without saying which requirement it
  satisfied. Fix by adding the requirement id to the ticket's
  `links:` when you next touch it, not by a sweep.
- **Unknown requirement** is a citation to an id the PRD does not
  define: a typo, or a requirement that was renumbered.
- **Epics** are minted only when a requirement has visibly outgrown
  three tickets, never ahead of that. Requirements are the parent
  tasks until then.

## Exit codes

| Code | Meaning |
|------|---------|
| 0    | report printed |
| 3    | no PRDs found (or none matching the id given) |
| 12   | no `.development/` tree, or bad arguments |

## Why this is a tool

The family's PRDs grow a Work to Date section and re-check
requirements in prose ("FR-004 is demonstrated"); tickets cite the
PRD loosely. A decomposition step that writes every ticket up front
was rejected as big design up front. What was missing was two
pointers, forward and backward, and both can be derived from the
citations the tickets already half-carry. A derived map cannot go
stale; a maintained table always does.

## Tests

```bash
bats skills/prd-trace/test/
```
