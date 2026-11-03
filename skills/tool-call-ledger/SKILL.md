---
name: tool-call-ledger
description: Turn permission prompts into a queue of tools. Reads the per-repo ledger of Bash tool calls written by hooks/tool-call-ledger.sh (or shell calls straight from Claude Code or Codex transcripts with --transcripts), clusters commands by shape, and for each recurring shape proposes one of - an allowlist entry (for Codex, a rule to review), an existing skill, a new tool, or keep prompting. Run it when asked to track tool calls, when prompts have been piling up, at a session close, or as the dry run before building a tool by hand.
allowed-tools: Bash(~/.claude/skills/tool-call-ledger/tool-call-ledger.rb*)
---

# tool-call-ledger

A permission prompt on a routine command means the shape should have
been a tool. The prompt used to be consumed by the operator and lost.
This reads the record instead.

## Capture and report

**Claude Code hook:** `hooks/tool-call-ledger.sh`, PreToolUse on Bash, appends
`{ts, cwd, session, command}` to `<repo>/.claude/tool-calls.jsonl`.
Commands only. Always exits 0. Symlinked per repo, registered with
matcher `Bash` and no `if`.

**Native transcripts:** both clients already record calls. Pass the
active session's JSONL file with `--transcripts`; a directory reads
the `*.jsonl` directly in it, and `--recursive` adds its subdirectories
(Codex keeps rollouts under `sessions/YYYY/MM/DD/`). Prefer the known active file for a
session question rather than scanning unrelated history. Re-read it at
checkpoints to include new calls. Reading a transcript does not install
a hook or start background monitoring.

- Claude: reads `assistant` → `tool_use` → `Bash` command inputs.
- Codex: reads completed `CommandExecution` items, including commands
  invoked inside `functions.exec`. Deduplicates item IDs and reports
  failures too. Without completion items, reads direct `exec_command`,
  `shell_command`, and `shell` requests, labelled completion unknown.
- Codex request totals include orchestration and polling calls. They
  are separate from the shell-command count, not added to it. Embedded
  JavaScript is never evaluated; missing completion records are reported
  as incomplete rather than guessed from source code. Neither client's
  outputs, patches, nor conversation text become ledger commands.

The Codex record shapes were verified locally with CLI 0.166.0 on
2026-11-02. Unknown record kinds are ignored; do not claim a complete
count for a format the reader does not recognize. This is a command
pattern report, not a duration, cost, or complete all-tool audit.

The shared source is `dave-skills/skills/tool-call-ledger/`. Link each
client's skill directory to that source; do not maintain client copies.

## Run

```bash
~/.claude/skills/tool-call-ledger/tool-call-ledger.rb                   # this repo's ledger, shapes seen 3+ times
~/.claude/skills/tool-call-ledger/tool-call-ledger.rb --min 5
~/.claude/skills/tool-call-ledger/tool-call-ledger.rb --all             # every shape
~/.claude/skills/tool-call-ledger/tool-call-ledger.rb --transcripts ~/.claude/projects/<slug>   # dry run over history
~/.claude/skills/tool-call-ledger/tool-call-ledger.rb --transcripts ... --no-hints             # as if today's tools did not exist
~/.codex/skills/tool-call-ledger/tool-call-ledger.rb --transcripts /path/to/rollout.jsonl
~/.codex/skills/tool-call-ledger/tool-call-ledger.rb --transcripts /path/to/rollout.jsonl --no-hints
~/.codex/skills/tool-call-ledger/tool-call-ledger.rb --transcripts ~/.codex/sessions --recursive
```

In Codex, use `--transcripts` with the current rollout. The no-argument
default reads Claude's hook ledger; it is not evidence that Codex calls
are being captured there. A report over the active transcript stays
local. Never commit or publish transcripts or command logs.

Output, one block per cluster:

```text
   9×  git log <arg> --format=<v>
       first 2026-09-02 10:12  last 2026-09-02 18:40  sessions 1
       e.g. git log -1 --format='%ci %s' HEAD
            git log -3 --format='%h %ad %s' --date=short -- .development/active/
       → allowed: Bash(git log:*)

   4×  grep -E <args> | awk -F <v> <arg> | sort | uniq -c
       first 2026-09-02 10:31  last 2026-09-02 15:02  sessions 1
       e.g. grep -E '^rspec \./spec' log | awk -F'[/:]' '{print $3}' | sort | uniq -c
       → use instead: rspec-summary
```

