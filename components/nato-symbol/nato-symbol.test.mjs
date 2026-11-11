// node --test components/nato-symbol/nato-symbol.test.mjs
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import vm from "node:vm";

const context = {};
vm.runInNewContext(readFileSync(new URL("./nato-symbol.js", import.meta.url), "utf8"), context);
const draw = o => context.natoSymbol({ x: 0, y: 0, ...o });

test("moves the symbol to its point and scales it", () => {
  assert.match(draw({ x: 10.5, y: 20, scale: 2.25 }), /^<g transform="translate\(10.5 20\) scale\(2.25\)">/);
});

test("draws the frame in the side's colours", () => {
  assert.match(draw({ ink: "#3f4a1c", fill: "#b0c372" }),
    /<rect x="-13" y="-8.5" width="26" height="17" fill="#b0c372" stroke="#3f4a1c"/);
});

test("draws the sign for each kind", () => {
  const paths = kind => (draw({ kind }).match(/<path /g) || []).length;
  assert.equal(paths("infantry"), 1);
  assert.equal(paths("cavalry"), 1);
  assert.match(draw({ kind: "armor" }), /<ellipse /);
  assert.match(draw({ kind: "mechanized" }), /<path d="M-13 -8.5L13 8.5M13 -8.5L-13 8.5".*<ellipse /);
  assert.equal(paths("airborne"), 2);
  assert.match(draw({ kind: "artillery" }), /<circle r="3"/);
  assert.doesNotMatch(draw({ kind: "other" }), /<path |<ellipse |<circle /);
});

test("colours the sign apart from the frame", () => {
  assert.match(draw({ kind: "infantry", ink: "#8f0d0d", glyph: "#fdf296" }), /<path [^>]*stroke="#fdf296"/);
});

test("puts the echelon above and the label below", () => {
  const svg = draw({ echelon: "||", label: "1/7" });
  assert.match(svg, /<text y="-11" font-size="9"[^>]*>\|\|<\/text>/);
  assert.match(svg, /<text y="21" font-size="11"[^>]*>1\/7<\/text>/);
});

test("rings a unit holding a position and outlines one in focus", () => {
  assert.match(draw({ ring: true }), /<circle r="17"/);
  assert.match(draw({ focus: "#d68a00" }), /<rect [^>]*stroke="#d68a00"/);
  assert.doesNotMatch(draw({}), /<circle r="17"|rx="3"/);
});

test("dashes and fades a faint symbol", () => {
  const svg = draw({ faint: true, ring: true });
  assert.match(svg, /opacity="0.5"/);
  assert.equal((svg.match(/stroke-dasharray="4 3"/g) || []).length, 2);
});

test("escapes text and passes attributes to the group", () => {
  const svg = draw({ label: "A&B <x>", attrs: { class: "unit s-us", "data-unit": 'B/"2"' } });
  assert.match(svg, /<title>A&amp;B &lt;x&gt;<\/title>/);
  assert.match(svg, / class="unit s-us" data-unit="B\/&quot;2&quot;"/);
});

test("titles the symbol with its label unless given a title", () => {
  assert.match(draw({ label: "1/7", title: "1st Battalion, 7th Cavalry" }), /<title>1st Battalion, 7th Cavalry<\/title>/);
  assert.match(draw({}), /<title><\/title>/);
});
