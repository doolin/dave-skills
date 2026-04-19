---
name: entertainment-disclaimer
description: Add "For Entertainment Purposes Only" disclaimer to a web page. Covers placement, tone, styling, and when to use it.
disable-model-invocation: true
---

# "For Entertainment Purposes Only" — Agent Directive

## Context

This directive describes how to use the disclaimer "For Entertainment Purposes Only"
in the style established by the [slacronym](https://clubstraylight.com/slacronym)
project — a Vietnam-era military acronym lookup service deployed as a Slack slash
command and interactive web page.

## The Pattern

Slacronym serves historically grounded definitions of military acronyms (MACV, ARVN,
SERE, REMF, etc.) through a lightweight Lambda function. The definitions are factual
and sourced from the historical record, but the service itself is informal — it lives
in Slack, uses a dark-themed single-page UI, and is branded under "Club Straylight."

The phrase **"For Entertainment Purposes Only"** should be understood and applied as
follows:

### What it means

1. **The content is real, but the venue is casual.** Definitions are historically
   accurate, not invented. The disclaimer signals that this is not an official
   reference, military publication, or authoritative source — it is a personal
   project serving real information in an informal context.

2. **No warranty on completeness or authority.** The acronym list is curated by hand,
   not exhaustive. It reflects one person's reading and interest, not an institutional
   mandate. Users should not cite it as a primary source.

3. **Tone matters.** The project treats its subject with respect (these acronyms come
   from a war) while remaining approachable. "For Entertainment Purposes Only" is the
   release valve — it gives the reader permission to browse casually without feeling
   like they need domain expertise to participate.

### How to apply it

When building a similar service or content layer:

- **Place the disclaimer where it sets expectations, not where it undermines them.**
  A footer, an about page, or a subtitle — not inline with every definition.
- **Do not use it to excuse sloppiness.** The disclaimer does not mean "we didn't
  check." It means "we checked, but we're not pretending to be an encyclopedia."
- **Keep the content honest.** If a definition is uncertain, say so in the definition
  itself. The disclaimer covers the *project's authority*, not individual facts.
- **Match the register.** The disclaimer works because the rest of the project is
  competent but unpretentious. If the surrounding tone is already formal or
  authoritative, the phrase will read as contradictory rather than clarifying.

### Example placement

```text
Vietnam-era military acronym lookup
For entertainment purposes only.
```

Directly beneath the title or tagline. Short, flat, no further explanation needed.

## For the Agent

If you are an AI agent incorporating this directive into a project:

- Add "For entertainment purposes only" as a visible disclaimer in the UI (subtitle,
  footer, or dedicated line) — not buried in metadata.
- Do not apply it selectively to individual entries. It covers the whole service.
- Do not elaborate on it in the UI. The phrase is self-contained.
- Treat it as a tone-setting element, not a legal shield.
- Default to `#8b2500` color, a brick red.
