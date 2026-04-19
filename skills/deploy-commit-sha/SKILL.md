---
name: deploy-commit-sha
description: Add the current deployed git commit SHA to a web page. Makes it visible which exact commit is running in any environment. Implemented — reference pattern from slacronym (Node.js/Lambda).
disable-model-invocation: true
---

# Deploy Commit SHA

Display the current deployed git commit SHA on a web page so anyone
can verify exactly which commit is running in any environment.

## Pattern (from slacronym)

Three-part approach: generate at deploy time, placeholder in HTML,
inject at server startup.

### 1. Generate `version.json` at deploy time

In the deploy script, write the full SHA into the deploy package:

```bash
echo "{\"sha\":\"$(git rev-parse HEAD)\"}" > "$TEMP_DIR/version.json"
```

This runs during packaging, before the zip is uploaded. The file is
bundled alongside the app and never committed to the repo.

### 2. HTML placeholder

Add a placeholder in the HTML (e.g. footer) where the SHA will appear:

```html
<footer id="build-info"><!-- BUILD_SHA --></footer>
```

Display the bare SHA only — no label like "Build:" or "Version:".
The SHA is meaningful on its own to anyone who needs it, and a label
adds visual noise.

### 3. Server-side injection at startup

Read `version.json` when the server starts, replace the placeholder,
fall back to `"dev"` when no version file exists (local dev):

```js
const VERSION_PATH = join(moduleDirname, "version.json");

function loadBuildSha() {
  try {
    const raw = readFileSync(VERSION_PATH, "utf8");
    return JSON.parse(raw).sha || "";
  } catch {
    return "";
  }
}

const BUILD_SHA = loadBuildSha();

function loadHtmlPage() {
  try {
    const raw = readFileSync(HTML_PATH, "utf8");
    const shortSha = BUILD_SHA.slice(0, 7);
    const display = shortSha ? shortSha : "dev";
    return raw.replace("<!-- BUILD_SHA -->", display);
  } catch (error) {
    console.error("Failed to load index.html:", error);
    return "<html><body>app</body></html>";
  }
}

const HTML_PAGE = loadHtmlPage();
```

## Hidden SHA in page metadata

When the SHA should not be visible to end users — marketing pages,
customer-facing apps, regulated environments — embed it in metadata
rather than rendered text. It remains discoverable by developers via
View Source or DevTools without cluttering the UI.

### `<meta>` tag (preferred)

```html
<meta name="build-version" content="<!-- BUILD_SHA -->" />
```

Replace the placeholder the same way as the visible pattern; the value
just lives in a `content` attribute instead of a text node.

### `<link>` canonical-style annotation

```html
<link rel="version-history" href="https://github.com/org/repo/commit/<!-- BUILD_SHA -->" />
```

Makes the SHA a navigable link to the exact commit on the forge —
useful for internal tooling that scrapes deployed pages.

### HTTP response header (server-rendered apps)

Avoid putting the SHA in the HTML at all; emit it as a response header
instead:

```js
headers: {
  "x-build-sha": BUILD_SHA.slice(0, 7),
}
```

This keeps the page source clean and the SHA accessible via
`curl -I` or browser DevTools Network tab.

### When to prefer each approach

| Situation | Recommended approach |
| ----------- | --------------------- |
| Developer tooling / internal app | Visible footer (short SHA) |
| Customer-facing, brand-sensitive | `<meta name="build-version">` |
| API / JSON responses | `x-build-sha` response header |
| Auditing / compliance scraping | `<link rel="version-history">` with full SHA URL |
| CSP-strict environments | Response header (no inline content change) |

## Key decisions

- **Deploy-time generation** — no SHA is committed to the repo; it is
  produced fresh from `git rev-parse HEAD` during packaging.
- **Short SHA (7 chars)** — sufficient for human identification;
  full SHA stored in `version.json` for programmatic use.
