# Kindle map capture

Capture the figures (maps, diagrams) from a Kindle book the operator
owns, at the best resolution the reader's GUI will give, without
touching DRM, the keychain, SIP, or any device. Drive Kindle for Mac
with cua-driver, verify by OCR, capture the display at native pixels.

Reference implementation: `~/src/bong-son/scripts/` (`kindle_lib.sh`
primitives, `capture_map.sh` one-shot, `book.sh` per-book table,
`README.md` usage). Lessons in `~/src/bong-son/.development/lessons-learned.md`.

## Non-negotiables

- GUI only. No DRM stripping, key extraction, SIP change, device
  connection. Everything stays local.
- Captured imagery and text are attributed research inputs, not
  deliverables. Publish only public-domain, fair-use, or original
  material; see `historical-research-dossier.md`.
- A file is a map only when OCR reads back its caption. Size, ink
  density, and brightness never decide.
- Scripts print one short line per step. Window-state JSON and
  base64 screenshots never reach a terminal or a transcript. The
  first harness on this job ran out of context by reading those,
  not because the job needed them.

## Facts that shape the pipeline

1. **The reader paints pages as images.** No text in the AX tree;
   OCR is the only reader of text. But the toolbar buttons, the
   table-of-contents sidebar entries, the search results, and the
   "Page N of M" label are AX elements when the toolbar is shown.
2. **The driver's window screenshot is 1x.** `get_window_state`
   returns about screen points. On a 2x Retina display that is a
   quarter of the pixels. `get_desktop_state` returns the display in
   true pixels; crop the window's bounds × scale factor out of it.
   Kindle must be frontmost and unobscured for that capture.
   `screencapture` from a shell lacks Screen Recording permission;
   the driver has it, so go through the driver.
3. **Two-column view halves the figure and skips odd pages.** The
   right arrow advances two pages per press in that mode. Set
   one-column view (Reading Settings → Layout) before anything.
   Measured on one map: two-column 415 px wide, one-column 1x 822,
   one-column native 1585.
4. **Captions may follow figures.** In the reference book the
   `Map N. Title` line is set after the figure, so a caption at the
   top of a page means the figure ended the previous page. Check
   the convention on the first map and encode it.
5. **The List of Maps page is a link table** reachable from the TOC
   sidebar (AX button "Maps, 9"). Its entries are pixel-click links
   to each caption. Numerals in blue underlined type OCR badly;
   locate a row by its title words (tesseract TSV word boxes).
6. **Double-click selects an image, it does not zoom.** There is no
   image viewer. A selected figure screenshots with a blue tint;
   Escape does not clear it, a click on blank page area does.
7. **After a TOC or link jump Kindle frames the page** and shows a
   "Back to N" widget, then drops both a few seconds later and
   reflows the page: rows move. Wait ~3 s after a jump before
   capturing, and make every click self-checking (capture, locate,
   click, capture, confirm, re-locate if not). A trim taken in the
   framed state returns the page frame; shave and trim again.
8. **Arrow keys can miss.** The on-screen page arrows at the window
   edges (x≈27 and x≈W−27, mid-height) take a foreground pixel
   click every time.
9. **Every map in the reference book has a black frame.** A framed
   block ≥300 px at 1x is a figure; prose and link tables never have
   a solid line along an edge. The frame also gives the exact crop:
   its lines are the only columns and rows more than half ink, so
   row and column ink profiles locate it even when the previous
   map's caption sits above the figure. Check the convention per
   book.

## The one-shot

`capture_map.sh N`, from wherever the reader is:

1. `list_windows` → pid, window id (they change every launch).
2. TOC sidebar via AX (reveal toolbar with a pixel click on its
   area if the buttons are absent) → press the Maps entry.
3. 1x capture of the list; OCR TSV; score lines by title words;
   foreground pixel click on the best row.
4. 1x capture; OCR caption must contain `Map N.` or stop.
5. Figure on this page? (framed block test). If not, click the back
   arrow and test again; stop if still absent.
6. Front Kindle; native display capture; crop window; whitespace
   trim; cut to the black frame by ink profile; require ≥600 px
   each side.
7. Write `map_NN_slug.png`, `_page.png`, caption `.txt`; keep the 1x
   working captures under `work/map_NN/`.

Preflight first (`preflight.sh`): tools, daemon, window, screenshot
size, page label. A window-state failure with Kindle open means the
display is asleep or locked; the operator wakes it, the agent never
touches the lock screen.

## Model-class assignment

- **Haiku**: run `preflight.sh`, then `capture_map.sh N` for each N,
  report the step lines, stop on the first FAIL. No image reading.
- **Sonnet**: triage a FAIL from the `work/` captures (open the
  PNGs), adjust a coordinate or a sleep, rerun. Run
  `caption_audit.sh` and update the inventory table.
- **Fable-class**: adapt to a new book (`book.sh` titles, caption
  convention, frame test), or to a new reader layout (crop and skip
  constants). Decide the capture method when the ceiling is unclear.

## Per-book adaptation

Only `book.sh` should change: TOC label for the map list, titles,
slugs, count. Before the first full run, capture one map by hand and
confirm: caption-before or caption-after figure; framed figures or
not; the toolbar skip and side skip for the window size in use.
