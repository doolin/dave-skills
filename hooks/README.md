# Hooks

Claude Code lifecycle hooks shared across repos. A hook is a shell
script that reads its event payload on stdin (or ignores it), prints
to stdout, and exits. Hooks here are repo-agnostic: they take their
root from the git toplevel of the cwd and accept env overrides for
tests.

## Symlink contract

Unlike skills (which link per-directory into `~/.claude/skills/`) and
playbooks (one whole-directory symlink), hooks link **per file** into
the consuming repo's `.claude/hooks/`, because that directory also
holds the repo's own local hooks:

```bash
ln -s ~/src/dave-skills/hooks/session-resume.sh \
  ~/src/<repo>/.claude/hooks/session-resume.sh
```

The consuming repo registers the hook in `.claude/settings.json` by
its local path (`./.claude/hooks/session-resume.sh`) and commits the
symlink. Renaming a hook here breaks every link, so treat filenames as
public API.

## Catalog

- **session-resume.sh** — `SessionStart`. Prints one line per ticket in
  `.development/active/` (id, title, `updated`) and its `## Next`
  section; stewardship tickets appear only while they carry a
  `## Next`. The read half of the `pause-session` contract for
  full-form `.development` repos, where the ticket file is the pause
  and there is no `next.md`. Always exits 0.

- **tool-call-ledger.sh** — `PreToolUse`, matcher `Bash`, no `if`.
  Appends `{ts, cwd, session, command}` for every Bash tool call to
  `<repo>/.claude/tool-calls.jsonl`. Commands only. Read by the
  `tool-call-ledger` skill, which clusters the shapes and proposes an
  allowlist entry, an existing skill, or a new tool. Always exits 0.

- **bash-policy.sh** — `PreToolUse`, matcher `Bash`, no `if`. Register it
  after `tool-call-ledger.sh` and before any consent gate. Reads
  `.tool_input.command` and prints a `deny`, an `ask`, or nothing, per the
  policy: the consuming repo's `.claude/bash-policy.rb` when it has one,
  otherwise `bash-policy/policy.rb` here. The engine (`bash-policy.rb`,
  stdlib Ruby) is only the mechanism; the rules read as English
  (`refuse`, `ask_when`, `allow_when`, `guard`), the same shape as
  `skills/tool-call-ledger/policy.rb`. Quoted spans are stripped before
  matching, so a commit message that mentions a refused command does not
  trip its rule. Refuse beats ask; a `CLAUDE_POLICY_OVERRIDE=1` prefix
  turns a refusal into an ask that names the rule, never into a silent
  allow. Rules that need a check rather than a match name a script in
  `bash-policy/guards/` (exit 0 allow, 1 refuse, 2 ask). Every deny and
  ask appends `{ts, session, decision, rule, command}` to
  `<repo>/.claude/policy-decisions.jsonl`. Missing `jq` or `ruby`,
  unreadable stdin, or a broken policy: one line to stderr and no
  decision. Always exits 0.

## Tests

```bash
bats hooks/test/
shellcheck hooks/*.sh hooks/bash-policy/guards/*.sh test/test_helper.bash
```

Fixtures come from the repo-level `test/test_helper.bash`, shared with
skill test suites.
