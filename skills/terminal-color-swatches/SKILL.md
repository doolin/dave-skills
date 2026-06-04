---
name: terminal-color-swatches
description: Render a color palette as truecolor ANSI swatches in the terminal. Use when the user asks to display colors, show a palette, or visualize hex codes — and prefers terminal output over a browser. Outputs a small executable script (typically bin/palette) the user can run directly.
---

# Terminal Color Swatches

Display a palette of hex colors as 24-bit truecolor background blocks
in the terminal, with each block annotated by hex code, design-token
name (e.g. `orange-500`), and a one-line role description.

## Why a script, not a one-liner

ANSI escapes (`\x1b[48;2;R;G;Bm`) render correctly in the user's
host terminal, but **Claude Code's tool-output pipeline strips the
leading ESC byte before the assistant sees the result**. The
assistant's view shows `[48;2;249;115;22m        [0m` as literal
characters, while the user sees a colored block.

This means:

- Running ANSI-emitting commands via the `Bash` tool works for the
  user but looks broken to the assistant. Trust the user's screen,
  not the captured tool output.
- A small reusable script (`bin/palette` is the conventional name)
  is more useful than inlining the escapes into every call. The user
  runs it whenever they want the palette; the assistant doesn't need
  to see colored output to confirm correctness.

## Script template

Drop the following into `bin/palette` (or any executable path),
`chmod +x`, and run:

```bash
#!/usr/bin/env bash
# Display the project color palette as truecolor swatches in the terminal.
# Run directly in your shell — ANSI escapes don't render inside Claude
# Code's tool-output pipeline.

set -e

sw() {
  local hex=${1#\#}
  local r=$((16#${hex:0:2}))
  local g=$((16#${hex:2:2}))
  local b=$((16#${hex:4:2}))
  printf '\x1b[48;2;%d;%d;%dm        \x1b[0m  %s  %-12s  %s\n' \
    "$r" "$g" "$b" "$1" "$2" "$3"
}

section() { printf '\n\x1b[1m── %s ──\x1b[0m\n' "$1"; }

section "Class semantic"
sw "#f97316" "orange-500" "positive class"
sw "#3b82f6" "blue-500"   "negative class"

# ... add as many sw / section calls as needed
```

## Key implementation details

### Hex → RGB in pure bash

```bash
local r=$((16#${hex:0:2}))
local g=$((16#${hex:2:2}))
local b=$((16#${hex:4:2}))
```

No `bc`, no `printf '%d' "0x$hex"`, no awk. Bash's `$((...))` with
the `16#` base prefix handles it directly.

### Truecolor escape format

- Background: `\x1b[48;2;R;G;Bm`
- Foreground: `\x1b[38;2;R;G;Bm`
- Reset:      `\x1b[0m`
- Bold:       `\x1b[1m`

R, G, B are decimal 0-255.

### macOS awk has no `strtonum`

If reaching for `awk` to parse hex, note that BSD awk (the macOS
default) lacks `strtonum` — using it errors with
`awk: calling undefined function strtonum`. Either install gawk or
stick with bash arithmetic. Bash is sufficient for this pattern.

### Section headers

Use bold ANSI (`\x1b[1m...\x1b[0m`) for section dividers, with
box-drawing characters (`──`) for visual separation. Keeps the
output scannable when listing 20+ colors.

### Column alignment

Use `printf` width specifiers (`%-12s`) on the token-name column
so swatches and hex codes line up regardless of name length.

## Sourcing the palette

For a Tailwind-using project, the palette is whatever hex values
appear in templates/views/SVG inline. Extract with:

```bash
grep -hroE "#[0-9a-fA-F]{6}" path/to/views/ | sort -uf
```

Then group by role (class semantic, decision boundary, accents,
ramps, UI chrome) rather than alphabetically — role grouping makes
the script useful for design review, not just inventory.

Flag any "banned" colors with a role-column note (e.g.
`BANNED card-bg (memory)`) so the swatch script itself documents
project-specific design constraints.

## Pairs well with

- `html-color-swatches` — when a browser-rendered version is also
  useful (e.g. sharing with collaborators, embedding in design docs)

## Reference implementation

- `dbb/bin/palette` — 30-color palette grouped into 8 sections
  (class semantic, decision boundary, error/accent, geometry,
  orange ramp, blue ramp, slate ramp, accents)
