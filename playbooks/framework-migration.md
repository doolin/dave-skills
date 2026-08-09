# Framework / library migration planning

How to plan a swap of one framework, library, or vendor component for
another (editor, ORM adapter, JS framework, CSS system) so the epic is
grounded in verified facts, preserves every capability users already
have, and retires the old dependency completely. Read BEFORE writing
any migration ticket. Reference run: dbb Trix → Lexxy (DBB-0511,
2026-07-15).

## Stage 1 — Capability inventory (repo side, deterministic)

Grep the repo for every touchpoint of the outgoing dependency. Expect
false positives (searching `trix` matches `matrix`); confirm each hit
by reading it. Classify every real touchpoint:

- **Workarounds** — code that exists because the old tool lacked
  something (custom configs, monkeypatches, hand-built toolbar
  buttons). These are DELETION candidates if the new tool is native.
- **Genuine extensions** — capabilities you built that no tool ships
  (custom server endpoints, bespoke UI actions). These must be
  REBUILT on the new tool's extension surface.
- **Glue** — event listeners, selectors, CSS hooks, importmap/bundle
  pins, layout partials. Mechanical PORTS.
- **Server-side survivors** — anything tool-agnostic (endpoints,
  models). Explicitly mark as untouched so nobody "migrates" them.

Also inventory the SPECS that encode old-tool behavior — they need
reframing, not just selector renames (an idempotency spec written for
the old serializer means something different under the new one).

## Stage 2 — Vendor fact table (docs side)

Check the operator's reference corpus first (reference-acquisition
playbook), then the new tool's own docs — never plan from training
data or the landing page alone. Pull implementation-grade specifics:

- install mechanics for THIS repo's stack (bundler vs importmap vs
  npm; version floor; framework-version behavior differences)
- the event/API surface your glue code needs, mapped name-by-name
  against what the old tool provided (a 1:1 table is the goal)
- the extension API, with class/method names — this decides whether
  your genuine extensions are rebuildable or blocked
- release maturity (pre-1.0? release cadence?) — feeds pin strategy;
  churn is a concrete reason for a pessimistic pin

Every claim in the plan cites a fetched doc or the repo, not memory.
Unknowns the docs don't settle become NAMED SPIKE QUESTIONS, not
assumptions.

## Stage 3 — Stored-data census

If the dependency touched persisted data (serialized content, schema
conventions, encoded formats), count the real corpus before planning:
how many records, how many use each at-risk feature. A migration whose
risk set is "2 documents with custom attachments" plans differently
than one with ten thousand. Read-only queries only; sizes both the
risk and the verification effort (small corpus → inspect every record).

## Stage 4 — Capability-preservation matrix

One table, one row per capability from Stage 1: how it survives
(native / rebuild / port / retire), the Stage-2 fact that proves it,
and effort. Rows with no proving fact go to the spike. This matrix IS
the migration contract — the epic's acceptance criteria derive from it.

## Stage 5 — Epic shape

- **Spike first, time-boxed**, answering the named unknowns against
  the REAL corpus on a branch. Conditional no-go keeps the ticket open
  with revisit triggers (spike-no-go-does-not-close).
- **Core swap** as its own ticket: dependency in, workarounds deleted,
  minimal green state. First inspectable milestone.
- **Ports and rebuilds** as parallel tickets after the core swap, one
  per capability cluster, each independently CI-green.
- **Retirement last**: normalize legacy data (DB mutation = operator
  gate, always), then sweep until `grep -ri <oldtool>` returns only
  intentional history. A migration that leaves the old dependency
  half-referenced is not done.
- Route the document trail per the owning PRD (version bump for
  material scope), and record follow-on capabilities the new tool
  unlocks as future scope candidates, not silent scope creep.

## Non-negotiables

- Cite facts, not vibes: every "the new tool supports X" traces to a
  doc fetched during planning or a spike finding.
- Dependency order between tickets is explicit (`depends_on`), and any
  known capability-gap window between tickets is named in the ticket
  that opens it.
- Data mutation during normalization is per-action operator-approved
  with a named backup, regardless of environment.
