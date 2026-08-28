#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
total_pass=0
total_fail=0
failed_suites=()

for test in "$SCRIPT_DIR"/test-*.sh; do
  name=$(basename "$test")
  echo ""
  echo "========================================"
  echo "Running $name"
  echo "========================================"
  set +e
  bash "$test"
  rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    failed_suites+=("$name")
  fi
done

echo ""
echo "========================================"
if [[ ${#failed_suites[@]} -eq 0 ]]; then
  echo "ALL SUITES PASSED"
  exit 0
else
  echo "FAILED SUITES: ${failed_suites[*]}"
  exit 1
fi
