#!/usr/bin/env bash
# hooks/bash-policy.sh — PreToolUse hook on Bash.
#
# Reads the hook payload, hands `.tool_input.command` to bash-policy.rb,
# and passes the engine's one-line decision through: a deny, an ask, or
# nothing at all. The rules are not here and not in the engine either —
# they are in bash-policy/policy.rb, or in the consuming repo's
# .claude/bash-policy.rb when it has one.
#
# Registered per repo under hooks.PreToolUse with matcher "Bash" and no
# `if`, after tool-call-ledger.sh and before any consent gate.
#
# Fails open, loudly. No jq, no ruby, unparseable stdin, an engine that
# exits non-zero: one line to stderr and exit 0. A deny hook that failed
# closed would block every Bash call on a machine missing a dependency,
# which is worse than a missed refusal the ledger still records. The
# stderr line is the tell.
#
# Canonical copy lives in dave-skills; consuming repos symlink it as
# <repo>/.claude/hooks/bash-policy.sh.
#
# Env overrides:
#   REPO_ROOT           default: git toplevel of the cwd, else the cwd
#   CLAUDE_POLICY_FILE  default: $REPO_ROOT/.claude/bash-policy.rb, else the bundled policy
#   CLAUDE_POLICY_LOG   default: $REPO_ROOT/.claude/policy-decisions.jsonl

set -uo pipefail

open_gate() {
  printf 'bash-policy: %s; this command was not checked\n' "$1" >&2
  exit 0
}

command -v jq >/dev/null 2>&1 || open_gate 'jq not found'
command -v ruby >/dev/null 2>&1 || open_gate 'ruby not found'
[ -t 0 ] && exit 0

# The hook is symlinked into the consuming repo, so $0's directory is the
# link's, not this file's. Walk the links to find the engine beside us.
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
  TARGET="$(readlink "$SOURCE")"
  case "$TARGET" in
    /*) SOURCE="$TARGET" ;;
    *) SOURCE="$(dirname "$SOURCE")/$TARGET" ;;
  esac
done
HOOK_DIR="$(CDPATH='' cd -- "$(dirname -- "$SOURCE")" && pwd)"
ENGINE="$HOOK_DIR/bash-policy.rb"
[ -f "$ENGINE" ] || open_gate "no policy engine at $ENGINE"

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

POLICY="${CLAUDE_POLICY_FILE:-}"
if [ -z "$POLICY" ]; then
  if [ -f "$REPO_ROOT/.claude/bash-policy.rb" ]; then
    POLICY="$REPO_ROOT/.claude/bash-policy.rb"
  else
    POLICY="$HOOK_DIR/bash-policy/policy.rb"
  fi
fi

INPUT="$(cat 2>/dev/null)" || open_gate 'could not read the hook payload'
[ -n "$INPUT" ] || exit 0

COMMAND="$(printf '%s' "$INPUT" | jq -r 'select(.tool_name == "Bash") | .tool_input.command // empty' 2>/dev/null)" \
  || open_gate 'unparseable hook payload'
[ -n "$COMMAND" ] || exit 0

SESSION="$(printf '%s' "$INPUT" | jq -r '.session_id // ""' 2>/dev/null)" || SESSION=''

DECISION="$(REPO_ROOT="$REPO_ROOT" CLAUDE_POLICY_SESSION="$SESSION" ruby "$ENGINE" "$COMMAND" "$POLICY")"
STATUS=$?
[ "$STATUS" -eq 0 ] || open_gate "the policy engine exited $STATUS"

[ -n "$DECISION" ] && printf '%s\n' "$DECISION"
exit 0
