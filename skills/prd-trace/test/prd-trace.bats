#!/usr/bin/env bats

load ../../../test/test_helper

fixture_prd() {
  mkdir -p "$TEST_TMPDIR/.development/prd"
  cat > "$TEST_TMPDIR/.development/prd/PRD-0000-template.md" <<'EOF'
---
id: PRD-0000
---
# PRD-0000: template
- **FR-001:**
EOF
  cat > "$TEST_TMPDIR/.development/prd/PRD-0001-widgets.md" <<'EOF'
---
id: PRD-0001
prd_title: Widgets for everyone
---

# PRD-0001: Widgets for everyone

## 9. Functional Requirements

### 9.1 Core Functional Requirements

- **FR-001:** Widgets must be listable.
- **FR-002:** Widgets must be deletable.
- **FR-003:** Widgets must be exportable.
EOF
}

fixture_linked_ticket() {
  local id="$1" dir="$2" status="$3"
  shift 3
  mkdir -p "$TEST_TMPDIR/.development/$dir"
  {
    printf -- '---\nid: DBB-%s\ntitle: Ticket %s\nstatus: %s\nlinks:\n' "$id" "$id" "$status"
    for link in "$@"; do printf '  - %s\n' "$link"; done
    printf -- '---\n\n## Why\nFixture.\n'
  } > "$TEST_TMPDIR/.development/$dir/DBB-${id}-fixture.md"
}

setup_repo() {
  fixture_prd
  fixture_linked_ticket 0001 done done "PRD-0001 FR-001"
  fixture_linked_ticket 0002 backlog backlog "PRD-0001 FR-001, FR-002"
  fixture_linked_ticket 0003 done done "PRD-0001"
  fixture_linked_ticket 0004 active in_progress "PRD-0001 FR-009"
  fixture_linked_ticket 0005 done done "https://example.com/unrelated"
}

@test "maps requirements to the tickets that cite them" {
  setup_repo
  run "$SUBJECT_DIR/prd-trace" -C "$TEST_TMPDIR"
  [ "$status" -eq 0 ]
  assert_output_contains "PRD-0001  Widgets for everyone"
  assert_output_contains "DBB-0001 done, DBB-0002 backlog"
  assert_output_contains "No ticket yet: FR-003"
  assert_output_contains "Cites the PRD, no requirement: DBB-0003 done"
  assert_output_contains "Unknown requirement: DBB-0004 -> FR-009"
}

@test "FR-002 cited on a shared line traces to the same ticket" {
  setup_repo
  run "$SUBJECT_DIR/prd-trace" -C "$TEST_TMPDIR"
  [[ "$output" == *"FR-002"*"DBB-0002 backlog"* ]]
}

@test "--table emits the Appendix D shape with a rollup status" {
  setup_repo
  run "$SUBJECT_DIR/prd-trace" -C "$TEST_TMPDIR" --table
  [ "$status" -eq 0 ]
  assert_output_contains "| Requirement ID | Section | Related Story / Ticket |"
  assert_output_contains "| FR-001 | 9.1 | DBB-0001, DBB-0002 |  |  | planned |"
  assert_output_contains "| FR-003 | 9.1 |  |  |  | none |"
}

@test "--json is valid JSON carrying ticket edges" {
  setup_repo
  run "$SUBJECT_DIR/prd-trace" -C "$TEST_TMPDIR" --json
  [ "$status" -eq 0 ]
  echo "$output" | ruby -rjson -e 'd = JSON.parse($stdin.read); exit(d[0]["requirements"][0]["tickets"].map { |t| t["id"] } == %w[DBB-0001 DBB-0002] ? 0 : 1)'
}

@test "filters to one PRD and exits 3 when none matches" {
  setup_repo
  run "$SUBJECT_DIR/prd-trace" -C "$TEST_TMPDIR" PRD-0001
  [ "$status" -eq 0 ]
  run "$SUBJECT_DIR/prd-trace" -C "$TEST_TMPDIR" PRD-0042
  [ "$status" -eq 3 ]
}

@test "the template PRD is never reported" {
  setup_repo
  run "$SUBJECT_DIR/prd-trace" -C "$TEST_TMPDIR"
  [[ "$output" != *"PRD-0000"* ]]
}

@test "exits 12 without a .development tree and on bad arguments" {
  run "$SUBJECT_DIR/prd-trace" -C "$TEST_TMPDIR"
  [ "$status" -eq 12 ]
  setup_repo
  run "$SUBJECT_DIR/prd-trace" -C "$TEST_TMPDIR" not-a-prd
  [ "$status" -eq 12 ]
}
