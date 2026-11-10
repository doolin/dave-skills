# Operation over time

Show a military operation as it unfolded: day by day on the whole
area, hour by hour within a day, and zoomed to one part of the map.
Every marker and arrow comes from one line of plain text that cites
its source, so the operator can read, quote and correct it from a
phone.

Reference implementation: `~/src/bong-son`, epic BSN-0030 with
tickets BSN-0025 to BSN-0029 (2026-11-10), for Operation
Masher/White Wing, 24 January to 6 March 1966: 42 day scripts, 617
statements, the book's eight battle maps read in, seven zoom views.
Built in one day, from a phone, in a cloud workspace. The parts:

- `.development/design/operation-over-time.md`: the lexicon, the
  rules the tools need, the review loop.
- `lib/bong_son/`, each with a spec at 100% line coverage:
  - `timeline_script.rb` (parser), `timeline_places.rb` (places and
    units), `timeline_check.rb` (checker), `timeline_build.rb`
    (compiler), `timeline_review.rb` (corrections);
  - `time_viewer.rb` (the page).
- Commands in `bin/`: `timeline-check` (with `--number` and
  `--uses`), `timeline-build`, `timeline-review`, `time-viewer`,
  `viewer-base`.
- Data: `data/timeline/1966-MM-DD.txt` (one script a day),
  `data/timeline.json` (compiled), `guide/time/base/` (base images
  and their extents).

Related:

- `operation-map-from-topos.md`: the mosaic and the register of
  places this builds on. Do it first.
- `battle-book-research.md` (in bong-son's `.development/playbooks/`
  until it moves here): the vocabulary, the dated events and the
  casualties this draws from.
- `historical-research-dossier.md`, for what may be published.

## What it needs before it starts

- **A register of places in grid references**, each with a source
  and a confidence radius (`operation-map-from-topos.md`). Every
  position on the page comes from it or from a grid reference
  written in a script. Nothing is placed by eye.
- **A closed vocabulary of units** with ids and sides. Company
  letters are written against it (`C/2-7-cav`), not added to it.
- **The source text one page per file**, so a citation such as
  `@s047` opens one page of OCR.
- **Dated events** with the page they come from. They seed the
  scripts; they are not the scripts.
- **Base images cut from the mosaic**, each with its extent in grid
  metres, committed, so the page can be built where the map
  programs are absent.

## The lexicon

One plain-text script per day. One statement per line:

    [0128-03] 0815-1000 A/2-7-cav moves lz-2 -> a-2-7-paddy-crossing by foot "departed LZ 2 on foot at 0815 hours" @s047 @map5 ~place

- id, written once by a tool and never renumbered, so the operator
  can refer to a line for good;
- when: a clock time, a range, a part of the day (`dawn`, `morning`, …)
  or `day`;
- who: a vocabulary id, with a company letter, or `-`;
- verb, from a closed list of about fifteen; a fact the list cannot
  say is written as `event` and the verb proposed to the operator,
  not added quietly;
- where: a register id, a grid reference, or `2km NW of` either;
  `->` for a destination, `via` for the arrow's bends;
- a short quote word for word from the source, the sources, and
  marks for what is uncertain (`~time`, `~place`, `~inferred`);
- `=ok` at the end, added only on the operator's word.

Write the tables of the lexicon first, then a section of the rules
a parser needs that the tables leave open: the order of the parts,
which verbs need `->`, where the parts of the day sort, which of two
register entries with one id a place takes. The tools are built to
that text, and every choice made while building goes back into it.

## The tools

Build them before any day is scripted, by a strong model, to the
design text, with specs:

- **Parser** that reads every line it can and reports every line it
  cannot, with its line number, so a whole file's faults show at
  once.
- **Checker** that refuses (unknown unit, place or verb; no source;
  a moving verb with no destination; duplicate ids) and flags (a
  unit in two places at one time, a ground move faster than 5 km an
  hour, out of time order, a unit with no position, a place with no
  grid). `--number` writes ids; `--uses ID` lists every statement a
  rename touches.
- **Compiler** to one JSON file: each unit's waypoints, held until
  the next; each day's statements and hours, in grid metres.
- **Review command** that applies one of the operator's one-line
  corrections (`ok 0128`, `0128-04 when 0835`, `drop 0128-08`) and
  prints the line before and after. `drop` keeps the line as a
  comment with its id, so the id is never given out again.
