#!/usr/bin/env bats
# Tests for skills/tool-call-ledger/tool-call-ledger.rb and the hook that
# feeds it. Every test builds its own ledger, settings, and skills
# fixtures under $TEST_TMPDIR; no real transcript or settings is read.

load ../../../test/test_helper

script() {
  echo "$SUBJECT_DIR/tool-call-ledger.rb"
}

hook() {
  echo "$SUBJECT_DIR/../../hooks/tool-call-ledger.sh"
}

# Empty settings + empty skills so the defaults under $HOME never leak in.
isolate() {
  mkdir -p "$TEST_TMPDIR/skills"
  echo '{"permissions":{"allow":[]}}' > "$TEST_TMPDIR/settings.json"
  ISOLATED=(--root "$TEST_TMPDIR" --settings "$TEST_TMPDIR/settings.json" --skills "$TEST_TMPDIR/skills")
}

rec() { # ts command
  printf '{"ts":"%s","cwd":"/r","session":"s1","command":%s}\n' "$1" "$(printf '%s' "$2" | ruby -rjson -e 'print STDIN.read.to_json')"
}

write_ledger() {
  {
    rec 2026-09-02T10:00:00Z "git diff --cached --stat"
    rec 2026-09-02T11:00:00Z "git diff --cached --stat"
    rec 2026-09-02T12:00:00Z "git diff --cached --stat"
    rec 2026-09-02T10:05:00Z "grep -E '^rows' a.txt | awk -F'[/:]' '{print \$3}' | sort | uniq -c"
    rec 2026-09-02T13:05:00Z "grep -E '^rows' b.txt | awk -F'[/:]' '{print \$3}' | sort | uniq -c"
    rec 2026-09-02T14:05:00Z "grep -E '^rows' c.txt | awk -F'[/:]' '{print \$3}' | sort | uniq -c"
    rec 2026-09-02T15:00:00Z "SHOT_DIR=/tmp/a node walk.mjs 2>&1 | tail -3"
    rec 2026-09-02T15:01:00Z "SHOT_DIR=/tmp/b node walk.mjs 2>&1 | tail -3"
    rec 2026-09-02T15:02:00Z "SHOT_DIR=/tmp/c node walk.mjs 2>&1 | tail -3"
    rec 2026-09-02T16:00:00Z "git -C ~/src/other add a"
    rec 2026-09-02T16:01:00Z "git -C ~/src/other add b"
    rec 2026-09-02T16:02:00Z "git -C ~/src/other add c"
    rec 2026-09-02T17:00:00Z "git -C ~/src/other commit -m 'a'"
    rec 2026-09-02T17:01:00Z "git -C ~/src/other commit -m 'b'"
    rec 2026-09-02T17:02:00Z "git -C ~/src/other commit -m 'c'"
    rec 2026-09-02T10:10:00Z "git commit -m 'x'"
    rec 2026-09-02T10:11:00Z "git commit -m 'y'"
    rec 2026-09-02T10:12:00Z "git commit -m 'z'"
    rec 2026-09-02T10:20:00Z "ls scripts"
    rec 2026-09-02T10:21:00Z "ls spec"
    rec 2026-09-02T10:30:00Z "scripts/lines a.rb 1-3"
    rec 2026-09-02T10:31:00Z "scripts/lines b.rb 4"
    rec 2026-09-02T10:32:00Z "scripts/lines c.rb 9"
  } > "$TEST_TMPDIR/ledger.jsonl"
}

@test "--help exits 0" {
  run "$(script)" --help
  [ "$status" -eq 0 ]
  assert_output_contains "Usage:"
}

@test "unknown option exits 10" {
  run "$(script)" --bogus
  [ "$status" -eq 10 ]
}

@test "missing ledger exits 11 with the hook hint" {
  isolate
  run "$(script)" "${ISOLATED[@]}" "$TEST_TMPDIR/absent.jsonl"
  [ "$status" -eq 11 ]
  assert_output_contains "no ledger at"
  assert_output_contains "register hooks/tool-call-ledger.sh"
}

