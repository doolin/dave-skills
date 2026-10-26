#!/usr/bin/env bats
# Tests for skills/references/references.
#
# A stub of the reference API (test/stub_api.rb) listens on a free local
# port for the whole file and logs each request it receives, so the tests
# can check both what the tool printed and what it sent. Nothing here
# touches the network or a running dbb server.

load ../../../test/test_helper

setup_file() {
  export STUB_PORT_FILE="$BATS_FILE_TMPDIR/port"
  export STUB_LOG="$BATS_FILE_TMPDIR/requests.jsonl"
  ruby "$BATS_TEST_DIRNAME/stub_api.rb" "$STUB_PORT_FILE" "$STUB_LOG" 3>&- &
  export STUB_PID=$!
  for _ in $(seq 50); do
    [ -s "$STUB_PORT_FILE" ] && return 0
    sleep 0.1
  done
  echo "the stub API did not start" >&2
  return 1
}

teardown_file() {
  kill "$STUB_PID" 2>/dev/null || true
}

refs() {
  REFERENCE_API_URL="http://127.0.0.1:$(cat "$STUB_PORT_FILE")" \
    REFERENCE_API_TOKEN="${TOKEN-good-token}" \
    ruby "$SUBJECT_DIR/references" "$@"
}

# The last request the stub received, as one field.
last_request() {
  tail -n 1 "$STUB_LOG" | jq -r ".$1"
}

# ── Requests ──────────────────────────────────────────────────────────

@test "search sends the query and filters, with the bearer token" {
  run refs search 'margin classifier' --tags ml,perceptron --domain arxiv.org --state read --limit 50
  [ "$status" -eq 0 ]
  [ "$(last_request path)" = "/api/v1/references?q=margin+classifier&tags=ml%2Cperceptron&domain=arxiv.org&reading_state=read&limit=50" ]
  [ "$(last_request authorization)" = "Bearer good-token" ]
}

@test "search with no query or filters lists" {
  run refs search
  [ "$status" -eq 0 ]
  [ "$(last_request path)" = "/api/v1/references" ]
}

@test "show asks for one reference" {
  run refs show 42
  [ "$status" -eq 0 ]
  [ "$(last_request path)" = "/api/v1/references/42" ]
}

@test "content asks for the cached page" {
  run refs content 42
  [ "$status" -eq 0 ]
  [ "$(last_request path)" = "/api/v1/references/42/content" ]
}

# ── Output ────────────────────────────────────────────────────────────

@test "prints the response as pretty JSON" {
  run refs show 42
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf '{\n  "reference": {\n    "id": 42,\n    "title": "Tinian"\n  }\n}')" ]
}

@test "an API error exits 1 and says what the API said" {
  run refs content 43
  [ "$status" -eq 1 ]
  assert_output_contains 'answered 409 no_content: no cached snapshot'
}

@test "a missing reference exits 1 with not_found" {
  run refs show 9
  [ "$status" -eq 1 ]
  assert_output_contains 'answered 404 not_found'
}

@test "a wrong token exits 1 with unauthorized, and the token is not printed" {
  TOKEN=wrong-token run refs search
  [ "$status" -eq 1 ]
  assert_output_contains 'answered 401 unauthorized'
  [[ "$output" != *wrong-token* ]]
}

@test "an error page that is not JSON still exits 1 with the status" {
  run refs show 44
  [ "$status" -eq 1 ]
  assert_output_contains 'answered 500 Internal Server Error: no error message'
}

# ── Refusals before any request ───────────────────────────────────────

@test "no token exits 11 and sends nothing" {
  before="$(wc -l < "$STUB_LOG")"
  TOKEN='' run refs search
  [ "$status" -eq 11 ]
  assert_output_contains 'REFERENCE_API_TOKEN is not set'
  [ "$(wc -l < "$STUB_LOG")" = "$before" ]
}

@test "an unreachable server exits 7 and says so" {
  run env REFERENCE_API_URL=http://127.0.0.1:1 REFERENCE_API_TOKEN=good-token ruby "$SUBJECT_DIR/references" search
  [ "$status" -eq 7 ]
  assert_output_contains 'cannot reach http://127.0.0.1:1'
}

@test "a REFERENCE_API_URL that is not a URL exits 10" {
  run env 'REFERENCE_API_URL=http://bad host' REFERENCE_API_TOKEN=good-token ruby "$SUBJECT_DIR/references" search
  [ "$status" -eq 10 ]
  assert_output_contains 'REFERENCE_API_URL is not a URL'
}

@test "show without a numeric id exits 10" {
  run refs show tinian
  [ "$status" -eq 10 ]
  assert_output_contains 'show takes one numeric ID'
}

@test "two unquoted query words exit 10" {
  run refs search margin classifier
  [ "$status" -eq 10 ]
  assert_output_contains 'at most one QUERY'
}

@test "an unknown option exits 10" {
  run refs search --colour ml
  [ "$status" -eq 10 ]
  assert_output_contains 'invalid option: --colour'
}

@test "an unknown command exits 10" {
  run refs fetch 42
  [ "$status" -eq 10 ]
  assert_output_contains 'unknown command: fetch'
}

@test "no command exits 10" {
  run refs
  [ "$status" -eq 10 ]
  assert_output_contains 'no command given'
}

@test "--help prints the usage and exits 0" {
  run refs --help
  [ "$status" -eq 0 ]
  assert_output_contains 'usage: references search'
}
