#!/usr/bin/env ruby
# frozen_string_literal: true

# rspec-summary — the few lines that matter from a full rspec run: the
# example tally, SimpleCov's line and branch totals, any coverage-floor
# breach, and the failures grouped by spec directory. Replaces the
# `grep -nE 'examples,|coverage' log` + `awk -F'[/:]'` pair that answered
# "did the full suite pass, and are the failures the known ones?" by
# hand and matched no allowlist prefix.
#
# Usage (from the repo root of any rspec + SimpleCov project):
#   ~/.claude/skills/rspec-summary/rspec-summary.rb [LOG]         summarize a log
#   ~/.claude/skills/rspec-summary/rspec-summary.rb --run [LOG]   run the suite,
#                                                     tee to LOG, summarize
#
#   LOG defaults to tmp/rspec-full.log under the cwd.
#
# Options:
#   --files      also list failures per spec file
#   --help, -h   usage
#
# --run deletes coverage/.resultset.json first: SimpleCov merges results
# within a time window, so a narrow run left behind would blend into this
# one and the coverage figure would not be a measurement.
#
# Exit codes: 0 summary printed · 1 the run failed (--run only, mirrors
# rspec) · 10 bad args · 11 log missing or has no rspec summary line

require 'fileutils'

DEFAULT_LOG = 'tmp/rspec-full.log'

def usage
  puts <<~USAGE
    Usage: rspec-summary.rb [--run] [--files] [LOG]

      LOG      rspec log to read or write (default: #{DEFAULT_LOG})
      --run    run `bundle exec rspec`, write LOG, then summarize
      --files  list failures per spec file as well as per directory
  USAGE
end

args = ARGV.dup
if args.include?('--help') || args.include?('-h')
  usage
  exit 0
end

run   = args.delete('--run')
files = args.delete('--files')

unknown = args.select { |a| a.start_with?('-') }
unless unknown.empty?
  warn "rspec-summary: unknown option(s): #{unknown.join(' ')}"
  usage
  exit 10
end
if args.size > 1
  warn "rspec-summary: expected at most one LOG argument, got #{args.size}"
  exit 10
end

log = args.first || DEFAULT_LOG
run_status = nil

if run
  FileUtils.mkdir_p(File.dirname(log))
  FileUtils.rm_f('coverage/.resultset.json')
  warn "rspec-summary: running bundle exec rspec → #{log}"
  File.open(log, 'w') do |out|
    IO.popen(%w[bundle exec rspec], err: %i[child out]) do |io|
      io.each_line { |line| out.write(line) }
    end
    run_status = $CHILD_STATUS.exitstatus
  end
end

unless File.exist?(log)
  warn "rspec-summary: no log at #{log}"
  warn 'rspec-summary: run with --run, or pass the path of an rspec log.'
  exit 11
end

text = File.read(log)

summary = text[/^\d+ examples?, \d+ failures?(?:, \d+ pending)?.*$/]
unless summary
  warn "rspec-summary: #{log} has no rspec summary line (did the run finish?)"
  exit 11
end

puts summary
%w[Line Branch].each do |kind|
  line = text[/^#{kind} coverage: .*$/]
  puts line if line
end
text.scan(/^.*below the expected minimum.*$/) { |l| puts "FLOOR: #{l.strip}" }
text.scan(/^.*Stopped processing SimpleCov.*$/) { |l| puts "ABORTED: #{l.strip}" }

failures = text.scan(%r{^rspec \./(spec/[^:\s]+):\d+}).flatten
unless failures.empty?
  by_dir = failures.group_by { |path| path.split('/').first(2).join('/') }
  puts 'Failures by directory:'
  by_dir.sort_by { |dir, list| [-list.size, dir] }.each do |dir, list|
    puts format('  %<n>4d  %<dir>s', n: list.size, dir: dir)
  end
  if files
    puts 'Failures by file:'
    failures.tally.sort_by { |path, n| [-n, path] }.each do |path, n|
      puts format('  %<n>4d  %<path>s', n: n, path: path)
    end
  end
end

if run_status
  puts "rspec exit: #{run_status}"
  exit run_status.zero? ? 0 : 1
end
exit 0
