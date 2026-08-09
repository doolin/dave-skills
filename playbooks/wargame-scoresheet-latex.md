# Wargame scoresheet from scenario cards → LaTeX

Turn scanned scenario/OOB cards from a board wargame into a
printable per-counter tracking form (rows = counters, columns =
game turns, plus rules/scoring text). Reference implementations:
`~/src/silver-bayonet/forms/s9.tex` (small scenario, portrait)
and `s11.tex` (39-turn campaign, landscape longtable).

## Pipeline

1. **Read the card scans with vision** (Read tool on the JPEGs).
   Transcribe every counter's ID and combat values, the scoring
   schedules, victory conditions, replacements, and special
   rules. A Fable/Opus-class read; Haiku will drop counters.
2. **Cross-check values against the card, never a prior form** —
   transcription slips in old forms propagate silently (found
   two in silver-bayonet's s9.tex this way).
3. **Decode arrival vs. withdrawal.** On GMT cards, red-boxed
   reinforcement groups are *withdrawals* (a small NOTE box says
   so). Verify by matching each red group to an earlier arrival
   of the same units. Encode as a GT column: `6–23` = in GT6 /
   out GT23, `6–22, 33` = returns GT33, `set` = at-start,
   `var` = variable entry.
4. **Pick the layout by scale.** ≤ ~12 turns: portrait, minipage
   rules column beside a tabular grid (s9 pattern). Campaign
   scale: landscape, rules page up front, one `longtable` per
   side with repeated header (s11 pattern).
5. **Render-verify loop:** compile (xelatex ×2 for longtable),
   `pdftoppm -png -r 200`, Read the PNGs, compare against the
   card. Check grid rules, shading, overfull warnings.

## LaTeX specifics that bite

- `*{N}{T|}` not `*{N}{T}|` — the `|` must be inside the repeat
  or only the outer edge gets ruled.
- Turn cells: `\newcolumntype{T}{>{\centering\arraybackslash}p{4.3mm}}`
  with `\tabcolsep` 1.5pt fits 39 columns + labels on landscape
  letter at 8pt. Fix overfull by shaving the column type
  (0.1mm × N columns), not individual cells.
- `\LTleft`/`\LTright` `0pt plus 1fill` to center a longtable.
- Faux-Arial: `fontspec` + `\setmainfont{Arial}` with
  `sansmath`; `\rowcolors` from `[table]{xcolor}`.

## Verification trap

`pdftoppm` below ~150dpi drops hairline rules irregularly —
indistinguishable from missing column separators. Always
re-render the suspect page at 200dpi before changing the table
spec.
