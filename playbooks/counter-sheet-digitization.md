# Counter-sheet digitization

Scanned wargame counter sheet → frozen roster JSON → (later)
SVG counter art. The extraction half is proven end-to-end on
CLF Dien Bien Phu (hand-drawn 1969 sheet surviving as a xerox
scan, read 2026-07-05, 112/112 cells); the art half is a
surveyed pattern from sgp-linebacker-2, not yet run against a
frozen roster. Update this entry when it has been.

Reference implementations:

- Extraction: `~/src/clf-dien-bien-phu` — `tools/counters.rb`
  (cell cropper), `map/counters.json` (frozen roster),
  `map/counters.md` (findings doc, the shape to copy).
- Art: `~/src/sgp-linebacker-2/counters/` — `counter.rb` base
  class, one emitter per counter type, sheet assembler,
  Makefile + Inkscape SVG→PDF/PNG.

## Stages

1. **Calibrate a cell cropper** (Sonnet-class). Render the
   sheet page once at full scanner density and cache it. Grid
   constants (origin, cell pitch W/H) calibrated against the
   corners of the grid — check the FAR row/column, not just
   row 0 (a 2px pitch error rides 30px high by row 13). Add
   padding for the hand-ruled card's tilt. One CLI:
   `tool ROW COL [SCALE%]`, printing the crop path.

2. **Build the closed vocabulary — game documents first,
   history second.** Setup lists, artillery/range tables,
   reinforcement schedules from the game's own rules are the
   authority; the historical order of battle is the backstop.
   Two DBP lessons: units that match no history can still be
   the designer's own canon (DBP's "345"/"154" are typed in
   the rules' ranges table), and historical vocabularies must
   include the support formations, not just the famous
   regiments (the real 237th Heavy Weapon Regiment was missing
   and got flagged as out-of-vocabulary).

3. **Fan out one reader agent per row** (strong vision model —
   Fable/Opus class for hand-drawn or degraded xerox; typeset
   counters can go lighter). All readers share one brief file:
   the glyph key from the rules, the closed vocabulary, an
   exemplar row, the VERBATIM RULE (record the ink; never
   force-fit the vocabulary; flag mismatches), per-cell
   confidence (high/medium/low), and "escalate magnification
   before settling for low confidence". Output: pure JSON per
   cell. Bank each row's result to disk as it lands — the
   sweep outlives any one context window.

4. **Arbitrate in the main loop.** Re-crop every contested
   cell and look yourself; resolve against the game's own
   tables. Resolutions live in a SEPARATE arbitration list
   (cell coords + resolved reading + rationale) — the verbatim
   cells are never overwritten. Web-check off-vocabulary
   readings before declaring them errors; save the URL and
   context of any source you cannot retrieve (login walls,
   dead mirrors) — in the findings doc and in memory.

5. **Close the censuses.** The strongest arbitration evidence
   is arithmetic, not squinting: sequence runs (battalions
   1-2-3 per regiment), per-family counts against the rules
   (DBP: 17 attached-mortar owners named, 17 dot-glyph
   combat-1 counters found — which uniquely resolved two
   illegible ones), and coverage both directions (every rules
   unit has a counter; every finished counter has a home).
   A closed census turns a low-confidence blob into a proof.

6. **Freeze the roster.** One JSON artifact: source block
   (scan, page, grid, cropper), a legend recording the sheet's
   discovered grammar (glyph deviations from the printed key,
   side-text rotation, corner-number semantics), the verbatim
   cells, the arbitration list. A one-off merge script in the
   scratchpad is fine — the frozen JSON is the artifact, like
   a stitch-curation file. Ship a findings doc beside it:
   grammar, per-row contents table, settled riddles, open
   items, sources.

7. **Emit the art** (unproven half). Follow linebacker-2's
   emitter pattern but schema-driven: the frozen roster feeds
   the sheet assembler; no unit values hardwired in layout
   code, no magic offsets. NATO glyphs per the map-elements
   rules.

## Non-negotiables

- Verbatim first: the ink is the record; interpretation is a
  separate, cited layer.
- Flag, don't force-fit: out-of-vocabulary readings are
  findings, not errors (they found the designer's own units
  and a vocabulary gap in DBP).
- Owner pencil is not designer ink (same rule as
  map-digitization): marginalia gets recorded but never alters
  a reading — in DBP the owner's "how come 3 figures?" was a
  misparse the roster later explained.
- Voided counters (struck out) and unfinished boxes are
  content: they record the designer's second thoughts and
  missing pieces (DBP's absent rocket-unit counter).