@test "clusters by shape: same command three times is one 3× block" {
  isolate; write_ledger
  run "$(script)" "${ISOLATED[@]}" "$TEST_TMPDIR/ledger.jsonl"
  [ "$status" -eq 0 ]
  assert_output_contains "   3×  git diff --cached --stat"
  assert_output_contains "first 2026-09-02 10:00  last 2026-09-02 12:00  sessions 1"
}

@test "positional args fold: three different files are one pipeline shape" {
  isolate; write_ledger
  run "$(script)" "${ISOLATED[@]}" "$TEST_TMPDIR/ledger.jsonl"
  assert_output_contains "   3×  grep -E <args> | awk -F<v> <arg> | sort | uniq -c"
}

@test "an env-var prefix is not the verb, and 2>&1 takes no operand" {
  isolate; write_ledger
  run "$(script)" "${ISOLATED[@]}" "$TEST_TMPDIR/ledger.jsonl"
  assert_output_contains "   3×  SHOT_DIR=<v> node 2>&1 <arg> | tail -3"
}

@test "an env-var prefix without a chain still proposes a wrapper, not a rule" {
  isolate
  {
    rec 2026-09-02T10:00:00Z "SHOT_DIR=/tmp/a node walk.mjs"
    rec 2026-09-02T10:01:00Z "SHOT_DIR=/tmp/b node walk.mjs"
    rec 2026-09-02T10:02:00Z "SHOT_DIR=/tmp/c node walk.mjs"
  } > "$TEST_TMPDIR/env.jsonl"
  run "$(script)" "${ISOLATED[@]}" "$TEST_TMPDIR/env.jsonl"
  assert_output_contains "   3×  SHOT_DIR=<v> node <arg>"
  assert_output_contains "→ new tool: an env-var prefix never matches a rule"
}

@test "git -C DIR keeps the subcommand, so the proposal is not the blanket grant" {
  isolate; write_ledger
  run "$(script)" "${ISOLATED[@]}" "$TEST_TMPDIR/ledger.jsonl"
  assert_output_contains "   3×  git -C <v> add <arg>"
  assert_output_contains "→ allowlist: Bash(git add *)"
}

@test "git -C DIR commit is still a state change, not an allowlist proposal" {
  isolate; write_ledger
  run "$(script)" "${ISOLATED[@]}" "$TEST_TMPDIR/ledger.jsonl"
  assert_output_contains "   3×  git -C <v> commit -m <arg>"
  [[ "$output" != *"→ allowlist: Bash(git commit *)"* ]]
}

@test "a rule that exists but cannot match this form is called out" {
  isolate; write_ledger
  echo '{"permissions":{"allow":["Bash(git add *)"]}}' > "$TEST_TMPDIR/settings.json"
  run "$(script)" "${ISOLATED[@]}" "$TEST_TMPDIR/ledger.jsonl"
  assert_output_contains "→ use instead: Bash(git add *) exists but this form does not match it"
}

@test "a pipeline whose first segment is allowed is not thereby allowed" {
  isolate; write_ledger
  echo '{"permissions":{"allow":["Bash(grep *)"]}}' > "$TEST_TMPDIR/settings.json"
  run "$(script)" "${ISOLATED[@]}" "$TEST_TMPDIR/ledger.jsonl"
  [[ "$output" != *"→ allowed: Bash(grep *)"* ]]
}

@test "a pipeline with no rule and no skill proposes a new tool" {
  isolate; write_ledger
  run "$(script)" "${ISOLATED[@]}" "$TEST_TMPDIR/ledger.jsonl"
  assert_output_contains "→ new tool: pipe, chain, or redirect"
}

@test "a state-changing verb keeps prompting whatever the count" {
  isolate; write_ledger
  run "$(script)" "${ISOLATED[@]}" "$TEST_TMPDIR/ledger.jsonl"
  assert_output_contains "   3×  git commit -m <arg>"
  assert_output_contains "→ keep prompting: changes state"
}

@test "a single read-only verb proposes an allowlist line" {
  isolate; write_ledger
  echo '{"permissions":{"allow":[]}}' > "$TEST_TMPDIR/settings.json"
  run "$(script)" "${ISOLATED[@]}" --min 3 "$TEST_TMPDIR/ledger.jsonl"
  # scripts/lines is a hint-free single verb in the isolated fixture
  assert_output_contains "   3×  scripts/lines <args>"
  assert_output_contains "→ allowlist: Bash(scripts/lines *)"
}

