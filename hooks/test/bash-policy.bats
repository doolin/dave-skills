#!/usr/bin/env bats
# Tests for hooks/bash-policy.sh and its engine, hooks/bash-policy.rb.
#
# The hook is run as `bash "$SUBJECT_DIR/bash-policy.sh"` and the engine as
# `ruby "$SUBJECT_DIR/bash-policy.rb"`, so nothing here depends on an
# executable bit. test_helper exports REPO_ROOT as the scratch dir; every
# run also points the policy file, the decision log and the guard
# directory at scratch, so no test can read or write the real repo.
#
# The guard tests build a scratch repo whose `origin` is a local bare
# repo inside $TEST_TMPDIR. Nothing in this file touches the network.

load ../../test/test_helper

default_policy() {
  echo "$SUBJECT_DIR/bash-policy/policy.rb"
}

# POLICY unset → the bundled default. POLICY='' → let the engine resolve
# it from REPO_ROOT, which is how a repo policy gets picked up.
policy_env() {
  case "${POLICY-unset}" in
    unset) export CLAUDE_POLICY_FILE="$(default_policy)" ;;
    "") unset CLAUDE_POLICY_FILE ;;
    *) export CLAUDE_POLICY_FILE="$POLICY" ;;
  esac
  export REPO_ROOT="${POLICY_ROOT:-$TEST_TMPDIR}"
  export CLAUDE_POLICY_LOG="${LOG:-$TEST_TMPDIR/.claude/policy-decisions.jsonl}"
  export CLAUDE_POLICY_GUARD_DIR="${GUARDS:-$SUBJECT_DIR/bash-policy/guards}"
  export CLAUDE_POLICY_SESSION="bats-session"
}

decide() {
  policy_env
  ruby "$SUBJECT_DIR/bash-policy.rb" "$1"
}

payload() {
  printf '%s' "$1" | jq -Rsc '{tool_name: "Bash", session_id: "bats-session", tool_input: {command: .}}'
}

hook() {
  policy_env
  payload "$1" | bash "$SUBJECT_DIR/bash-policy.sh"
}

# $1 expected permissionDecision, $2 a substring of the reason.
# shellcheck disable=SC2154  # bats assigns $output and $status
assert_decision() {
  [ "$status" -eq 0 ] || { echo "expected exit 0, got $status: $output"; return 1; }
  local got
  got="$(printf '%s' "$output" | jq -r '.hookSpecificOutput.permissionDecision' 2>/dev/null)"
  [ "$got" = "$1" ] || { echo "expected decision $1, got '$got' from: $output"; return 1; }
  assert_output_contains "$2"
}

# shellcheck disable=SC2154
assert_no_decision() {
  [ "$status" -eq 0 ] || { echo "expected exit 0, got $status: $output"; return 1; }
  [[ "$output" != *permissionDecision* ]] || { echo "expected no decision, got: $output"; return 1; }
}

log_file() {
  echo "${LOG:-$TEST_TMPDIR/.claude/policy-decisions.jsonl}"
}

# A scratch repo with a local bare `origin`, one commit, pushed to main.
fixture_git_repo() {
  export GIT_AUTHOR_NAME=bats GIT_AUTHOR_EMAIL=bats@example.com
  export GIT_COMMITTER_NAME=bats GIT_COMMITTER_EMAIL=bats@example.com
  git init -q --bare "$TEST_TMPDIR/origin.git"
  git init -q "$TEST_TMPDIR/work"
  git -C "$TEST_TMPDIR/work" symbolic-ref HEAD refs/heads/main
  printf 'one\n' > "$TEST_TMPDIR/work/file.txt"
  git -C "$TEST_TMPDIR/work" add file.txt
  git -C "$TEST_TMPDIR/work" commit -q -m 'first'
  git -C "$TEST_TMPDIR/work" remote add origin "$TEST_TMPDIR/origin.git"
  git -C "$TEST_TMPDIR/work" push -q origin main
}

# A repo policy that layers the dbb lines on top of the default.
fixture_repo_policy() {
  mkdir -p "$TEST_TMPDIR/.claude"
  cat > "$TEST_TMPDIR/.claude/bash-policy.rb" <<'EOF'
load_default_policy

refuse 'gh pr', because: 'no pull requests in dbb; commits land on main behind the consent gate'
refuse_when(%r{\b(perl|sed) -i\b.*\.development/},
            because: 'ticket close-outs use Edit and scripts/close-tickets, never an in-place edit')
EOF
}

