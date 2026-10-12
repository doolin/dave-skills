# frozen_string_literal: true

# What cargo-summary shows from a cargo run. Edit this file, not the
# engine. Each line is one rule in one of three verbs; the engine
# (cargo-summary.rb) knows nothing about rustc or libtest except what is
# written here and the `test result:` tally.
#
# Point the tool at another policy with --policy PATH.

# ── Blocks: from a matching line to the next blank line. ──────────────
#    rustc ends every diagnostic with a blank line; libtest ends a
#    panic's message the same way.

block_from(/\A(error|warning)(\[\w+\])?: /)
block_from(/\Athread '.*' panicked at /)

# ── Single lines. ─────────────────────────────────────────────────────

line_matching(/\Atest \S+ \.\.\. FAILED\z/)
line_matching(/\A\s*Finished /)

# ── How much to print. The full log is always kept. ───────────────────

show_at_most 12, lines_per_block: 25
