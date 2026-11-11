# nato-symbol

One NATO unit symbol as an SVG string, for the family's map viewers:
bong-son's time viewer, silver-bayonet's timeline page and the
derived yom-kippur viewer. One function, so the three draw units the
same way.

```js
svg.insertAdjacentHTML("beforeend", natoSymbol({
  x, y, scale: mapUnitsPerScreenPixel,
  kind: "infantry", echelon: "||", label: "1/7",
  ink: "#3f4a1c", fill: "#b0c372", ring: true
}));
```

The symbol is drawn at one size about (0, 0), a 26 x 17 frame with
its echelon mark above and its label below, then moved to (x, y) and
scaled. A viewer that zooms passes the map units per screen pixel as
`scale`, and the symbol stays the same size on screen. The options
are listed at the top of `nato-symbol.js`.

| kind | inside the frame |
|---|---|
| infantry | X |
| cavalry | a slash |
| armor | an oval |
| mechanized | X and an oval |
| airborne | X and a canopy |
| artillery | a dot |
| other | nothing |

The colours are the caller's: each viewer passes its sides' ink and
fill, and a glyph colour where the sign must stand out from a dark
fill.

## Copies

Each viewer carries a byte-for-byte copy of `nato-symbol.js`, so a
page builds and opens with no link to this repo. The copies are
synced from here and never edited in place: change the master, run
the test, then copy it into each repo. The first line carries the
version, so a copy that has fallen behind shows it.

## Test

```sh
node --test components/nato-symbol/nato-symbol.test.mjs
```
