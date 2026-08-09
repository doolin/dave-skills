# Digitizing a scanned board-game map → clean SVG + game graph

Proven end-to-end on *Sabotage* (1943) in `~/src/sabotage-1942` (rename to
`-1943` pending). The reference implementation and full write-ups live
there: `docs/jpeg-to-svg.md` (scan→geometry pipeline) and
`docs/refining-art.md` (art iteration loop, guardrails, auditing tips).
Read both before starting a new map; this page is the cross-project
distillation with model-class assignments.

## Pipeline stages, and which model class handles each

| # | Stage | Model class |
| --- | ----- | ----------- |
| 1 | Raw vector trace: ImageMagick grayscale/despeckle → `mkbitmap -f 32 -s 2 -t 0.42` → `potrace -s -t 40 --tight`. Keep as reference only, never ship it. | **Haiku** — mechanical, commands above |
| 2 | Node detection: OpenCV Hough circles scored by ring-likeness (sample the circumference against the OUTSIDE background only — digits inside circles poison interior estimates), radius sweep ±4 px; targeted ROI passes for stubborn circles; adaptive threshold + contours for squares. **Freeze results to JSON immediately** — ids derive from them. | **Fable** to derive for a new map; **Sonnet** to re-run the documented recipe |
| 3 | Edge classification: sample the scan along each close node pair (perpendicular-band min darkness), require thin-line isolation (flanks light) so illustrations don't read as paths, run-length analysis for dashed vs solid, collinearity pruning. | **Fable** first time; **Sonnet** with the recipe |
| 4 | Curation tables: semantic ids (EXPECTED), EXTRA/REMOVE/RESTYLE edges, SNAP_GROUPS (photo-warp straightening), FIXUPS (print-faithful nudges), BENDS (printed curvature). The game's rules document is the arbiter for every ambiguity. | **Sonnet**; escalate genuinely ambiguous calls to **Fable** |
| 5 | Deterministic emission + byte-identical fixture pinning + 100% line/branch coverage + black. | **Sonnet** to set up; **Haiku** to maintain |
| 6 | Artwork: one function per object built from 7 SVG primitives, positions in scan pixels, ~2–3 KB per object, drawn from phone closeups the user supplies — never from the blurry full scan. Crop-magnify-compare loop with ImageMagick. | **Sonnet** for most objects; complex machines / perspective buildings go faster on **Fable** |
| 7 | Audit vs print: overlay render (geometry over faded scan; draw deliberately-moved nodes ORANGE so they don't read as drift), tiled side-by-side crops, ring-spacing math, live user reports. | **Sonnet** for mechanical sweeps; phantom-edge and rules-conflict judgment → **Fable** |
| 8 | Game-graph JSON export: spaces/adjacency/equipment requirements keyed to the SVG ids, fixture-pinned, shared `assemble()` with the SVG build. | **Sonnet** |

## Map elements: the inker's workflow (David, 2026-07-01)

(Terminology per David 2026-07-03: these are "map elements" —
never "furniture", a word not used in this domain.)

Tables/charts/title blocks are INDEPENDENT artifacts emplaced onto the
map — never drawn in place. That matches how the originals were made:
the designer inked each table separately and overlaid them during
print prep (pen up, move, pen down, draw — David inked graphics this
way 45 years ago and will supply physical-workflow leverage on
request). Consequences: each table is its own emitter with a local
origin, positioned by one (x, y, rotation) emplacement; registration
is checked per-table against the scan (compare/triptych tool), and
repositioning never touches table internals. Match the print's
typography; skip its drop shadows unless asked (JV). Reproduce table
GLYPHS (NATO unit boxes — crossed box = infantry, size marker sits ON
TOP of the box — stars, aircraft/ship icons) as vector emitters; mind
that glyphs rotate with their panel (some print upside down).

## Print-fidelity techniques (Sabotage audit passes, 2026-07-02)

- **Route re-stroke over occluders.** When path edges legally render
  under illustrations (layer order: paths → buildings), the print often
  still shows the route crossing the artwork (dashes over a gate leaf,
  a line through a window). Don't reorder layers globally — re-stroke
  just the hidden segment in a group drawn after the artwork, matching
  the edge's exact stroke width and dasharray, so the route reads
  continuous. Keep them in one `entry_routes()`-style function.
- **Crop arithmetic for measuring the print.** Derive coordinates from
  crops, not eyeballs: `scan_px = crop_offset + crop_px / resize`.
  Measure the same feature in two independent sources (map scan AND
  phone closeup) before coding; closeups have perspective, the scan has
  warp — where they disagree, trust the scan for position and the
  closeup for structure.
- **One symbol per print variant.** Two instances that look "like the
  same thing" may be different designs in the print (Sabotage: narrow
  herringbone gate at 3 vs wide squat double gate at 5). Parameterize a
  shared emitter only after confirming the print repeats the design;
  otherwise you'll faithfully draw the wrong gate twice.
