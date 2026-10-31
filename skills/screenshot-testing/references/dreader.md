# dreader: WKWebView through CuaDriver

Read the repository's current AGENTS.md before using these commands.
They are project tools, not prerequisites for other applications.

## Build and isolate

`bin/app-check mathml fixtures/epub/mathml` builds the app, runs checks
inside the real WKWebView on a scratch data root, and exits.
`bin/app-run --keep mathml-review fixtures/epub/mathml` builds and
opens the same fixture for inspection. The named scratch root is under
`tmp/app-run/`; use a fresh name when cold-start behavior matters.
Use `--no-build` only when the embedded assets match the current source.

Do not inspect the installed reader's library, scan real books under
`~/Documents/personal/`, or change `com.clubstraylight.dreader`
preferences. The project wrappers supply isolated state.

## Use the existing driver grant

Check the driver process and socket before starting another instance.
The working recovery on this machine was:

```sh
open -a /Applications/CuaDriver.app --args serve \
  --socket "$HOME/Library/Caches/cua-driver/cua-driver.sock"
```

Directly launching `cua-driver serve` from the agent shell reported
missing Screen Recording permission, while LaunchServices used the
installed app's existing grant successfully. A sandboxed permission
probe also reported no daemon when it could not reach the socket.
Neither justified a broader grant. Request narrowly scoped command
escalation if the shell sandbox blocks the approved project wrapper.
Never use a permission-gate bypass.

```sh
bin/app-drive front
bin/app-drive shot tmp/mathml-review.png
```

The wrapper targets `target/debug/dreader-app`, not the installed app,
and captures its window rather than the desktop. Verify the reported
PID/window and inspect the image. Read `bin/app-drive` usage before
input; click coordinates use screenshot pixels. An AX tree truncated
to the window does not mean pixel capture failed. A process on another
Space can still be captured while background input is refused; use the
exact known scratch window when restoring focus. Never guess a sibling.

## What DR-0133 taught

- Native MathML had layout boxes while omitting a matrix divider and a
  radical. The equation number was on the wrong side. Compare notation
  with W3C examples, not only box sizes.
- SVG copied into a shadow root also needed its full stylesheet. The
  divider existed geometrically but had zero computed stroke width.
- Percentage sizing inside MathML collapsed the first page's SVGs;
  restored-page testing had missed it. Add a cold-start assertion.
- Dark mode must recolor explicit publisher/SVG ink. Verify light mode
  still preserves the intended publisher color.
- Test source text and CFIs separately from pixels. A rendering that
  looks correct can corrupt quotation or search positions.
- A scrollable wide formula must consume its horizontal gesture without
  also turning the book's page.

See `.development/design/mathml-screenshots/` for evidence and
`.development/lessons-learned.md` for the permission investigation.
Use these as examples of measured failures, not as a fixed checklist
for every feature. Ask the operator questions in ordinary text; this
workflow requires no changes to their key bindings.
