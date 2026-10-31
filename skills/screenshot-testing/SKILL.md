---
name: screenshot-testing
description: Verify application rendering with scoped window screenshots, compare visible results with references, and turn observed defects into meaningful regression checks. Use for visual QA of a running application, including native webviews.
---

# Screenshot testing

Use screenshots to establish what the application actually draws.
Pair them with focused runtime checks for behavior that pixels cannot
prove. For dreader and its macOS CuaDriver setup, read
[references/dreader.md](references/dreader.md).

## Establish the test surface

Identify the intended build, fixture, scratch state, process and
window. Prefer the project's test launcher and scoped capture wrapper.
Do not substitute the operator's live application or private documents
when a fixture will exercise the behavior. Rebuild when assets are
embedded into the binary; an open window may still show older code.

Use a capture path already authorized for the task. Distinguish:

- A client missing its own computer-use grant.
- A shell sandbox unable to connect to an existing driver's socket.
- An installed driver whose macOS permission depends on its launch
  identity.
- A known window being on another desktop, where capture may work but
  background input is refused.

Evidence about one path does not establish the others are unavailable.
On macOS, use the installed driver app through LaunchServices when that
is the supported, already authorized path. Do not change screen grants,
bypass permission checks, or request unrestricted access to recover a
scoped capture. If the authorized path is unavailable, record the
limitation and continue independent checks.

## Observe, act, verify

Capture the target window and inspect it before choosing coordinates.
Use that image's coordinate convention, not remembered positions from
another window size. Keep input, waits and the resulting screenshot
sequential. Fully await any tool session before issuing dependent
input or treating its output file as fresh.

A successful input call proves delivery, not its visible effect.
Inspect the resulting screenshot. If input is refused for an off-space
window, bring that exact known test window forward when authorized;
do not redirect input to a sibling or repeatedly retry blindly.

Compare the visible result with a named reference and explicit expected
features. Inspect actual strokes, glyphs, alignment, clipping, contrast
and duplicates. A nonempty bounding box does not prove a divider was
painted, a radical exists, or text contrasts with its background.
State whether comparison is structural/manual or pixel-based.

Exercise states implicated by the change: cold start versus restored
state, themes, viewport changes, pagination, or content overflow. Use
the smallest relevant set; do not expand into an unrelated UI audit.

## Turn observations into evidence

For a discovered regression, add a check for the observable failure:
visible stroke plus correct placement, nonzero cold-start dimensions,
actual computed colors, or scroll movement without a page turn.
Avoid tests that merely assert an implementation class or marker exists.
Use runtime checks for source positions, selection, accessibility and
network/security behavior; screenshots alone cannot establish them.
Do not claim accessibility was tested without exercising it.

Save representative before/after images with build, fixture, settings,
capture date and comparison notes. Label an intermediate failure as a failure;
replace stale "final" images after a rendering change. Preserve
uncropped originals when crops are useful for comparison. Keep personal
information out of committed evidence by using fixtures from the start.

Once relevant checks and final visual inspection pass, stop repeating
them unless code changes or new evidence warrants another run. Report
the observed result and material limits. Stop only test processes this
session owns, and leave the operator's application untouched.
