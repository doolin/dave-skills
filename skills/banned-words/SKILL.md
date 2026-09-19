---
name: banned-words
description: The operator's banned words and banned rhetorical devices — words that read as bafflegab, filler, or euphemism, and argumentative moves that assert more than they establish, with replacements and carve-outs for each. Applies to all prose an agent produces (responses, documents, commit messages, tickets) and to inherited text being edited. Load when writing or reviewing prose, and whenever a listed word or device is about to appear.
---

# Banned words and rhetorical devices

Bafflegab asserts value or agreement without naming anything. This
list bans the recurring offenders. Each entry records the ban's
scope, the replacements, and any carve-out — the carve-outs are
part of the ban, not exceptions to it.

Two lists, because they are caught differently. A word is caught by
reading; a device is caught by checking the *shape* of a claim. Both
fire at the same moment — before prose is written or reviewed — which
is why they live in one skill.

Ground rules:

- A ban covers every inflection and derived form of the word
  unless the entry says otherwise.
- When editing text that already contains a banned word, fix it in
  passing, even when that isn't the task. Don't launch sweeps for
  banned words alone.
- The list grows by operator decree. Don't add entries on your own
  judgment; do propose candidates when you notice a pattern.

## The list

### richer

- **Banned:** in every sense except literal wealth or money.
- **Why:** it claims improvement without naming the improved
  property.
- **Instead:** name the property — more detailed, more fields,
  higher-resolution, more expressive, broader coverage.

### groom

- **Banned:** always, in all forms, including the backlog-jargon
  sense ("backlog grooming").
- **Why:** euphemism with a bad valence; the concrete verbs are
  all better.
- **Instead:** prune, tidy, triage; for the recurring backlog
  ritual specifically, **review**.
- **Carve-out:** literal animal care. Grooming is ok if there is
  a horse involved.

### exactly

- **Banned:** as agreement or intensifier — "Exactly!", "exactly
  right", "this is exactly the pattern".
- **Why:** filler agreement; it performs precision instead of
  providing it.
- **Instead:** state the confirmed fact, or delete the word.
- **Carve-out:** counting and matching claims keep it — "exactly
  one `ADR.md` per module", "the copies match exactly".

### honest

- **Banned:** as a self-applied credibility marker — "the honest
  answer", "an honest caveat", "honest minimum", "to be honest".
- **Why:** anything prefaced with "honest" immediately raises
  suspicion about everything else. Credibility is carried by the
  content, not asserted over it.
- **Instead:** delete the word and let the statement stand, or
  name what the marker was gesturing at — the limitation, the
  uncertainty, the unflattering number.
- **Carve-out:** describing a person's character, and direct
  quotation of sources.

### cleanly

- **Banned:** as an outcome adverb — "applies cleanly", "compiles
  cleanly", "maps cleanly", "separates cleanly".
- **Why:** it asserts nothing went wrong without saying what was
  checked. The reader learns the author's satisfaction, not the
  result.
- **Instead:** name the check and its result — "applies with no
  conflicts", "compiles with zero warnings" — or delete.
- **Carve-out:** the concrete verb "clean up" (removing things)
  is a different word and not covered.

### spine

- **Banned:** as structural metaphor — "the spine of the
  document", "narrative spine", "the spine of the argument".
- **Why:** it names a shape where the reader needs the function.
- **Instead:** say what the thing does — the ordering principle,
  the main sequence, the section everything else references.
- **Carve-out:** literal spines — anatomy, book bindings.

### load bearing

- **Banned:** as an importance marker, hyphenated or not — "the
  load-bearing sentence", "load-bearing consistency".
- **Why:** it asserts that something depends on this without
  naming what. If nothing named would break, the phrase was
  decoration.
- **Instead:** name the dependent — "X breaks if this changes",
  "the claim the argument rests on".
- **Carve-out:** literal structural and rock mechanics — walls,
  beams, pillars, abutments.

### settles

- **Banned:** as a claim that a question has been closed — "that
  settles it", "one call settles it", "the matter is settled",
  "this settles whether X".
- **Why:** it announces a conclusion in place of the evidence that
  reached one. The reader learns that the writer considers the
  question closed, not what closed it — and a question the writer
  has closed is the one a reader most needs shown.
- **Instead:** state the finding and let it do the closing — "the
  command ran without a prompt, so the allowlist is not the cause".
- **Carve-outs:**
  - The physical and legal senses: a foundation settles, a claim is
    settled out of court, a settlement is a place.
  - `settle` as an identifier in code. The ban covers prose; a
    method name is a name, not a claim.

## Banned rhetorical devices

A device is a *move*, not a word, so no phrase list catches it.
These entries describe shapes. Check a draft against them the way
you check it against the word list above.

Ground rules:

- **The substitution test.** If a sentence stays just as true when
  an unrelated topic is swapped in, the device is doing the work
  the fact should be doing. "COMMONS.md says nothing about
  handoffs" / "…about bananas" — both true, so the sentence was
  never evidence.
- A banned device is banned in every artifact: responses, tickets,
  commit messages, documents.
- Fix in passing when editing text that carries one.
- Each entry names the device, so it can be looked up and argued
  with, and shows it working — these are real instruments, banned
  here for misuse, not because they are always wrong.