@test "an existing allow rule marks the cluster allowed" {
  isolate; write_ledger
  echo '{"permissions":{"allow":["Bash(scripts/lines*)"]}}' > "$TEST_TMPDIR/settings.json"
  run "$(script)" "${ISOLATED[@]}" "$TEST_TMPDIR/ledger.jsonl"
  assert_output_contains "→ allowed: Bash(scripts/lines*)"
}

@test "a skill grant marks the cluster covered by that skill" {
  isolate; write_ledger
  mkdir -p "$TEST_TMPDIR/skills/lines"
  printf -- '---\nname: lines\nallowed-tools: Bash(scripts/lines*)\n---\n' > "$TEST_TMPDIR/skills/lines/SKILL.md"
  run "$(script)" "${ISOLATED[@]}" "$TEST_TMPDIR/ledger.jsonl"
  assert_output_contains "→ covered: lines"
}

@test "a hint routes a known shape to its skill" {
  isolate; write_ledger
  run "$(script)" "${ISOLATED[@]}" "$TEST_TMPDIR/ledger.jsonl"
  assert_output_contains "   3×  git diff --cached --stat"
  assert_output_contains "→ use instead: index-audit"
}

@test "--no-hints shows what would be proposed before the hinted tool existed" {
  isolate; write_ledger
  run "$(script)" "${ISOLATED[@]}" --no-hints "$TEST_TMPDIR/ledger.jsonl"
  [[ "$output" != *"use instead: index-audit"* ]]
  assert_output_contains "→ allowlist: Bash(git diff *)"
}

@test "--policy swaps the judgment: a custom rules file is read, the bundled one is not" {
  isolate; write_ledger
  cat > "$TEST_TMPDIR/policy.rb" <<'EOF'
keep_prompting_for 'scripts/lines'
subcommand_after 'git'
report_shapes_seen_at_least 3
EOF
  run "$(script)" "${ISOLATED[@]}" --policy "$TEST_TMPDIR/policy.rb" "$TEST_TMPDIR/ledger.jsonl"
  [ "$status" -eq 0 ]
  assert_output_contains "   3×  scripts/lines <args>"
  assert_output_contains "→ keep prompting: changes state"
  # the bundled reach_for rules are gone with the bundled policy
  [[ "$output" != *"use instead: index-audit"* ]]
}

@test "a policy the DSL cannot read exits 12 and names the file" {
  isolate; write_ledger
  echo "reach_for_the_moon 'x'" > "$TEST_TMPDIR/bad.rb"
  run "$(script)" "${ISOLATED[@]}" --policy "$TEST_TMPDIR/bad.rb" "$TEST_TMPDIR/ledger.jsonl"
  [ "$status" -eq 12 ]
  assert_output_contains "cannot read policy"
}

@test "the policy's report_shapes_seen_at_least is the default --min" {
  isolate; write_ledger
  printf "report_shapes_seen_at_least 2\n" > "$TEST_TMPDIR/policy.rb"
  run "$(script)" "${ISOLATED[@]}" --policy "$TEST_TMPDIR/policy.rb" "$TEST_TMPDIR/ledger.jsonl"
  assert_output_contains "   2×  ls <arg>"
  assert_output_contains "(min 2)"
}

@test "--min hides small clusters; --all shows them" {
  isolate; write_ledger
  run "$(script)" "${ISOLATED[@]}" "$TEST_TMPDIR/ledger.jsonl"
  [[ "$output" != *"ls <arg>"* ]]
  run "$(script)" "${ISOLATED[@]}" --all "$TEST_TMPDIR/ledger.jsonl"
  assert_output_contains "   2×  ls <arg>"
}

@test "summary line counts records, shapes, and reported clusters" {
  isolate; write_ledger
  run "$(script)" "${ISOLATED[@]}" "$TEST_TMPDIR/ledger.jsonl"
  assert_output_contains "23 records, 8 shapes, 7 reported (min 3)"
}

