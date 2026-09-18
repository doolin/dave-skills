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
