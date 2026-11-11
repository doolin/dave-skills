# Counter roster from sources

A battle's history (a book and the public-domain records behind
it) → a counter roster for a new game in a model game's style →
(later) counter sheets. Unlike `counter-sheet-digitization.md`
there is no printed sheet to read: every counter is a decision,
and the sources, not a designer, say which units existed.

Status: stages 1–5 proven on bong-son, Operation Masher/White
Wing, in Silver Bayonet's style (BSN-0035, 10–11 November 2026:
a 136-counter proposal, ten questions answered, four records
searched, nine vocabulary changes). Stages 6 and 7 not yet run.
Update this entry when they have been.

Reference implementation: `~/src/bong-son`:

- `.development/design/counter-roster.md`: the proposal
  (sections 1–5), the operator's answers (section 6), what the
  records say about enemy units (section 7);
- `data/roster-proposed.json`: the proposal's rows;
- `.development/active/BSN-0035-counter-roster-and-sheets.md`.

The model game was `~/src/silver-bayonet` (`counters/`,
`reference/vassal/counters/index.md`).

Prerequisites: a closed vocabulary of units with side, echelon
and parent, and the day scripts that say which units act where
(`operation-over-time.md`).

## Stages

1. **Read the model game's conventions** before drawing a row.
   Write down what a counter is on each side: the echelon
   (Silver Bayonet: companies on every side), the exceptions (US
   D companies stronger, PAVN D companies at half stacking),
   artillery by battery, aviation split by aircraft, leaders,
   markers, what is printed on a face, the counter and sheet
   size. Cite the file each convention came from.

2. **Draw up a proposal** (one agent, then the lead's review).
   Sort every vocabulary unit into one of four: on the sheet;
   stood for by its sub-units; off the map (higher headquarters,
   air, naval); background the order of battle already leaves
   out. Each row carries its formation, the days it acts in the
   scripts, and whether it is inferred. Count by side and
   formation. Write down where the model game and the sources
   disagree (bong-son: the game is all companies, but the
   sources follow the enemy only by battalion). End with
   numbered questions, each with its options.

3. **Put the questions to the operator one at a time**
   (2026-11-11: "ask one at a time"). Each question stands alone:
   the facts it turns on, the options, the recommended one first
   and why. Record each answer in his words in the design file
   before acting on it. Expect answers that reach back: question
   7's reply amended question 6, and an answer to the eighth
   brought in a second model game (*Vietnam 1965–1975* for the
   Marines' anchor) that the repo does not hold.

4. **Search the records for what the answers leave open**
   (bong-son: enemy mortar units, and the 2nd VC Regiment's
   battalions). Turn each PDF into text in the scratch folder
   first (`pdftotext -layout`), so the reader agent needs file
   tools only. Brief it for verbatim quotes with a citation per
   finding and "nothing found" per source. Check the key quotes
   yourself before reporting: the agent's reading is a claim.
   Record the findings and the counters they add in the design
   file, each with its source.

5. **Fix the vocabulary the roster exposes**: units filed twice,
   ids that break the naming rule, sides set inconsistently.
   Every file that cites a changed id changes with it (scripts,
   casualty records, the proposal), and the generated pages are
   rebuilt. Run the timeline checker on the change and on
   unchanged main: the same flags on both is the proof the fix
   broke nothing.

6. **Rebuild the roster** from the answers and the findings as
   one frozen file, every row with its evidence and inference
   marked. (Not yet run.)

7. **Give each counter its values, then draw it.** The sources
   give no combat values; each value comes from the operator or
   is marked as the model game's for the same unit type. Faces
   and sheets follow `counter-sheet-digitization.md`, stage 7.
   (Not yet run.)

## What the first run found

- **One record can add a unit the book never mentions.** CHECO
  150 alone named the 2nd VC Regiment's 95th Battalion; the book
  and the division's report did not. A unit on one source gets
  its counter, flagged as single-source.
- **Summaries give companies without their regiment.** The
  division's report lists "a mortar company, a recoilless rifle
  company, an anti-aircraft company, and a signal company" for
  the whole enemy division. Assign them by the other evidence
  (weapons captured from a named regiment) and mark them
  inferred.
- **A generated page can change far more than the data.** One
  side change moved three aircraft into the order-of-battle
  chart and shifted every row below them: 490 changed lines from
  nine vocabulary changes. Read the diff before trusting the size.
- **Ids that scripts cite are not free to rename.** The
  vocabulary forbade it; the operator's answer allowed it. Record
  the old id in the entry's notes so a reader of old work can
  follow it.

## Non-negotiables

- **Better to have a counter and not need it.** A unit any
  source attests gets a counter, though no scenario is known to
  use it (`counter-sheet-digitization.md`, non-negotiables).
- **No invented values.** Every value is the operator's or
  marked as the model game's.
- **Inference is marked on the row**, never folded silently
  into a counter.
- **The model game's art is never copied.** Its conventions are
  read; its faces are drawn anew.
- **Hobby sites that claim copyright over public-domain records
  are not sources** (rjsmith.com, 2026-11-11). Go to the record
  itself.
