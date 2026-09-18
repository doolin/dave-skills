#!/usr/bin/env ruby
# frozen_string_literal: true

# bash-policy.rb — decide what a Bash command is allowed to be.
#
# Reads one command string (ARGV[0]) and prints one PreToolUse decision on
# stdout: a deny, an ask, or nothing at all. The judgment is not here. It
# lives in a policy file written in a small DSL (see Rules for the seven
# verbs): the consuming repo's .claude/bash-policy.rb when there is one,
# otherwise bash-policy/policy.rb beside this file. The engine knows
# nothing about git, rails, python or sqlite except what the policy says.
#
# Ordering is fixed and is not the file's: refuse first, then guards, then
# allow_when, then ask. The most restrictive match wins, not the most
# specific. A CLAUDE_POLICY_OVERRIDE=1 prefix on a refused command turns
# the refusal into an ask that names the rule — an operator-typed override
# is the operator's decision, so it goes to the operator, never to a
# silent allow.
#
# The command is matched with quoted spans removed, so a commit message
# that mentions a refused command does not trip its rule. Stripping can
# only narrow what is caught: the failure mode is a missed match, never a
# false refusal.
#
# Every deny and ask appends one line to the decision log. Allowed
# commands are not logged here; the tool-call ledger already has them.
#
# Usage: bash-policy.rb COMMAND [POLICY]
#
# Exit codes: 0 decided (printed or not) · 12 policy unreadable
#
# Env:
#   REPO_ROOT                default: git toplevel of the cwd, else the cwd
#   CLAUDE_POLICY_FILE       default: $REPO_ROOT/.claude/bash-policy.rb, else the bundled policy
#   CLAUDE_POLICY_LOG        default: $REPO_ROOT/.claude/policy-decisions.jsonl
#   CLAUDE_POLICY_GUARD_DIR  default: bash-policy/guards beside this file
#   CLAUDE_POLICY_SESSION    session id recorded in the log (the hook passes it)

require 'json'
require 'fileutils'

