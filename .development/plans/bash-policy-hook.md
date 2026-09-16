# Bash policy hook

A PreToolUse hook on Bash that refuses or forces a prompt on command
shapes the operator has ruled out, with the rules in a policy file
written in the same small DSL as `skills/tool-call-ledger/policy.rb`.
Planned 2026-09-16 from the dbb MEMORY.md audit (item 1); the memory
entries it replaces are listed at the end and are deleted only when the
hook is live in dbb.

## Why

Six rules live in the dbb agent's memory as "never do X" or "not without
asking": no `git commit -F`, no `gh pr`, no python heredocs or one-liners,
no `perl -i` / `sed -i` on ticket files, no `--amend` without a fetch, no
database write without per-action approval. Each is enforced by the agent
remembering it. The telemetry log records the rule loaded and broken
anyway, caught by the operator, seven times out of ten. Memory is the
wrong home for a check a machine can make before the command runs.

The hook is syntactic. It reads one string. It stops a lapse; it does not
stop a rephrased command, and it cannot see inside a script that shells
out. The operator's framing (2026-09-16): trust is the primary
consideration and the boundary is mechanical where it can be. This hook
is the mechanical part for the shell layer. The layer below it, for the
database, is dbb DBB-0547.

## Shape

Two files in `hooks/`, one registered:

- `hooks/bash-policy.sh` — the registered hook. Reads the PreToolUse JSON
  on stdin, extracts `.tool_input.command`, and hands it to the engine.
  Registered in the consuming repo with matcher `Bash` and no `if`, after
  `tool-call-ledger.sh` and before any consent gate. Symlinked per file
  per the hooks README.
- `hooks/bash-policy.rb` — the engine. Loads a policy, evaluates the
  command, prints one decision or nothing. Ruby, stdlib only. Knows
  nothing about git, rails, python or sqlite except what the policy says.
- `hooks/bash-policy/policy.rb` — the default policy, below.
- `hooks/bash-policy/guards/` — shell checks a policy line can name,
  for the rules that need more than a match (below).

### Decisions

The engine prints one of three things:

| Policy verb | Hook output | What the agent sees |
| --- | --- | --- |
| `refuse` / `refuse_when` | `permissionDecision: deny` with the `because:` text | the command does not run; the reason names the alternative |
| `ask_for` / `ask_when` | `permissionDecision: ask` with the `because:` text | the operator is prompted even if the command is allowlisted |
| no match, or `allow_when` | nothing, exit 0 | the normal permission flow |

`allow_when` is an exception carved out of a broader `ask_when`, tested
first. A refuse always beats an ask; the most specific match does not
win, the most restrictive does.

### The command is read with quoted spans removed

Same lesson as dbb's `consent-gate.sh`: a `git commit -m "... sed -i ..."`
must not trip the `sed -i` rule on its message. Strip `'...'` and
`"..."` before matching. Stripping only narrows what is caught, so its
failure mode is a missed match, never a false refusal.

### Override goes through ask, never through allow

An operator-typed override is the operator's decision. An agent-typed one
is not. So a `CLAUDE_POLICY_OVERRIDE=1` prefix on a refused command
downgrades the refusal to an **ask** whose reason says an override was
requested and names the rule. The operator sees it and decides. There is
no path from refuse to silent allow.

### Guards

Two of the six rules are checks, not matches:

- `--amend` is safe when HEAD is not on the remote. The guard
  `guards/amend-unpushed.sh` runs `git fetch origin main -q` then
  `git merge-base --is-ancestor HEAD origin/main`; ancestor means pushed,
  and the guard says refuse. It costs a network round trip, once per
  amend, which is cheaper than the force-push conversation it prevents.
- Rails database subcommands split into reads and writes by name, which
  is a match, not a guard. Listed under the policy.

A guard is a shell script that exits 0 (allow), 1 (refuse) or 2 (ask) and
prints its reason on stdout. The policy names it with `guard`. Guards are
the only extension point; the engine grows no new verbs for them.

### Decision log

Every refuse and ask appends one line to `<repo>/.claude/policy-decisions.jsonl`:
`{ts, session, decision, rule, command}`. The ledger already has every
command; this file has the ones the policy touched, so the dbb telemetry
report and the ledger skill can both read it. Allowed commands are not
logged here.

### Fail open, loudly

No `jq`, no `ruby`, unparseable stdin: the hook prints one line to stderr
and exits 0. A deny hook that failed closed would block every Bash call
on a machine missing a dependency, which is a worse failure than a
missed refusal the ledger still records. The stderr line is the tell.

## The default policy

