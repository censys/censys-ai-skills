#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURES="$SCRIPT_DIR/fixtures"
SCRIPT="$REPO_DIR/scripts/censys-count.sh"
TMPDIR="${TMPDIR:-/tmp}"
TEST_DIR=$(mktemp -d "$TMPDIR/censys-count-test.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT

pass=0
fail=0

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $label"
    pass=$((pass + 1))
  else
    echo "  FAIL: $label (expected '$expected', got '$actual')"
    fail=$((fail + 1))
  fi
}

assert_exit() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" -eq "$actual" ]]; then
    echo "  PASS: $label"
    pass=$((pass + 1))
  else
    echo "  FAIL: $label (expected exit $expected, got $actual)"
    fail=$((fail + 1))
  fi
}

# Create a mock censys binary that returns fixture data
mock_censys() {
  local fixture="$1"
  cat > "$TEST_DIR/censys" <<MOCK
#!/usr/bin/env bash
cat "$fixture"
MOCK
  chmod +x "$TEST_DIR/censys"
}

# Create a mock that returns N identical records (for ceiling test)
mock_censys_n() {
  local n="$1"
  cat > "$TEST_DIR/censys" <<MOCK
#!/usr/bin/env bash
n=$n
printf '['
for ((i=0; i<n; i++)); do
  [[ \$i -gt 0 ]] && printf ','
  printf '{"host":{"ip":"203.0.113.%d"}}' \$((i % 256))
done
printf ']'
MOCK
  chmod +x "$TEST_DIR/censys"
}

echo "=== censys-count.sh tests ==="

echo ""
echo "--- Test: counts 3 hosts correctly ---"
mock_censys "$FIXTURES/search_results_3.json"
output=$(PATH="$TEST_DIR:$PATH" bash "$SCRIPT" "test-query" 2>/dev/null)
assert_eq "count is 3" "3" "$output"

echo ""
echo "--- Test: exit 0 when count < ceiling ---"
mock_censys "$FIXTURES/search_results_3.json"
set +e
PATH="$TEST_DIR:$PATH" bash "$SCRIPT" "test-query" >/dev/null 2>&1
exit_code=$?
set -e
assert_exit "exit code 0 for normal count" 0 "$exit_code"

echo ""
echo "--- Test: detects 10000-result ceiling ---"
mock_censys_n 10000
set +e
output=$(PATH="$TEST_DIR:$PATH" bash "$SCRIPT" "test-query" 2>"$TEST_DIR/stderr.txt")
exit_code=$?
set -e
assert_eq "count is 10000" "10000" "$output"
assert_exit "exit code 2 at ceiling" 2 "$exit_code"
stderr=$(cat "$TEST_DIR/stderr.txt")
if [[ "$stderr" == *"ceiling"* ]]; then
  echo "  PASS: stderr contains ceiling warning"
  pass=$((pass + 1))
else
  echo "  FAIL: stderr missing ceiling warning (got: $stderr)"
  fail=$((fail + 1))
fi

echo ""
echo "--- Test: custom page-size changes ceiling ---"
mock_censys_n 5000
set +e
output=$(PATH="$TEST_DIR:$PATH" bash "$SCRIPT" "test-query" --page-size 50 2>"$TEST_DIR/stderr.txt")
exit_code=$?
set -e
assert_eq "count is 5000" "5000" "$output"
assert_exit "exit code 2 at ceiling (50*100=5000)" 2 "$exit_code"

echo ""
echo "--- Test: no arguments prints usage ---"
set +e
PATH="$TEST_DIR:$PATH" bash "$SCRIPT" 2>"$TEST_DIR/stderr.txt"
exit_code=$?
set -e
assert_exit "exit code 1 on no args" 1 "$exit_code"
stderr=$(cat "$TEST_DIR/stderr.txt")
if [[ "$stderr" == *"Usage"* ]]; then
  echo "  PASS: stderr contains usage"
  pass=$((pass + 1))
else
  echo "  FAIL: stderr missing usage (got: $stderr)"
  fail=$((fail + 1))
fi

echo ""
echo "--- Test: handles empty result (null → 0) ---"
cat > "$TEST_DIR/censys" <<'MOCK'
#!/usr/bin/env bash
echo "null"
MOCK
chmod +x "$TEST_DIR/censys"
set +e
output=$(PATH="$TEST_DIR:$PATH" bash "$SCRIPT" "test-query" 2>/dev/null)
exit_code=$?
set -e
assert_eq "null returns count 0" "0" "$output"
assert_exit "exit code 0 on null (zero results)" 0 "$exit_code"

echo ""
echo "--- Test: handles truly empty output ---"
cat > "$TEST_DIR/censys" <<'MOCK'
#!/usr/bin/env bash
true
MOCK
chmod +x "$TEST_DIR/censys"
set +e
PATH="$TEST_DIR:$PATH" bash "$SCRIPT" "test-query" >/dev/null 2>&1
exit_code=$?
set -e
assert_exit "exit code 1 on empty output" 1 "$exit_code"

echo ""
echo "=== Results: $pass passed, $fail failed ==="
[[ $fail -eq 0 ]] && exit 0 || exit 1
