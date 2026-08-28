#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURES="$SCRIPT_DIR/fixtures"
SCRIPT="$REPO_DIR/scripts/censys-to-sqlite.sh"
TMPDIR="${TMPDIR:-/tmp}"
TEST_DIR=$(mktemp -d "$TMPDIR/censys-sqlite-test.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT

source "$SCRIPT_DIR/helpers.sh"

echo "=== censys-to-sqlite.sh tests ==="

echo ""
echo "--- Test: loads 3 records into default table ---"
output=$(bash "$SCRIPT" "$FIXTURES/search_results_3.json" "$TEST_DIR/test1.db" 2>/dev/null)
assert_eq "row count output" "3" "$output"
db_count=$(sqlite3 "$TEST_DIR/test1.db" "SELECT COUNT(*) FROM hosts;")
assert_eq "actual DB row count" "3" "$db_count"

echo ""
echo "--- Test: JSON data is queryable ---"
ip=$(sqlite3 "$TEST_DIR/test1.db" "SELECT json_extract(data, '$.host.ip') FROM hosts LIMIT 1;")
assert_eq "first IP extractable" "203.0.113.1" "$ip"

echo ""
echo "--- Test: json_extract works for nested fields ---"
asn=$(sqlite3 "$TEST_DIR/test1.db" "SELECT json_extract(data, '$.host.autonomous_system.asn') FROM hosts WHERE json_extract(data, '$.host.ip') = '203.0.113.2';")
assert_eq "ASN for .2 host" "16509" "$asn"

echo ""
echo "--- Test: custom table name ---"
output=$(bash "$SCRIPT" "$FIXTURES/search_results_3.json" "$TEST_DIR/test2.db" "scan_results" 2>/dev/null)
assert_eq "row count with custom table" "3" "$output"
db_count=$(sqlite3 "$TEST_DIR/test2.db" "SELECT COUNT(*) FROM scan_results;")
assert_eq "custom table row count" "3" "$db_count"

echo ""
echo "--- Test: appends to existing table ---"
bash "$SCRIPT" "$FIXTURES/search_results_3.json" "$TEST_DIR/test3.db" 2>/dev/null
output=$(bash "$SCRIPT" "$FIXTURES/search_results_3.json" "$TEST_DIR/test3.db" 2>/dev/null)
db_count=$(sqlite3 "$TEST_DIR/test3.db" "SELECT COUNT(*) FROM hosts;")
assert_eq "appended total is 6" "6" "$db_count"

echo ""
echo "--- Test: handles data with single quotes ---"
cat > "$TEST_DIR/quotes.json" <<'EOF'
[{"host":{"ip":"203.0.113.1","name":"Let's Encrypt test O'Brien"}}]
EOF
set +e
output=$(bash "$SCRIPT" "$TEST_DIR/quotes.json" "$TEST_DIR/test4.db" 2>/dev/null)
exit_code=$?
set -e
assert_exit "exit code 0 with quotes in data" 0 "$exit_code"
name=$(sqlite3 "$TEST_DIR/test4.db" "SELECT json_extract(data, '$.host.name') FROM hosts;")
assert_eq "quoted data preserved" "Let's Encrypt test O'Brien" "$name"

echo ""
echo "--- Test: missing file exits 1 ---"
set +e
bash "$SCRIPT" "$TEST_DIR/nonexistent.json" "$TEST_DIR/test5.db" 2>/dev/null
exit_code=$?
set -e
assert_exit "exit code 1 on missing file" 1 "$exit_code"

echo ""
echo "--- Test: no arguments prints usage ---"
set +e
bash "$SCRIPT" 2>"$TEST_DIR/stderr.txt"
exit_code=$?
set -e
assert_exit "exit code 1 on no args" 1 "$exit_code"
stderr=$(cat "$TEST_DIR/stderr.txt")
if [[ "$stderr" == *"Usage"* ]]; then
  echo "  PASS: stderr contains usage"
  pass=$((pass + 1))
else
  echo "  FAIL: stderr missing usage"
  fail=$((fail + 1))
fi

echo ""
echo "--- Test: rejects invalid table name ---"
set +e
PATH="$TEST_DIR:$PATH" bash "$SCRIPT" "$FIXTURES/search_results_3.json" "$TEST_DIR/inject.db" "hosts; DROP TABLE hosts; --" 2>"$TEST_DIR/stderr.txt"
exit_code=$?
set -e
assert_exit "exit code 1 on invalid table" 1 "$exit_code"
stderr=$(cat "$TEST_DIR/stderr.txt")
if [[ "$stderr" == *"invalid table name"* ]]; then
  echo "  PASS: stderr rejects invalid table name"
  pass=$((pass + 1))
else
  echo "  FAIL: stderr missing rejection (got: $stderr)"
  fail=$((fail + 1))
fi

echo ""
echo "=== Results: $pass passed, $fail failed ==="
[[ $fail -eq 0 ]] && exit 0 || exit 1