- The list grows by operator decree. Propose candidates under
  `## Candidates` rather than banning on your own judgment.

### argument from absence

- **Banned:** naming what a document, file, or system does *not*
  contain as though the absence were itself a finding —
  "COMMONS.md says nothing about handoffs", "the ticket never
  mentions the rollback path", "there is no test for this".
- **Why:** absence is unbounded. The same sentence is true of
  infinitely many topics, so singling one out implies a notability
  the sentence never establishes. Whatever made the gap matter is
  the real fact, and it is always somewhere else.
- **Instead:** state the positive fact that creates the
  expectation — "ADR-0003 requires a pause discipline but never
  says what a handoff contains". If no such fact exists, there was
  no finding to report.
- **Reference:** *argumentum ex silentio*, the argument from
  silence — long-standing in historiography and textual criticism,
  where it is treated as valid only when the source would be
  expected to mention the thing. Adjacent to, but narrower than,
  *argumentum ad ignorantiam*.
- **In proper use:** Conan Doyle, "Silver Blaze" (1892). Gregory:
  "Is there any other point to which you would wish to draw my
  attention?" Holmes: "To the curious incident of the dog in the
  night-time." Gregory: "The dog did nothing in the night-time."
  Holmes: "That was the curious incident." The inference holds
  because the expectation was closed and certain — that dog barks
  at strangers — so its silence names the intruder as someone it
  knew. Absence is evidence once something guarantees the presence.
- **Carve-outs:**
  - A completeness check against a **closed** list: which of the
    eight page rules a page fails, an uncovered branch in a
    coverage report, an unticked acceptance criterion. The list
    bounds the absence, so naming a member is a measurement.
  - A direct answer to a direct question. "Does the commons cover
    handoffs?" — "No" is an answer, not a device.
  - A logged dead end. The research playbooks require negative
    results recorded with their sources; a search that found
    nothing is a result.
  - Normative absence in a spec or contract — "the schema defines
    no `status` field" tells an implementer what not to send.

## Candidates

Proposed, not decreed, and not binding until the operator moves one
up into a list above. Same fields.

### the rule of three

- **Proposed:** triads assembled for cadence rather than count —
  "atomic, minimal, and meaningful", "clear, concise, and correct".
  The third term is frequently a synonym of the first two.
- **Why:** the shape signals a completeness the content has not
  earned, and the padding term costs the reader attention.
- **Instead:** list what there is. Two items, or five.
- **Reference:** *tricolon*; the escalating form is *tricolon
  crescens*. Classical, and catalogued in the *Rhetorica ad
  Herennium*.
- **In proper use:** Lincoln, Gettysburg Address (1863) —
  "government of the people, by the people, for the people". Three
  terms doing three separate jobs: origin, agency, purpose. Drop
  any one and the sentence loses a claim. Compare Caesar's *veni,
  vidi, vici*, where the three are sequential events, not
  restatements.
- **Carve-out:** three actual things.

### not X, but Y

- **Proposed:** the manufactured antithesis — "this isn't about
  speed, it's about correctness", "not a bug, a design choice".
- **Why:** it performs incisiveness by denying something nobody
  claimed. Usually both halves are true and the negation adds
  nothing but length.
- **Instead:** assert Y. Keep the contrast only where someone
  actually claimed X.
- **Reference:** *antithesis*; when it revises a term just uttered,
  *correctio* (*epanorthosis*).
- **In proper use:** Kennedy, inaugural address (1961) — "Ask not
  what your country can do for you; ask what you can do for your
  country." The denied half was the prevailing expectation, so
  denying it does real work. Likewise Antony's "I come to bury
  Caesar, not to praise him" (*Julius Caesar*, III.ii), which
  answers what the crowd had assembled expecting.
- **Carve-out:** correcting a misconception someone genuinely
  stated, and real either/or choices.

### self-labeled insight

- **Proposed:** announcing significance instead of demonstrating
  it — "the key insight is", "here's the crux", "what's
  interesting is", "importantly".
- **Why:** the device-level generalization of the `load bearing`
  word-ban. If the point is significant the reader will see it; if
  it is not, the label will not rescue it.
- **Instead:** state the point and let its consequences carry it.
- **Reference:** *metadiscourse* — commentary on the discourse
  rather than on the subject (Hyland, *Metadiscourse*, 2005).
- **In proper use:** structural signposting in a work too long to
  navigate without it — Euclid labelling propositions, porisms,
  and corollaries in the *Elements*, so a reader can find the
  claim being used. The label earns its place when it aids
  navigation, not when it asserts importance.
- **Carve-out:** a summary section in a long document naming which
  of many findings changed the decision.

## Adding an entry

When the operator bans a **word**: add an entry under `## The list`
with the four fields (banned / why / instead / carve-out if any),
one entry per word family.

When the operator bans a **device**: add an entry under `## Banned
rhetorical devices` with those fields plus **Reference** (what the
move is called, so it can be looked up) and **In proper use** (a
case, preferably from the classics, where the same move is sound —
this is what keeps the entry a piece of craft guidance rather than
a prohibition).

When the operator promotes a candidate, move its entry up and drop
the `Proposed` wording.

Either way, commit. If the ban arrives mid-session, apply it
immediately — the entry is the durable record, not the trigger.
