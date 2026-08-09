---
name: session-telemetry
description: Append-only session event log for agent efficacy review — stamp session boundaries, commits, ticket transitions, blockers, and lapses to JSONL, then report hypotheses at a stopping rule. Use when an operator wants to know where session time goes, whether behavior changed after a model or client upgrade, or why the same rule keeps getting broken. Self-contained; shells `date` directly.
disable-model-invocation: false
allowed-tools: Bash(date *), Bash(claude --version), Bash(jq *), Read
---

# session-telemetry

Hypothesis-generation about session behavior. Not per-tool-call or
response-gap timing — that line is deliberate.

Status: proposal.

## Log

`.claude/telemetry/events.jsonl` — gitignored, append-only. Stamp with shell,
never Edit:

```bash
echo '{"ts":"...","local":"...","event":"...", ...}' >> .claude/telemetry/events.jsonl
```

## Schema

Envelope on every event; kinds add extras.

```json
{
  "ts":             "2026-07-16T00:35:54Z",
  "local":          "2026-07-15 17:35 PDT (Wed)",
  "event":          "<kind>",
  "model":          "claude-opus-4-8",
  "client_version": "2.1.210",
  "agent":          "Peter",
  "anchor":         "<repo or session>",
  "notes":          "<shape, not narrative>"
}
```

Sources: `date -u "+%Y-%m-%dT%H:%M:%SZ"`, `date "+%Y-%m-%d %H:%M %Z (%a)"`,
`claude --version` (or the `AI_AGENT` env var).

Record `client_version` from event one — you cannot backfill it, and without
it "did the client upgrade change anything?" is unanswerable. Never backfill
any field; a guessed value is worse than a null.

## Kinds

`session_start`, `session_end`, `compaction`, `commit_start`, `commit_done`,
`ticket_open`, `ticket_done`, `blocker`, `unblocker`, `lapse`,
`telemetry_report`.

### `lapse`

A rule the agent knew and broke.

```json
{
  "rule":          "commit-push-consent-gate-bypass",
  "gates":         ["commit", "push"],
  "vector":        "how the rule was defeated, mechanically",
  "caught_by":     "operator | self | ci | hook",
  "had_consent":   true,
  "recurrence_of": "event-140"
}
```

`vector`, not just `rule` — one rule recurs across different mechanisms, and
each needs its own fix. `caught_by` is the number to drive down.
`had_consent` separates a defeated gate (infrastructure bug) from a rogue
agent.

## Discipline

- One stamp per event; don't double-stamp a boundary.
- If unsure, skip. Missing data beats misleading data.
- Stamp when it happens. Stamping at session end undercounts, invisibly.
- Retroactive stamping is fine for `lapse`, not for timestamps.

## Reporting

Stopping rule: ~30 events or ~10 sessions. Propose hypotheses; don't try to
confirm them at this volume.

```bash
jq -r 'select(.event=="lapse") | "\(.local|split(" ")[0])  \(.model)  \(.client_version//"?")  \(.rule)  \(.caught_by)"' events.jsonl
jq -r 'select(.event=="lapse") | .rule' events.jsonl | sort | uniq -c | sort -rn
jq -r '.local//.ts | split(" ")[0] | split("T")[0]' events.jsonl | sort | uniq -c
```

## Open questions

- `caught_by: self` is unverifiable; an under-reporting agent produces a
  flattering, useless log.
- Stamping relies on the agent remembering, and it forgets exactly when the
  data matters. A `PostToolUse` hook on `git commit` would stamp
  `commit_done` reliably; boundaries and lapses resist that.
- Per-repo logs hide cross-repo patterns for the same agent.
- No rotation.