@test "--transcripts reads Bash tool_use blocks out of transcript jsonl" {
  isolate
  mkdir -p "$TEST_TMPDIR/tx"
  cat > "$TEST_TMPDIR/tx/sess-1.jsonl" <<'EOF'
{"type":"user","message":{"content":"hi"}}
{"type":"assistant","timestamp":"2026-09-02T10:00:00Z","cwd":"/r","sessionId":"sess-1","message":{"content":[{"type":"text","text":"x"},{"type":"tool_use","name":"Bash","input":{"command":"git status --short"}}]}}
{"type":"assistant","timestamp":"2026-09-02T10:01:00Z","cwd":"/r","sessionId":"sess-1","message":{"content":[{"type":"tool_use","name":"Read","input":{"file_path":"a"}},{"type":"tool_use","name":"Bash","input":{"command":"git status --short"}}]}}
not json
{"type":"assistant","timestamp":"2026-09-02T10:02:00Z","cwd":"/r","sessionId":"sess-1","message":{"content":[{"type":"tool_use","name":"Bash","input":{"command":"git status --short"}}]}}
EOF
  run "$(script)" "${ISOLATED[@]}" --transcripts "$TEST_TMPDIR/tx"
  [ "$status" -eq 0 ]
  assert_output_contains "   3×  git status --short"
  assert_output_contains "3 records, 1 shapes, 1 reported"
}

@test "--transcripts on a missing directory exits 11" {
  isolate
  run "$(script)" "${ISOLATED[@]}" --transcripts "$TEST_TMPDIR/nope"
  [ "$status" -eq 11 ]
}

# ── the hook ──────────────────────────────────────────────────────────

@test "hook appends one JSON line per Bash call and exits 0" {
  export CLAUDE_LEDGER_FILE="$TEST_TMPDIR/led.jsonl"
  run bash -c "echo '{\"tool_name\":\"Bash\",\"session_id\":\"abc\",\"cwd\":\"/r\",\"tool_input\":{\"command\":\"git status --short\"}}' | '$(hook)'"
  [ "$status" -eq 0 ]
  [ "$(wc -l < "$CLAUDE_LEDGER_FILE" | tr -d ' ')" -eq 1 ]
  grep -q '"command":"git status --short"' "$CLAUDE_LEDGER_FILE"
  grep -q '"session":"abc"' "$CLAUDE_LEDGER_FILE"
  grep -q '"cwd":"/r"' "$CLAUDE_LEDGER_FILE"
}

@test "hook ignores non-Bash tools and empty commands" {
  export CLAUDE_LEDGER_FILE="$TEST_TMPDIR/led.jsonl"
  bash -c "echo '{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"x\"}}' | '$(hook)'"
  bash -c "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"\"}}' | '$(hook)'"
  [ ! -f "$CLAUDE_LEDGER_FILE" ] || [ "$(wc -l < "$CLAUDE_LEDGER_FILE" | tr -d ' ')" -eq 0 ]
}

@test "hook survives malformed stdin and an unwritable ledger" {
  export CLAUDE_LEDGER_FILE="$TEST_TMPDIR/absent-dir/x/led.jsonl"
  mkdir -p "$TEST_TMPDIR/absent-dir"
  chmod 500 "$TEST_TMPDIR/absent-dir"
  run bash -c "echo 'not json' | '$(hook)'"
  [ "$status" -eq 0 ]
  run bash -c "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"ls\"}}' | '$(hook)'"
  [ "$status" -eq 0 ]
  chmod 700 "$TEST_TMPDIR/absent-dir"
}

@test "hook then skill: a ledger the hook wrote is a ledger the skill reads" {
  isolate
  export CLAUDE_LEDGER_FILE="$TEST_TMPDIR/led.jsonl"
  for _ in 1 2 3; do
    bash -c "echo '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"scripts/lines a.rb 1\"}}' | '$(hook)'"
  done
  run "$(script)" "${ISOLATED[@]}" "$CLAUDE_LEDGER_FILE"
  [ "$status" -eq 0 ]
  assert_output_contains "   3×  scripts/lines <args>"
}
