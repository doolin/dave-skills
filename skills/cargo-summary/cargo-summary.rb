#!/usr/bin/env ruby
# frozen_string_literal: true

# cargo-summary — the lines that matter from a cargo build, test, clippy,
# or check: each distinct error and warning, each panic, the tests that
# failed, and one tally of the `test result:` lines. Replaces the
# `cargo … 2>&1 | grep -E "^(error|warning)|FAILED|panicked" -A8 | head`
# pipeline, which matched no allowlist prefix and dropped what fell past
# the head.
#
# Usage (from the directory cargo would run in):
#   cargo-summary.rb test -p dreader-core index::   run cargo, keep the log, summarize
#   cargo-summary.rb --from LOG                      summarize a log already written
#
# Options:
#   --log PATH      where the full output goes (default: tmp/cargo-summary.log)
#   --policy PATH   what to show (default: policy.rb beside this script)
#   --help, -h      usage
#
# Exit codes: 0 summary printed and cargo succeeded · 1 cargo failed
# (mirrors cargo) · 10 bad args · 11 --from LOG missing · 12 bad policy

require 'English' # $CHILD_STATUS
require 'fileutils'

# Everything lives under one namespace so the file is loadable for tests
# without running (see the guard at the bottom).
module CargoSummary
  DEFAULT_LOG = 'tmp/cargo-summary.log'
  DEFAULT_POLICY = File.join(__dir__, 'policy.rb')
  RESULT = /\Atest result: (\w+)\. (\d+) passed; (\d+) failed; (\d+) ignored/

  # The policy DSL. A policy file is instance_eval'd here, so each line
  # of it is one call to one of these verbs.
  class Rules
    attr_reader :starts, :lines, :max_blocks, :max_lines

    def initialize
      @starts = []
      @lines = []
      @max_blocks = 12
      @max_lines = 25
    end

    def self.load(path)
      rules = new
      rules.instance_eval(File.read(path), path)
      rules
    rescue Errno::ENOENT, SyntaxError, NoMethodError, ArgumentError => e
      warn "cargo-summary: cannot read policy #{path}: #{e.message}"
      exit 12
    end

    # block_from(/\Aerror: /)
    def block_from(pattern)
      @starts << pattern
    end

    # line_matching(/FAILED\z/)
    def line_matching(pattern)
      @lines << pattern
    end

    # show_at_most 12, lines_per_block: 25
    def show_at_most(blocks, lines_per_block:)
      @max_blocks = blocks
      @max_lines = lines_per_block
    end
  end

  # The log read once: blocks and lines in the order cargo printed them,
  # each distinct one once, and the test tally.
  class Digest
    attr_reader :items, :tally

    def initialize(text, rules)
      @rules = rules
      @items = []
      @tally = { binaries: 0, passed: 0, failed: 0, ignored: 0 }
      read(text.lines(chomp: true))
    end

    def report(max_blocks:, max_lines:)
      shown = @items.first(max_blocks).map { |item| item.first(max_lines).join("\n") }
      hidden = @items.size - shown.size
      shown << "… #{hidden} more" if hidden.positive?
      shown << tally_line if @tally[:binaries].positive?
      shown
    end

    private

    def read(lines)
      block = nil
      lines.each do |line|
        if block && line.strip.empty?
          keep(block)
          block = nil
        elsif block
          block << line
        elsif @rules.starts.any? { |re| re.match?(line) }
          block = [line]
        else
          single(line)
        end
      end
      keep(block) if block
    end

    def single(line)
      if (m = RESULT.match(line))
        count(m)
      elsif @rules.lines.any? { |re| re.match?(line) }
        keep([line])
      end
    end

    def count(match)
      @tally[:binaries] += 1
      %i[passed failed ignored].each_with_index { |key, i| @tally[key] += match[i + 2].to_i }
    end

    def keep(item)
      @items << item unless @items.include?(item)
    end

    def tally_line
      t = @tally
      "tests: #{t[:passed]} passed, #{t[:failed]} failed, #{t[:ignored]} ignored " \
        "(#{t[:binaries]} test #{t[:binaries] == 1 ? 'binary' : 'binaries'})"
    end
  end

  module_function

  def usage
    <<~USAGE
      Usage: cargo-summary.rb [--log PATH] [--policy PATH] CARGO_ARGS...
             cargo-summary.rb [--policy PATH] --from LOG

        CARGO_ARGS   what to run, as after `cargo` (build, test -p x, clippy)
        --log PATH   full output (default: #{DEFAULT_LOG})
        --from LOG   summarize LOG instead of running cargo
    USAGE
  end

  # Options come before the cargo arguments; the first word that is not
  # one of ours begins cargo's.
  def parse(argv)
    opts = { log: DEFAULT_LOG, policy: DEFAULT_POLICY, from: nil, cargo: [] }
    args = argv.dup
    while (flag = args.first) && %w[--log --policy --from --help -h].include?(flag)
      args.shift
      return { help: true } if %w[--help -h].include?(flag)
      value = args.shift or return { error: "#{flag} needs a value" }
      opts[flag.delete_prefix('--').to_sym] = value
    end
    opts[:cargo] = args
    return { error: '--from takes no cargo arguments' } if opts[:from] && args.any?
    return { error: 'nothing to run: give cargo arguments or --from LOG' } if !opts[:from] && args.empty?

    opts
  end

  def run_cargo(args, log)
    FileUtils.mkdir_p(File.dirname(log))
    File.open(log, 'w') do |out|
      IO.popen({ 'CARGO_TERM_COLOR' => 'never' }, ['cargo', *args], err: %i[child out]) do |io|
        io.each_line { |line| out.write(line) }
      end
    end
    $CHILD_STATUS.exitstatus
  end

  def main(argv)
    opts = parse(argv)
    if opts[:help]
      puts usage
      return 0
    end
    if opts[:error]
      warn "cargo-summary: #{opts[:error]}"
      warn usage
      return 10
    end
    summarize(opts)
  end

  def summarize(opts)
    rules = Rules.load(opts[:policy])
    status = nil
    log = opts[:from] || opts[:log]
    if opts[:from]
      return missing(log) unless File.exist?(log)
    else
      status = run_cargo(opts[:cargo], log)
    end
    digest = Digest.new(File.read(log), rules)
    puts digest.report(max_blocks: rules.max_blocks, max_lines: rules.max_lines).join("\n\n")
    finish(status, log)
  end

  def missing(log)
    warn "cargo-summary: no log at #{log}"
    11
  end

  def finish(status, log)
    puts "full log: #{log}"
    return 0 if status.nil?

    puts "cargo exit: #{status}"
    status.zero? ? 0 : 1
  end
end

exit CargoSummary.main(ARGV) if $PROGRAM_NAME == __FILE__
