---
name: cold-reader
description: Editorial precepts for durable documents — technical reports, ADRs, PRDs, design docs, READMEs. Write for the cold reader who holds only the artifact and its citations, not the session that produced it. Use when writing or reviewing any document meant to outlive its writing session, and as the audit pass before a document ships or prints.
---

# Cold Reader

A durable document is read by someone holding only the artifact and
whatever it cites — no session transcript, no chat history, no
memory of the conversation that produced it, no access to the
author. Call this person the **cold reader**. Every referent in the
document must resolve for them.

This generalizes the commit-message test (see the `commit-message`
skill: a message must read complete from message + diff alone) to
documents with room for argument and a citation apparatus. Commits
are the degenerate case; reports are the full case.

## The failure mode

Fluent prose whose referents die when the session ends. LLM agents
are especially prone because they write *inside* the session that
produced the work: the ticket discussion, the operator's request,
the working-memory shorthand all feel resolvable at writing time.
Humans do it too — sometimes on purpose, usually not. The prose
reads smoothly either way; the information is simply not there.

## Precepts

### 1. One narrative voice

The document speaks as its author, throughout. Session participants
do not appear as characters. Conversational input becomes "the
author's recollection, recorded <month year>" or a
personal-communication citation — not a named person making a
cameo in the third person.

**Test:** could the credited author read the document aloud as
their own words, without referring to themselves in the third
person or to a conversation the reader never saw?

### 2. Every name expands at first use

People, initials, project nicknames, internal artifact names get a
citation or a one-clause gloss the first time they appear.
"Attributed in source comments to TCK" fails; "attributed to
Te-Chih Ke (Ke and Bray 1995)" resolves. A rule known by its
author's surname needs the citation that says who and where.

**Test:** the document plus its bibliography, nothing else. Any
name that requires the repo, the session, or community folklore to
decode is a violation.

### 3. Pointers locate; they never carry

Ticket IDs, file paths, companion-document names may tell the
reader where more detail lives. They may not be the sole carrier
of a load-bearing fact. If removing the pointer removes the
claim's content, the content was never in the document.

Wrong: "the threshold defect (see ticket 41)."
Right: "the accessor returns the wrong field, so the admission
threshold runs about 3.3x wider than intended (ticket 41 tracks
the deferred fix)."

### 4. Show each derived number's arithmetic once

Every computed quantity gets its derivation visible at first use:
"about 3.3x (the intended factor is 0.3, and 1/0.3 = 3.3)";
"three orders of magnitude (2e-4 vs 2e-7)". An underived
multiplier reads as an assertion and cannot be checked without
reconstructing the author's arithmetic.

### 5. Chronology is provenance, not argument

Discovery dates, session order, and who-found-what-when belong in
a change-history block, an appendix, or the repository — not
inline in the analysis. Organize by consequence, not by the order
things happened to be found. Inline dates that mark *when a fact
was established* are bookkeeping; the fact itself is the content.

The complement: a claim about mutable state — "the current
implementation", "as of now" — names the version, commit, or
date it observed. The author's *currently* is the cold reader's
*years ago*.

### 6. Future artifacts are design, not promise

A road-map section may describe planned work. Nothing *outside*
that section may lean on artifacts that do not exist yet. A claim
supported by "the forthcoming experiment suite will show" is not
supported.

### 7. Cite coordinates that don't move

A citation only works if it still resolves when the cold reader
arrives. Published papers, versioned specs, and SHA-qualified
paths (`src/df.c` at `abc1234`) hold; bare file paths rot as
files move, and line numbers rot fastest of all. When a mutable
pointer is unavoidable, pair it with enough content that the
claim survives the pointer's death (precept 3 already requires
this).

### 8. Evidence stands alone

Every table and figure self-captions: a reader who lands on it
without the surrounding prose can tell what it shows, in what
units, from what source. Paper is the honest test here too —
figures get detached, photocopied, and cited on their own. This
is the complement of "don't repeat the evidence": if the prose
must not re-carry the fact, the evidence must be able to carry
it alone.

## Inherited from the commit-message precepts

These transfer directly; restated here so this skill audits
alone. If the two copies diverge, the `commit-message` skill is
authoritative — sync from there:

- **No private references** — labels that resolve only in the
  author's head or another document ("per lever 4", "the Tuesday
  item"). Name the concept in place.
- **No background narration** — production history and design
  discussion that belongs in the artifact or the repo. The
  document carries content; every sentence of how-it-came-to-be
  must earn its place as method, not chronicle.
- **No confessing invisible cleanups** — if no reader would notice
  the tidied thing, it does not rate a sentence.
- **Don't repeat the evidence** — when a document quotes code, a
  table, or a source verbatim, the prose adds interpretation, not
  paraphrase. One of the two carries the fact; the other builds on
  it.

## Running the audit

Before a document ships or prints, one dedicated pass:

1. **Referent sweep.** Every proper noun, initialism, nickname,
   and cross-reference: does it resolve from the document plus its
   bibliography, and will the cited coordinate still resolve after
   the repo moves on? (Precepts 1-3, 7.)
2. **Number and evidence sweep.** Every computed quantity: is the
   arithmetic visible at first use? Every table and figure: does
   it read without the surrounding prose? (Precepts 4, 8.)
3. **Chronicle sweep.** Every date and sequence marker: provenance
   or argument? Move provenance out of the analysis. Every
   "currently" / "as of now": anchored to a version or date?
   (Precepts 5-6, background narration.)
4. **Voice read.** Read a section aloud as the credited author.
   Third-person cameos by the author, or scenes from the writing
   session, fail. (Precept 1.)

Report findings grouped by precept, worst class first, each with
its location and a proposed fix — then apply only after the
operator's own editorial pass, so machine findings and human
findings can be compared rather than merged silently.

## Scaling by genre

- **Commit message** — use the `commit-message` skill; it is this
  discipline at minimum size.
- **ADR** — precepts 1-3 and 7 dominate. An ADR's cold reader
  arrives years later mid-refactor; rejected-alternative names
  and constraint sources must resolve on the spot.
- **Technical report** — all eight precepts, full audit before
  print. Printing is the honest test: paper strips every referent
  the session was silently supplying.
- **PRD / design doc** — precept 6 dominates: these documents are
  *about* future artifacts, so the design/promise line must be
  explicit — what exists today vs. what the document proposes.