- **Direction arrows are data.** Keep arrowheads in a
  `(from_node, to_node, fraction)` table rendered by one function —
  placement fixes ("arrow must clear the taller gate") become
  one-number edits, and missing arrows are one-line adds.
- **Closed frames.** Printed stands/hearths/frames sit on ground sills —
  a frame whose posts end open at the ground line reads as floating.
  Check every boxy illustration's bottom edge against the closeup.

## Multi-sheet hex maps (Nguyen Hue, 2026-07-02)

Reference implementation: `~/src/vs-nguyen-hue` (`tools/lattice.rb`,
`stitch.rb`, `survey.rb`, `emit.rb`, `overlay.rb`,
`map/control-points.json`, `map/hexes.json`).

- **Printed hex ids are absolute lattice addresses (CCRR)** — so
  multi-sheet assembly is NOT pairwise photo-stitching: register each
  sheet independently onto one global lattice. Hand-measure label
  centers as control points (frozen JSON, append-only), fit one
  similarity transform per sheet in a single linear least-squares
  system, pick the odd-column parity variant by residual (the wrong
  one is ~10× worse — unambiguous). Seam hexes then align by
  construction. Expect real per-sheet scanner skew (up to ~1°);
  abutment can never work.
- **The label-anchored frame pitfall.** Anchors measured at label
  centers make the whole fitted frame label-anchored: every derived
  hex rides north by the label-to-center distance (~60 px at 300 DPI
  here). It reads as a systematic ¼-hex shift on the overlay.
  Measure it against the print once and apply it as a documented
  constant in the lattice library — labels stay on the fitted
  points, geometry drops.
