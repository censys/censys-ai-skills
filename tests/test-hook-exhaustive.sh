#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK="$REPO_DIR/hooks/check-exhaustive-search.sh"

# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

run_hook() {
  local cmd="$1"
  jq -n --arg c "$cmd" '{"tool_input":{"command":$c}}' | bash "$HOOK" 2>/dev/null
}

echo "=== check-exhaustive-search.sh hook tests ==="

echo ""
echo "--- Test: exhaustive without -S warns about streaming ---"
output=$(run_hook 'censys search "host.services.port=443" --max-pages -1 -O json')
assert_contains "warns about streaming" "without -S" "$output"
assert_contains "warns about credits" "10,000 results" "$output"

echo ""
echo "--- Test: exhaustive with -S only warns about credits ---"
output=$(run_hook 'censys search "host.services.port=443" --max-pages -1 -S')
assert_not_contains "no streaming warning" "without -S" "$output"
assert_contains "warns about credits" "10,000 results" "$output"

echo ""
echo "--- Test: exhaustive with --streaming only warns about credits ---"
output=$(run_hook 'censys search "host.services.port=443" --max-pages -1 --streaming')
assert_not_contains "no streaming warning" "without -S" "$output"
assert_contains "warns about credits" "10,000 results" "$output"

echo ""
echo "--- Test: exhaustive with -p -1 alias ---"
output=$(run_hook 'censys search "host.services.port=443" -p -1 -O json')
assert_contains "recognizes -p alias" "without -S" "$output"

echo ""
echo "--- Test: non-exhaustive search is silent ---"
output=$(run_hook 'censys search "host.services.port=443" --max-pages 5')
assert_empty "no output for bounded search" "$output"

echo ""
echo "--- Test: non-censys command is silent ---"
output=$(run_hook 'git status')
assert_empty "no output for git" "$output"

echo ""
echo "--- Test: censys view is silent ---"
output=$(run_hook 'censys view 8.8.8.8 -O json')
assert_empty "no output for view" "$output"

echo ""
echo "--- Test: censys aggregate is silent ---"
output=$(run_hook 'censys aggregate "host.services.port=443" host.location.country')
assert_empty "no output for aggregate" "$output"

echo ""
echo "--- Test: always exits 0 (advisory, not blocking) ---"
set +e
echo '{"tool_input":{"command":"censys search \"x\" --max-pages -1"}}' | bash "$HOOK" >/dev/null 2>&1
exit_code=$?
set -e
assert_exit "exit 0 on warning" 0 "$exit_code"

set +e
echo '{"tool_input":{"command":"git status"}}' | bash "$HOOK" >/dev/null 2>&1
exit_code=$?
set -e
assert_exit "exit 0 on no-op" 0 "$exit_code"

echo ""
echo "=== Results: $pass passed, $fail failed ==="
[[ $fail -eq 0 ]] && exit 0 || exit 1
