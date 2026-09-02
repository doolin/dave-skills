#!/usr/bin/env bash
# hooks/session-resume.sh — SessionStart resume banner.
#
# Prints the resume anchors for a full-form .development repo: one line
# per ticket in .development/active/ (id, title, last update), followed
# by that ticket's `## Next` section when it has one. Stewardship
# tickets are standing work and would flood the banner, so they are
# listed only while they carry a `## Next` — that is, while a session
# paused on one. This is the read half of the pause/resume contract.
# The write half is the pause-session skill, which in a full-form repo
# updates the ticket's `## Next` in place; there is no next.md in that
# form. Sessions open from AGENTS.md and memory, neither of which
# points at active/, so without this banner a pause has no reader:
# "if you don't recall it, it failed." Vigilance decays; a reflexive
# banner does not.
#
# Canonical copy lives in dave-skills. Consuming repos symlink it as
# <repo>/.claude/hooks/session-resume.sh and register it under
# hooks.SessionStart in .claude/settings.json.
#
# Always exits 0 — a broken banner must never block a session.
#
# Env overrides:
#   REPO_ROOT                default: git toplevel of the cwd, else the cwd
#   CLAUDE_ACTIVE_DIR        default: $REPO_ROOT/.development/active
#   CLAUDE_STEWARDSHIP_DIR   default: $REPO_ROOT/.development/stewardship

set -u

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
ACTIVE_DIR="${CLAUDE_ACTIVE_DIR:-$REPO_ROOT/.development/active}"
STEWARDSHIP_DIR="${CLAUDE_STEWARDSHIP_DIR:-$REPO_ROOT/.development/stewardship}"

# First value of a frontmatter field, trailing comment and space stripped.
field() {
  head -40 "$1" \
    | grep -E "^$2:[[:space:]]*" \
    | head -1 \
    | sed -E "s/^$2:[[:space:]]*//; s/[[:space:]]+#.*$//; s/[[:space:]]+$//"
}

files=""
if [ -d "$ACTIVE_DIR" ]; then
  files=$(find "$ACTIVE_DIR" -maxdepth 1 -name '*.md' 2>/dev/null | sort)
fi

if [ -d "$STEWARDSHIP_DIR" ]; then
  paused=$(grep -lE '^## Next[[:space:]]*$' "$STEWARDSHIP_DIR"/*.md 2>/dev/null | sort)
  if [ -n "$paused" ]; then
    files="${files:+$files
}$paused"
  fi
fi

if [ ! -d "$ACTIVE_DIR" ] && [ -z "$files" ]; then
  echo "resume: no active/ directory ($ACTIVE_DIR)"
  exit 0
fi

if [ -z "$files" ]; then
  echo "resume: no active tickets"
  exit 0
fi

while IFS= read -r f; do
  id=$(field "$f" id)
  title=$(field "$f" title)
  updated=$(field "$f" updated)
  echo "resume: ${id:-?}  ${title:-(untitled)}  (updated ${updated:-?})"

  # Body of `## Next` up to the next H2, blank lines dropped.
  next=$(awk '/^## Next[[:space:]]*$/ { on = 1; next } /^## / { on = 0 } on' "$f" \
    | sed '/^[[:space:]]*$/d')
  if [ -n "$next" ]; then
    while IFS= read -r line; do echo "  $line"; done <<< "$next"
  else
    echo "  (no ## Next section; pause-session writes one)"
  fi
done <<< "$files"

exit 0
