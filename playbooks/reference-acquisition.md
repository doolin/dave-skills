# Reference acquisition (Straylight)

How a Straylight agent pulls references — prior reading the operator has
bookmarked, with AI summaries, tags, and cached page text — from dbb's
**Agent Reference API**. Use when a task (harness engineering, research,
design) would benefit from what the corpus already holds, instead of
re-deriving it.

Spec: `PRD-0003 §10.2` in the dbb repo. Epic `DBB-0459`; Phase 1
substrate `DBB-0460` (shipped); MCP adapter `DBB-0461` (deferred).

## Preconditions

- The dbb Rails server is running locally (`http://localhost:3000`).
  dbb is local-only and never deploys, so there is no remote host.
- `REFERENCE_API_TOKEN` is exported in the shell (global `~/.zshrc`
  export). The same value authenticates the server and every client
  agent. The API is **fail-closed**: no token, every call is `401`.

## Endpoints

Base: `http://localhost:3000/api/v1/references`

| Call | Returns |
| ---- | ------- |
| `GET /references` | search/list. Params: `q` (full-text), `tags` (comma-separated, **match-all/AND**), `domain`, `reading_state`, `limit` (default 25, max 100). |
| `GET /references/:id` | one reference's metadata + AI summary |
| `GET /references/:id/content` | the cached page body for `:id` |

## Making the call

Bash `curl` (most common):

```bash
curl -s -H "Authorization: Bearer $REFERENCE_API_TOKEN" \
  "http://localhost:3000/api/v1/references?tags=ml,perceptron"
```

`?tags=ml,perceptron` returns only references carrying **both** tags
(AND). Combine filters: `?q=margin&tags=ml&reading_state=read&limit=50`.

Fetch one reference and its cached text:

```bash
curl -s -H "Authorization: Bearer $REFERENCE_API_TOKEN" \
  http://localhost:3000/api/v1/references/42
curl -s -H "Authorization: Bearer $REFERENCE_API_TOKEN" \
  http://localhost:3000/api/v1/references/42/content
```

`WebFetch` against the same URLs works too if you prefer a tool call
over the shell.

## Response shape

```jsonc
// GET /references
{ "references": [ { "id", "url", "title", "summary", "tags": [],
                    "domain", "notes", "reading_state", "rating",
                    "created_at" } ],
  "pagination": { "page", "limit", "count", "pages", "next", "prev" } }

// GET /references/:id        -> { "reference": { ...same fields... } }
// GET /references/:id/content -> { "id", "url", "content": "<page body>" }
```

Errors share one envelope: `{ "error": { "code", "message" } }`.

- `401 unauthorized` — token missing/wrong, or server booted without it
  (restart the server from a shell that has `REFERENCE_API_TOKEN`).
- `404 not_found` — no reference with that id.
- `409 no_content` — reference exists but has no cached snapshot.

## Token setup

```bash
# generate once
openssl rand -hex 32
# export in ~/.zshrc (feeds server + all client agents)
export REFERENCE_API_TOKEN=<value>
```

`.env` does NOT work for this: dbb has no `dotenv-rails`, so the Rails
boot never reads `.env`. Use a real shell export.

## Future

`DBB-0461` wraps these endpoints in an MCP server, so agents call
`search_references` / `get_reference` / `get_cached_content` as native
tools with no curl or token handling. Until then, use curl/WebFetch as
above.
