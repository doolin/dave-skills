# Historical research dossier

Turn a research question about a historical subject — an
airfield, a unit, a campaign event, a piece of equipment —
into a cited dossier under the project's `docs/reference/`,
plus license-verified imagery, fit to feed a published
supplement under a strict text-sourcing policy.

Reference implementation:
`~/src/sgp-linebacker-2/docs/reference/kep-airfield.md`
(Kép Air Base, researched 2026-08-08), with its companion
provenance entry and downloaded public-domain photo.

## When to use

Any time an agent researches a historical subject whose
findings may reach a deliverable: enhanced-edition content,
designer's notes, a rules supplement, box copy. Read this
BEFORE writing the research agent's brief.

## Pipeline (minimum model class per stage)

1. **Frame** (operator + Fable-class): subject, what the
   project needs from it, where findings will land.
2. **Corpus check** (any): follow `reference-acquisition.md`
   — query the operator's Agent Reference API before any web
   research; record hit or miss at the top of the dossier.
3. **Web sweep** (Sonnet): history and imagery. Prefer
   primary sources; when a fact arrives through an
   aggregator (Wikipedia), cite the underlying source AND
   the mediator so the chain is auditable.
4. **License verification** (Sonnet): machine-readable
   metadata over page prose — e.g. Wikimedia Commons API
   `extmetadata` (`Copyrighted`, `UsageTerms`), not a
   caption's say-so. Download only what verifies clean;
   descriptive kebab-case filenames; one provenance record
   per file (source URL, license, verification method).
5. **Dossier** (Sonnet): structure below.
6. **Operator review** (operator): gap triage, upgrading
   mediated citations to direct ones, publication decisions.

## Dossier structure

- Corpus-check result first — fresh research or built on
  prior reading.
- Cited history: one claim per bullet, each with its
  citation. No orphan facts.
- **Gap notes**: what was looked for and NOT found, stated
  explicitly ("no source ties X to Y") — never papered over.
  Conflicting sources are recorded as conflicts with a
  better-supported lean, not silently resolved.
- Imagery table: description, date, URL, license status,
  downloaded or not (and why not).
- **Dead ends**: every blocked or broken source with its URL
  and failure mode (HTTP 403, DNS failure, paywall, expired
  cert) so the operator can visit manually. A blocked source
  is a finding, not an omission.
- Provenance records for anything downloaded.

## Non-negotiables

- **Corpus before web.** The operator's bookmarked reading
  is checked first, via `curl` inside sub-agents.
- **Verbatim text is quoted, everywhere.** Any phrase copied
  from a source sits in quotation marks with its source,
  even in internal notes — this is the firewall that keeps
  unquoted third-party prose from migrating into deliverable
  drafts.
- **Deliverable text policy** (operator decree, 2026-08-08):
  published text is original prose built from verified
  facts; researched-site text appears only as direct,
  attributed quotation justified under public domain or fair
  use — never paraphrased or closely reworded. The operator
  reviews all such documentation before it ships.
- **US federal works are public domain** (17 USC §105). A
  hosting archive gains no rights by holding or scanning
  them (*Bridgeman Art Library v. Corel Corp.*, 36 F. Supp.
  2d 191 (S.D.N.Y. 1999)); "educational use only" notices
  over federal works are access policy, not license — use
  the work, skip the permission request, do not credit the
  archive. Keep the service credit (USAF, US Navy) and date
  in provenance records for research value. The question
  that DOES need care: whether the item genuinely is a
  federal work (embedded press photos are not).
- **Unverifiable license → catalogue, don't download.**
- **Research agents return findings; they do not commit and
  do not edit existing files.** The orchestrating session
  reviews and commits with co-author credit.
