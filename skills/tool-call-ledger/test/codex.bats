#!/usr/bin/env bats

load ../../../test/test_helper

isolate() {
  mkdir -p "$TEST_TMPDIR/skills"
  echo '{"permissions":{"allow":[]}}' > "$TEST_TMPDIR/settings.json"
  ISOLATED=(--root "$TEST_TMPDIR" --settings "$TEST_TMPDIR/settings.json" --skills "$TEST_TMPDIR/skills")
}

ledger() {
  "$SUBJECT_DIR/tool-call-ledger.rb" "${ISOLATED[@]}" --all --transcripts "$@"
}

@test "Codex completed items include nested commands once and ignore output" {
  isolate
  cat > "$TEST_TMPDIR/session.jsonl" <<'EOF'
{"type":"session_meta","payload":{"id":"codex-one","cwd":"/r"}}
{"type":"response_item","payload":{"type":"custom_tool_call","name":"exec","call_id":"wrapper","input":"do not evaluate me"}}
{"type":"response_item","payload":{"type":"function_call","name":"exec_command","call_id":"direct","arguments":"{\"cmd\":\"git status --short\"}"}}
{"timestamp":"2026-11-02T10:00:00Z","type":"event_msg","payload":{"type":"item_completed","item":{"type":"CommandExecution","id":"exec-one","command":["/bin/zsh","-lc","git status --short"],"cwd":"file:///r","status":"completed","aggregated_output":"private output"}}}
{"timestamp":"2026-11-02T10:01:00Z","type":"event_msg","payload":{"type":"item_completed","item":{"type":"CommandExecution","id":"exec-one","command":["/bin/zsh","-lc","git status --short"],"cwd":"file:///r","status":"completed"}}}
{"timestamp":"2026-11-02T10:02:00Z","type":"event_msg","payload":{"type":"item_completed","item":{"type":"CommandExecution","id":"exec-two","command":["/bin/bash","-c","git status --short"],"status":"failed","exit_code":1}}}
{"type":"event_msg","payload":{"type":"item_completed","item":{"type":"FileChange","id":"patch","changes":{"secret":"private diff"}}}}
{"type":"response_item","payload":{"type":"custom_tool_call_output","output":"private result"}}
EOF
  run ledger "$TEST_TMPDIR/session.jsonl"
  [ "$status" -eq 0 ]
  assert_output_contains "2 recorded tool requests; 2 completed shell executions (including failures)"
  assert_output_contains "   2×  git status --short"
  assert_output_contains "2 records, 1 shapes, 1 reported"
  [[ "$output" != *"private"* ]]
  [[ "$output" != *"do not evaluate"* ]]
}

@test "Codex direct calls work without completion events and retain command quoting" {
  isolate
  cat > "$TEST_TMPDIR/session.jsonl" <<'EOF'
{"type":"session_meta","payload":{"id":"direct-session","cwd":"/r"}}
{"timestamp":"2026-11-02T10:00:00Z","type":"response_item","payload":{"type":"function_call","name":"functions.exec_command","call_id":"one","arguments":"{\"cmd\":\"scripts/inspect 'book title'\",\"workdir\":\"/r/books\"}"}}
{"type":"response_item","payload":{"type":"function_call","name":"shell_command","call_id":"two","arguments":{"command":"scripts/inspect another"}}}
{"type":"response_item","payload":{"type":"function_call","name":"shell","call_id":"three","arguments":"{\"command\":[\"/bin/zsh\",\"-lc\",\"scripts/inspect last\"]}"}}
{"type":"response_item","payload":{"type":"function_call","name":"write_stdin","call_id":"poll","arguments":"{\"chars\":\"\"}"}}
EOF
  run ledger "$TEST_TMPDIR/session.jsonl"
  [ "$status" -eq 0 ]
  assert_output_contains "4 recorded tool requests; 3 shell requests (completion unknown)"
  assert_output_contains "   3×  scripts/inspect <arg>"
  assert_output_contains "scripts/inspect 'book title'"
  assert_output_contains "→ review rule: scripts/inspect (Codex rules and sandbox permissions are not inspected)"
}

@test "orchestration without command events is reported as incomplete and never evaluated" {
  isolate
  cat > "$TEST_TMPDIR/session.jsonl" <<'EOF'
{"type":"response_item","payload":{"type":"custom_tool_call","name":"exec","call_id":"one","input":"await tools.exec_command({cmd: 'touch should-not-exist'})"}}
{"type":"response_item","payload":{"type":"function_call","name":"wait","call_id":"two","arguments":"{}"}}
EOF
  run ledger "$TEST_TMPDIR/session.jsonl"
  [ "$status" -eq 11 ]
  assert_output_contains "2 recorded tool requests; 0 shell requests (completion unknown)"
  assert_output_contains "embedded JavaScript is not evaluated or counted as shell execution"
  [ ! -e should-not-exist ]
}

