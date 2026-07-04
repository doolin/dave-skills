---
name: update-family-graph-entry
description: Update your own entry in the Straylight family knowledge graph (knowledge.json in clubstraylight.com) — mechanical corrections only, committed under the standing CSL-0027 ticket. Rarely needed; load only when your graph entry has drifted from reality and the operator asks you to bring it current.
disable-model-invocation: true
---

# Update your family graph entry

The family knowledge graph — `knowledge.json` in
`~/src/clubstraylight.com` — describes every member and every
repository in the Straylight portfolio. Straylight curates it, but
you may correct **your own entry** directly when it has drifted
from reality. This skill is that path.

## When this applies — mechanical corrections only

You are the authority on your own repos, so corrections of fact
go in directly (the graph-separation decision, 2026-07-02):

- Tooling or mechanics the entry gets wrong (a runner that was
  replaced, a mechanism misdescribed, a build that changed)
- Progress and status lines that have gone stale
- Wrong `language`, missing `visibility`, a renamed file or path

**Substantive changes go through Straylight instead** — adding or
removing a repository, changing your role or scope line, touching
any other member's entry, or restructuring the graph. Ask; don't
edit.

One home per fact: the graph carries the summary, your repo's
`.development/` carries the detail. Point at the detail
(`.development/design/<note>.md`) rather than copying it in.

## Procedure

1. **Find every location.** A repo can appear in up to three
   places — your `family.members[].repositories[]` entry, a
   `projects.<theme>.repositories[]` entry, and your member
   `infrastructure` line. Grep the repo name and correct all of
   them; a half-updated graph is worse than a stale one.

   ```bash
   grep -n "your-repo-name" ~/src/clubstraylight.com/knowledge.json
   ```

2. **Edit against the repo, not the README.** Your
   `.development/` files (roadmap, design notes, changelog) are
   the source of truth; READMEs drift.

3. **Validate.**

   ```bash
   ruby -rjson -e 'JSON.parse(File.read("knowledge.json")); puts "valid"'
   ```

4. **Commit under the standing ticket.** Graph-membership and
   entry-correction passes ride `CSL-0027`, clubstraylight's
   standing portfolio stewardship ticket. One commit, subject
   prefixed with the ticket id, body saying what drifted and why
   the correction is mechanical. Credit yourself honestly —
   your identity, your client, your model; never guess at any of
   them:

   ```text
   CSL-0027 Correct <repo> entry to match the repo

   <what the entry got wrong, and what changed in
   reality to make it wrong>

   Co-Authored by <You> via <Client> with <Model>
   ```

5. **Do not push.** The operator reviews and pushes
   clubstraylight, same as everywhere else.

Straylight keeps the CSL-0027 log (the portfolio diary) and will
record your pass there — you don't need to touch the stewardship
file.

## Boundaries

- Never edit `identity`, `creator`, `memory_protocol`, or the
  `decisions` log — those are Straylight's.
- Never edit another member's entry, even to fix an obvious typo
  — flag it instead.
- If you're unsure whether a change is mechanical or substantive,
  it's substantive.
