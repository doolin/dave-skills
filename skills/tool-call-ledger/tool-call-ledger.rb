#!/usr/bin/env ruby
# frozen_string_literal: true

# tool-call-ledger — cluster an agent's Bash tool calls by shape and
# propose, per recurring shape, one of: an allowlist entry, something
# that already exists (a skill grant, a skill, a file tool), a new tool,
# or keep prompting. Reads the JSONL ledger written by
# hooks/tool-call-ledger.sh, or Bash tool_use records straight out of
# Claude Code transcripts (--transcripts DIR) for a dry run over history.
#
# The judgment lives in policy.rb beside this file, written in a small
# DSL (see Ledger::Rules for the six verbs). This file is the engine and
# knows nothing about git or rspec that the policy does not tell it.
#
# Usage:
#   tool-call-ledger.rb [LEDGER ...]          default: <git root>/.claude/tool-calls.jsonl
#   tool-call-ledger.rb --transcripts DIR     read every *.jsonl transcript in DIR
#
# Options:
#   --min N            report clusters seen at least N times (policy default 3)
#   --all              report every cluster, regardless of --min
#   --no-hints         ignore the policy's reach_for rules (what would have been proposed
#                      before those tools existed)
#   --policy PATH      rules file (default: policy.rb beside this script)
#   --settings PATH    an allowlist source; repeatable (default: <root>/.claude/settings.json,
#                      <root>/.claude/settings.local.json, ~/.claude/settings.json)
#   --skills DIR       a skills directory whose SKILL.md grants count as coverage;
#                      repeatable (default: ~/.claude/skills, <root>/.claude/skills)
#   --root DIR         repo root for the defaults above (default: git toplevel of cwd)
#   --help, -h
#
# Exit codes: 0 report printed · 10 bad args · 11 no records found · 12 policy unreadable
#
# Normalization is deliberately crude (see Shaper): argv[0] plus a
# subcommand where the policy says so, flags kept with values
# abstracted, every positional argument folded to <arg>/<args>. Pipes,
# chains, and redirects stay in the shape: they are what makes a
# command a tool candidate.

require 'json'
require 'shellwords'