```ruby
# frozen_string_literal: true

# Which shell commands an agent may not run, or may run only after the
# operator says so this time. Read by hooks/bash-policy.rb. Edit this
# file, not the engine. A consuming repo overrides it with its own
# .claude/bash-policy.rb, which is loaded instead of this one when present.

# ── Refused: the alternative is always a tool that already exists. ────

refuse 'git commit -F', 'git commit --file',
       because: 'commit messages are inline with -m; a message file hides the text from the commit-message hook'
refuse_when(/\bpython3? (-c|<<|-\s*$)/,
            because: 'no python one-liners or heredocs; use the file tools, jq, or a Ruby script under scripts/')
refuse_when(/\b(perl|ruby) -[a-z]*e\b/,
            because: 'no one-liner interpreters; the change belongs in a file or in Edit')
refuse_when(/\bcat\s*>>?\s*\S+\s*<</,
            because: 'writing a file through a heredoc is opaque to the permission system; use Write')

# ── Asked: the operator decides this one, every time. ─────────────────

ask_when(%r{\b(bin/rails|rake) db:},
         because: 'this changes the development database schema or data; per-action approval')
allow_when(%r{\b(bin/rails|rake) db:(version|schema:dump|test:prepare)\b})
ask_when(%r{\bbin/rails (runner|dbconsole|console)\b},
         because: 'a runner string can write to the development database and the hook cannot read Ruby')
ask_when(/\bsqlite3 \S+\.sqlite3\b/,
         because: 'direct SQL against a database file; per-action approval')
ask_when(/\bCLAUDE_POLICY_OVERRIDE=1\b/,
         because: 'an override was requested; the rule it overrides is named below')
ask_when(/\bDBB_DB_WRITABLE=1\b/,
         because: 'the read-only development connection is being opened for writing (DBB-0547)')

# ── Guarded: a check runs before the answer. ──────────────────────────

guard 'git commit --amend', with: 'amend-unpushed',
      because: 'HEAD is already on origin/main; amending it forces a force-push'
```

dbb's own `.claude/bash-policy.rb` adds the repo-specific lines and is
committed there:

```ruby
load_default_policy

refuse 'gh pr', because: 'no pull requests in dbb; commits land on main behind the consent gate'
refuse_when(%r{\b(perl|sed) -i\b.*\.development/},
            because: 'ticket close-outs use Edit and scripts/close-tickets, never an in-place edit')
```

## Tests

`hooks/test/bash-policy.bats`, fixtures from `test/test_helper.bash`.
Each test pipes a PreToolUse JSON payload on stdin with `REPO_ROOT`
pointed at scratch, and asserts on stdout and the decision log. At
minimum:

- each refuse line in the default policy: deny, reason text present
- each ask line: ask, reason text present
- `allow_when` beats `ask_when` for `db:version`; `ask_when` still fires
  for `db:migrate`
- the quoted-span rule: `git commit -m "run sed -i on it"` is not refused
- `CLAUDE_POLICY_OVERRIDE=1 git commit -F msg`: ask, reason names the
  overridden rule; never deny, never silent
- guard: with a scratch remote where HEAD is pushed, amend is refused;
  where HEAD is ahead, amend passes; the fetch is against the scratch
  remote, never the network (set `origin` to a local bare repo)
- repo policy present: `load_default_policy` plus the repo lines both
  apply; repo policy absent: default applies
- unknown verb in a policy: exit 12 naming the file, and the hook
  prints its stderr line and exits 0 (fail open)
- missing `jq` (PATH without it): stderr line, exit 0, no decision
- decision log: one line per refuse and ask, none for allow
- `shellcheck hooks/bash-policy.sh hooks/bash-policy/guards/*.sh` clean

## Landing in dbb

1. Symlink `hooks/bash-policy.sh` to `~/src/dbb/.claude/hooks/`.
2. Add the PreToolUse entry (matcher `Bash`, no `if`) directly after the
   ledger entry in `.claude/settings.json`.
3. Commit `.claude/bash-policy.rb` with the two repo lines.
4. Add `.claude/policy-decisions.jsonl` to `.gitignore` beside the ledger.
5. Run `scripts/gate`; run one refused command on purpose and confirm the
   deny text appears in the session and the log has the line.
6. Then, and only then, delete these memory files from
   `~/.claude/projects/-Users-daviddoolin-src-dbb/memory/` and their
   `MEMORY.md` index lines:
   - `feedback_commit_message_inline_never_file` (the `Claude-Session:`
     half is already blocked by `commit-message-precommit.sh`)
   - `project_dbb_no_pr_workflow`
   - `feedback_dedicated_tools_over_python`
   - `feedback_closeout_no_perl_oneliner`
   - `feedback_pre_amend_fetch`
   - `project_bash_heredoc_policy_open`
   - `feedback_operator_owns_data_semantics`: delete the **HARD GATE**
     section only; the data-semantics half (operator owns the meaning of
     the data; fix bad rows at the source) stays
7. Update `hooks/README.md` catalog; update the tooling-catalog playbook
   with one line; commit in dave-skills under the hooks convention.

## What this does not do

It does not stop a determined rephrasing, a script that shells out, or a
write hidden inside Ruby. Those are the connection layer (DBB-0547) and
the git layer (DBB-0494). The three together are the trust boundary as
currently understood: the shell layer stops the agent early with a reason
it can act on; the lower layers stop what the shell layer cannot see.

## Model class

Sonnet or Opus executes from this plan. The engine is a page of Ruby
under the ledger's conventions; the guard is ten lines of shell; the
tests are the bulk of the work.
