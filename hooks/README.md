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

## Tests

```bash
bats hooks/test/
shellcheck hooks/*.sh test/test_helper.bash
```

Fixtures come from the repo-level `test/test_helper.bash`, shared with
skill test suites.
