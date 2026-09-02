---
name: tool-call-ledger
description: Turn permission prompts into a queue of tools. Reads the per-repo ledger of Bash tool calls written by hooks/tool-call-ledger.sh (or Bash calls straight from Claude Code transcripts with --transcripts), clusters commands by shape, and for each recurring shape proposes one of - an allowlist entry, an existing skill, a new tool, or keep prompting. Run it when prompts have been piling up, at a session close, or as the dry run before building a tool by hand.
allowed-tools: Bash(~/.claude/skills/tool-call-ledger/tool-call-ledger.rb*)
---

# tool-call-ledger

A permission prompt on a routine command means the shape should have
been a tool. The prompt used to be consumed by the operator and lost.
This reads the record instead.

## Two halves

**The hook** (`hooks/tool-call-ledger.sh`, PreToolUse on Bash) appends
`{ts, cwd, session, command}` to `<repo>/.claude/tool-calls.jsonl`.
Commands only. Always exits 0. Symlinked per repo, registered with
matcher `Bash` and no `if`.

**The skill** (this script) clusters that ledger and proposes.

## Run

```bash
~/.claude/skills/tool-call-ledger/tool-call-ledger.rb                   # this repo's ledger, shapes seen 3+ times
~/.claude/skills/tool-call-ledger/tool-call-ledger.rb --min 5
~/.claude/skills/tool-call-ledger/tool-call-ledger.rb --all             # every shape
~/.claude/skills/tool-call-ledger/tool-call-ledger.rb --transcripts ~/.claude/projects/<slug>   # dry run over history
~/.claude/skills/tool-call-ledger/tool-call-ledger.rb --transcripts ... --no-hints             # as if today's tools did not exist
```

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
| **new tool** | a pipe, chain, or redirect that recurs | write the tool (dave-skills if generic, `scripts/` if repo-bound) |
| **keep prompting** | the verb changes state, or a rule would be a blanket `git *` | nothing; the prompt is the point |

A pipeline is allowed only when every segment matches a rule, which is
how Claude Code judges it; `rubocop 2>&1 | tail -2` prompts on the
`tail` half, and the report says so.

The skill proposes. Nothing is granted by running it.

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

That built-in skill scans transcripts and proposes allowlist entries
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
| 11   | no ledger, no transcripts directory, or no Bash records in them |

## Tests

```bash
bats skills/tool-call-ledger/test/
```
