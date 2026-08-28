#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<EOF
Usage: censys-export <query> <format> [output_file]

Export Censys search results in one of three formats.

Formats:
  ips     Plain text, one IP per line
  ndjson  One JSON object per line (ip, asn, country, services)
  csv     Spreadsheet-ready with header row

Uses streaming (-S) to avoid buffering large result sets.
Output goes to stdout unless output_file is given.

Exit codes:
  0  success
  1  usage error or censys CLI failure
EOF
  exit 1
}

[[ $# -lt 2 ]] && usage
query="$1"
format="$2"
outfile="${3:-}"

case "$format" in
  ips|ndjson|csv) ;;
  *) echo "Error: format must be ips, ndjson, or csv (got: $format)" >&2; usage ;;
esac

jq_ips='.host.ip'

jq_ndjson='{
  ip: .host.ip,
  asn: .host.autonomous_system.asn,
  as_name: .host.autonomous_system.name,
  country: .host.location.country_code,
  city: .host.location.city,
  services: [.host.services[]? | {port, protocol, software: [.software[]?.product] | join(",")}]
}'

jq_csv='[
  .host.ip,
  (.host.autonomous_system.asn | tostring),
  .host.autonomous_system.name,
  .host.location.country_code,
  .host.location.city,
  ([.host.services[]?.port | tostring] | join(";"))
] | @csv'

run_export() {
  case "$format" in
    ips)
      censys search "$query" --max-pages -1 -S 2>/dev/null | jq -r "$jq_ips"
      ;;
    ndjson)
      censys search "$query" --max-pages -1 -S 2>/dev/null | jq -c "$jq_ndjson"
      ;;
    csv)
      echo "ip,asn,as_name,country,city,ports"
      censys search "$query" --max-pages -1 -S 2>/dev/null | jq -r "$jq_csv"
      ;;
  esac
}

if [[ -n "$outfile" ]]; then
  run_export > "$outfile"
  lines=$(wc -l < "$outfile" | tr -d ' ')
  echo "Wrote $lines lines to $outfile" >&2
else
  run_export
fi
