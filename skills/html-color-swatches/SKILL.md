---
name: html-color-swatches
description: Generate a standalone HTML palette page with color swatches for browser viewing. Use when the user wants to see colors rendered in a browser (sharing, design review, screenshots), or when the terminal-rendering path is not viable. Output is a single self-contained HTML file, typically written to /tmp/ for ephemeral viewing.
---

# HTML Color Swatches

Generate a single-file HTML page that renders a project's color
palette as visual swatches, grouped by role, with hex codes and
design-token names visible. Open it in the default browser with
`open` (macOS) or `xdg-open` (Linux).

## When to use this over terminal swatches

- **Sharing**: the file can be sent to a collaborator who doesn't
  have the terminal script — pure HTML, no dependencies.
- **Screenshots**: easier to capture and embed in design docs than
  a terminal screenshot.
- **Hover/inspect**: a browser lets you eyedropper the rendered
  pixel color or copy hex codes from the DOM.
- **Light-mode review**: terminal-only review tends to assume a dark
  background; HTML can show the palette on both light and dark
  surfaces if needed.

For quick iteration during development, `terminal-color-swatches`
is faster (no file write, no browser switch). HTML is the artifact
form.

## Output location

Default to `/tmp/<project>-palette.html` — ephemeral, gets cleaned
up by the OS, doesn't pollute the repo. Only put it in a tracked
location (e.g. `docs/palette.html`) if the user explicitly asks for
a persistent design-reference page.

## Template

```html
<!doctype html>
<meta charset="utf-8">
<title>{{ project }} palette — colors in active use</title>
<style>
  :root { color-scheme: dark; }
  body {
    font-family: ui-sans-serif, system-ui, sans-serif;
    background: #0f172a; color: #e2e8f0;
    margin: 2rem auto; max-width: 880px;
  }
  h1 { font-size: 1.25rem; font-weight: 600; }
  h2 {
    font-size: 0.95rem; font-weight: 600; color: #94a3b8;
    margin: 1.75rem 0 0.5rem;
    text-transform: uppercase; letter-spacing: 0.05em;
  }
  table { width: 100%; border-collapse: collapse; font-size: 0.9rem; }
  td { padding: 0.4rem 0.6rem; vertical-align: middle; }
  .sw {
    display: inline-block; width: 96px; height: 32px;
    border-radius: 4px; border: 1px solid #334155;
  }
  .hex  { font-family: ui-monospace, monospace; color: #cbd5e1; }
  .name { font-family: ui-monospace, monospace; color: #e2e8f0; }
  .role { color: #94a3b8; }
  tr:hover td { background: #1e293b; }
</style>

<h1>{{ project }} palette — colors in active use</h1>

<h2>Class semantic</h2>
<table>
  <tr>
    <td><span class="sw" style="background:#f97316"></span></td>
    <td class="hex">#f97316</td>
    <td class="name">orange-500</td>
    <td class="role">positive class</td>
  </tr>
  <!-- ... repeat per color ... -->
</table>
```

## Design notes

### Dark default

`color-scheme: dark` plus `background: #0f172a` matches how the
deck/app actually renders the colors in practice — light-content
SVG on dark cards. Reviewing on a light background can mislead
about contrast.

### Fixed-size swatches

`96px × 32px` rectangles are the practical minimum that still let
you compare two adjacent colors confidently. Smaller and the eye
can't separate near-duplicates (e.g. `slate-50` vs `slate-100`).

### Hex first, name second, role last

Hex is the load-bearing identifier (search across the repo with it),
name aids comprehension (`orange-500` is more memorable than
`#f97316`), role is the design intent. Order them visually
left-to-right by frequency of lookup.

### Row hover

`tr:hover td { background: #1e293b; }` — small thing, but helps the
eye track across the row when scanning for a specific color in a
long table.

### Banned colors

If the project has memory-tracked banned colors (unreadable bg,
fails contrast, etc.), tag the role cell in red so the file itself
documents the constraint:

```html
<td class="role" style="color:#f87171">BANNED card-bg (memory)</td>
```

## Sourcing the palette

Same approach as terminal-color-swatches — grep the template/view
directory for `#[0-9a-fA-F]{6}` matches, dedupe, group by role:

```bash
grep -hroE "#[0-9a-fA-F]{6}" path/to/views/ | sort -uf
```

Avoid auto-generating the HTML from the grep alone — the value of
the swatch page is the *grouping* (class semantic vs accent vs
chrome), and that's a human judgment call.

## Opening

After writing:

```bash
open /tmp/<project>-palette.html      # macOS
xdg-open /tmp/<project>-palette.html  # Linux
```

## Pairs well with

- `terminal-color-swatches` — for the in-development quick-iteration
  view; the HTML is the artifact/share form.

## Reference implementation

- `dbb` — `/tmp/dbb-palette.html` generated from
  `docs/presentations/interactive/linear-scoring/` and
  `app/views/neural_net/` (30 unique colors across 8 role groups)
