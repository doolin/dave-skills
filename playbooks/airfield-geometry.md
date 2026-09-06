# Airfield geometry — real heading to oriented map symbol

Draw a real-world feature that carries a heading — a runway,
a bridge span, a dam, a rail-yard throat — at its true
orientation on a schematic wargame map whose drawn frame is
rotated, unlabeled, or both. The chain is: resolve what the
print's symbol refers to → recover the map's compass →
research the heading → transform it into the map's frame →
draw, place, and verify → register and archive.

Reference implementation: `~/src/sgp-linebacker-2`, Kép Air
Base (airfield 2) on the *Combat!* magazine *Linebacker 2*
map. Coordinates that hold: `tools/north_bearing.rb` at
`2877a07`, `map_bearing` at `53e2a53`, the north-arrow
overlay at `4538a47`, the symbol
`editions/improved/kep-airfield.tikz` at `371abc2`, the
dossier `docs/reference/kep-airfield.md` at `9626dba`. The
project-side plan for the remaining fields is
`.development/plans/airfield-symbols.md`.

## When to use

Any symbol whose orientation is a fact about the world and
not a drawing convention, on any map that lacks a trustworthy
north. If the print carries a compass rose or a graticule,
read it (see `map-digitization.md`, board-facing orientation)
and skip stage 2 — this playbook's fit is for maps that have
no north indicator and draw geography schematically.

The technique is not airfield-specific. Runways are the
common case because their heading is documented, visible
from orbit, and legible at symbol size.

## Pipeline (minimum model class per stage)

1. **Resolve the referent** (Sonnet). The print's label is
   not the referent. Names arrive transliterated, garbled by
   the typesetter, or attached to the wrong mark: on the
   Linebacker 2 print, star 10 is listed as "Than Hoa" and
   drawn beside Vinh, 130 km away. Output: the real name,
   coordinates, an ICAO code if one exists, and the evidence
   that the print's mark means this field. Record it at the
   top of the dossier. No heading research starts until the
   referent is settled.
2. **Recover the map's compass** (Fable-class to set up, any
   class to rerun). Choose anchors — named features whose
   drawn positions and real coordinates are both known;
   cities are ideal — at least three, not collinear, spread
   across the sheet. Fit the real constellation onto the
   drawn one by similarity Procrustes (rotation, uniform
   scale, translation; **no reflection**) and read off the
   rotation θ. Report every anchor's residual and gate on the
   worst. Pin θ and the gate in a spec so the number cannot
   drift silently. Reference: `tools/north_bearing.rb`, six
   cities, θ = 52.7° CCW of map-up, Hanoi residual 0.04 map
   units, worst (Thanh Hoa) 0.84 on a sheet roughly 18 × 13
   units.
3. **Research the heading** (Sonnet, under
   `historical-research-dossier.md`). Pick a rung of the
   precision ladder below and say which rung in the dossier.
4. **Transform** (any). `map_bearing = true_bearing − θ`,
   degrees clockwise from map-up. One function, one place,
   every caller. Then the handedness check (below).
5. **Draw the symbol** (Sonnet+; `svg-symbol-reproduction.md`
   for the render-compare loop if the symbol is more than
   lines). Orientation is the fact; size is symbolic — state
   the exaggeration. A second feature drawn by its real
   compass side (a taxiway, an apron) is what makes the
   handedness check possible.
6. **Place** (Haiku/Sonnet, mechanical). From the generator's
   own source coordinates through every transform to the
   rendered sheet, with the arithmetic written in the symbol
   file. Never position by eye.
7. **Verify** (Sonnet+, must Read images). Render at 300 dpi,
   crop, measure the drawn angle from endpoint pixels, compare
   to the expected map bearing and to the north arrow. Never
   judge at fit-to-window.
8. **Register and archive** (any). Deviations entry, dossier
   update, sources stored with the project.

## The precision ladder for headings

Each rung names its source, its frame, and its error. Decide
the rung the deliverable needs before researching; record
the rung used.

1. **Runway designator** (07/25, from Wikipedia or any
   airport listing). Magnetic, rounded to the nearest 10°:
   ±5° before declination. Declination in Southeast Asia is
   small — look it up for the site and date with NOAA's
   historical field calculator rather than assuming — but a
   designator's rounding swamps it. Designators are also
   reassigned as declination drifts, so a modern designator
   reflects the modern magnetic heading, not 1972's.
2. **Published aeronautical data** (a national AIP —
   Aeronautical Information Publication — or an ICAO airport
   record): true bearing to 0.01°. Civil fields only;
   military fields in a wartime theater rarely have it.
3. **Measured from imagery**: two runway-end coordinates →
   forward azimuth, which is a true bearing directly, to
   about half a degree. Sources: satellite basemaps,
   OpenStreetMap runway ways (node coordinates are under the
   Open Database License, ODbL — record it), declassified
   frames from the CORONA and GAMBIT reconnaissance-satellite
   programs, period reconnaissance photos when north is
   known.
