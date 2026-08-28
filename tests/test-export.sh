#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURES="$SCRIPT_DIR/fixtures"
SCRIPT="$REPO_DIR/scripts/censys-export.sh"
TMPDIR="${TMPDIR:-/tmp}"
TEST_DIR=$(mktemp -d "$TMPDIR/censys-export-test.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT

source "$SCRIPT_DIR/helpers.sh"

# Mock censys that emits NDJSON (simulates -S streaming)
mock_censys_stream() {
  cat > "$TEST_DIR/censys" <<MOCK
#!/usr/bin/env bash
cat "$FIXTURES/ndjson_stream_3.ndjson"
MOCK
  chmod +x "$TEST_DIR/censys"
}

echo "=== censys-export.sh tests ==="

echo ""
echo "--- Test: ips format ---"
mock_censys_stream
output=$(PATH="$TEST_DIR:$PATH" bash "$SCRIPT" "test-query" ips 2>/dev/null)
lines=$(echo "$output" | wc -l | tr -d ' ')
assert_eq "ips: 3 lines" "3" "$lines"
first=$(echo "$output" | head -1)
assert_eq "ips: first IP" "203.0.113.1" "$first"
last=$(echo "$output" | tail -1)
assert_eq "ips: last IP" "203.0.113.3" "$last"

echo ""
echo "--- Test: ndjson format ---"
mock_censys_stream
output=$(PATH="$TEST_DIR:$PATH" bash "$SCRIPT" "test-query" ndjson 2>/dev/null)
lines=$(echo "$output" | wc -l | tr -d ' ')
assert_eq "ndjson: 3 lines" "3" "$lines"
first_ip=$(echo "$output" | head -1 | jq -r '.ip')
assert_eq "ndjson: first ip field" "203.0.113.1" "$first_ip"
first_asn=$(echo "$output" | head -1 | jq -r '.asn')
assert_eq "ndjson: first asn field" "13335" "$first_asn"
first_country=$(echo "$output" | head -1 | jq -r '.country')
assert_eq "ndjson: first country field" "US" "$first_country"
services=$(echo "$output" | head -1 | jq '.services | length')
assert_eq "ndjson: first host has 2 services" "2" "$services"

echo ""
echo "--- Test: csv format ---"
mock_censys_stream
output=$(PATH="$TEST_DIR:$PATH" bash "$SCRIPT" "test-query" csv 2>/dev/null)
header=$(echo "$output" | head -1)
assert_eq "csv: header row" "ip,asn,as_name,country,city,ports" "$header"
lines=$(echo "$output" | wc -l | tr -d ' ')
assert_eq "csv: 4 lines (header + 3 data)" "4" "$lines"
assert_contains "csv: first IP in data" "203.0.113.1" "$(echo "$output" | sed -n '2p')"

echo ""
echo "--- Test: output to file ---"
mock_censys_stream
PATH="$TEST_DIR:$PATH" bash "$SCRIPT" "test-query" ips "$TEST_DIR/out.txt" 2>/dev/null
assert_eq "file: exists" "true" "$([[ -f "$TEST_DIR/out.txt" ]] && echo true || echo false)"
file_lines=$(wc -l < "$TEST_DIR/out.txt" | tr -d ' ')
assert_eq "file: 3 lines" "3" "$file_lines"

echo ""
echo "--- Test: invalid format exits 1 ---"
mock_censys_stream
set +e
PATH="$TEST_DIR:$PATH" bash "$SCRIPT" "test-query" xml 2>/dev/null
exit_code=$?
set -e
assert_exit "exit 1 on invalid format" 1 "$exit_code"

echo ""
echo "--- Test: no arguments prints usage ---"
set +e
bash "$SCRIPT" 2>"$TEST_DIR/stderr.txt"
exit_code=$?
set -e
assert_exit "exit 1 on no args" 1 "$exit_code"
stderr=$(cat "$TEST_DIR/stderr.txt")
assert_contains "stderr has usage" "Usage" "$stderr"

echo ""
echo "=== Results: $pass passed, $fail failed ==="
[[ $fail -eq 0 ]] && exit 0 || exit 1
