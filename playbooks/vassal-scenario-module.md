# A scenario of our own in a VASSAL module

Add a designed scenario to a game's VASSAL module for local play and
logged games: a predefined setup in the Scenarios menu, optionally on a
board made from the scenario card. Reference implementation:
`~/src/silver-bayonet/tools/vassal_scenario.rb` and
`tools/vassal_card_board.rb`, driven by
`scenarios/pleiku/vassal/scenario-p.yml`; notes in
`reference/vassal/README.md`.

## Non-negotiables

- **Write a copy, never the module.** The output is a new `.vmod`
  beside the original (`<module>-local.vmod`).
- **Never change the printable card to feed the module.** Not even
  invisible marks that leave it pixel-identical (operator's rule).
  Read positions from the finished PDF.
- **Prove the encoder before writing a save:** re-encode every piece in
  every save of the module, byte for byte.

## Facts that shape it

1. A `.vmod` is a zip: `buildFile` (XML), `moduledata`, `images/`, and
   the predefined `.vsav` files. A predefined setup is one
   `<VASSAL.build.module.PredefinedSetup file= name= useFile="true"/>`
   line plus its `.vsav`.
2. A `.vsav` is a zip of `savedGame`, `savedata`, `moduledata`.
   `savedGame` is "`!VCSK`" + a key byte in hex + hex pairs, each XORed
   with the key.
3. Decoded, it is commands split on ESC: `begin_save`, an empty one, a
   nested block of `+/id/type/state` AddPiece commands (each but the
   last ending in a backslash, the escaped ESC), then the windows'
   `…BoardPicker\t<board>\t0\t0` lines, notes, `end_save`.
4. SequenceEncoder: tokens joined by a delimiter; a backslash goes
   before each delimiter inside a token and nothing else, so nesting
   adds a backslash per level. A piece's type and state are trait
   chains on `\t`, outermost first, `BasicPiece` (`piece;;;image;name`,
   state `map;x;y;gpid`) last. Pieces come before the stacks that list
   them (`stack` type, state `map;x;y;id;id…`).
5. Palette PieceSlots hold `prototype;NAME` traits; VASSAL expands them
   (the prototype's traits and states, minus its BasicPiece) when a
   piece is placed. Expand, then compare with the module's own saves;
   older saves can predate a palette edit, so a match with any save
   passes.
6. A module's scenario boards (extra `Board`s in the main map's
   `BoardPicker`, chosen by the save's BoardPicker line) are often the
   scenario card rendered at the map's scale. Units that set up go in
   hexes; others sit on their printed counters; the turn marker on the
   card's track. Washing out the printed counters in the board image
   makes an emptied slot read as empty.
7. Grid attributes: `x0`/`y0` must be integers (VASSAL 3.8 refuses to
   load otherwise); `dx`/`dy` may be decimal. A board-level `HexGrid`
   with `HexGridNumbering` (`hOff`, `vOff`, `stagger`) chosen with the
   same column parity as the main map reports the same hex numbers.
8. Positions in a finished PDF: `pdftocairo -svg` gives `<use>`
   transforms for image placements (JPEG sources keep their bytes, so
   match artwork by bytes) and vector paths with their transforms (a
   map's hex outlines place the map). TeX's `\pdfsavepos` inside TikZ
   or tcolorbox misses PGF's transform; do not use it.

## Procedure

1. Unpack the module and decode its saves (reference: `tools/vassal.rb
   extract`, `saves`, `dump`, `slots`).
2. List the scenario's pieces by palette entry name and where each
   starts, in a data file.
3. Build each piece from its PieceSlot with prototypes expanded; run
   the round-trip and expansion checks.
4. Take a template save of the same module for the header, displays,
   decks and markers; keep only what the scenario needs.
5. If the scenario has a card: render it at the map's px/in, read
   positions from its PDF, check the map placement against every hex,
   write the `Board` with grid and zones, and draw the computed
   positions over the image to look before shipping.
6. Write the save, the board image and the `buildFile` lines into a
   copy of the module. Open it in VASSAL; on "error loading", read
   `~/Library/Application Support/VASSAL/errorLog-<version>`.

## Model classes

The encoder, expansion and geometry are deterministic code, so no
reader agents. Visual checks of the overlay image need a
vision-capable model; the operator verifies play in VASSAL.

## Logged play

File → Begin Logging before the first move; Save Game at the end of
each turn; a new numbered log when resuming from a save. Keep logs and
saves in the repo's deep dive for the scenario. Board images cut from
a publisher's map make the module copy unshareable; publish the logs,
the write-up and the builder.