4. **Declassified imagery-analysis reports** (the CIA's
   National Photographic Interpretation Center, NPIC, via the
   CIA reading room or its archive.org mirrors) sometimes
   state runway length and orientation outright; a primary
   source for the period, worth citing beside rung 3.

Sizing the decision: an angular error ε moves a symbol's tip
by L·sin ε. Kép's runway symbol is 0.44 in long; at ±5°
that is 0.44 × 0.087 ≈ 0.04 in, one millimetre — invisible on
the sheet but not nothing in a register. Kép's first symbol
used rung 1 — the 07/25 designator, recorded as "heading
070°"; the rung-3 measurement from OpenStreetMap runway
endpoints gave 067.2°, a 2.8° change that moved the tip
0.02 in. Invisible on the sheet; the register now states
what was established rather than what was assumed.

## Sign conventions — where the errors hide

| Quantity | Frame | Sense |
|---|---|---|
| True bearing *b* | geographic | clockwise from true north, 0–360 |
| θ (fit rotation) | y-up map | counter-clockwise, real → map; map-up faces true bearing θ |
| `map_bearing(b)` = *b* − θ | map | clockwise from map-up |
| SVG | y down | north unit vector is (−sin θ, −cos θ) |
| TikZ polar `(α:len)` | y up | α counter-clockwise from +x; map bearing *m* is at α = 90 − *m*; the north arrow at α = 90 + θ |
| Runway endpoints at map bearing *m*, half-length *h* | y up | (± *h* sin *m*, ± *h* cos *m*) |

Kép: `map_bearing(67.2)` = 67.2 − 52.7 = 14.5°; *h* = 0.21 in
gives endpoints (±0.053, ±0.203) in, which is what the
symbol file draws. The north arrow is at TikZ angle
90 + 52.7 = 142.7°.

**Handedness check.** The fit forbids reflection, which
assumes the map is not mirrored — an assumption, not a
result. A reflected map would still put the runway axis at a
plausible angle; only a side-dependent feature exposes it.
Real south on the map is the direction `map_bearing(180)`;
Kép's taxiway strip lies on the real-south side per the
c1966 reconnaissance photo, so it is drawn on that side, and
that is the check.

## Placement — the general form

Symbol coordinates in the generator's own units → every
transform the generator applies (Linebacker 2: a
`translate(1,1)` group) → the viewBox origin → the render
scale (rendered height ÷ canvas height) → offset from the
rendered image's center, with y flipped from SVG-down to
TikZ-up. Write the chain, with numbers, in the symbol file.

Kép, in full: star 2 sits at (3.1, 1.6); plus the translate,
(4.1, 2.6). The canvas is 18.71 × 13.62 units with its
viewBox origin at (0.70, 0.69), so its center is
(0.70 + 9.355, 0.69 + 6.81) = (10.055, 7.50). Rendered at
9.0 in tall, one unit is 9.0 ÷ 13.62 = 0.6608 in. Offset:
x = (4.1 − 10.055) × 0.6608 = −3.935 in;
y = (7.50 − 2.6) × 0.6608 = +3.238 in. The symbol file uses
(−3.934, +3.238).

Symbol scale, so the exaggeration is stated: Hanoi to
Haiphong is 88 km real (0.163° of latitude ≈ 18 km, 0.830°
of longitude × cos 21° ≈ 86 km) and 4.53 drawn units
(√(3.4² + 3.0²)), so one unit is 19.4 km and one rendered
inch is 19.4 ÷ 0.6608 ≈ 29 km. A
6,000 ft (1.83 km) runway at true scale would be 0.06 in;
the 0.44 in symbol is about 7× life.

## Verification — measure, don't look

`pdftoppm -r 300 -f 1 -l 1 -png sheet.pdf out`, then
`magick out-1.png -crop WxH+X+Y crop.png`, then Read the
crop. Do not compute sheet pixel positions by hand for the
first crop — the map's placement inside its page layout is
not the map's own geometry; crop wide around the expected
region, find the symbol, then tighten. From the tight crop,
take the runway's two endpoint pixels and compute
atan2(dx, −dy) for degrees clockwise from up; it must match
`map_bearing` within the render's own pixel error. Measure
the north arrow the same way. The two agreeing with each
other is the visual contract the sheet makes with the
player; the two agreeing with θ is the contract with the
world.

## Archive with the project

Operator decree (2026-09-05): every downloadable item a
heading or a placement rests on is stored in the project,
beside the dossier under `docs/reference/`, with a provenance
record — source URL, retrieval date, license, verification
method — in the form `historical-research-dossier.md`
specifies. That covers period reconnaissance photos,
declassified reports as PDF, OSM extracts (ODbL), AIP pages,
and the imagery crop the endpoint coordinates were read
from. Where the imagery's license forbids redistribution
(commercial satellite basemaps), store the small crop and the
coordinates read from it and mark the record *internal
reference only — not for any deliverable*. The reason is
precept 7 of the cold-reader discipline: a live URL is a
pointer and pointers rot; the archived copy is what lets a
later reader re-derive the number, check the license, and
audit the claim without the session that produced it.