@test "Claude Bash grants cannot mark Codex commands allowed or covered" {
  isolate
  echo '{"permissions":{"allow":["Bash(scripts/inspect *)"]}}' > "$TEST_TMPDIR/settings.json"
  mkdir -p "$TEST_TMPDIR/skills/inspect"
  printf -- '---\nname: inspect\nallowed-tools: Bash(scripts/inspect*)\n---\n' > "$TEST_TMPDIR/skills/inspect/SKILL.md"
  echo '{"type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{\"cmd\":\"scripts/inspect a\"}"}}' > "$TEST_TMPDIR/session.jsonl"
  run ledger "$TEST_TMPDIR/session.jsonl"
  [ "$status" -eq 0 ]
  assert_output_contains "→ review rule: scripts/inspect"
  [[ "$output" != *"→ allowed:"* ]]
  [[ "$output" != *"→ covered:"* ]]
}

mixed_history() {
  mkdir -p "$TEST_TMPDIR/history/2026/11/02"
  cat > "$TEST_TMPDIR/history/claude.jsonl" <<'EOF'
{"type":"assistant","sessionId":"claude-one","message":{"content":[{"type":"tool_use","name":"Bash","id":"one","input":{"command":"scripts/inspect a"}}]}}
EOF
  cat > "$TEST_TMPDIR/history/2026/11/02/codex.jsonl" <<'EOF'
{"type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{\"cmd\":\"scripts/inspect b\"}"}}
{"type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"malformed"}}
null
{"type":
EOF
}

@test "--recursive reads mixed clients across nested rollout directories" {
  isolate; mixed_history
  run ledger "$TEST_TMPDIR/history" --recursive
  [ "$status" -eq 0 ]
  assert_output_contains "2 records, 1 shapes, 1 reported"
  assert_output_contains "sessions 2"
}

@test "without --recursive a directory reads only its own jsonl, as before" {
  isolate; mixed_history
  run ledger "$TEST_TMPDIR/history"
  [ "$status" -eq 0 ]
  assert_output_contains "1 records, 1 shapes, 1 reported"
  [[ "$output" != *"Codex"* ]]
}

@test "a Claude grant on a state-changing verb still reports allowed, as before" {
  isolate
  echo '{"permissions":{"allow":["Bash(git commit *)"]}}' > "$TEST_TMPDIR/settings.json"
  echo '{"ts":"2026-11-02T10:00:00Z","command":"git commit -m fix"}' > "$TEST_TMPDIR/ledger.jsonl"
  run "$SUBJECT_DIR/tool-call-ledger.rb" "${ISOLATED[@]}" --all "$TEST_TMPDIR/ledger.jsonl"
  [ "$status" -eq 0 ]
  assert_output_contains "→ allowed: Bash(git commit *)"
}

@test "a Codex state-changing verb keeps prompting despite a Claude grant" {
  isolate
  echo '{"permissions":{"allow":["Bash(git commit *)"]}}' > "$TEST_TMPDIR/settings.json"
  echo '{"type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{\"cmd\":\"git commit -m fix\"}"}}' > "$TEST_TMPDIR/session.jsonl"
  run ledger "$TEST_TMPDIR/session.jsonl"
  [ "$status" -eq 0 ]
  assert_output_contains "→ keep prompting: changes state"
  [[ "$output" != *"→ allowed:"* ]]
}

@test "completed argv preserves spaces and file URI cwd without reading results" {
  isolate
  cat > "$TEST_TMPDIR/session.jsonl" <<'EOF'
{"type":"session_meta","payload":{"id":"uri-session","cwd":"/fallback"}}
{"timestamp":"2026-11-02T10:00:00Z","type":"event_msg","payload":{"type":"item_completed","item":{"type":"CommandExecution","id":"one","cwd":"file:///r/book%20titles","command":["scripts/inspect","a b"],"aggregated_output":"private"}}}
EOF
  run ruby -rjson -r "$SUBJECT_DIR/tool-call-ledger.rb" -e 'r=Ledger::Reader.transcript(ARGV[0]).first; puts({cwd:r.cwd, command:r.command, client:r.client}.to_json)' "$TEST_TMPDIR/session.jsonl"
  [ "$status" -eq 0 ]
  assert_output_contains '"cwd":"/r/book titles"'
  assert_output_contains '"client":"codex"'
  [[ "$output" != *"private"* ]]
}