# ── Refusals ──────────────────────────────────────────────────────────

@test "refuse: git commit -F denies and names the alternative" {
  run decide 'git commit -F msg.txt'
  assert_decision deny 'commit messages are inline with -m'
  assert_output_contains '[rule: git commit -F]'
}

@test "refuse: git commit --file denies" {
  run decide 'git commit --file msg.txt'
  assert_decision deny 'commit messages are inline with -m'
}

@test "refuse: a python one-liner denies" {
  run decide 'python3 -c "print(1)"'
  assert_decision deny 'no python one-liners or heredocs'
}

@test "refuse: a python heredoc denies" {
  run decide 'python3 <<EOF'
  assert_decision deny 'no python one-liners or heredocs'
}

@test "refuse: perl -e denies" {
  run decide 'perl -pe s/a/b/ file.txt'
  assert_decision deny 'no one-liner interpreters'
}

@test "refuse: ruby -e denies" {
  run decide 'ruby -e "puts 1"'
  assert_decision deny 'no one-liner interpreters'
}

@test "refuse: writing a file through a heredoc denies" {
  run decide 'cat > notes.txt <<EOF'
  assert_decision deny 'opaque to the permission system'
}

@test "a refused command anywhere in a chain is still refused" {
  run decide 'ls && git commit -F msg.txt'
  assert_decision deny 'commit messages are inline with -m'
}

# ── Asks ──────────────────────────────────────────────────────────────

@test "ask: a db: rake task asks" {
  run decide 'bin/rails db:migrate'
  assert_decision ask 'changes the development database'
}

@test "ask: bin/rails runner asks" {
  run decide 'bin/rails runner "User.first"'
  assert_decision ask 'cannot read Ruby'
}

@test "ask: sqlite3 against a database file asks" {
  run decide 'sqlite3 storage/development.sqlite3 "select 1"'
  assert_decision ask 'direct SQL against a database file'
}

@test "ask: a bare override prefix asks" {
  run decide 'CLAUDE_POLICY_OVERRIDE=1 ls -la'
  assert_decision ask 'an override was requested'
}

@test "ask: opening the read-only connection for writing asks" {
  run decide 'DBB_DB_WRITABLE=1 bundle exec rspec'
  assert_decision ask 'read-only development connection'
}

# ── allow_when beats ask_when ─────────────────────────────────────────

@test "allow_when beats ask_when for db:version" {
  run decide 'bin/rails db:version'
  assert_no_decision
  [ -z "$output" ]
}

@test "ask_when still fires for db:migrate" {
  run decide 'rake db:migrate'
  assert_decision ask 'changes the development database'
}

@test "an ordinary command gets no decision at all" {
  run decide 'ls -la'
  assert_no_decision
  [ -z "$output" ]
}

# ── Quoted spans are removed before matching ──────────────────────────

@test "a commit message that mentions sed -i is not refused" {
  fixture_repo_policy
  POLICY=''
  run decide 'git commit -m "ran sed -i over .development/ by hand"'
  assert_no_decision
}

@test "the same sed -i outside quotes is refused" {
  fixture_repo_policy
  POLICY=''
  run decide 'sed -i "" .development/done/DBB-0001.md'
  assert_decision deny 'never an in-place edit'
}

@test "a commit message that mentions python -c is not refused" {
  run decide 'git commit -m "drop the python -c habit"'
  assert_no_decision
}

# ── Override goes through ask, never through allow ────────────────────

@test "an override on a refused command asks and names the rule" {
  run decide 'CLAUDE_POLICY_OVERRIDE=1 git commit -F msg.txt'
  assert_decision ask 'an override was requested for a refused command'
  assert_output_contains '[rule: git commit -F]'
  assert_output_contains 'commit messages are inline with -m'
  [[ "$output" != *'"deny"'* ]]
}

@test "the override is logged as an ask, not as a deny" {
  run decide 'CLAUDE_POLICY_OVERRIDE=1 git commit -F msg.txt'
  [ "$(jq -r '.decision' "$(log_file)")" = "ask" ]
  [ "$(jq -r '.rule' "$(log_file)")" = "git commit -F" ]
}