module BashPolicy
  DEFAULT_POLICY = File.join(__dir__, 'bash-policy', 'policy.rb')
  OVERRIDE = /\bCLAUDE_POLICY_OVERRIDE=1\b/

  # A command starts at the start of the string or after a separator, and
  # may carry leading VAR=value assignments — the override prefix is one,
  # so a refused command still matches while wearing it.
  COMMAND_START = /(?:\A|[;&|\n])[[:blank:]]*(?:[A-Za-z_][A-Za-z0-9_]*=\S*[[:blank:]]+)*/

  Rule = Struct.new(:kind, :name, :pattern, :because, :guard)
  Decision = Struct.new(:decision, :rule, :reason)

  # The policy DSL. A policy file is instance_eval'd here, so each line of
  # it is one call to one of these verbs. Keep it small: a DSL that grows
  # past a handful of verbs has become a second engine. Guards are the
  # extension point, and they add no verbs.
  class Rules
    attr_reader :rules

    def initialize
      @rules = []
    end

    def self.load(path)
      rules = new
      rules.instance_eval(File.read(path), path)
      rules
    rescue ScriptError, StandardError => e
      warn "bash-policy: cannot read policy #{path}: #{e.message}"
      exit 12
    end

    # A literal prefix, matched at a command boundary: 'git commit -F'
    # catches `git commit -F msg` and `... && git commit -F msg`.
    def self.prefix(text)
      words = text.split.map { |w| Regexp.escape(w) }.join('[[:blank:]]+')
      /#{COMMAND_START}#{words}(?:[[:blank:]]|[;&|]|\z)/
    end

    # refuse 'git commit -F', 'git commit --file', because: '...'
    def refuse(*prefixes, because:)
      add(:refuse, prefixes, because)
    end

    # refuse_when(/\bpython3? -c/, because: '...')
    def refuse_when(pattern, because:)
      @rules << Rule.new(:refuse, pattern.source, pattern, because, nil)
    end

    # ask_for 'bin/rails db:drop', because: '...'
    def ask_for(*prefixes, because:)
      add(:ask, prefixes, because)
    end

    # ask_when(%r{\bbin/rails db:}, because: '...')
    def ask_when(pattern, because:)
      @rules << Rule.new(:ask, pattern.source, pattern, because, nil)
    end

    # An exception carved out of a broader ask_when, tested before it.
    def allow_when(pattern)
      @rules << Rule.new(:allow, pattern.source, pattern, nil, nil)
    end

    # guard 'git commit --amend', with: 'amend-unpushed', because: '...'
    # The named script exits 0 (allow), 1 (refuse) or 2 (ask) and prints
    # its reason; `because:` is the fallback when it prints nothing.
    def guard(*prefixes, with:, because:)
      prefixes.flatten.each { |p| @rules << Rule.new(:guard, p, Rules.prefix(p), because, with) }
    end

    # A repo policy calls this to layer its own lines on top of the default.
    def load_default_policy
      instance_eval(File.read(DEFAULT_POLICY), DEFAULT_POLICY)
    end

    private

    def add(kind, prefixes, because)
      prefixes.flatten.each { |p| @rules << Rule.new(kind, p, Rules.prefix(p), because, nil) }
    end
  end

  # Applies the rules to one command in the fixed order.
  class Engine
    GUARD_CODES = { 1 => :refuse, 2 => :ask }.freeze

    def initialize(rules)
      @rules = rules
    end

    def self.strip_quoted(command)
      command.gsub(/'[^']*'/, '').gsub(/"[^"]*"/, '')
    end

    def decide(command)
      bare = Engine.strip_quoted(command)
      override = OVERRIDE.match?(bare)

      refused = match(:refuse, bare)
      return refusal(refused.name, refused.because, override) if refused

      guarded = guard_decision(bare, override)
      return guarded if guarded
      return nil if match(:allow, bare)

      asked = match(:ask, bare)
      asked && ask(asked.name, asked.because)
    end

    private

    def match(kind, bare)
      @rules.rules.find { |r| r.kind == kind && r.pattern.match?(bare) }
    end

    def refusal(name, because, override)
      return Decision.new('deny', name, "bash-policy refuses this: #{because} [rule: #{name}]") unless override

      Decision.new('ask', name,
                   "bash-policy: an override was requested for a refused command [rule: #{name}]: " \
                   "#{because}. Approve it only to set that rule aside this once.")
    end

    def ask(name, because)
      Decision.new('ask', name, "bash-policy asks first: #{because} [rule: #{name}]")
    end

    def guard_decision(bare, override)
      rule = match(:guard, bare)
      return nil unless rule

      out, code = run_guard(rule)
      verdict = GUARD_CODES[code]
      return nil unless verdict

      reason = out.empty? ? rule.because : out
      return refusal(rule.name, reason, override) if verdict == :refuse

      ask(rule.name, reason)
    end

    # Guards run under bash, so a lost executable bit never silences one.
    # A guard that cannot run leaves the rule unchecked: fail open, loudly.
    def run_guard(rule)
      path = File.join(Main.guard_dir, "#{rule.guard}.sh")
      unless File.exist?(path)
        warn "bash-policy: no guard at #{path}; '#{rule.name}' went unchecked"
        return ['', nil]
      end

      out = IO.popen(['bash', path], err: File::NULL, &:read).to_s.strip
      code = $?&.exitstatus
      warn "bash-policy: guard #{rule.guard} exited #{code}; '#{rule.name}' went unchecked" unless
        [0, 1, 2].include?(code)
      [out, code]
    end
  end

  # The decision log: the commands the policy touched, for the telemetry
  # report and the ledger skill to read.
  module Log
    def self.append(decision, command, root)
      path = ENV['CLAUDE_POLICY_LOG']
      path = File.join(root, '.claude', 'policy-decisions.jsonl') if path.nil? || path.empty?
      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, 'a') { |f| f.puts JSON.generate(line(decision, command)) }
    rescue SystemCallError => e
      warn "bash-policy: cannot write the decision log: #{e.message}"
    end

    def self.line(decision, command)
      { ts: Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'),
        session: ENV.fetch('CLAUDE_POLICY_SESSION', ''),
        decision: decision.decision, rule: decision.rule, command: command }
    end
  end

  module Main
    def self.run(argv)
      command = argv[0].to_s
      return 0 if command.strip.empty?

      root = repo_root
      decision = Engine.new(Rules.load(policy_path(argv[1], root))).decide(command)
      return 0 unless decision

      Log.append(decision, command, root)
      puts JSON.generate(hookSpecificOutput: { hookEventName: 'PreToolUse',
                                               permissionDecision: decision.decision,
                                               permissionDecisionReason: decision.reason })
      0
    end

    def self.repo_root
      from_env = ENV['REPO_ROOT'].to_s
      return from_env unless from_env.empty?

      top = `git rev-parse --show-toplevel 2>/dev/null`.strip
      top.empty? ? Dir.pwd : top
    end

    def self.policy_path(given, root)
      return given if given && !given.empty?

      from_env = ENV['CLAUDE_POLICY_FILE'].to_s
      return from_env unless from_env.empty?

      repo = File.join(root, '.claude', 'bash-policy.rb')
      File.exist?(repo) ? repo : DEFAULT_POLICY
    end

    def self.guard_dir
      from_env = ENV['CLAUDE_POLICY_GUARD_DIR'].to_s
      from_env.empty? ? File.join(__dir__, 'bash-policy', 'guards') : from_env
    end
  end
end

exit BashPolicy::Main.run(ARGV) if $PROGRAM_NAME == __FILE__