## The outcomes

| Outcome | Meaning | What to do |
|---|---|---|
| **allowed** | every segment matches a current allow rule | nothing; the prompt you remember predates the rule |
| **covered** | a skill's own grant matches the command | nothing; it is already a tool |
| **use instead** | a hint says a skill or a file tool answers this shape | use that next time |
| **allowlist** | one read-only verb, no pipeline | add the printed `Bash(...)` line to settings |
| **review rule** | a Codex command has a simple recurring shape | review its prefix against Codex rules and sandbox permissions; this tool does not inspect those grants |
| **new tool** | a pipe, chain, or redirect that recurs | write the tool (dave-skills if generic, `scripts/` if repo-bound) |
| **keep prompting** | the verb changes state, or a rule would be a blanket `git *` | nothing; the prompt is the point |

A pipeline is allowed only when every segment matches a rule, which is
how Claude Code judges it; `rubocop 2>&1 | tail -2` prompts on the
`tail` half, and the report says so.

The skill proposes. Nothing is granted by running it. Claude's
`Bash(...)` grants and `allowed-tools` fields do not grant Codex
permissions. Mixed-client clusters do not inherit Claude grants, so a
state-changing Codex command reports keep prompting even where a
Claude grant would match it. A Claude cluster is judged exactly as
before Codex support: an existing grant reports allowed.

## Adding a client

Hermes, OpenCode, pi, or any other agent: extending this skill is
welcome. Add a reader for your transcript format, tag your records
with your own `client` value, and gate any client-specific judgment
on that tag, the way `grants` skips Claude grants for Codex clusters.

Do not change existing behavior for another client. On the same input,
Claude Code and Codex must get the same report they got before your
change: same records, same order of decisions in `decide`, same
outcomes. The bats suites in `test/` pin that; if an existing test
has to change for your client to work, the change belongs behind your
client's tag instead.

## The policy file

The judgment lives in `policy.rb` beside the script, not in the engine.
It is written in six verbs, each line one rule, meant to be read by the
operator and the agent the same way:

```ruby
keep_prompting_for 'git commit', 'git push', 'rm', 'sudo'
keep_prompting_when(/\Acurl .*-X (POST|PUT|DELETE)/, because: 'it sends')

subcommand_after 'git', 'npx', 'npm'           # "git" is half a verb; "git diff" is a verb
subcommand_after 'gh', 'bundle', words: 2      # "gh run watch", "bundle exec rspec"
value_follows 'git', '-C', '-c'                # the next word is a value, not the verb
keep_paths_starting_with 'scripts/', '~/src/'  # stay legible in a shape

reach_for 'index-audit', when_it_looks_like: /\Agit diff --cached\b/
reach_for 'the Read tool', when_it_looks_like: /\A(sed -n|head|tail|cat) /

report_shapes_seen_at_least 3
show_examples 3
```

Add a `reach_for` line when a tool lands; add a `keep_prompting_for`
line when a verb turns out to change state. `--policy PATH` points the
tool at another file, so a repo can carry its own. A line the DSL does
not understand stops the run with exit 12 and the file name.

## How shapes are made

Deliberately crude, on purpose: argv[0], a subcommand for the few
multiplexers (git, gh, bundle, npx, npm, bin/rails), flags kept with
their values abstracted, every positional argument folded to `<arg>`
or `<args>`, absolute paths reduced to their basename. Pipes, chains,
and redirects stay in the shape because they are what makes a command
a tool candidate. If the crude shape is wrong for a case, the three
verbatim examples under it show why.

## Relation to `/fewer-permission-prompts`

That Claude Code skill scans transcripts and proposes allowlist entries
only; it cannot say "this is a tool you should build" or "you already
have one." This skill keeps its guardrail (state-changing verbs are
never proposed for allowlisting) and adds the other two outcomes. The
transcript reader here exists so the two can be compared on the same
input.

## Exit codes

| Code | Meaning |
|------|---------|
| 0    | report printed |
| 10   | bad arguments |
| 11   | no ledger, no transcript path, or no shell command records |

## Tests

```bash
bats skills/tool-call-ledger/test/
```
