# frozen_string_literal: true

# The ledger's judgment, written to be read by the operator, the agent,
# and whoever inherits both. Edit this file, not the engine. Each line is
# one rule in one of six verbs; the engine (tool-call-ledger.rb) knows
# nothing about git or rspec except what is written here.
#
# Point the tool at another policy with --policy PATH.

# ── Verbs that change state. A prompt on these is the point. ──────────

keep_prompting_for 'git commit', 'git push', 'git reset', 'git rebase', 'git checkout',
                   'git restore', 'git clean', 'git merge', 'git am', 'git cherry-pick', 'git stash'
keep_prompting_for 'rm', 'sudo', 'chmod', 'chown', 'mv', 'cp', 'ln'
keep_prompting_for 'gh pr', 'gh repo'
keep_prompting_when(/\Acurl .*-X (POST|PUT|DELETE)/, because: 'it sends')

# ── Commands that are only half a verb until the next word. ───────────
#    "git" is not a verb; "git diff" is. A rule proposed for a bare
#    multiplexer would be the blanket grant, so those are never proposed.

subcommand_after 'git', 'npx', 'npm', 'rake', 'brew', 'docker', 'bin/rails', 'scripts/tickets'
subcommand_after 'gh', 'bundle', words: 2

# ── Flags that swallow the next word (so it is not mistaken for the verb). ──

value_follows 'git', '-C', '-c'
value_follows 'jq', '--arg', '--argjson', '-f'
value_follows 'find', '-name', '-path', '-maxdepth', '-type', '-perm'
value_follows 'grep', '-e', '-f', '-A', '-B', '-C'
value_follows 'sed', '-e', '-f'
value_follows 'awk', '-F', '-v'

# ── Paths that stay legible in a shape instead of collapsing to a basename. ──

keep_paths_starting_with '~/.claude/skills/', 'scripts/', 'bin/', '~/src/', './'

# ── Shapes a tool already answers. Reach for the tool next time. ──────
#    Matched against the shape and against the verbatim examples.

reach_for 'git-orient',    when_it_looks_like: /\Agit (rev-parse|status|log|branch)\b/
reach_for 'index-audit',   when_it_looks_like: /\Agit diff --cached\b|\Agit status --short\b/
reach_for 'rspec-summary', when_it_looks_like: /\Agrep .*(examples,|coverage|rspec).*\.log\b/i
reach_for 'watch-ci',      when_it_looks_like: /\Agh run (watch|list|view)\b/
reach_for 'the Read tool', when_it_looks_like: /\A(sed -n|head|tail|cat) /
reach_for 'gate',          when_it_looks_like: %r{\A(bundle exec |bin/)(rspec|rubocop|brakeman|bundle-audit)\b}
reach_for 'gate',          when_it_looks_like: /\Anpx (vitest|markdownlint-cli2)\b/
reach_for 'gate',          when_it_looks_like: %r{\A(bats scripts/test|shellcheck scripts)}

# ── Reporting defaults. Command-line flags override. ──────────────────

report_shapes_seen_at_least 3
show_examples 3
