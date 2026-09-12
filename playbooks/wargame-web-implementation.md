# Wargame → web implementation

Printed wargame (already digitized to rules text + component art)
→ a browser game with a solitaire bot and CRDT two-player. The
hard part is not the code; it is that **a printed edition may
reproduce an ambiguity, and a program may not**. Every place the
designer was vague becomes a decision someone has to own, and the
decisions outnumber the rules.

Status: stages 1–3 proven on sgp-linebacker-2 (SGP *Linebacker
2*, 1979 — 26 rulings, 11 boxes, 3 tables, 3 scenarios); stages
4–7 surveyed, not yet run to completion. Update when they have.

Reference implementation: `~/src/sgp-linebacker-2` —
`.development/plans/webgame.md` (the wave plan),
`.development/interpretations.md` (the rulings register),
`webgame/src/rules/` (engine).

Prerequisite: the rules must already exist as text and the
components as data. See `map-digitization.md` and
`counter-sheet-digitization.md` for getting there.

## The third register

A digitization project keeps two registers: **deviations**
(departures you chose) and **discrepancies** (contradictions you
found). Software needs a third.

**interpretations.md** — one numbered entry per place the print
does not say enough for a machine to act. Each entry is three
parts: *Print* (verbatim quote + case number, or the nearest
thing the print does say), *Question* (what an implementer cannot
resolve), *Ruling* (what the engine does, concrete enough to code
from). Plus **Concern** where the ruling strains the text.

Four properties make it work:

- **Numbered `R<n>`, cited from code and tests.** A test is named
  for the ruling it proves. Changing a rules argument touches one
  register entry and the tests that grep to it.
- **Defaults, not verdicts.** The header says the operator may
  overturn any entry and the engine must then change. This is
  what keeps an agent from quietly legislating.
- **Concerns are mandatory.** An agent told "implement as
  written, but flag internal tension" surfaces the weak rulings
  instead of smoothing them. On Linebacker 2 this caught two
  (R9 extends a setup clause to every night; R11 denies the F-111
  an action the print grants it).
- **Silence gets an anchor.** "The print says nothing" is an
  argument from absence. Make the entry cite the nearest thing it
  *does* say, so a cold reader can check the gap is real.

Expect roughly one ruling per two pages of rules text.

## The facts that shape the pipeline

1. **Tables carry rules in their ink.** Linebacker 2's "only the
   four boxed-in results are valid" names a rule that exists
   nowhere but as a heavy line drawn on the CRT — absent from
   every text source and from the LaTeX transcription.
2. **A count in prose is the checksum for a drawing.** The print
   said *four*; the scan's box enclosed four cells. That
   agreement is the proof you read the ink right.
3. **The same convention on a neighbouring table may mean
   nothing.** The Air-to-Air CRT carries a box of the same kind
   enclosing six cells, which no rule references. A drawing
   convention is not self-documenting — count, then check the
   count against the text, then log a discrepancy if they differ.
4. **The components settle what the rules contradict.** Two
   victory ladders that cannot both be tracked were resolved by
   the map itself: a single signed track reading NV 9…0…9 US.
   Look at the board before ruling on the text.
5. **The counter sheet is a supply ceiling, not a roster.** 192
   F-4 counters against a scenario roster of 182. Where they
   differ the scenario governs; assert the mismatch in a test so
   a later edit trips rather than silently "fixes" it.
6. **Sequence-of-play lists and prose routinely disagree.** The
   list is a summary written once; the prose is where the
   designer was thinking. Prefer the prose, rule it explicitly,
   and say in the Concern what the other reading would change.
7. **Determinism is the multiplayer architecture.** Shared state
   is an append-only action log; state is a fold. No clock and no
   random source inside the engine — dice enter as action
   payloads. Get this wrong and CRDT sync cannot work at all.
8. **Hidden information is a UI concern, not a security one**,
   for two players who know each other. Say so in the README so
   nobody mistakes the relay for a trusted server.

## Stages

1. **Read everything first** (Opus). The full rules text, the
   components page, the map, both counter sheets. Do not start
   the register from the rules alone — half the rulings are
   settled by a track or a table.

2. **Open the interpretations register** (Sonnet under a strict
   brief; Opus reviews). Brief it to quote verbatim from the
   faithful transcription layer, never the corrected edition, and
   to add a Concern rather than improve a ruling it doubts.

3. **Static data, transcribed and verified by different agents.**
   Sonnet transcribes from the derived sources (LaTeX, the art
   generators); a *separate* Opus agent verifies against the scan
   at 300 dpi and never sees the transcriber's reasoning. The
   scan wins. Budget the verification — a 130-cell bombing table
   is the expensive one.

4. **Types and phase machine** (Opus, serial, operator-reviewed
   before anything builds on it). This is the fan-out point and
   the whole schedule's bottleneck.

5. **One module per phase** (Sonnet, parallel). See the fan-out
   rule below.

6. **Property tests** (Opus): replay determinism, conservation
   (alive + downed + destroyed = roster), no negative supply,
   the acting seat always has a legal action.

7. **Sync, UI, bots** in parallel off the finished engine. The
   opponent bot for the *planning* side (missions, targets) is
   harder than the reactive side and belongs on the critical
   path.

## Fan-out rule

Parallel agents are safe only where touch sets are disjoint. Two
things make that true:

- **One file per agent, stated in the brief**, including "another
  agent is editing X right now; do not touch it, report the lines
  you need and the orchestrator will apply them."
- **Declare shared helpers before the fan-out.** The skeleton
  names every helper more than one phase needs — hit allocation,
  morale adjustment, score posting — with signatures and stubbed
  bodies. Without this, four agents each write their own.

Shared config files are the exception that still bites: a lint
config or a `package.json` edited by two agents at once. Keep
those for the orchestrator.

## Non-negotiables

- **The engine is pure.** No clock, no RNG, no DOM, no CRDT
  import under the rules directory. A test asserts it.
- **No silent interpretation.** Any behaviour the print does not
  dictate carries an `R<n>` citation in the code.
- **Bots read a public view only**, never full state, enforced by
  an import test — otherwise the bot cheats by accident and the
  solitaire game is worthless.
- **Art is single-sourced.** A build script copies the existing
  SVG/PDF toolchain's output; no hand-edited duplicates.
- **Constrain subagent command shapes in the brief.** Agents that
  shell out freely prompt-storm the operator. Name the
  allowlisted verbs; tell them to prefer file tools over `cat`,
  `grep`, `ls`; forbid `&&` chains.
