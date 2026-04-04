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
|-----------|---------------------|
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
|-----------|-----------------|
| Node.js (Lambda/server) | `readFileSync` at startup, `String.replace` |
| Static site (Vite/Next) | `VITE_COMMIT_SHA` env var set in CI, read via `import.meta.env` |
| Rails | `ENV["COMMIT_SHA"]` written by deploy hook, rendered in a partial |
| Docker | `ARG COMMIT_SHA` → `ENV COMMIT_SHA` → read at runtime |

For static sites have the CI step write the SHA to an env var before
the build step runs, rather than a `version.json` file.

## Reference implementation

- `slacronym/deploy.sh` — SHA written to `version.json`
- `slacronym/public/index.html` — `<!-- BUILD_SHA -->` footer placeholder
- `slacronym/index.mjs` — `loadBuildSha()` and `loadHtmlPage()`
