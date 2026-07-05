---
name: banned-words
description: The operator's banned-words list — words that read as bafflegab, filler, or euphemism, with replacements for each. Applies to all prose an agent produces (responses, documents, commit messages, tickets) and to inherited text being edited. Load when writing or reviewing prose, and whenever a listed word is about to appear.
---

# Banned words

Bafflegab asserts value or agreement without naming anything. This
list bans the recurring offenders. Each entry records the ban's
scope, the replacements, and any carve-out — the carve-outs are
part of the ban, not exceptions to it.

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

## Adding a word

When the operator bans a word: add an entry above with the four
fields (banned / why / instead / carve-out if any), one entry per
word family, and commit. If the ban arrives mid-session, apply it
immediately — the entry is the durable record, not the trigger.
