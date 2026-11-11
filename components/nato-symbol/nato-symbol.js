// nato-symbol.js, version 1
// One NATO unit symbol as an SVG string, for the family's map viewers.
// Master: dave-skills components/nato-symbol/nato-symbol.js. The copies in
// bong-son, silver-bayonet and yom-kippur are synced from it, never edited
// in place; change the master, then copy it.
//
// natoSymbol(o) draws the symbol at one fixed size about (0, 0) and moves
// it to (o.x, o.y) scaled by o.scale, so a caller keeps it the same size on
// screen at any zoom by passing map units per screen pixel as the scale.
//
//   x, y        where the symbol stands, in the caller's SVG units
//   scale       1 draws a 26 x 17 frame; default 1
//   kind        infantry (X), cavalry (/), armor (oval), mechanized (X and
//               oval), airborne (X and a canopy), artillery (dot), other
//               (empty frame)
//   echelon     the mark above the frame: "|", "||", "X", ...
//   label       the text below the frame
//   title       the tooltip; defaults to the label
//   ink, fill   the frame's line and fill colours
//   glyph       the colour of the sign inside; defaults to ink
//   text, halo  the colour of the echelon and label text and of its outline
//   ring        true for a ring round the frame (a unit holding a position)
//   focus       a colour for a highlight round the frame, or null
//   faint       true for a dashed, half-transparent symbol
//   attrs       extra attributes for the outer <g>: {class: "unit", ...}
function natoSymbol(o) {
  const W = 13, H = 8.5;
  const esc = s => String(s).replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" })[c]);
  const n = v => Number(v.toFixed(3));
  const ink = o.ink || "#3a3833", fill = o.fill || "#e2e2e2", glyph = o.glyph || ink;
  const text = o.text || "#111111", halo = o.halo || "#ffffff";
  const dash = o.faint ? ' stroke-dasharray="4 3"' : "";
  const stroke = (colour, width) => `fill="none" stroke="${colour}" stroke-width="${width}"`;
  const cross = `<path d="M${-W} ${-H}L${W} ${H}M${W} ${-H}L${-W} ${H}" ${stroke(glyph, 1.3)}/>`;
  const oval = `<ellipse rx="${n(W * 0.62)}" ry="${n(H * 0.5)}" ${stroke(glyph, 1.3)}/>`;
  const canopy = `<path d="M-6 ${H - 1.5}Q-3 ${H - 5} 0 ${H - 1.5}Q3 ${H - 5} 6 ${H - 1.5}" ${stroke(glyph, 1.3)}/>`;
  const inside = {
    infantry: cross,
    cavalry: `<path d="M${-W} ${H}L${W} ${-H}" ${stroke(glyph, 1.3)}/>`,
    armor: oval,
    mechanized: cross + oval,
    airborne: cross + canopy,
    artillery: `<circle r="3" fill="${glyph}"/>`
  }[o.kind] || "";
  const words = (y, size, s) => `<text y="${y}" font-size="${size}" font-weight="600" text-anchor="middle" ` +
    `fill="${text}" stroke="${halo}" stroke-width="3" stroke-linejoin="round" paint-order="stroke">${esc(s)}</text>`;
  const attrs = Object.entries(o.attrs || {}).map(([k, v]) => ` ${k}="${esc(v)}"`).join("");
  return `<g transform="translate(${n(o.x)} ${n(o.y)}) scale(${n(o.scale || 1)})"${o.faint ? ' opacity="0.5"' : ""}${attrs}>` +
    `<title>${esc(o.title || o.label || "")}</title>` +
    (o.ring ? `<circle r="17" ${stroke(ink, 1.5)}${dash}/>` : "") +
    (o.focus ? `<rect x="${-W - 3}" y="${-H - 3}" width="${2 * W + 6}" height="${2 * H + 6}" rx="3" ${stroke(o.focus, 3)}/>` : "") +
    `<rect x="${-W}" y="${-H}" width="${2 * W}" height="${2 * H}" fill="${fill}" stroke="${ink}" stroke-width="1.5"${dash}/>` +
    inside +
    (o.echelon ? words(-11, 9, o.echelon) : "") +
    (o.label ? words(21, 11, o.label) : "") +
    "</g>";
}
