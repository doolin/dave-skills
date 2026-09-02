#!/usr/bin/env bash
# hooks/tool-call-ledger.sh — PreToolUse hook on Bash (DBB-0531).
#
# Appends one JSON line per Bash tool call to a per-repo ledger:
#   {"ts":"…Z","cwd":"…","session":"…","command":"…"}
# Commands only: never the tool's output, never file contents. The
# ledger is what the tool-call-ledger skill clusters into proposals
# (allowlist entry / existing skill / new tool), so a permission prompt
# stops being a signal the operator absorbs and forgets.
#
# Registered per repo under hooks.PreToolUse with matcher "Bash" and no
# `if`, so every Bash call is recorded. Always exits 0 and never
# blocks: a ledger must not cost a tool call.
#
# Canonical copy lives in dave-skills; consuming repos symlink it as
# <repo>/.claude/hooks/tool-call-ledger.sh.
#
# Env overrides:
#   REPO_ROOT            default: git toplevel of the cwd, else the cwd
#   CLAUDE_LEDGER_FILE   default: $REPO_ROOT/.claude/tool-calls.jsonl

set -u

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
LEDGER="${CLAUDE_LEDGER_FILE:-$REPO_ROOT/.claude/tool-calls.jsonl}"

command -v jq >/dev/null 2>&1 || exit 0
[ -t 0 ] && exit 0

input=$(cat 2>/dev/null) || exit 0
[ -n "$input" ] || exit 0

mkdir -p "$(dirname "$LEDGER")" 2>/dev/null || exit 0

printf '%s' "$input" \
  | jq -c \
      --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --arg cwd "$PWD" \
      'select(.tool_name == "Bash" and ((.tool_input.command // "") != ""))
       | {ts: $ts, cwd: (.cwd // $cwd), session: (.session_id // ""), command: .tool_input.command}' \
  >> "$LEDGER" 2>/dev/null || true

exit 0
