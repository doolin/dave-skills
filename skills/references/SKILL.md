---
name: references
description: Query dbb's Agent Reference API — the operator's bookmarked reading, with AI summaries, tags, and cached page text — by full-text search, tags, domain, or reading state, or fetch one reference or its cached page. Use it to check the corpus before fresh web research, and always in place of curl against the API, in the main session and in every subagent brief.
disable-model-invocation: false
allowed-tools: Bash(~/.claude/skills/references/references *), Bash(/Users/daviddoolin/.claude/skills/references/references *)
---

# References

Query the operator's reference corpus in dbb (PRD-0003 §10.2 there) with
one named command.

```bash
~/.claude/skills/references/references search 'margin classifier' --tags ml,perceptron
~/.claude/skills/references/references search --domain arxiv.org --state read --limit 50
~/.claude/skills/references/references show 42
~/.claude/skills/references/references content 42
```

`search` takes at most one query (quote a phrase) and any of `--tags`
(comma-separated, all must match), `--domain`, `--state` (the reading
state) and `--limit` (default 25, max 100). `show` returns one reference
with its AI summary; `content` returns its cached page text.

The response prints as JSON on stdout. Response shapes and error codes
are in `~/.claude/playbooks/reference-acquisition.md`.

## Preconditions

- The dbb server is running at `http://localhost:3000` (override with
  `REFERENCE_API_URL`).
- `REFERENCE_API_TOKEN` is exported in the shell. The API is fail-closed:
  without the token, every call is refused. The tool never prints the
  token.

## Exit codes

| Code | Meaning |
|------|---------|
| 0    | the API answered; JSON on stdout |
| 1    | the API answered with an error (401, 404, 409, ...), named on stderr |
| 7    | the server is unreachable |
| 10   | bad arguments, or `REFERENCE_API_URL` is not a URL |
| 11   | `REFERENCE_API_TOKEN` is not set |

## Why this is a tool, not curl

A curl call carries its URL, so every call is a new shape that no
allowlist prefix matches. Ten research subagents each curling the API
produced a stream of permission prompts too fast to stop. This command
is the same shape every time, so it allowlists once. WebFetch cannot
send the API's bearer token. The Bash policy hook
(`hooks/bash-policy/policy.rb`) now refuses curl from agents and names
this tool.

## Why this is global

Lives in the shared `dave-skills` collection and is symlinked into
`~/.claude/skills/`, so every Straylight agent has it in every repo.
Pure Ruby stdlib (`net/http`, `json`, `optparse`): no gems, no per-repo
setup.

## Tests

```bash
bats skills/references/test/
```

The suite runs against a stub of the API (`test/stub_api.rb`) on a free
local port; nothing touches the network or a running dbb server.