# ── Guards ────────────────────────────────────────────────────────────

@test "guard: amending a pushed HEAD is refused" {
  fixture_git_repo
  POLICY_ROOT="$TEST_TMPDIR/work"
  run decide 'git commit --amend --no-edit'
  assert_decision deny 'HEAD is already on origin/main'
}

@test "guard: amending an unpushed HEAD passes" {
  fixture_git_repo
  printf 'two\n' >> "$TEST_TMPDIR/work/file.txt"
  git -C "$TEST_TMPDIR/work" commit -q -am 'second'
  POLICY_ROOT="$TEST_TMPDIR/work"
  run decide 'git commit --amend --no-edit'
  assert_no_decision
}

@test "guard: a repo with no origin passes" {
  git init -q "$TEST_TMPDIR/solo"
  POLICY_ROOT="$TEST_TMPDIR/solo"
  run decide 'git commit --amend'
  assert_no_decision
}

@test "guard: exit 2 asks, with the guard's own reason" {
  mkdir -p "$TEST_TMPDIR/guards"
  cat > "$TEST_TMPDIR/guards/coin.sh" <<'EOF'
echo "the guard could not tell"
exit 2
EOF
  cat > "$TEST_TMPDIR/guarded.rb" <<'EOF'
guard 'git commit --amend', with: 'coin', because: 'the fallback reason'
EOF
  POLICY="$TEST_TMPDIR/guarded.rb"
  GUARDS="$TEST_TMPDIR/guards"
  run decide 'git commit --amend'
  assert_decision ask 'the guard could not tell'
}

@test "guard: a silent guard falls back to the because: text" {
  mkdir -p "$TEST_TMPDIR/guards"
  cat > "$TEST_TMPDIR/guards/mute.sh" <<'EOF'
exit 1
EOF
  cat > "$TEST_TMPDIR/guarded.rb" <<'EOF'
guard 'git commit --amend', with: 'mute', because: 'the fallback reason'
EOF
  POLICY="$TEST_TMPDIR/guarded.rb"
  GUARDS="$TEST_TMPDIR/guards"
  run decide 'git commit --amend'
  assert_decision deny 'the fallback reason'
}

@test "guard: a missing guard script leaves the rule unchecked and says so" {
  cat > "$TEST_TMPDIR/guarded.rb" <<'EOF'
guard 'git commit --amend', with: 'absent', because: 'the fallback reason'
EOF
  POLICY="$TEST_TMPDIR/guarded.rb"
  GUARDS="$TEST_TMPDIR/guards"
  run decide 'git commit --amend'
  assert_no_decision
  assert_output_contains 'went unchecked'
}

# ── Policy resolution ─────────────────────────────────────────────────

@test "repo policy: load_default_policy plus the repo lines both apply" {
  fixture_repo_policy
  POLICY=''
  run decide 'gh pr create --fill'
  assert_decision deny 'no pull requests in dbb'
  run decide 'git commit -F msg.txt'
  assert_decision deny 'commit messages are inline with -m'
}

@test "no repo policy: the bundled default applies" {
  POLICY=''
  [ ! -f "$TEST_TMPDIR/.claude/bash-policy.rb" ]
  run decide 'git commit -F msg.txt'
  assert_decision deny 'commit messages are inline with -m'
}

@test "an unknown verb in a policy exits 12 and names the file" {
  cat > "$TEST_TMPDIR/bad-policy.rb" <<'EOF'
forbid 'git commit'
EOF
  POLICY="$TEST_TMPDIR/bad-policy.rb"
  run decide 'git commit -F msg.txt'
  [ "$status" -eq 12 ]
  assert_output_contains "$TEST_TMPDIR/bad-policy.rb"
  [[ "$output" != *permissionDecision* ]]
}

# ── The decision log ──────────────────────────────────────────────────

@test "decision log: one line per deny and ask, none for an allow" {
  run decide 'git commit -F msg.txt'
  run decide 'bin/rails db:migrate'
  run decide 'bin/rails db:version'
  run decide 'ls -la'
  [ "$(wc -l < "$(log_file)" | tr -d ' ')" = "2" ]
  [ "$(jq -sr '.[0].decision' "$(log_file)")" = "deny" ]
  [ "$(jq -sr '.[1].decision' "$(log_file)")" = "ask" ]
}

