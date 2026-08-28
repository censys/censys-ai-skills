#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<EOF
Usage: censys-to-sqlite <json_file> <db_file> [table_name]

Load a JSON array of Censys search results into a SQLite database.
Each array element is stored as a JSON document in a single column.

Requires: sqlite3 >= 3.38 (for json_extract / json_each)
Default table name: hosts

The load runs as a single transaction for performance — one sqlite3
process, not one per row.

Exit codes:
  0  success
  1  usage error, missing dependency, or load failure
EOF
  exit 1
}

[[ $# -lt 2 ]] && usage
json_file="$1"
db_file="$2"
table="${3:-hosts}"

if [[ ! -f "$json_file" ]]; then
  echo "Error: file not found: $json_file" >&2
  exit 1
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "Error: sqlite3 not found in PATH" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq not found in PATH" >&2
  exit 1
fi

sqlite_version=$(sqlite3 --version | awk '{print $1}')
sqlite_major=$(echo "$sqlite_version" | cut -d. -f1)
sqlite_minor=$(echo "$sqlite_version" | cut -d. -f2)
if [[ "$sqlite_major" -lt 3 ]] || { [[ "$sqlite_major" -eq 3 ]] && [[ "$sqlite_minor" -lt 38 ]]; }; then
  echo "Error: sqlite3 >= 3.38 required (found $sqlite_version)" >&2
  exit 1
fi

sqlite3 "$db_file" "CREATE TABLE IF NOT EXISTS ${table} (data JSON);"

jq -c '.[]' "$json_file" | {
  echo "BEGIN TRANSACTION;"
  while IFS= read -r line; do
    printf "INSERT INTO %s VALUES (json('%s'));\n" "$table" "$(printf '%s' "$line" | sed "s/'/''/g")"
  done
  echo "COMMIT;"
} | sqlite3 "$db_file"

row_count=$(sqlite3 "$db_file" "SELECT COUNT(*) FROM ${table};")
echo "Loaded $row_count rows into ${table} in ${db_file}" >&2
echo "$row_count"
