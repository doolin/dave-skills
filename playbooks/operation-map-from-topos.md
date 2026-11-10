# Operation map from period topographic sheets

Turn the period 1:50,000 topographic sheets of a battle area into:

- one seamless mosaic;
- a cited register of every place the sources name, each placed on
  the mosaic with its method and a confidence radius;
- a zoomable viewer with a star per place;
- a game-scale hex layout.

The base is public domain throughout. The book's maps and hobby
sites are the check, not the source.

Reference implementation: `~/src/bong-son`, ticket BSN-0019
(2026-11-04 to 2026-11-05), for Operation Masher/White Wing (1966)
on twelve AMS L7014 sheets. The parts:

- `lib/bong_son/`, with a spec for each:
  - `topo_mosaic.rb`, `grid_fit.rb`, `scan_georef.rb` (the mosaic
    and the scan georeferencing);
  - `grid_ref.rb` (grid references);
  - `location_merge.rb` (the register merge);
  - `operation_map.rb` (the viewer);
  - `hex_layout.rb`, `hex_sheet.rb` (the hex layout).
- Commands in `bin/`: `topo-mosaic`, `topo-tiles`, `topo-crop`,
  `georef-scan`, `merge-locations`, `operation-map`, `sb-layout`.
  `bin/README.md` there sets the rules every command keeps.
- Data:
  - `data/locations.json`: 213 places, 196 placed;
  - `data/georef/`.

Related:

- `battle-book-research.md`, the book-to-data arc this follows. It
  is staged in bong-son's `.development/playbooks/`.
- `operation-over-time.md`, which builds on this map: the operation
  day by day, hour by hour and zoomed, from cited day scripts.
- `historical-research-dossier.md`, for what may be published.
- `reference-acquisition.md`: check the corpus first.
- `airfield-geometry.md`, for drawing a real heading on a schematic.
- `map-digitization.md`, for a board-game map scan rather than a
  topo sheet.
- `wargame-web-implementation.md`, for the game built on it.
- The `operator-review-page` skill, for the calls only the operator
  can make.

## Non-negotiables

- **The base is public domain.** It comes from AMS/DMA/NGA sheets
  (USGS store GeoPDFs, UT PCL scans) and public geodata.
  Commercial and hobby maps, rjsmith.com included, are read for
  reference and never traced or copied.
- **The register stores grid references in the sheets' own grid,
  and nothing else for position.** WGS84 is computed for display,
  so a corrected reference (from a report, or from Kelley's *Where
  We Were in Vietnam*) moves its star with no other edit.
- **Every placement carries its method, a confidence radius, and
  its evidence** with screen or page. A place that cannot be placed
  is a record with no grid and the reason. Never guess a grid to
  fill a gap.
- **Two placements more than a kilometre apart are flagged for the
  operator, never averaged.**
- **The operator downloads; every PDF is scanned before it is
  opened** (ClamAV plus a static PDF check). No curl.
- **Durable tooling is tested Ruby**, one declared job per command,
  external programs called with argument arrays.

## Facts that shape the work

1. **Sheet numbers are computable; list the sheets before
   searching.** For L7014, the first two digits step longitude by
   half a degree and the last two latitude, with quarters 1 NE, 2 SE,
   3 SW, 4 NW. Most sheets are NGA GeoPDFs on the USGS store; the
   UT PCL fills gaps with plain scans.
2. **GDAL does not know the datum the GeoPDFs declare.** The NGA
   sheets carry Indian 1960 in their georeferencing dictionary.
   GDAL falls back to WGS84, and the seams shift. Assign the CRS
   explicitly on every warp: `-s_srs`, `-t_srs` and `-cutline_srs`,
   all EPSG:3149 (Indian 1960 / UTM 49N; EPSG:3148 is zone 48N).
   Cut each sheet to its neatline (`-cutline` from the NEATLINE,
   `-crop_to_cutline -dstalpha`), so no collar overlaps a neighbour.
   Then join the sheets in a VRT. Check a seam on a road and a grid
   line.
3. **A plain scan is georeferenced from its own printed grid.**
   - **What failed:**
     - pairing grid lines band by band, because vegetation hides
       lines and the counts differ;
     - extrapolating from a corner, which biased the fit by about
       10 px.
   - **What worked:**
     - read one labelled line each way by eye;
     - sight lines in many bands across the sheet;
     - fit each family as one model,
       `position = c0 + c1·index + c2·across`. This also absorbs
       the scan's rotation.

   The reference sheet gave 728 control points at RMS 0.3 m, and
   Highway 19 met its neighbour within about 3 px. Grid lines
   differ by about 50 m between printings; note it and accept it.
4. **Neighbouring printings differ in tone.** That is cosmetic; the
   game art redraws over it.
5. **A crop with every kilometre line labelled on all four edges is
   what lets a reader take grid references off an image.** Keep
   crops under about 2,000 px a side, and choose metres per pixel to
   fit. `bin/topo-crop "BS 860 040" "BS 900 080" OUT.png 8`.
6. **Placement has four tiers, best first.** Record the tier used:
   1. **report grid ref:** a grid reference in an official report
      (CHECO, an operational report). About 100 m.
   2. **topo label:** the place is printed on the sheet. 100–300 m.
   3. **book map registration:** the place is drawn on a book map;
      place it by at least three features shared with the topo,
      weighting the near ones. 300–800 m.
   4. **book distance:** distance and bearing from a placed point,
      chained. 1,000–2,000 m.
