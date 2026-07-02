#!/usr/bin/env ruby
# frozen_string_literal: true

# Audit and reconcile .development/INDEX.md against the files on disk.
#
# Why this exists: the index is meant to be kept current by a Haiku-level
# agent on a recurring schedule. Small models hand-editing a markdown table
# drift and corrupt it, so the mechanical reconciliation is done here, in a
# deterministic script. The agent's job shrinks to: run this, read the
# flagged summary, surface it to the human. Same (disk state, git dates,
# today) always produces the same INDEX.md.
#
# What it NEVER does: edit, move, or delete any indexed document. It only
# rewrites the managed table region inside INDEX.md.
#
# Usage (from anywhere inside the target repo):
#   ruby audit_index.rb                 # dry run: print summary only
#   ruby audit_index.rb --write         # apply changes to INDEX.md
#   ruby audit_index.rb --today 2026-07-02 --staleness-days 90 --write
#
# Exit status: 0 if clean (every doc current, nothing flagged), 1 if the
# audit flagged anything (orphaned / missing / stale) so a caller or CI can
# react.
#
# Extracted from ww-dien-bien-phu (scripts/audit_index.rb); generalized to
# resolve the repo root from git instead of the script's own location, so
# one copy serves any repo it is copied into or run against.

require 'date'
require 'optparse'

ROOT = begin
  top = `git rev-parse --show-toplevel 2>/dev/null`.strip
  top.empty? ? Dir.pwd : top
end
DEV   = File.join(ROOT, '.development')
INDEX = File.join(DEV, 'INDEX.md')
BEGIN_MARK = '<!-- INDEX:BEGIN -->'
END_MARK   = '<!-- INDEX:END -->'

opts = { today: Date.today, staleness_days: 90, write: false }
OptionParser.new do |o|
  o.on('--today YYYY-MM-DD', 'Audit date (default system date)') { |v| opts[:today] = Date.parse(v) }
  o.on('--staleness-days N', Integer, 'Flag docs older than N days (default 90)') { |v| opts[:staleness_days] = v }
  o.on('--write', 'Write changes back to INDEX.md (default dry run)') { opts[:write] = true }
end.parse!

abort "INDEX.md not found: #{INDEX}" unless File.exist?(INDEX)

# Repo-relative path with forward slashes, for stable table keys.
def rel(path) = path.sub(%r{\A#{Regexp.escape(ROOT)}/}, '')

# The document's own first heading (or first non-blank line), trimmed — the
# only text the auditor ever generates, and only to fill an empty Purpose.
def derive_purpose(path)
  File.foreach(path) do |line|
    s = line.strip
    next if s.empty?
    s = s.sub(/\A#+\s*/, '')
    return s.length > 60 ? "#{s[0, 57]}..." : s
  end
  '(empty file)'
end

# Last commit date (YYYY-MM-DD) for a path; nil if uncommitted/untracked.
def git_date(path)
  out = `git -C #{ROOT.inspect} log -1 --format=%cs -- #{path.inspect} 2>/dev/null`.strip
  out.empty? ? nil : Date.parse(out)
end

# --- parse the existing managed table -------------------------------------
text = File.read(INDEX)
unless text.include?(BEGIN_MARK) && text.include?(END_MARK)
  abort "INDEX.md is missing the #{BEGIN_MARK} / #{END_MARK} markers."
end
pre, rest = text.split(BEGIN_MARK, 2)
_table, post = rest.split(END_MARK, 2)

existing = {} # path => {purpose:, status:, audited:}
_table.each_line do |line|
  next unless line.start_with?('|')
  cells = line.split('|').map(&:strip)
  next if cells[1].nil? || cells[1].empty? || cells[1] == 'Path' || cells[1].match?(/\A-+\z/)
  existing[cells[1]] = { purpose: cells[2].to_s, status: cells[3].to_s, audited: cells[4].to_s }
end

# --- enumerate docs on disk ------------------------------------------------
disk = Dir.glob(File.join(DEV, '**', '*.md')).reject { |p| File.expand_path(p) == INDEX }.map { |p| rel(p) }.sort

today = opts[:today]
rows = {}
flags = { orphaned: [], missing: [], stale: [] }

disk.each do |path|
  prior = existing[path]
  purpose = (prior && !prior[:purpose].empty? && prior[:purpose] != '—') ? prior[:purpose] : derive_purpose(File.join(ROOT, path))
  gdate = git_date(path)
  status =
    if prior.nil?
      flags[:orphaned] << path
      'orphaned'
    elsif prior[:status] == 'superseded'
      'superseded'
    elsif gdate && (today - gdate).to_i > opts[:staleness_days]
      flags[:stale] << path
      'stale?'
    else
      'current'
    end
  rows[path] = { purpose: purpose, status: status, audited: today.iso8601 }
end

# Indexed paths no longer on disk: keep the row, mark missing, never delete.
(existing.keys - disk).each do |path|
  flags[:missing] << path
  rows[path] = { purpose: existing[path][:purpose], status: 'missing', audited: today.iso8601 }
end

# --- deterministic ordering: core working files, then the rest A→Z ---------
# Covers the current one-file-per-concern set plus legacy names (planning).
CORE = %w[
  .development/roadmap.md
  .development/backlog.md
  .development/todo.md
  .development/changelog.md
  .development/adr.md
  .development/prd.md
  .development/design.md
  .development/stewardship.md
  .development/lessons-learned.md
  .development/CAPTURE.md
  .development/planning.md
].freeze
ordered = rows.keys.sort_by { |p| [CORE.index(p) || CORE.size, p] }

table = +"\n| Path | Purpose | Status | Last audited |\n|------|---------|--------|--------------|\n"
ordered.each do |p|
  r = rows[p]
  table << "| #{p} | #{r[:purpose]} | #{r[:status]} | #{r[:audited]} |\n"
end

# --- report ----------------------------------------------------------------
puts "Audited #{disk.size} document(s) under .development/ as of #{today.iso8601}."
%i[orphaned missing stale].each do |k|
  next if flags[k].empty?
  puts "  #{k.to_s.upcase} (#{flags[k].size}): #{flags[k].join(', ')}"
end
clean = flags.values.all?(&:empty?)
puts(clean ? '  All current — nothing flagged.' : '  ^ surface the above to the human; the auditor does not act on flags.')

if opts[:write]
  File.write(INDEX, "#{pre}#{BEGIN_MARK}#{table}#{END_MARK}#{post}")
  puts 'Wrote INDEX.md.'
else
  puts 'Dry run — pass --write to update INDEX.md.'
end

exit(clean ? 0 : 1)