- **Sheets scanned while assembled** leave flap shadows AND occluded
  seam strips that exist on no scan (the overlap flap hid the
  neighbor's ink from the copier). Per-sheet edge trims live in the
  control-points JSON; kill the shadow bars there, accept the lost
  sliver — vectorization regenerates the linework anyway.
- **Sheets with cut labels** (a strip at a sheet edge) still anchor
  via partial constraints: hex left-vertices pin only lattice-x
  (u = 1.5·col − 1), cut labels pin only lattice-y. Without them a
  sheet whose full anchors cluster in one corner extrapolates its
  rotation badly.
- **Hand-drawn grid existence detection**: a hex exists where all six
  sides read as drawn lines *at one coherent local offset* — the
  grid wanders up to ~40 px off ideal near creases, so search an
  offset grid, but cap the search RADIUS or a blank candidate
  aliases onto its real neighbor one column over. Exclude
  map-element bboxes (legend sample hexes read as real ones).
  Calibrate the detector against the control-point hexes (all are
  known-true) until recall is 100%, then freeze and curate by id —
  the operator says "1720 and 1721 are superfluous" and the fix is
  a two-line JSON edit plus a seconds-fast re-emit.
- **Sheets with NO printed hex ids** (CLF Dien Bien Phu, 2026-07-04):
  register on the lattice itself. Pointy-top hex paper's only long
  vertical ink strokes are hex sides; they form combs (pitch W/2 in
  x, 1.5s in y) fit by weighted autocorrelation + circular phase,
  with rotation as a residual-vs-orthogonal slope. Use only
  full-length strokes for the y comb (dashes drag midpoints). Pick
  each sheet's cell window by ink-support maximization; identical
  windows across sheets (same master paper, same copier placement)
  is the cross-check. Integer window errors are seam-feature
  curation, one frozen-JSON nudge per sheet. Fit an affine, not a
  similarity — photocopies carry ~0.5% x/y anisotropy plus shear.
- **Butt seams amputate single-sheet testimony.** Sheets draw ink
  past their block boundary (fort halves, line hooks live in the
  partial edge hexes); a hard cut leaves loose ends that read as
  misregistration. Merge a small overlap band with darkest-pixel
  compositing (ink beats paper) — margins chosen to stay inside
  paper-edge junk (scanner bars above, penciled sheet numbers
  below). And expect the DESIGNER's own inter-sheet misregistration:
  if no integer shift reconciles all of a sheet's seam features at
  once, the steps are the print's — reproduce, don't fix. Verify
  with the ideal-lattice overlay before curating anything.
- **Owner marginalia is not designer testimony.** Penciled sheet
  numbers, hex counts, and margin notes on a surviving copy come
  from a later OWNER's hand; they attest the set that survived,
  not the set that shipped. Completeness arguments built on them
  are circular (CLF DBP: circled ①–⑨ + "map 36×54" pencil count
  cannot prove no tenth sheet existed). Designer-side evidence is
  the ink itself: ruler-straight closure lids drawn to a board
  edge, terrain lines that RESOLVE at the last hex row instead of
  cutting off mid-stroke, no feature amputated at an edge, the
  full historical extent on-map. Write the missing-material
  question up as its own doc with both sides and provenance leads;
  don't let it block the pipeline.
- **The audit loop must be seconds, not a minute.** Overlay = ideal
  geometry in a contrast color over the print faded to gray, SAME
  canvas frame as the composite so it's 1:1. Default the render to
  half scale with the faded base cached; keep full-res behind a
  flag. When the operator reports misalignment, ask which of two
  things it is: a systematic offset (registration bug — fix the
  frame) or local wander (the hand-drawn grid meandering around the
  ideal lattice — the thing you're digitizing away from; leave it).

## Single-sheet color hex maps (Bloodtree Rebellion, 2026-07-06)

Reference implementation: `~/src/bloodtree-rebellion`
(`tools/hex_anchors.rb`, `hex_lattice.rb`, `emit_hex_overlay.rb`,
`overlay_check.rb`; frozen `map/anchors.json`, `map/lattice.json`;
lessons in `.development/LESSONS-LEARNED.md`).

- **Printed center markers are the best anchors when the map has
  them.** GDW-style maps often print a dot/symbol at select hex
  centers (power bases, objectives). Detect them (HSL hue+saturation
  mask, connected components, solid-disc filter on area/aspect/fill),
  bind a spread to printed ids by reading crops, freeze, fit the
  affine — the label-anchored-frame pitfall never arises because the
  anchors ARE hex centers. Validate the fit against every detected
  marker by nearest-center residual, not just the bound ones.
- **Tune the detector on a marks render, not a histogram.** Area
  histograms have plausible wrong clusters (stipple texture dots,
  round letterforms in map lettering). Circle every candidate on a
  half-scale render and look.
- **Suspected edge-hex geometry quirks: measure before coding.** A
  heavy game-boundary band drawn centered on hex sides makes edge
  rows read as stretched/shallow. 4x crops of two sample hexes
  settled it (ideal within warp) and deleted a planned special case.
  Crop-the-scan-first applies to the agent's own hypotheses too.
- **Print rectangle by per-edge strip trims** — whole-image trim is
  poisoned by scanner streaks that reach the canvas edge. The rect
  drives edge clipping; 300 dpi × rect should reproduce the sheet's
  nominal inches (sanity check).
- **Overlay semantics**: viewBox in scan pixels so the SVG drops 1:1
  onto the scan; one `<g id="hex-CCRR">` per hex (polygon + label) so
  hexes are independently addressable/selectable; polygons clipped
  geometrically (Sutherland–Hodgman against the rect, hairline
  slivers dropped, `partial` classed); labels cut by a layer
  clipPath so edge labels truncate exactly like the print's own.
- **Column parity is data.** Fit both half-offset variants against
  bound anchors and let residuals choose (the wrong one misplaces
  alternating columns by W/2 — here 14.5 vs 15.5 u-steps was
  unambiguous across anchor pairs).
- A folded-and-scanned flat sheet carries smooth fold warp (±20 px
  over 8200): one global affine still lands every line within the
  print's own stroke width; do not chase it with local corrections
  until a QA crop shows a real misread.

## Hex-number label module (Bloodtree, 2026-07-06)

Placement math for printed-style hex ids on an overlay, parametric so
one constant moves everything. Reference: `emit_hex_overlay.rb`.

- **Frame**: scan orientation, pointy-top hexes; `W` = flat-to-flat hex
  width taken from the fitted lattice (the affine's row step — never a
  hand-measured constant); `F` = font size in scan px.
- **Element**:
  `<text text-anchor="middle" transform="translate(x y) rotate(-90)">CCRR</text>`
  — rotate(−90) reads bottom-to-top, matching GDW print orientation.
- **x = cx − W/2 + k·F** with `k ≈ 1.0`: baseline one em in from the
  hex's near vertical edge. Under rotate(−90) the ascent extends
  toward that edge, so the digit column occupies roughly
  `[x − 0.75F, x]` — hugging the edge with ~0.25F clearance.
- **y = cy** exactly; `text-anchor: middle` centers the string on the
  hex's vertical midline. No baseline correction needed.
- **Size**: print-matched F ≈ 0.12·W (Bloodtree print caps ≈23 px at
  W=187). Operator-preferred: F ≈ 0.11·W, squat wide grotesque
  (Verdana), gray ink (#7a7a7a) not black, slight tracking (+2 px).
  Converge by the operator's ladder: start too small, step up — judged
  ONLY on the composite next to the print's own labels.
- **Edge rules**: emit the label only when its anchor x lies inside the
  print rect (left-edge half hexes correctly lose labels, exactly like
  the print); a layer clipPath on the whole hex group truncates
  edge-row labels the way the print's own sheet edge does.
- **Freshness trap**: if the QA tool caches a full-size composite,
  key it on the SVG's mtime — stale composites silently show the
  previous emit and burn an iteration round.

## PDF-reprint quadrant scans (Fifth Frontier War, 2026-07-06)

Reference implementation: `~/src/fifth-frontier-war` (`tools/
extract_sections.rb`, `detect_discs.rb`, `fit_stitch.rb`,
`emit_map.rb`, `emit_hex_overlay.rb`, `overlay_check.rb`; frozen
`map/stitch.json`, `map/hex-curation.json`; lessons in
`.development/LESSONS-LEARNED.md`).

- **Publisher PDF reprints hide the map as page-sized cuts of one
  master scan.** `pdfimages -list` finds them (landscape pages,
  uniform ppi); `pdfimages -all` copies the JPEG streams
  byte-for-byte — never re-render the pages. Content continues
  exactly across the cuts (split world discs rejoin), but each page
  carries its own crop slop and edge junk and each cut eats a
  2–12 px sliver, so naive abutment still fails.
- **Unsupervised lattice registration, no id reading.** When hex
  centers carry printed markers on every sheet: detect them, joint
  least-squares fit of one lattice + per-sheet placement, seed the
  whole-hex integer ambiguity from the physical page joins. Printed
  ids enter only to bind CCRR numbering afterward (one confirmed
  anchor + column-parity check + validate every marker by nearest
  node).
- **A tight translation fit still jogs the seams.** Per-sheet
  scale/shear hides in sheet-averaged residuals (RMS 2–3 px looked
  fine; the seam was off ~9 px at its far end — the operator's eye
  caught it first). Affine-per-sheet applies to flatbed PDF scans,
  not just photocopies.
- **Rectify the target lattice when a regular overlay is the goal.**
  Scans ran ~1.2% y-anisotropic. Force the fit target to
  H = W·2/√3 and let the affines absorb it: the composite becomes
  geometrically regular, so overlay hexes are perfect and drift
  never accumulates. Record raw `scan_h` beside the rectified pitch.
- **Butt-seam edge correlation is a dead end** (weak broad 1-D NCC
  peaks at wrong offsets); the lattice fit replaces it.
- **Hex-existence sampling on a stitched composite:** seam fill must
  count as UNKNOWN edge evidence, not absent (else misses cascade
  down every seam column); world discs defeat mean-brightness center
  tests (use per-pixel dark-neutral majority); dark box-panel
  backing + box outlines defeat both color and wall probes (add
  connected-component minimum + neighbor rescue + frozen id
  curation). Validate: every detected center marker lies in a kept
  hex, key-inset samples excluded by design.

## Point-to-point starmaps, bright ink on starfield (Company War, 2026-07-06)

Reference implementation: `~/src/company-war` (routes-only overlay).

- **Bright near-white ink cannot be color-separated from stars** — the
  route dots sample (240,255,250), stars the same. Keep stars in the
  mask; edge classification rejects them statistically (a real broken
  route measures coverage >= 0.74 along the node-pair band; star-noise
  "edges" measure 0.30-0.42 — a 0.6 cut is decisive).
- **Round dots vs square dashes: run/gap profiles are USELESS after
  scan blur** (both ~9 px runs, 2-5 px gaps at any band width). The
  decisive feature is connected-component ELEMENT AREA in the edge
  corridor: round dots 57-58 px^2, square dashes 65-75. Calibrate on
  crop-verified pairs of each style before trusting any threshold.
- Node classes separate by erosion radius alone when the map has
  waypoint discs (~26 px) vs station rings (~50 px): Erode 6 leaves
  waypoints; Close 6 + Erode 16 leaves stations. Title lettering
  passes the station pass — prune by region, then bind ids by reading
  an indexed marks render against the printed numbers.

## Terrain classification by Haiku-class agents (Nguyen Hue, 2026-07-03)

655 hexes of monochrome texture terrain classified with Haiku doing
all bulk visual work (~75 agents), Sonnet used only for a calibration
comparison, and Fable-class effort spent on exemplar curation, prompt
tuning, and ~160-hex arbitration. Full method with measured accuracy
per tier: `~/src/vs-nguyen-hue/map/terrain-method.md`; versioned
prompts: `tools/classify.rb`. Transferable core:

- **Reduce to closed-choice matching with the answer key in view.**
  One ~250 px crop per unknown; ten exemplar crops (real map hexes,
  classes in the FILENAMES) read first in the same context; fixed
  answer vocabulary plus an `unclear` escape ("never guess").
  Haiku scored 79% cold, 89% after prompt tuning; non-confusable
  classes were 100% at every tier.
- **Calibrate before sweeping, on held-out knowns.** Freeze ~20
  hand-verified hexes disjoint from the exemplars; grade candidate
  tiers and prompt revisions against them (a `score` tool makes this
  one command). Prompt fixes that earned points: name the ignorables
  (text, roads, symbols, neighbor-sliver texture in crop margins);
  give an ordered decision rule for the confusable axis.
- **All errors live on one confusable axis** (here: three dot
  textures — hills stipple / paddy dots / trail dots). Sweep cheap
  everywhere; re-ask ONLY that family as a narrower 3-way question
  at 2x magnification (second Haiku pass). The two passes fail in
  opposite directions — cross-check, arbitrate disagreements.
- **Voting agrees on wrong answers; regions catch it.** Per-hex
  votes missed 14 borderline corridor hexes both passes miscalled.
  The catch: render the class map as a color overlay (disputes in
  magenta), crop whole disputed REGIONS from the print, rule with
  geographic coherence (trail = contiguous border corridor, paddy =
  delta). Different modality beats more votes.
- **Record rulings as a frozen override table** applied over machine
  votes by the freeze tool (self-classifying-ruleset pattern), so
  the whole pipeline is rerunnable without re-litigating judgment.
- **Agents save their own answers** (Write tool, one JSON each) and
  the merge step normalizes stray key forms (`hex-0642`,
  `hex-1925-2x`) instead of reprompting.
- **Never let batch agents index into a shared batch file** (Dien
  Bien Phu, 2026-07-04): ~35% of Haiku classifiers mis-indexed a
  `batches.json` array and classified a NEIGHBOR batch's ids —
  answers stayed valid (crops keyed by id) but coverage silently
  gapped. Embed the explicit id list in each agent's prompt, audit
  coverage per answer file (expected vs answered ids) before merging,
  and re-run only the gaps.
- **Vote passes must differ in batch structure, not just be run
  twice** (Dien Bien Phu, 2026-07-05): agents also drifted positions
  WITHIN their ordered batch (hex k's content credited to id k-2),
  and because both passes shared the same batches.json with the same
  in-batch order, identical drift landed at identical wrong ids and
  FORGED CONSENSUS — 54 hexes, in agreeing runs the dispute list
  never surfaces (whole boundary bands). Shuffle or re-cut the
  batches between passes, keep the raw per-agent answer files until
  the freeze lands (they prove drift), and run a cheap deterministic
  cross-check of class vs pixels (e.g. interior ink density vs class
  median) to flag mismatches for eyeball ruling.
- **Map-element lettering poisons terrain votes** (Dien Bien Phu):
  both independent passes agreed the title-block letters were a
  "village" while the real village sat in the disputes. Hexes under
  emplaced elements (title block, scatter diagram, compass) go
  straight to the frozen override table.

## Text layer: harvest wide, close by hand (Nguyen Hue, 2026-07-05)

Stage 3 on a 176-label hex map, done in three passes with a hard
model-class boundary the operator set after watching a fleet plateau:
Sonnet fleets get a text layer ~85% aligned; the last 15% — precision
placement QA — is main-loop frontier work, one element at a time
("the subagents just don't have the power"). Reference:
`~/src/vs-nguyen-hue/tools/text.rb`, `map/text.json`, lessons in
`.development/lessons-learned.md`.

- **Pass 1 harvest**: overlapping tiles (no label cut in every tile
  that sees it), one Read/Write-only agent per tile emitting
  tile-local JSON; the merge tool translates to canvas coordinates
  (agents never do arithmetic), dedupes overlap duplicates, and
  normalizes font sizes by label kind.
- **Pass 2 fleet correction**: render red text over the faded print,
  cut one 1:1 window per label centered on the label middle, agents
  return {dx,dy,dangle} or {skip,note}; an apply tool folds with
  clamps. Delete applied corr files immediately — they re-apply.
- **Pass 3 main-loop closure**, one window at a time. Techniques that
  made it converge in one session:
  - Proof ink at fill-opacity ~0.55 — opaque ink hides the gray twin
    under every CORRECT placement, so good labels get skipped as
    unverifiable; semi-transparent turns alignment into a glance.
  - Measure on raw-print crop isolates at 2–5×, never on the faded
    overlay; isolates give ±3 px anchors and settle wording disputes.
  - Expect harvested angles to be SIGN-FLIPPED — it was the dominant
    defect class (a dozen mirrored town names).
  - Sizes cluster by print role (display faces, junction numerals vs
    in-line numerals, region arcs); the print's tall-condensed faces
    can't match a mono font on both cap height and span — match span
    (collisions are worse) and cheat with negative letter-spacing.
  - Wrapped print labels = one entry per printed line; vertical words
    are usually one entry rotated ±90°, not "stacked letters". This
    removed a planned emitter feature entirely.
  - Keep entry indices stable during the pass (windows and corr files
    are index-keyed): flag deletions with a note, append additions at
    the end, physically remove only after the last window is judged.
  - The apply log in a session transcript is recoverable state — grep
    it before declaring a deleted skip-list lost.

## Interactive pick tool: local click server (YOTR, 2026-07-02 — PLANNED, not yet built)

Design only so far; full plan in
`~/src/year-of-the-rat/.development/map-click-server-plan.md`. When an
audit or labeling pass needs the operator to point at the print
("this road is fake", "the label goes here"), a local web tool beats
montage-reading. The transferable design:

- **One shared CSS transform for raster and overlay.** A single
  pan/zoom container (`translate(tx,ty) scale(s)`) holds the map
  `<img>` at native size and an `<svg viewBox="0 0 W H">` on top.
  Overlay geometry is authored in native scan pixels; the browser
  scales both together, pixel-locked. Screen→map is one affine
  inverse (`map = (screen − t) / s`) — no Leaflet, no CRS.
- **Native scan pixels are the only coordinates on the wire.**
  Screen coordinates never leave the browser. Clicks POST in the
  same frame as the frozen JSONs and the generated SVG.
- **The server enriches clicks with the frozen lattice** (it's the
  project's own Ruby, so `hex_at` is a require away) and appends to
  a `clicks.jsonl` log — that file is the terminal-side channel the
  agent reads.
- **Overlay layers**: the generated SVG drops in verbatim (same
  frame) for print-vs-generated comparison; a session layer is
  replaced wholesale (`innerHTML` of one `<g>`) on a version-number
  poll — replacing a group never touches the transform or raster.
  `vector-effect="non-scaling-stroke"` keeps picks visible at any
  zoom.
- **Clicks carry a mode** (label / path / flag) so one tool serves
  naming, curve-drawing (server echoes a Catmull-Rom preview), and
  y/n audit verdicts snapped to the nearest frozen feature.
- Session output is raw material only; frozen JSONs still change
  through curation tables + re-freeze.

## Non-negotiables (any model class)

- **The Ruby tools are the canonical version of the map; the SVG/HTML
  are artifacts those tools produce** (David, 2026-07-02). Every fix —
  geometry, placement, dike coordinates, keep-lists, refit decisions —
  is expressed as tool code/constants and the artifact is re-emitted.
  Never hand-patch an artifact, never run ad-hoc scripts against it;
  extend the committed tool and rerun it. Diagnostics likewise belong
  in committed instruments (overlay/compare tools), not one-off
  scripts.

- Never re-run detection or edit the frozen JSONs; node ids must stay stable.
- The committed fixture is a ratchet: updating it is the deliberate act of
  accepting a visual change, done only after comparing renders at matched crops.
- One object per commit, source closeup committed alongside; imperative
  summary ≤ 57 chars; body says why.
- The print is the arbiter. When anyone reports a discrepancy, crop the scan
  FIRST — a "missing" line may be yours to delete (a phantom edge from
  illustration darkness), not the map's to gain.
- The rules text settles what eyes can't (counter inventories, charge
  weights, ambiguous cursive glyphs).
- Tangent reads as badly as overlap; separate shapes with an unmistakable gap.
- Layer like the print: ground → border → paths → illustrations (white-filled
  walls occlude paths behind buildings) → spaces → over-space marks.
- Board-facing orientation (operator principle, 2026-07-02): BEFORE any
  text or symbol orientation work, an agent must establish two facts and
  write them into the project README: (1) the map's compass, fixed from
  named anchors on the print (YOTR: Soc Trang at the south edge, Quang
  Tri near the north edge; the printed compass rose confirms) — NSEW are
  absolute, top/bottom/left/right are relative and banned; (2) which
  edges the players occupy — it varies per map (YOTR: E and W). Then:
  elements BOTH players read (feature names — towns, rivers, supply
  points) run parallel with the N/S edges, N up; features applicable to
  only one side face that side (a faction's setup boxes and tracks face
  that faction's seat — why boards print a table twice, one copy rotated
  180°).
- Shell discipline: `pytest -q | tail` masks the exit code — never chain a
  commit after a piped test run.

## Tooling required

ImageMagick (`magick` — the crop/magnify/compare loop is the core skill),
potrace + mkbitmap, Python venv with opencv-python-headless + numpy,
pytest + coverage (branch, fail_under=100) + black, and an agent that can
Read images. No GUI needed; everything verifies through rendered crops.

## Working with the user

Closeups arrive incrementally — `git status` on `original/` shows what is
new and therefore what to work on. The user reviews the live SVG and
reports discrepancies in plain language ("gap after 7", "tangent is
ambiguous"); treat each as a crop-the-scan-first audit item. Atomic
commits, pushed when a batch completes.

## /tmp + permissions structure for autonomy (Ruby projects)

Learned the hard way on fall-of-south-vietnam (2026-06-11): ad-hoc shell
churn (`cd /tmp/X && rm ... && magick ...`) generates a permission prompt
per unique compound command and burns the user's attention. Structure the
project so the agent runs autonomously:

- **One scratch dir per project**, fixed name, declared once in the shared
  module (`WORK = '/tmp/<project>-work'`). All intermediates go there,
  never in the repo; the repo holds only sources, tools, frozen JSON, and
  shipped artifacts.
- **Content-cached stages**: a `stage(name) { build }` helper that builds
  a file only if absent. Tools then simply *ask* for `ink`/`labels`/etc.
  and the pipeline self-assembles. No manual ordering, no "did I rebuild
  X?".
- **Cleanup is a tool, not a shell command**: `rebuild.rb [all]` deletes
  stage files via Ruby `File.delete`. The agent never types `rm`.
- **Every shell-ish operation becomes a small Ruby tool** (inspect.rb,
  sample.rb, map_areas.rb...): the only command the agent issues is
  `ruby <tool> <args>`, which is one allowlist entry.
- **Allowlist at project start**, in the project's own
  `.claude/settings.json` (travels with extraction if the dir is split
  out into its own repo):
  `Bash(ruby *)`, `Bash(magick *)`, `Bash(potrace *)`, plus
  `Bash(rm /tmp/<project>-work/*)` and `Bash(ls /tmp/<project>-work*)`
  as escape hatches. Do this BEFORE friction builds, not after the user
  complains.
- Caveat: a `.claude/` dir created mid-session may not be picked up until
  the user runs `/hooks` (config reload) or restarts.

## Ruby notes (vs the Python/OpenCV stack above)

The whole pipeline runs without OpenCV: ImageMagick subprocesses do the
raster heavy lifting, plain Ruby does the logic. Mappings that worked:

- **Uneven photo lighting**: `-lat 35x35+10%` (local adaptive threshold)
  extracts clean ink where any global threshold fails near washed-out
  folds. This single flag replaced mkbitmap's high-pass for the board
  photo.
- **Sealing border gaps**: `-morphology Close Disk:4` on the ink (seals
  up to ~8 px without permanently thickening); remaining gaps are data
  (patches.json of hand-placed discs/lines drawn onto the mask).
- **Region segmentation**: `-connected-components` with verbose output
  parsed by Ruby; labels exported via `-depth 16 gray:` raw dump and
  `String#unpack('n*')` — no numpy needed, 4M pixels is fine in Ruby.
- **Hough-free circle detection**: connected-component geometry is
  enough — a circle interior has bbox aspect ~1 and fill ratio ~pi/4
  (0.785). No OpenCV.
- **Gap localization** (which pixel merges two areas): pure-Ruby erosion
  on a bbox-cropped window until the region splits, then BFS-grow the
  halves back and report where they meet. ~100 lines, unit-testable
  (raster.rb).
- **Classifying hand-painted color regions**: sample 9x9 means at known
  points first (sample.rb), then write the fx expression from the
  numbers. Blue-deficiency `max(r,g)-b` separates most land from sea;
  marsh painted sea-teal needed a second term (green-tint g-r AND
  lightness). Expect one painted-color exception per map; calibrate from
  samples, never guess thresholds.
- specs: RSpec + SimpleCov (line+branch 100%) in place of pytest +
  coverage; same fixture-pinning ratchet.
- **Compositing colored ink onto a grayscale-typed base silently
  downcasts it to gray** — keep the faded base RGB (skip
  `-colorspace Gray`; fade with `-fill white -colorize 55%` alone).
  Recolor emitted SVG by rewriting its own color strings, not with
  `-colorize` on the rasterized alpha.
- **macOS can EPERM `cp` into ~/Documents** (copyfile syscall
  blocked) while plain open/write succeeds — archive renders with a
  Ruby tool that streams `IO.copy_stream`, not `cp`. Access can also
  change mid-session (iCloud eviction / TCC); verify with `ls`
  before assuming the archive landed.
