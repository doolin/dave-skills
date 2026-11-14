#!/usr/bin/env ruby
# frozen_string_literal: true

# pushed-watch-ci.rb -- UserPromptSubmit. A push from the terminal is
# reported to the session in words ("pushed", "I pushed."), and no tool
# call sees it, so the PostToolUse watch on `git push` never fires. When
# the prompt says "pushed", this adds context that has the agent start
# watch-ci on every repository whose commits were waiting, in the
# background, before anything else and without being asked.
#
# Registered once in ~/.claude/settings.json, so it applies in every
# repository. Reads the event on stdin; prints nothing for any other
# prompt. Unreadable input prints nothing. Always exits 0.

require "json"

WORD = /\bpushed\b/i

CONTEXT = <<~TEXT.tr("\n", " ").strip
  The prompt reports a push made from the terminal. Before anything
  else in the reply, and without asking, start
  ~/.claude/skills/watch-ci/watch-ci with run_in_background for each
  repository whose commits were waiting to push in this session: no
  argument for the current repository, `-C ~/src/<repo>` for another.
  If the session holds no record of which were waiting, watch the
  current repository. A repository with no .github/workflows has no run
  to watch, so say so in one line. Do not
  ask for a push, and do not say a watch will follow a push. When a
  watch finishes, read the run's conclusion; on a failure, pull the
  failed job's log and report what failed.
TEXT

def prompt_from(stdin)
  JSON.parse(stdin.read).fetch("prompt", "").to_s
rescue JSON::ParserError, TypeError
  ""
end

if prompt_from($stdin).match?(WORD)
  puts JSON.generate(
    "hookSpecificOutput" => { "hookEventName" => "UserPromptSubmit", "additionalContext" => CONTEXT }
  )
end
exit 0