- **`"dev"` fallback** — lets the app run locally without a
  `version.json` present.
- **Single replace** — `<!-- BUILD_SHA -->` appears once in the HTML,
  making the substitution unambiguous.

## Adapting to other frameworks

| Framework | Injection point |
| ----------- | ----------------- |
| Node.js (Lambda/server) | `readFileSync` at startup, `String.replace` |
| Static site (Vite/Next) | `VITE_COMMIT_SHA` env var set in CI, read via `import.meta.env` |
| Rails | `ENV["COMMIT_SHA"]` written by deploy hook, rendered in a partial |
| Ruby/Sinatra (Lambda) | `REVISION` file read at module load, rendered in ERB layout |
| Docker | `ARG COMMIT_SHA` → `ENV COMMIT_SHA` → read at runtime |

For static sites have the CI step write the SHA to an env var before
the build step runs, rather than a `version.json` file.

## Ruby/Sinatra pattern (from retirement)

Write a plain `REVISION` file (not JSON) at deploy time:

```bash
git rev-parse --short HEAD > REVISION
cp REVISION "$BUILD_DIR/REVISION"
```

Read it as a module constant at load time:

```ruby
REVISION = if File.exist?(File.expand_path("../REVISION", __dir__))
               File.read(File.expand_path("../REVISION", __dir__)).strip
             end
```

Render conditionally in the ERB layout:

```erb
<% if MyApp::REVISION %>
  <p style="text-align:center;color:#ccc;font-size:0.7rem;"><%= MyApp::REVISION %></p>
<% end %>
```

## Pitfall: Ruby `__dir__` path resolution

`__dir__` returns the directory of the **file**, not a subdirectory
named after the module. For `lib/myapp.rb`, `__dir__` is `lib/`, not
`lib/myapp/`. So `../REVISION` from `lib/` reaches the project root.
Using `../../REVISION` goes one level too high and silently fails —
`REVISION` will be `nil` with no error, because the `if File.exist?`
guard just returns false.

## Local dev server

Projects often have a separate local dev server (`serve.js`,
`rackup`, `shotgun`, etc.) that serves the same HTML as the
production handler but doesn't go through the Lambda/deploy path.
The `version.json` or `REVISION` file won't exist locally, so the
placeholder is never replaced — it renders as an invisible HTML
comment or is silently absent.

Fix: hardcode `"dev"` in the local server's HTML replacement.

**Node.js** (`serve.js`):

```js
let html = fs.readFileSync(htmlPath, "utf8");
html = html.replace("<!-- BUILD_SHA -->", "dev");
res.end(html);
```

**Ruby/Sinatra** (in the route or before filter):

```ruby
get "/" do
  html = File.read(File.join(settings.public_folder, "index.html"))
  html.sub("<!-- BUILD_SHA -->", "dev")
end
```

Or use the `REVISION` constant with a fallback:

```ruby
display = MyApp::REVISION || "dev"
html.sub("<!-- BUILD_SHA -->", display)
```

This way `"dev"` always appears in the footer during local
development, making it obvious the page is not a deployed build.

## Reference implementation

- `slacronym/deploy.sh` — SHA written to `version.json`
- `slacronym/public/index.html` — `<!-- BUILD_SHA -->` footer placeholder
- `slacronym/index.mjs` — `loadBuildSha()` and `loadHtmlPage()`
- `retirement/bin/deploy` — SHA written to `REVISION`
- `retirement/lib/retirement.rb` — `REVISION` constant loaded at module init
- `retirement/lib/retirement/views/layout.erb` — conditional footer render
- `CM02/.github/workflows/ci-cd.yml` — `version.json` generated at deploy time
- `CM02/index.js` — `loadBuildSha()` and `<!-- BUILD_SHA -->` replacement
- `CM02/serve.js` — hardcoded `"dev"` replacement for local server
- `CM02/public/index.html` — `<!-- BUILD_SHA -->` footer placeholder
