---
name: operator-review-page
description: Put a batch of judgment calls in front of the operator as one local HTML page, with one card per open call showing the question, the verbatim evidence and where it was read, the choices with the current state marked, and a note field. The answers are saved in the browser and exported as a decisions file that a tested tool applies. Use when work waits on more than a handful of decisions only the operator can make (merges, disagreements between sources, inferences, spellings, placements), instead of asking in chat or handing over a raw data file.
disable-model-invocation: false
allowed-tools: Bash(*/review-page*), Bash(review-page*)
---

# Operator review page

Some calls only the operator can make: whether two records are one
thing, which of two sources stands, whether an inference holds, how
a name is spelled. One such call fits in chat. Forty do not, and
neither does a 9,000-line JSON file with the calls buried in it.
This skill builds a page with one card per open call. The operator
works through it, and the page exports the answers as a file. A
tested tool then applies that file, so the decisions are recorded
in the data rather than left in a conversation.

Reference implementation: the vocabulary review of the bong-son
battle-research project, 43 calls (3 merges, 22 source
disagreements, 15 inferences, 3 spellings), each with OCR evidence.

## The contract

- **Agents never decide a call on the operator's behalf.** An item
  leaves the queue only when the operator has answered it. "Unsure"
  is always an option, and it keeps the item open.
- **Evidence is verbatim, with where it was read.** Each card shows
  the source lines that bear on the call, quoted exactly, each
  labelled with its page, screen, or document reference, so the
  operator judges the source and not the agent's summary of it.
- **The card says what the data holds now** (`current`), so the
  operator can see that keeping it is a choice too.
- **The page is a view; the decisions file is the record.** A tested
  command applies each decision to the data and writes it into the
  record's notes ("Operator, 2026-11-05: Keep merged — note"). The
  page is then rebuilt from what is still open.
- **The page stays local.** It opens from disk, makes no network
  request, and loads no external asset. When the evidence is
  research input (quoted book text), the page is private, like the
  data.

## Steps