## Non-negotiables

- **Referent before heading.** The print's label is evidence,
  not identity.
- **One compass per sheet.** The north arrow and every
  oriented symbol derive from the same θ, from the same
  spec-pinned tool. No per-symbol eyeballing, ever.
- **Rung stated.** The dossier and the symbol file both say
  which rung of the precision ladder the heading came from.
- **Orientation is fact, size is symbol.** Say the
  exaggeration factor once.
- **Derivation lives in the symbol file.** Position and angle
  arithmetic, with the numbers, where the next agent will
  copy from.
- **Verify by measurement at 300 dpi.** Never by eye, never
  at fit-to-window.
- **Sources archived with the project**, provenance recorded.
- **Register the deviation.** The improved edition departs
  from the print; the register says how and why.
- **Map art untouched.** The symbol is sheet furniture over
  the included map; the original edition keeps the print's
  mark.

## Generalizing further

- **Other features.** Bridges (span axis), dams (crest),
  rail yards (throat axis), harbor moles, straight river
  reaches, runway-like roads. Same chain, different symbol.
  Multiple runways at one field each get their own heading;
  Kép's pair happen to be parallel.
- **Hex maps.** The hex grain fixes map-up; θ from anchors
  still applies. A printed rose replaces the fit entirely.
- **Projection.** For a sheet spanning a few degrees,
  equirectangular with longitude scaled by cos(mean
  latitude) is adequate — that is what the reference tool
  does. For continental sheets, project anchors (UTM, or the
  map's own projection if known) before fitting.
- **When the fit is poor.** Residuals over the gate mean the
  map is not a similarity of the world. Options, in order:
  more or better anchors; a local fit from anchors near the
  feature; an affine fit (adds shear and anisotropic scale,
  so the effective rotation varies by position — compute it
  at the feature). Whatever is chosen, the sheet still draws
  one north arrow from one θ; record the local disagreement
  in the dossier rather than drawing two norths.
- **Reflection.** If the handedness check fails and the map
  really is mirrored (it happens with reversed negatives),
  rerun the fit allowing reflection and carry the sign
  through every convention in the table above.
- **Automating the placement table.** Once more than one
  symbol is placed, promote the placement arithmetic into a
  tool with a spec that emits every mark's offset; hand-copied
  numbers are how a rounding error becomes a misplaced
  airfield.

## Reference run: the other nine (September 2026)

One session took the remaining nine Linebacker 2 airfields
through the chain with nine Sonnet research agents and three
tools, all in `~/src/sgp-linebacker-2/tools/`:
`runway_bearing.rb` (Overpass fetch → archive → bearing and
length per runway way), `airfield_symbol.rb` (label + bearing
+ optional strip side → the TikZ fragment, placement included),
`axis_angle.rb` (thresholded crop → drawn angle). What the run
taught, beyond the pipeline above:

- **Stage 1 earns its place.** Three of nine print labels had
  no drawable referent: one named a district with no airfield,
  one was a heavily bombed town with no airfield, one was the
  already-drawn field counted twice under its province. Two
  more resolved only by name-to-district reasoning ("Kim Anh"
  is the district Phúc Yên was built in; "Yen Dai" garbles the
  district next to Thọ Xuân). Heading research on any of those
  before the referent was settled would have been wasted or
  wrong.
- **The handedness feature can come from OSM.** Project the
  centroid of an `aeroway=taxiway` way onto the runway's
  normal; the sign gives the real-world side. Period-correct
  only when a period source attests the taxiway (Kiến An's 1966
  NPIC report does); otherwise draw the runway alone.
- **Two patches, not one.** White out the printed star and its
  printed numeral with separate rectangles. The union's corner
  nicked a city square the print draws touching the star. Size
  the star patch for the mitered stroke: a five-point star's
  stroke reaches `half_stroke / sin 18°` past each tip — about
  0.02 in here, enough to leave specks under a patch cut to the
  vertex.
- **The verifier can lie by 2°.** A crop that clips a parallel
  taxiway at its edge, or a numeral mask large enough to chop
  the taxiway's end, biases the principal axis; both showed as
  a 1.8–2.6° error that vanished when the crop took the whole
  taxiway and the mask covered only the glyph. When a
  measurement disagrees with the derivation, suspect the crop
  before the drawing — and re-measure before touching the
  symbol.
- **Today's runway is not 1972's.** Rung 3 from OSM measures
  the present axis. Three fields had been lengthened (Kép,
  Kiến An, Vinh), one built over (Bạch Mai, rung 1 only), and
  two carried period descriptions that fit today's axis poorly
  (Thọ Xuân, Vinh). State "rung 3 for today's runway" and log
  the period axis as a gap; the upgrade is a georeferenced
  period frame.
- **Referent conflicts are the operator's.** Star 10 is
  labeled for one city and drawn beside another. The run drew
  the position's field so the result could be seen, entered
  the conflict in the discrepancies register, and left the
  decision in the resume brief — one `\input` line to remove.