7. **The sources disagree with themselves.** The reference book
   gives LZ Papa as 2, 4 and 6 km from LZ 4 on different screens. It
   gives one LZ two bearings, and puts a provincial boundary where
   the sheet does not. Record each statement, choose with a reason,
   and keep the rest in the notes.
8. **One name can be two places.** The reference book has "LZ Jim"
   on two screens, for two units, two days apart, 33 km apart. It
   also has two hamlets named Phu Ninh. Read the text before
   accepting a large disagreement as a conflict.
9. **The merge key is kind plus id.** A mountain and the engagement
   fought on it share a vocabulary id, and so do a village and the
   airfield named for it. Match on kind plus the record's own id or
   its vocabulary id. A report's grid reference outranks any
   estimate; otherwise the tighter radius wins, and the other
   placement is kept in the notes.
10. **The merge is a rebuild.** Start each merge from the seed
    records and all batches. Merging onto an already-merged
    register writes every note twice.
11. **The hex scale is a fact; the printed hex size is a
    measurement.** Take kilometres per hex from the game's
    documents: Silver Bayonet is 1.5 km. Build the layout at each
    candidate size until the operator measures a printed hex.
    Name the off-map areas: An Khe is off-map in Silver Bayonet.

## Stages

Model classes:

- **The lead** (Opus or Fable class): the sheet list, a new
  georeferencing fit, seed records, merge judgment, and review of
  every batch.
- **Sonnet:** the region placement readers, and re-running a
  documented recipe.
- **Haiku or a command:** assembly from settled data.

| # | Stage | Output (reference impl) | Who |
|---|-------|-------------------------|-----|
| 0 | Sheet list and acquisition | sheet numbers from coordinates; operator downloads; scans; sheet list committed | lead, operator |
| 1 | Mosaic | per-sheet warped TIFFs, VRT, overview (`bin/topo-mosaic`); large rasters in the map archive, not the repo | lead first time, then Sonnet |
| 2 | Plain-scan georeferencing | `data/georef/<sheet>.json` (what was read by eye) → GCPs (`bin/georef-scan`) | lead |
| 3 | Tiles and crop tool | XYZ tiles z9–15 (`bin/topo-tiles`), labelled crops (`bin/topo-crop`) | command |
| 4 | Seed register | `data/locations.json` seeded with report grid references and one topo-label anchor per region | lead |
| 5 | Placement readers | one JSON batch per region | Sonnet, one per region |
| 6 | Merge and conflicts | register rebuilt from seeds plus batches (`bin/merge-locations`); conflicts over 1 km listed | command, lead judges |
| 7 | Viewer | Leaflet page, star per place styled by kind, confidence circle, popup with method and evidence (`bin/operation-map`) | command |
| 8 | Game-scale layout | SVG in true inches over the resampled mosaic, hexes numbered CCRR, stars (`bin/sb-layout`) | command; operator measures |
| 9 | Operator review | disagreements, the hex size, lookups in Kelley | `operator-review-page` |

## Fanning out readers

The placement readers are the one place this work fans out, and
the place it went wrong. In the reference run, six background
readers caused a stream of permission prompts. The brief had invited
`grep` and `mkdir` through Bash, and neither was allowlisted.

- **Region by engagement, with exact screen ranges.** Give each
  reader:
  - the engagements it owns;
  - the OCR screens to read;
  - the book maps likely relevant;
  - the anchors already placed, to use and not re-place.
- **One shared brief** with the tiers, the grid reference format,
  the confidence radii, the output record and the reply format.
  Each region's prompt points at the brief and adds only its scope.
- **Every command the brief invites must already be allowlisted.**
  In the reference run that was exactly two Bash shapes,
  `ruby bin/topo-crop …` and `magick …`, each as a single command
  with no chains, pipes or redirects. Background agents in the
  reference harness had no Grep tool and read the screens directly.
  Plan for that.
- **Readers do not write files.** The lead creates their crop
  folders under one fixed temp directory (`/tmp/<project>/`, never
  a per-session scratchpad path). Each reader returns its JSON array
  in one fenced block in its final reply, and the lead writes the
  batch file.
- **Before merging, the lead fixes the ids that cross batches.**
  Shared anchors (LZ Duck, LZ Pony) carry the same vocabulary id in
  every batch. Unplaced records that name another region's place
  are linked to it. A place one batch could not place takes the
  other batch's placement, with the reason kept.

## Checking the result

- Every engagement has a star, and every LZ the sources name is
  placed or listed with its reason.
- Each conflict over 1 km is read against the text before it goes
  to the operator. Some are two places sharing a name (fact 8), and
  some are two points on one range.
- ImageMagick does not follow the layout SVG's relative link to its
  base image, and draws a red placeholder. Check the base PNG on its
  own and view the SVG in a browser.

## Adapting to another battle

- Other UTM zones: Indian 1960 is EPSG:3148 for zone 48N, which
  covers western Vietnam and Laos. Read the zone off the sheet
  collar.
- Other series: the 1:250,000 sheets frame the whole operation
  area. Confirm the series and its datum from the collar before
  warping.
- Another game's scale changes only the hex size and the sheet size
  in the layout.
- No book? A placement's evidence can be a report, an oral history
  or a unit journal. The tiers stand.

## Status

Ran end to end on the reference battle, 2026-11-05: twelve sheets,
213 places with 196 placed, all 13 engagements starred, and layouts
at two hex sizes. Open in the reference project:

- a public copy of the viewer (BSN-0021);
- the stars animated over time (BSN-0024);
- per-engagement analyses on the topos (BSN-0023);
- the 1:250,000 frame (BSN-0020).