# Everything lives under one namespace so the file is loadable for tests
# without running (see the guard at the bottom).
module Ledger
  Record = Struct.new(:ts, :cwd, :session, :command)

  # The policy DSL. A policy file is instance_eval'd here, so each line
  # of it is one call to one of these verbs.
  class Rules
    attr_reader :state_changing, :raw_prompts, :subcommands, :valued_flags, :path_prefixes, :hints
    attr_accessor :min, :examples

    def initialize
      @state_changing = []
      @raw_prompts = []
      @subcommands = {}
      @valued_flags = Hash.new { |h, k| h[k] = [] }
      @path_prefixes = []
      @hints = []
      @min = 3
      @examples = 3
    end

    def self.load(path)
      rules = new
      rules.instance_eval(File.read(path), path)
      rules
    rescue Errno::ENOENT, SyntaxError, NoMethodError => e
      warn "tool-call-ledger: cannot read policy #{path}: #{e.message}"
      exit 12
    end

    # keep_prompting_for 'git commit', 'rm'
    def keep_prompting_for(*verbs)
      @state_changing.concat(verbs.flatten)
    end

    # keep_prompting_when(/\Acurl .*-X POST/, because: 'it sends')
    def keep_prompting_when(pattern, because:)
      @raw_prompts << [pattern, because]
    end

    # subcommand_after 'git'            (one word)
    # subcommand_after 'gh', words: 2
    def subcommand_after(*names, words: 1)
      names.flatten.each { |n| @subcommands[n] = words }
    end

    # value_follows 'git', '-C', '-c'
    def value_follows(name, *flags)
      @valued_flags[name].concat(flags.flatten)
    end

    # keep_paths_starting_with 'scripts/', '~/src/'
    def keep_paths_starting_with(*prefixes)
      @path_prefixes.concat(prefixes.flatten)
    end

    # reach_for 'git-orient', when_it_looks_like: /\Agit status\b/
    def reach_for(name, when_it_looks_like:)
      @hints << [when_it_looks_like, name]
    end

    def report_shapes_seen_at_least(count)
      @min = Integer(count)
    end

    def show_examples(count)
      @examples = Integer(count)
    end

    # Names a proposed rule must never be reduced to (the blanket grant).
    def blanket_names
      @subcommands.keys
    end
  end

  # Command-line parsing. Exits 10 on anything malformed.
  module Options
    DEFAULTS = { min: nil, all: false, hints: true, policy: nil, settings: [], skills: [],
                 transcripts: nil, root: nil, ledgers: [] }.freeze
    VALUED = { '--min' => :min, '--policy' => :policy, '--settings' => :settings, '--skills' => :skills,
               '--transcripts' => :transcripts, '--root' => :root }.freeze

    def self.usage
      puts <<~USAGE
        Usage: tool-call-ledger.rb [--transcripts DIR] [--min N] [--all] [--no-hints] [--policy PATH]
                                   [--settings PATH]... [--skills DIR]... [--root DIR] [LEDGER ...]
      USAGE
    end

    def self.parse(argv)
      opts = DEFAULTS.transform_values { |v| v.is_a?(Array) ? v.dup : v }
      args = argv.dup
      take(opts, args, args.shift) until args.empty?
      opts
    rescue ArgumentError => e
      warn "tool-call-ledger: #{e.message}"
      exit 10
    end

    def self.take(opts, args, arg)
      return help if ['-h', '--help'].include?(arg)
      return opts[:all] = true if arg == '--all'
      return opts[:hints] = false if arg == '--no-hints'
      return opts[:min] = Regexp.last_match(1).to_i if arg =~ /\A--min=(\d+)\z/
      return valued(opts, args, arg) if VALUED.key?(arg)
      return unknown(arg) if arg.start_with?('-')

      opts[:ledgers] << arg
    end

    def self.valued(opts, args, flag)
      value = args.shift || raise(ArgumentError, "#{flag} needs a value")
      key = VALUED[flag]
      case key
      when :min then opts[:min] = Integer(value)
      when :settings, :skills then opts[key] << value
      else opts[key] = value
      end
    end

    def self.help
      usage
      exit 0
    end

    def self.unknown(arg)
      warn "tool-call-ledger: unknown option #{arg}"
      usage
      exit 10
    end
  end

  # Reads records from the hook's ledger or from Claude Code transcripts.
  module Reader
    def self.ledger(path)
      File.foreach(path).filter_map { |line| record_from_ledger(line) }
    end

    def self.record_from_ledger(line)
      h = JSON.parse(line)
      cmd = h['command']
      return unless cmd.is_a?(String) && !cmd.empty?

      Record.new(h['ts'].to_s, h['cwd'].to_s, h['session'].to_s, cmd)
    rescue JSON::ParserError
      nil
    end

    def self.transcript(path)
      session = File.basename(path, '.jsonl')
      File.foreach(path).flat_map { |line| records_from_transcript_line(line, session) }
    end

    def self.records_from_transcript_line(line, session)
      h = JSON.parse(line)
      return [] unless h['type'] == 'assistant'

      blocks = h.dig('message', 'content')
      return [] unless blocks.is_a?(Array)

      bash_commands(blocks).map { |cmd| Record.new(h['timestamp'].to_s, h['cwd'].to_s, h['sessionId'] || session, cmd) }
    rescue JSON::ParserError
      []
    end

    def self.bash_commands(blocks)
      blocks.filter_map do |b|
        next unless b.is_a?(Hash) && b['type'] == 'tool_use' && b['name'] == 'Bash'

        cmd = b.dig('input', 'command')
        cmd if cmd.is_a?(String) && !cmd.empty?
      end
    end
  end

  # A command's shape: argv[0], its subcommand where the policy says so,
  # flags with values abstracted, positionals folded. Also reports the
  # "verb" (argv[0] plus subcommand) an allowlist rule would name,
  # whether the command is a chain (pipe, &&, ;, redirect), and whether
  # it carries a leading environment assignment.
  class Shaper
    OPERATORS = %w[| || && ;].freeze
    REDIRECT_WITH_OPERAND = /\A(\d?>>?|<|&>)\z/
    REDIRECT_BARE = /\A\d?>&\d?\z/
    ASSIGNMENT = /\A[A-Za-z_][A-Za-z0-9_]*=/
    # A short flag with its value attached: -F'[/:]', -n5, -L8,8. Combined
    # letter flags like -nE are not this.
    ATTACHED_VALUE = /\A-[A-Za-z][^A-Za-z-]/

    Shape = Struct.new(:text, :verb, :chained, :env)

    def initialize(home, rules)
      @home = home
      @rules = rules
    end

    def call(command)
      tokens = tokenize(command)
      segments = split_on_operators(tokens)
      shaped = segments.map { |seg| segment(seg[:tokens]) }
      Shape.new(text_for(shaped, segments), shaped.first[:verb], chained?(tokens, segments), shaped.first[:env])
    end

    # Segment texts for rule matching: tokens rejoined by spaces, so a
    # prefix rule sees the verb and flags it would see in the real call.
    def raw_segments(command)
      split_on_operators(tokenize(command)).map { |seg| seg[:tokens].join(' ') }.reject(&:empty?)
    end

    private

    def tokenize(command)
      Shellwords.shellsplit(command)
    rescue ArgumentError
      command.split
    end

    def text_for(shaped, segments)
      shaped.zip(segments).map { |s, seg| [seg[:op], s[:text]].compact.join(' ') }.join(' ')
    end

    def chained?(tokens, segments)
      segments.size > 1 || tokens.any? { |t| t.match?(REDIRECT_WITH_OPERAND) || t.match?(REDIRECT_BARE) }
    end

    def split_on_operators(tokens)
      segments = [{ op: nil, tokens: [] }]
      tokens.each do |t|
        if OPERATORS.include?(t)
          segments << { op: t, tokens: [] }
        else
          segments.last[:tokens] << t
        end
      end
      segments
    end

    def segment(tokens)
      env = tokens.take_while { |t| t.match?(ASSIGNMENT) }
      prefix = env.map { |e| "#{e.sub(/=.*/, '')}=<v>" }
      rest = tokens.drop(env.size)
      return { text: prefix.join(' '), verb: prefix.first.to_s, env: true } if rest.empty?

      command_shape(prefix, collapse(rest[0]), rest[1..])
    end

    def command_shape(prefix, argv0, rest)
      words = Words.new(argv0, @rules).run(rest)
      { text: (prefix + [argv0] + words.out).join(' '), verb: ([argv0] + words.sub).join(' '), env: !prefix.empty? }
    end

    def collapse(word)
      word = word.sub(%r{\A#{Regexp.escape(@home)}/}, '~/')
      return word if @rules.path_prefixes.any? { |p| word.start_with?(p) }

      word.start_with?('/') ? "/…/#{File.basename(word)}" : word
    end

    # Walks the tokens after argv[0], deciding per token whether it is a
    # redirect, a valued flag, a flag, a subcommand, or a positional.
    class Words
      attr_reader :out, :sub

      def initialize(argv0, rules)
        @out = []
        @sub = []
        @positional = 0
        @subs_wanted = rules.subcommands.fetch(argv0, 0)
        @valued = rules.valued_flags.fetch(argv0, [])
      end

      def run(rest)
        idx = 0
        idx += consume(rest[idx]) while idx < rest.size
        @out << '<arg>' if @positional == 1
        @out << '<args>' if @positional > 1
        self
      end

      private

      # Returns how many tokens were consumed.
      def consume(token)
        return emit("#{token} <file>", 2) if token.match?(REDIRECT_WITH_OPERAND)
        return emit(token, 1) if token.match?(REDIRECT_BARE)
        return emit("#{token} <v>", 2) if @valued.include?(token)
        return emit(flag_shape(token), 1) if token.start_with?('-')

        word(token)
        1
      end

      def emit(text, consumed)
        @out << text
        consumed
      end

      def flag_shape(token)
        return "#{token[0, 2]}<v>" if token.match?(ATTACHED_VALUE)

        token.sub(/=.*\z/, '=<v>')
      end

      def word(token)
        if @sub.size < @subs_wanted
          @sub << token
          @out << token
        else
          @positional += 1
        end
      end
    end
  end

  # Decides what to propose for a cluster, from the allow rules, the
  # skill grants, and the policy.
  class Policy
    def initialize(rules:, allow_rules:, skill_rules:, hints: true)
      @rules = rules
      @allow_rules = allow_rules
      @skill_rules = skill_rules
      @hints = hints
    end

    def self.rules_from_settings(path)
      return [] unless File.exist?(path)

      Array(JSON.parse(File.read(path)).dig('permissions', 'allow')).filter_map { |r| r[/\ABash\((.*)\)\z/, 1] }
    rescue JSON::ParserError
      []
    end

    def self.rules_from_skills(dir)
      Dir.glob(File.join(dir, '*', 'SKILL.md')).flat_map do |md|
        line = File.read(md)[0, 4000][/^allowed-tools:\s*(.+)$/, 1]
        next [] unless line

        line.scan(/Bash\(([^)]*)\)/).flatten.map { |r| [r, File.basename(File.dirname(md))] }
      end
    end

    # Claude Code prefix semantics: a trailing `*` (or `:*`) is a prefix,
    # anything else is exact. Every segment of a chain must match.
    def self.rule_matches?(rule, command)
      return command == rule unless rule.end_with?('*')

      prefix = rule.sub(/:?\*\z/, '').rstrip
      command == prefix || command.start_with?(prefix)
    end

    def decide(cluster)
      allowed(cluster) || covered(cluster) || hinted(cluster) || never(cluster) ||
        env_prefixed(cluster) || chained(cluster) || allowlist(cluster)
    end

    private

    def allowed(cluster)
      segments = cluster[:segments]
      rule = allowed_by(segments.first)
      ['allowed', "Bash(#{rule})"] if rule && segments.all? { |s| allowed_by(s) }
    end

    def covered(cluster)
      return unless cluster[:segments].size == 1

      skill = covering_skill(cluster[:segments].first)
      ['covered', skill] if skill
    end

    def hinted(cluster)
      return unless @hints

      probe = [cluster[:shape], *cluster[:examples]]
      hint = @rules.hints.find { |re, _| probe.any? { |p| p.match?(re) } }&.last
      ['use instead', hint] if hint
    end

    def never(cluster)
      return ['keep prompting', 'changes state'] if state_changing?(cluster[:verb])

      raw = cluster[:segments].first
      because = @rules.raw_prompts.find { |re, _| raw.match?(re) }&.last
      ['keep prompting', because] if because
    end

    def state_changing?(verb)
      @rules.state_changing.any? { |v| verb == v || verb.start_with?("#{v} ") }
    end

    def env_prefixed(cluster)
      ['new tool', 'an env-var prefix never matches a rule; a wrapper should set it'] if cluster[:env]
    end

    def chained(cluster)
      ['new tool', 'pipe, chain, or redirect'] if cluster[:chained]
    end

    def allowlist(cluster)
      verb = cluster[:verb]
      return ['keep prompting', "a rule would be the blanket Bash(#{verb} *)"] if @rules.blanket_names.include?(verb)

      rule = "#{verb} *"
      if @allow_rules.include?(rule)
        return ['use instead', "Bash(#{rule}) exists but this form does not match it (an option before the verb?)"]
      end

      ['allowlist', "Bash(#{rule})"]
    end

    def allowed_by(segment)
      @allow_rules.find { |r| Policy.rule_matches?(r, segment) }
    end

    def covering_skill(segment)
      @skill_rules.find { |r, _| Policy.rule_matches?(r, segment) }&.last
    end
  end

  # What the report shows: the floor, whether to ignore it, how many examples.
  View = Struct.new(:floor, :all, :examples, keyword_init: true)

  # Groups records by shape and prints one block per cluster.
  class Report
    def initialize(records, shaper:, policy:, view:)
      @records = records
      @shaper = shaper
      @policy = policy
      @min = view.floor
      @all = view.all
      @examples = view.examples
    end

    def run
      clusters = cluster
      selected = select(clusters)
      return none(clusters) if selected.empty?

      tally = Hash.new(0)
      selected.each { |c| tally[print_cluster(c)] += 1 }
      summary(clusters, selected, tally)
    end

    def select(clusters)
      clusters.values.select { |c| @all || c[:count] >= @min }.sort_by { |c| [-c[:count], c[:shape]] }
    end

    private

    def cluster
      clusters = Hash.new { |h, k| h[k] = new_cluster(k) }
      @records.each { |r| absorb(clusters[@shaper.call(r.command).text], r) }
      clusters
    end

    def new_cluster(shape)
      { shape: shape, count: 0, chained: false, env: false, verb: nil,
        first: nil, last: nil, sessions: {}, examples: [], segments: [] }
    end

    def absorb(cluster, record)
      describe(cluster, record) if cluster[:count].zero?
      cluster[:count] += 1
      touch_times(cluster, record.ts)
      cluster[:sessions][record.session] = true unless record.session.empty?
      add_example(cluster, record.command)
    end

    # First record of a cluster fixes its verb, chain flag, and segments.
    def describe(cluster, record)
      shape = @shaper.call(record.command)
      cluster[:chained] = shape.chained
      cluster[:env] = shape.env
      cluster[:verb] = shape.verb
      cluster[:segments] = @shaper.raw_segments(record.command)
    end

    def touch_times(cluster, stamp)
      return if stamp.empty?

      cluster[:first] = stamp if cluster[:first].nil? || stamp < cluster[:first]
      cluster[:last] = stamp if cluster[:last].nil? || stamp > cluster[:last]
    end

    def add_example(cluster, command)
      return if cluster[:examples].size >= @examples || cluster[:examples].include?(command)

      cluster[:examples] << command
    end

    def print_cluster(cluster)
      kind, detail = @policy.decide(cluster)
      puts format('%<n>4d×  %<shape>s', n: cluster[:count], shape: cluster[:shape])
      puts "       first #{short(cluster[:first])}  last #{short(cluster[:last])}  sessions #{cluster[:sessions].size}"
      print_examples(cluster[:examples])
      puts "       → #{kind}: #{detail}"
      puts
      kind
    end

    def print_examples(examples)
      examples.each_with_index { |e, i| puts "       #{i.zero? ? 'e.g. ' : '     '}#{trim(e)}" }
    end

    def summary(clusters, selected, tally)
      puts "#{@records.size} records, #{clusters.size} shapes, #{selected.size} reported (min #{@all ? 1 : @min})"
      puts tally.sort_by { |k, n| [-n, k] }.map { |k, n| "#{n} #{k}" }.join(', ')
    end

    def none(clusters)
      puts "tool-call-ledger: #{@records.size} records, #{clusters.size} shapes, " \
           "none seen #{@min}+ times (try --all or --min)"
    end

    def short(stamp)
      stamp.to_s.sub(/:\d\d(\.\d+)?Z?\z/, '').sub('T', ' ')
    end

    def trim(example)
      one_line = example.lines.first.to_s.chomp
      one_line.length > 110 ? "#{one_line[0, 107]}..." : one_line
    end
  end

  # Wires options, policy, readers, and report together.
  module Main
    def self.run(argv)
      opts = Options.parse(argv)
      rules = Rules.load(opts[:policy] || File.join(__dir__, 'policy.rb'))
      root = root_for(opts)
      report_for(opts, rules, root).run
      0
    end

    def self.report_for(opts, rules, root)
      view = View.new(floor: opts[:min] || rules.min, all: opts[:all], examples: rules.examples)
      Report.new(load_records(opts, root),
                 shaper: Shaper.new(Dir.home, rules), policy: policy_for(opts, rules, root), view: view)
    end

    def self.policy_for(opts, rules, root)
      home = Dir.home
      Policy.new(rules: rules, allow_rules: allow_rules(opts, root, home),
                 skill_rules: skill_rules(opts, root, home), hints: opts[:hints])
    end

    def self.root_for(opts)
      root = opts[:root] || `git rev-parse --show-toplevel 2>/dev/null`.strip
      root.empty? ? Dir.pwd : root
    end

    def self.load_records(opts, root)
      records = opts[:transcripts] ? transcript_records(opts[:transcripts]) : ledger_records(opts[:ledgers], root)
      return records unless records.empty?

      warn 'tool-call-ledger: no Bash records found'
      exit 11
    end

    def self.transcript_records(dir)
      unless File.directory?(dir)
        warn "tool-call-ledger: no such directory #{dir}"
        exit 11
      end
      Dir.glob(File.join(dir, '*.jsonl')).sort.flat_map { |f| Reader.transcript(f) }
    end

    def self.ledger_records(ledgers, root)
      ledgers = [File.join(root, '.claude', 'tool-calls.jsonl')] if ledgers.empty?
      missing = ledgers.reject { |f| File.exist?(f) }
      unless missing.empty?
        warn "tool-call-ledger: no ledger at #{missing.join(', ')}"
        warn 'tool-call-ledger: register hooks/tool-call-ledger.sh, or pass --transcripts DIR.'
        exit 11
      end
      ledgers.flat_map { |f| Reader.ledger(f) }
    end

    def self.allow_rules(opts, root, home)
      paths = opts[:settings]
      if paths.empty?
        paths = [File.join(root, '.claude/settings.json'), File.join(root, '.claude/settings.local.json'),
                 File.join(home, '.claude/settings.json')]
      end
      paths.flat_map { |p| Policy.rules_from_settings(p) }.uniq
    end

    def self.skill_rules(opts, root, home)
      dirs = opts[:skills]
      dirs = [File.join(home, '.claude/skills'), File.join(root, '.claude/skills')] if dirs.empty?
      dirs.flat_map { |d| Policy.rules_from_skills(d) }
    end
  end
end

exit Ledger::Main.run(ARGV) if $PROGRAM_NAME == __FILE__
