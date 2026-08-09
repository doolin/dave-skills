# Self-classifying ruleset tool

A pattern for turning a one-off **semantic classification** (the kind an
LLM/subagent does well but irreproducibly) into a small, deterministic,
**self-checking tool** that any future run can re-execute and trust.

Use it whenever you need to bucket a growing set of items by a judgment
that isn't purely mechanical — commits → development phases, tickets →
themes, files → owners/areas, log lines → incident classes, expenses →
categories, test failures → root-cause families. The one-shot answer is
easy; the *reproducible, maintainable* answer is the value.

## The core shape

A classifier with four parts, in priority order:

1. **Override table** — keyed by each item's *stable id* (commit hash,
   ticket number, file path). Holds the documented judgment calls: items
   the rules would mis-route, or that are genuinely exceptions. Each entry
   is a one-liner with its rationale. This is where human/semantic
   judgment lives — explicit, reviewable, diffable.
2. **Ordered ruleset** — first-match-wins predicates over the item's
   *intrinsic attributes* (subject text, date, path, labels). Order
   encodes precedence; put specific rules before general ones.
3. **An explicit `unclassified` bucket** — anything matching no override
   and no rule. **Report it; never force-fit and never silently default.**
   Silent defaulting is the failure mode that makes these tools rot: a
   misbucketed item looks identical to a correct one.
4. **Deterministic recompute** — same inputs → same output, every run. No
   model call at classification time. Stats/derived numbers compute fresh
   from source each run so they never go stale.

The non-negotiable is #3. A classifier that always returns *a* bucket
hides its own mistakes; one that surfaces "I couldn't place these 3"
turns every new item into a visible triage prompt and keeps itself honest.

## Build workflow (semantic pass → frozen tool)

1. **One-shot semantic pass.** Have a subagent classify the full current
   set with reasoning, and emit a per-bucket *distribution* (counts, date
   ranges) plus a list of the judgment calls it made. This is your oracle.
2. **Reverse-engineer rules.** Pull the raw items yourself (the actual
   subjects/attributes) and write the ordered ruleset to *reproduce the
   oracle's distribution*. Validate by count per bucket, not by vibe.
3. **Pin the judgment calls as overrides**, not as ever-more-specific
   regex. Rule of thumb: if a rule needs a clause that only exists to
   catch one item, that item belongs in the override table instead. Keep
   rules general and few; let overrides carry the irregularities.
4. **Prove zero `unclassified`** on the current set (or consciously leave
   some flagged). Then the tool is frozen and trustworthy.
5. **Validate against an independent oracle where one exists.** If a
   sibling tool already computes a global number (e.g. a repo-wide total),
   make the new tool's aggregate agree — and when it *can't* (see pitfall
   below), say so in the output rather than papering over it.

## Pitfalls (each has bitten a real run)

- **Regex over-breadth.** A generic word (`refactor`, `fix`, `update`)
  matches items you meant for another bucket. Prefer narrow, anchored
  patterns; when a broad word is unavoidable, order the bucket that should
  win *first*, or move the exception to an override.
- **Ordering bugs.** First-match-wins means a late-but-correct rule never
  fires if an early loose rule swallows the item. Test the precedence, not
  just the patterns.
- **Judgment leaking into rules.** Encoding a one-item special case as
  regex makes the ruleset unreadable and fragile. That's what the override
  table is for — and it self-documents the decision.
- **Aggregation that double-subtracts.** Per-bucket sessionization/rollups
  can undercount a global figure when items interleave across buckets
  (e.g. within-phase session gaps drop time spent between buckets). Report
  the per-bucket figure *and* the independently-computed global one, and
  explain the gap — don't claim they're equal when they aren't.
- **Stale derived data.** If the tool bakes a snapshot into a doc, note
  "regenerate with `<cmd>`" beside it, and recompute on every run so the
  snapshot is a deliberate checkpoint, not silent drift.

## Reference implementation

`~/src/nasfaa/bin/timeline` (stdlib Ruby, no deps): classifies every git
commit into a development phase via this exact pattern — `OVERRIDES`
hash (hash-prefix → phase, with rationale comments), an ordered
`classify()` ruleset over subject + date, an `:unclassified` bucket that
prints under "Classification notes," and per-phase stats recomputed from
`git log --numstat` each run. Its sibling `bin/time-analysis` is the
independent oracle for the repo-wide active-hours total. Both are
documented in that repo's `AGENTS.md`.
