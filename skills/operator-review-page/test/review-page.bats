#!/usr/bin/env bats
# Tests for skills/operator-review-page/review-page. Every test writes
# its own review file under $TEST_TMPDIR; the bundled template is the
# one under test.

load ../../../test/test_helper

cmd() {
  echo "$SUBJECT_DIR/review-page"
}

write_review() {
  cat > "$TEST_TMPDIR/review.json" <<'EOF'
{
  "title": "Vocabulary review",
  "source": "data/vocabulary.json",
  "source_line": "Review of data/vocabulary.json.",
  "storage_key": "test-review-v1",
  "built": "2026-11-05",
  "decisions_file": "vocabulary-decisions.json",
  "kinds": {"merge": "merge", "disagree": "disagreement"},
  "open_notes": ["merge"],
  "items": [
    {"item": "merge:position-dog", "kind": "merge", "entry": "position-dog",
     "name": "Position Dog", "variants": ["Dog", "LZ English"],
     "question": "Position Dog and LZ English are one place?",
     "options": ["Keep merged", "Split into two entries", "Unsure"],
     "current": "Keep merged",
     "notes": "Renamed once built.",
     "evidence": [{"page": 26, "text": "the position would be renamed LZ English </script> here"},
                  {"ref": "CHECO #150 p.32", "text": "a report line"}]},
    {"item": "disagree:lz-bird", "kind": "disagree", "name": "LZ Bird",
     "question": "Which placement stands?",
     "options": ["BR 747 816", "BR 732 810", "Unsure"], "current": null}
  ]
}
EOF
}

@test "fills the template with the review and reports counts by kind" {
  write_review
  run "$(cmd)" "$TEST_TMPDIR/review.json" "$TEST_TMPDIR/out.html"
  [ "$status" -eq 0 ]
  assert_output_contains "2 items (1 merge, 1 disagree)"
  grep -q '"storage_key":"test-review-v1"' "$TEST_TMPDIR/out.html"
  ! grep -qF '/*REVIEW*/' "$TEST_TMPDIR/out.html"
}

@test "escapes a closing tag inside the embedded JSON" {
  write_review
  run "$(cmd)" "$TEST_TMPDIR/review.json" "$TEST_TMPDIR/out.html"
  [ "$status" -eq 0 ]
  grep -qF 'LZ English <\/script> here' "$TEST_TMPDIR/out.html"
  [ "$(grep -c '</script>' "$TEST_TMPDIR/out.html")" -eq 2 ]
}

@test "--check validates and writes nothing" {
  write_review
  run "$(cmd)" "$TEST_TMPDIR/review.json" --check
  [ "$status" -eq 0 ]
  assert_output_contains "valid, 2 items"
  [ ! -e "$TEST_TMPDIR/out.html" ]
}

@test "names every broken rule and exits 11" {
  cat > "$TEST_TMPDIR/review.json" <<'EOF'
{"title": "R", "source": "x.json", "storage_key": "k",
 "items": [
   {"item": "a", "kind": "merge", "name": "A", "question": "Q?", "options": ["Yes"]},
   {"item": "a", "kind": "merge", "name": "B", "question": "Q?", "options": ["Yes", "No"], "current": "Maybe",
    "evidence": [{"text": "no source given"}]}
 ]}
EOF
  run "$(cmd)" "$TEST_TMPDIR/review.json" "$TEST_TMPDIR/out.html"
  [ "$status" -eq 11 ]
  assert_output_contains "options must be a list of at least two choices"
  assert_output_contains "item id repeats item 1"
  assert_output_contains 'current "Maybe" is not one of the options'
  assert_output_contains "needs a ref (string) or a page (integer)"
  [ ! -e "$TEST_TMPDIR/out.html" ]
}

@test "requires a storage key so two reviews never share saved answers" {
  echo '{"title": "R", "source": "x.json", "items": [{"item": "a", "kind": "k", "name": "A", "question": "Q?", "options": ["Yes", "No"]}]}' \
    > "$TEST_TMPDIR/review.json"
  run "$(cmd)" "$TEST_TMPDIR/review.json" --check
  [ "$status" -eq 11 ]
  assert_output_contains "storage_key missing or empty"
}

@test "exits 12 on a file that is not JSON" {
  echo 'not json' > "$TEST_TMPDIR/review.json"
  run "$(cmd)" "$TEST_TMPDIR/review.json" --check
  [ "$status" -eq 12 ]
  assert_output_contains "is not JSON"
}

@test "refuses a template without exactly one placeholder" {
  write_review
  echo '<html>no slot</html>' > "$TEST_TMPDIR/t.html"
  run "$(cmd)" "$TEST_TMPDIR/review.json" "$TEST_TMPDIR/out.html" --template "$TEST_TMPDIR/t.html"
  [ "$status" -eq 11 ]
  assert_output_contains "exactly once"
}

@test "refuses to overwrite its input, and bad arguments exit 10" {
  write_review
  run "$(cmd)" "$TEST_TMPDIR/review.json" "$TEST_TMPDIR/review.json"
  [ "$status" -eq 10 ]
  run "$(cmd)"
  [ "$status" -eq 10 ]
  run "$(cmd)" "$TEST_TMPDIR/review.json" --frobnicate
  [ "$status" -eq 10 ]
}
