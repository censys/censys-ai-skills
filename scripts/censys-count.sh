#!/usr/bin/env bash
set -euo pipefail

PAGE_SIZE=100
MAX_PAGES=100
CEILING=$((PAGE_SIZE * MAX_PAGES))

usage() {
  cat >&2 <<EOF
Usage: censys-count <query> [--page-size N]

Count hosts matching a CenQL query via censys search.

The Censys API returns at most $MAX_PAGES pages. At page-size $PAGE_SIZE
that ceiling is $CEILING results — returned with no warning. This script
detects the ceiling and prints a warning to stderr.

Output (stdout): the integer count
Exit codes:
  0  success
  1  usage error or censys CLI failure
  2  count hit the ceiling — the number is a floor, not a total
EOF
  exit 1
}

[[ $# -lt 1 ]] && usage
query="$1"; shift

page_size=$PAGE_SIZE
while [[ $# -gt 0 ]]; do
  case "$1" in
    --page-size) page_size="${2:?--page-size requires a value}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown argument: $1" >&2; usage ;;
  esac
done

ceiling=$((page_size * MAX_PAGES))

stderr_file=$(mktemp "${TMPDIR:-/tmp}/censys-count-stderr.XXXXXX")
trap 'rm -f "$stderr_file"' EXIT
raw=$(censys search "$query" --max-pages -1 --page-size "$page_size" -O json 2>"$stderr_file") || true

if [[ -z "$raw" ]]; then
  if [[ -s "$stderr_file" ]]; then
    cat "$stderr_file" >&2
  else
    echo "Error: censys search returned no output" >&2
  fi
  exit 1
fi

count=$(printf '%s' "$raw" | jq 'if type == "array" then length elif . == null then 0 else error("unexpected type") end')

if [[ -z "$count" ]]; then
  echo "Error: censys search returned no parseable output" >&2
  exit 1
fi

echo "$count"

if [[ "$count" -eq "$ceiling" ]]; then
  echo "WARNING: count equals the ${ceiling}-result ceiling (${MAX_PAGES} pages × ${page_size}/page)." >&2
  echo "The true count is higher — treat $count as a floor, not a total." >&2
  exit 2
fi