1. **Collect the open calls into a review file** (the lead's job).
   One item per decision, never two in one card. Put first the
   items that unblock the most work.
2. **Check and fill the page:**

   ```bash
   ~/.claude/skills/operator-review-page/review-page REVIEW.json guide/review.html
   ~/.claude/skills/operator-review-page/review-page REVIEW.json --check   # validate only
   ```

   The command checks every rule below and names each broken one
   (exit 11). It embeds the JSON into the bundled `template.html`,
   or into `--template PATH` for a project's own styling. The
   template must keep one `/*REVIEW*/` slot.
3. **The operator answers.** They open the page from disk, choose,
   add a note where it helps, and press **Download decisions**. They
   drop the file in the repo. **Copy JSON** is the fallback where
   downloads are blocked. Answers survive a reload, because they are
   saved in the browser under the review's `storage_key`.
4. **Apply the decisions with a tested command** in the project.
   It applies each choice to the data, records it in the record's
   notes, leaves "Unsure" items open, and fails loudly on a decision
   whose `item` is unknown. The skill does not provide this command:
   what a decision does is the project's business.
5. **Rebuild the review file from what is still open** and fill the
   page again. Item ids are stable, so answers saved for items that
   remain open stay checked.

## The review file

```json
{
  "title": "Vocabulary review",
  "source": "data/vocabulary.json",
  "source_line": "Review of data/vocabulary.json (BSN-0003). Choose for each item; download your decisions when done.",
  "storage_key": "bong-son-vocab-review-v1",
  "built": "2026-10-18",
  "decisions_file": "vocabulary-decisions.json",
  "kinds": {"merge": "merge", "disagree": "disagreement", "inferred": "inferred", "spelling": "spelling"},
  "open_notes": ["merge", "inferred"],
  "items": [
    {
      "item": "merge:position-dog",
      "kind": "merge",
      "list": "places",
      "entry": "position-dog",
      "name": "Position Dog",
      "variants": ["Dog", "LZ English"],
      "question": "Position Dog and LZ English are one place (Dog was renamed LZ English once built). The index lists them separately.",
      "options": ["Keep merged", "Split into two entries", "Unsure"],
      "current": "Keep merged",
      "notes": "The text says Dog was renamed LZ English once built (p.26).",
      "evidence": [
        {"page": 26, "text": "Once completed, the position would be renamed LZ English…"},
        {"ref": "CHECO #150 p.32", "text": "…"}
      ]
    }
  ]
}
```

| Field | Rule |
|---|---|
| `title`, `source`, `storage_key` | Required. `source` is the file under review, and is echoed into the decisions file. `storage_key` is unique per review; bump its version when the items change meaning, so stale answers do not carry over. |
| `source_line` | One line under the title saying what is reviewed and what to do. |
| `kinds` | Kind → label for badges, counts and filter chips. Unlisted kinds show their id. |
| `open_notes` | Kinds whose notes open by default (those where the notes are the evidence). |
| `decisions_file` | The download's file name (default `decisions.json`). |
| `item` | Required, unique, stable across rebuilds (`kind:entry` works). |
| `kind`, `name`, `question` | Required. The question states the call in a sentence, with the conflicting facts. |
| `options` | Two or more distinct choices, "Unsure" among them. |
| `current` | Null, or one of `options`: what the data holds now. |
| `entry`, `list`, `field`, `variants`, `notes` | Optional context; `entry` and `field` are echoed into each decision. |
| `evidence` | Optional list of `{text, ref}` or `{text, page}`: the verbatim line and where it was read. |

## The decisions file

```json
{
  "source": "data/vocabulary.json",
  "built": "2026-10-18",
  "decided_at": "2026-11-05T14:02:11.000Z",
  "decisions": [
    {"item": "merge:position-dog", "kind": "merge", "entry": "position-dog",
     "choice": "Keep merged", "note": null}
  ]
}
```

Only answered items appear. A note with no choice is kept in the
browser but not exported. The project's apply command should
treat `built` as the review's version, and apply a decisions file
built against an older review only for items whose `item` id still
exists.

## What makes a good card

- **One decision.** If the operator would answer "yes to the first
  half", it is two cards.
- **The question carries the conflict.** "Map 9 puts LZ Bird at the
  river curl; the text's 8 km from Duck puts it at hill 86, 1.6 km
  east." Not "Check LZ Bird."
- **One to four evidence lines,** the shortest that decide it, each
  with its reference. A card with no evidence is an opinion poll.
- **The options cover the field,** including the outcome the agent
  thinks unlikely, plus "Unsure".
- **Sorted by what the answers unblock,** with the kinds as filters,
  so a short sitting clears the calls that matter.

## The page

`template.html` is one file. It holds no external asset and works
from `file://`, on a phone, and in light and dark mode. It shows the
items in file order, with counts by kind, filter chips (All, each
kind, Unanswered), and a progress line top and bottom. An answered
card is marked by an edge rule. Answers are saved to `localStorage`
under `storage_key`, wrapped so a private window or blocked storage
still works for the session. Download writes the decisions file;
Copy JSON falls back to a selected text area where the clipboard is
blocked.

## Model classes

- **Lead** (Opus or Fable class): chooses what goes on the page,
  writes the questions and options, and orders the items.
- **Sonnet**: gathers the evidence lines against a written item list.
- **The command**: fills the page. No model writes HTML for this.

## Traps

- `</script>` inside a quoted line closes the data block early. The
  command writes `</` as `<\/`, which is the same JSON.
- Two reviews with one `storage_key` show each other's answers.
- Renaming an item id between rebuilds drops the operator's saved
  answer for it.
- Do not mark an item answered from the agent's own reading. If the
  agent is sure, the card shows that as `current`, and the operator
  still answers it.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | page written, or `--check` passed |
| 10 | bad arguments (including OUT the same as the review file) |
| 11 | the review file breaks a rule, or the template lacks one `/*REVIEW*/` slot |
| 12 | a file is unreadable or not JSON |

## Tests

```bash
bats skills/operator-review-page/test/
```
