# SVG symbol reproduction — one-shot subagent prompt

Reproduce a printed map/board symbol (compass rose, arrow, cartouche,
ornament) as parameterized Ruby-emitted SVG, by tasking a subagent
with a reference photo. Distilled from the Fall of South Vietnam
north-arrow experiment (2026-07-01): Opus got the full structure in
one shot with this recipe; the letterform knockout needed a directed
second round, whose lessons are now baked in as items 4-6.

Model class: Opus is the FLOOR for anything shippable. The Sonnet A/B
ran 2026-07-03 (gunslinger terrain, 5 Sonnet vs 10 Opus agents,
identical spec): Sonnet output is scaffolding tier — right structure,
not production quality. Operator verdict: ship quality requires at
least Opus and probably Fable-class generation, not just Fable
direction. Use Sonnet only for placeholder/scaffolding passes and
mechanical constant tweaks on an existing generator.

## Why it works

Three legs, all load-bearing:

1. **A close reading, not just the image.** The director decomposes
   the symbol into named parts with pixel estimates BEFORE tasking.
   The subagent verifies against the photo instead of interpreting
   from scratch.
2. **A render→Read→compare loop.** The agent rasterizes its own SVG
   and Reads it side by side with the reference in its multimodal
   context, comparing named dimensions. Without this it stops at
   "roughly similar"; with it, it converges.
3. **Isolation for hard subshapes.** Letterforms and knockouts get
   validated alone at large size before composition — a mangled
   letter inside an evenodd path is unreadable in situ but obvious
   in isolation.

## Prompt template

Fill the {SLOTS}; keep everything else verbatim.

---

Write a Ruby program that generates an SVG reproduction of {SUBJECT}.
Work ONLY in {WORKDIR} with filenames unique to this task — do not
touch any git repo.

The reference photo is at: {REFERENCE_PATH} — Read it FIRST and study
it before writing any code. (Read can see paths the Bash sandbox
cannot; never try to cat/copy the reference via shell.)

What the design is (my close reading; verify against the photo, image
frame is {W}x{H}): {CLOSE_READING — one bullet per part: shape,
position estimates in photo pixels, stroke weights, what overlaps
what, which marks are knocked out vs painted. Idealize print wobble
into clean vectors; say so explicitly.}

Ruby requirements (stdlib only, no gems):
- Create {WORKDIR}/{MODULE_FILE} defining `module {MODULE}` with the
  API `{MODULE}.svg_element(cx:, cy:, length:, angle: 0)`. Convention:
  angle 0 = {CANONICAL_ORIENTATION}; positive = clockwise (SVG y-down);
  `length` = {WHAT LENGTH MEANS}; every other dimension is a FRACTION
  of length defined as a named constant at the top. Rotation computed
  in Ruby, not via SVG transform. Ink color constant {INK}.
  frozen_string_literal, single-quoted strings, rubocop-clean style.
- A `__FILE__ == $PROGRAM_NAME` main that writes
  {WORKDIR}/{PREVIEW}.svg: neutral background, one large instance at
  the photo's orientation for direct comparison, plus one at angle 0.

Construction rules:
- Knockouts (letters, holes) are subpaths of the body path with
  fill-rule="evenodd" — NEVER a background-colored shape painted on
  top; the real background is not uniform.
- Validate hard subshapes IN ISOLATION first: render a letterform
  alone, black on white, ~400px tall, Read it, and only compose it
  once it reads cleanly. Then confirm the winding knocks out rather
  than fills.
- Draw EVERY structural element even where occluded — same-ink
  overlap is invisible and the protruding stubs are what the eye
  checks against the print.
- Where your own measurement of the photo disagrees with my close
  reading, trust your measurement and note the difference.

CRITICAL — iterate visually, this is the whole game:
1. `magick {WORKDIR}/{PREVIEW}.svg {WORKDIR}/{PREVIEW}.png`
2. Read the PNG and re-Read the reference photo side by side.
3. Compare named dimensions: {DIMENSIONS TO CHECK — axis angle, part
   sizes relative to each other, stroke weights, subshape legibility}.
4. Fix constants and repeat. Budget 4-6 render-compare rounds; do not
   stop at "roughly similar". The hardest part is {HARDEST PART} —
   spend your iterations there.

Deliverables in your final report: the module path, iteration count,
final constants, and an honest list of remaining differences from the
print. Commit nothing; write nothing outside {WORKDIR}.

---

## Director's checklist (before sending)

- [ ] Crops in hand? Zoom the reference and do the close reading
      yourself first; estimate positions in photo pixels.
- [ ] Width PROFILES, not endpoint widths: measure each elongated
      part at 3+ stations along its axis. "Tapers from head to tip"
      hides fat-then-taper knees; a wrong profile forces the agent
      into off-center compromises it can't diagnose (FoSV north
      arrow needed a third round for exactly this).
- [ ] {WORKDIR} filenames unique — a concurrent agent on the same
      symbol family will clobber shared /tmp names.
- [ ] On completion, render its preview and compare with YOUR eyes
      before relaying; critique in named parts ("second cross arm
      missing"), never "make it closer".
- [ ] Reference photos live on in the repo: docs/reference/ with
      subject-first kebab names (<subject>-closeup.png).