@test "decision log: every field the report reads is present" {
  run decide 'git commit -F msg.txt'
  [ "$(jq -r '.session' "$(log_file)")" = "bats-session" ]
  [ "$(jq -r '.rule' "$(log_file)")" = "git commit -F" ]
  [ "$(jq -r '.command' "$(log_file)")" = "git commit -F msg.txt" ]
  run jq -r '.ts' "$(log_file)"
  assert_output_contains "Z"
}

@test "decision log: no log file at all when nothing matched" {
  run decide 'ls -la'
  [ ! -f "$(log_file)" ]
}

# ── The hook itself ───────────────────────────────────────────────────

@test "hook: emits the deny decision for a refused command" {
  run hook 'git commit -F msg.txt'
  assert_decision deny 'commit messages are inline with -m'
  [ "$(printf '%s' "$output" | jq -r '.hookSpecificOutput.hookEventName')" = "PreToolUse" ]
}

@test "hook: the deny payload is exactly what the harness reads" {
  run hook 'git commit -F msg.txt'
  [ "$status" -eq 0 ]
  [ "$output" = '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"bash-policy refuses this: commit messages are inline with -m; a message file hides the text from the commit-message hook [rule: git commit -F]"}}' ]
}

@test "hook: emits nothing for an allowed command" {
  run hook 'bin/rails db:version'
  assert_no_decision
  [ -z "$output" ]
}

@test "hook: emits the ask decision and logs it" {
  run hook 'bin/rails db:migrate'
  assert_decision ask 'changes the development database'
  [ "$(jq -r '.decision' "$(log_file)")" = "ask" ]
}

@test "hook: ignores a tool call that is not Bash" {
  policy_env
  run bash -c 'printf "%s" "$1" | bash "$2"' _ \
    '{"tool_name":"Read","session_id":"s","tool_input":{"file_path":"x"}}' \
    "$SUBJECT_DIR/bash-policy.sh"
  assert_no_decision
  [ -z "$output" ]
}

@test "hook: unparseable stdin fails open with no decision" {
  policy_env
  run bash -c 'printf "%s" "not json at all" | bash "$1"' _ "$SUBJECT_DIR/bash-policy.sh"
  [ "$status" -eq 0 ]
  [[ "$output" != *permissionDecision* ]]
}

@test "hook: a broken policy fails open with one line on stderr" {
  cat > "$TEST_TMPDIR/bad-policy.rb" <<'EOF'
forbid 'git commit'
EOF
  POLICY="$TEST_TMPDIR/bad-policy.rb"
  run hook 'git commit -F msg.txt'
  [ "$status" -eq 0 ]
  assert_output_contains 'the policy engine exited 12'
  [[ "$output" != *permissionDecision* ]]
}

@test "hook: no jq on PATH means one line on stderr, exit 0, no decision" {
  mkdir -p "$TEST_TMPDIR/empty-bin"
  body="$(payload 'git commit -F msg.txt')"
  # bash by absolute path: the point of the test is a PATH with nothing on it.
  run bash -c 'printf "%s" "$1" | PATH="$2" "$4" "$3"' _ \
    "$body" "$TEST_TMPDIR/empty-bin" "$SUBJECT_DIR/bash-policy.sh" "$(command -v bash)"
  [ "$status" -eq 0 ]
  assert_output_contains 'jq not found'
  assert_output_contains 'was not checked'
  [[ "$output" != *permissionDecision* ]]
}

@test "hook: runs through a symlink and still finds its engine" {
  mkdir -p "$TEST_TMPDIR/linked"
  ln -s "$SUBJECT_DIR/bash-policy.sh" "$TEST_TMPDIR/linked/bash-policy.sh"
  policy_env
  run bash -c 'printf "%s" "$1" | bash "$2"' _ \
    "$(payload 'git commit -F msg.txt')" "$TEST_TMPDIR/linked/bash-policy.sh"
  assert_decision deny 'commit messages are inline with -m'
}

# ── Lint ──────────────────────────────────────────────────────────────

@test "shellcheck: the hook and its guards are clean" {
  command -v shellcheck >/dev/null 2>&1 || skip "shellcheck is not installed"
  run shellcheck "$SUBJECT_DIR/bash-policy.sh" "$SUBJECT_DIR"/bash-policy/guards/*.sh
  [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}
