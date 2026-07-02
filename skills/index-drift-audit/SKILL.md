---
name: index-drift-audit
description: Keep a .development/ document set from rotting silently — an auditor-managed INDEX.md manifest plus a deterministic Ruby reconciler that flags orphaned, missing, and stale documents. Statuses are computed determinations; rows transition, never disappear. Suitable for a cheap recurring pass by a small model.
---

# Index Drift Audit

A `.development/` directory tracks tasks well, but its documents —
especially `plans/` — go stale invisibly: a superseded approach, a
plan whose work shipped, a file renamed so cross-references dangle.
Nothing in the schema notices. The cost is paid later, when someone
trusts a stale plan.

The fix is a manifest with a mechanical reconciler:

1. **`.development/INDEX.md`** — one row per tracked document,
   between explicit markers. Prose around the table is free-form.
2. **`audit_index.rb`** (bundled with this skill) — a deterministic
   reconciler that owns all table edits: enumerate disk, diff
   against the table, refresh metadata, flag anomalies.
3. **A recurring agent** — runs the script and relays the summary.
   The agent does *no* table editing; hand-editing a markdown table
   is exactly the part small models corrupt (misaligned columns,
   dropped rows, invented dates).

Statuses are computed determinations, never free-form lifecycle:
`current`, `stale?`, `orphaned`, `missing`, and the human-set
`superseded`. Rows are never deleted — a vanished file becomes
`missing`, a replaced one `superseded`, so provenance survives.

Extracted from `ww-dien-bien-phu`, which built and proved the
technique. Pairs with the **document-drift** skill: that one audits
prose and link drift on demand; this is the narrower, mechanical
"does the index match the files" check, cheap enough for cron.

## Setup (run once per repo)

1. Copy `audit_index.rb` from this skill's directory into the
   repo's `scripts/`. It is stdlib-only and resolves the repo root
   via git, so it needs no editing.

2. Create `.development/INDEX.md`:

   ```markdown
   # Index — `.development/`

   A manifest of every tracked document under `.development/`.
   Its purpose is drift control: documents go stale silently, so
   a recurring audit reconciles this list against the files on
   disk and flags anything orphaned, missing, or stale.

   The table between the markers is auditor-managed — regenerated
   by `scripts/audit_index.rb`. You may freely edit the Purpose
   column (a terse hook; the document itself is the source of
   truth). Status and Last audited are set by the audit. Rows are
   never deleted — a removed file becomes `missing`, a replaced
   one `superseded`, so provenance survives.

   <!-- INDEX:BEGIN -->
   | Path | Purpose | Status | Last audited |
   |------|---------|--------|--------------|
   <!-- INDEX:END -->
   ```

3. Seed the table by running the audit twice: the first `--write`
   run adds every document as `orphaned` (expected — nothing was
   indexed yet); the second settles them to `current`.

## Running the audit

Run on a schedule, or before a release:

```sh
ruby scripts/audit_index.rb --today <YYYY-MM-DD> --write
```

Pass `--today` explicitly — an agent should never guess the clock.
`--staleness-days N` changes the 90-day default. Omit `--write`
for a dry-run preview.

Then:

1. **Read the printed summary.** It reports counts and, per
   anomaly class, the exact paths: `ORPHANED` (on disk, not in the
   index), `MISSING` (indexed, gone from disk), `STALE?` (last
   commit older than the staleness window).
2. **Surface every flag to the human, verbatim.** Do **not** act
   on flags: do not delete, move, rename, or rewrite any document,
   and do not resolve a `missing`/`orphaned`/`stale?` yourself — a
   missing file may have been intentionally moved; a stale plan
   may still be valid. Those are human decisions.
3. **Refine an orphan's Purpose only if needed.** The script fills
   it from the file's first heading. If that is uninformative,
   replace the Purpose cell with a terse (≤ ~10 word) hook — but
   never copy substantive content out of the document into the
   index (that just creates a second thing to drift).
4. **Commit** the updated `INDEX.md` if (and only if) it changed,
   with a message like `Reconcile .development index (audit
   YYYY-MM-DD)`. If nothing changed, there is nothing to commit;
   say so.

## Hard rules

- Only `INDEX.md` is ever modified, and only by the script.
- Rows are transitioned, never removed.
- The Purpose column is the only generated text, and only the
  document's own first heading may seed it.
- Given the same disk state, git dates, and `--today`, the output
  is identical — the audit is idempotent.
- Exit status: 0 clean, 1 if anything was flagged, so CI or cron
  can react.