- **Page generator** in Ruby that works out every position, frame
  and filter, leaving the page's own script only to draw.

## Scripting the days

- **One reader per phase of the operation**, mid-size model,
  read-only. The brief gives the days, the screens, the lexicon,
  one finished day as the model, and the rules: never invent an
  hour; mark an inference; quote word for word; a place the
  register lacks is listed, never guessed. Readers return the
  scripts in their reply; the lead writes the files.
- **The lead checks each batch before it is committed:** every id
  against the register and the vocabulary, the checker with
  nothing refused, ids written, and every quote found on its
  screen. Search for a short piece of each quote, because OCR line
  breaks split most of them; a whole-quote search misses half.
- **A day with no events still gets a script** that says so.
- **Losses only when the source gives a day's own count.** A running
  total at a link-up the next morning belongs to neither day until
  it can be split.
- **Commit each batch as soon as it is checked.** Workers' reports
  last only as long as the session.

## Reading the book's maps

Do this after the days are scripted, one map at a time, with a
strong model, read-only:

- List everything drawn: each arrow's unit, start, end and bends;
  each label.
- Place every point by the places the map shares with the
  register. **Never by the map's scale bar.** In the reference
  book every scale bar was wrong, one by a factor of seven.
- Time each arrow from the text; with no stated hour it stays
  `day` with `~time`.
- Where the map and the text disagree, the script follows the text
  and a `differ` line says why. **The book's maps often draw the
  plan**, not what happened: Map 5 drew two units attacking on foot
  that the text flew in by helicopter.
- The map is the best check on the scripts' stand-in places. Map 9
  showed that a stand-in for a stream put a start line 100 m from
  the trench it attacked, where the text gave 200 m; the register
  had the stream as its own entry.
- Ask the reader for only the changes: lines to change, new lines
  and which existing id each goes after. Whole revised files cost
  more to apply and to check.

## The page

- **Day by day first.** A day frame is the state at the end of the
  day, with the day's arrows, bursts and dots, and every unit held
  at its latest waypoint. Day chips, Prev and Next, the arrow keys,
  the day in the address (`#jan28`).
- **Then hour by hour.** The stops are only the hours the sources
  give. Statements with no hour are listed under "some time today"
  and drawn faint on every hour frame of their day, never given an
  hour. The address carries the stop (`#jan28-0845`).
- **Then views.** Each view swaps in a sharper base image, keeps
  the day and hour, draws only what falls in it, and points at the
  border toward a unit that leaves it. Its outline on the whole
  mosaic opens it. The address carries it (`#jan28-0845@phung-du`).
- **Tap anything** for its statement id, its script line and its
  sources. That is how the operator corrects the record.
- Keep marker and label sizes constant on screen under zoom, so
  they read at every scale.
- Watch the size: each hour frame carrying every unit made the
  reference page 3.7 MB, with 8.8 MB of images under a 16 MB limit.

## Checking it

- Open the page in headless Chromium after every build: no script
  errors, no sideways scroll at phone width, the keys and play
  stepping where they should.
- When the operator cannot check on a phone, emulate one and look
  at each view at a busy hour at Fit and 2x. In the reference run,
  a view at 6 m a pixel read its hamlet names at 2x and one at
  12 m a pixel did not.

## Cloud sessions

Most of the reference run was done from a phone. What it taught:

- **Check the git author before the first commit.** A container's
  global identity may be the agent's. The operator is the author of
  every commit; set it in the repo's config.
- **One commit per pull request, each on its own branch from
  `main`.** A second commit pushed to a branch already in a pull
  request joins it; a squash merge leaves the branch's earlier
  commits behind to reappear. A second working folder (a git
  worktree) lets commits go up while a worker edits the main
  checkout.
- **Changes to one generated file conflict.** Keep script changes
  and code changes out of the compiled JSON and the page, and
  rebuild those once, after the scripts merge.
- **Track work in flight in the ticket's State**, with how to
  restart it if the session ends, and every open question in the
  operator's review queue.

## Status

The reference run met every criterion of its three rounds except
the operator's: his review of the days, his acceptance of each
statement, and recutting the coarser views on the machine that has
the mosaic.
