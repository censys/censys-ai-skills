---
name: censys-analyze
description: Use when the user wants to do structured post-retrieval analysis on Censys CLI output — e.g. "censys analyze results," "analyze censys data," "censys jq," "query saved censys data," "censys batch certs," "cross-reference censys results," or "censys post-processing." Teaches saving CLI output to files, jq recipes for filtering/extraction, loading results into SQLite for SQL-style queries, batch certificate workflows, and cross-referencing multiple result sets. Not for generating the underlying data — see censys-search, censys-view, or censys-timeline for that.
version: 0.1.0
---

# censys-analyze

## When to use

Use this skill once Censys CLI output already exists (or is about to be produced) and
the user wants to filter it, transform it, count/group it, join it against another
result set, or run a batch certificate workflow on top of it. Typical asks:

- "censys analyze results, group by country"
- "censys jq to pull out all the IPs"
- "query saved censys data for hosts on port 8443"
- "censys batch certs — pull every fingerprint from this search"
- "cross-reference censys results with the enrichment output"

Do **not** use this to generate the underlying data — that's `censys-search`,
`censys-view`, `censys-enrich`, or `censys-timeline`. This skill is strictly
post-retrieval: it assumes CLI output is already sitting in a file (or about to be
piped to one) and focuses on what to do with it next.

## Core principle

Censys API calls cost credits, count against rate limits, and take time. **Save
results to files, then analyze locally — never re-query the API for data you
already have.** Every pattern below operates on a file already on disk, not on a
live API call. If a second question comes up about the same data ("now show me
just the German ones," "now count by ASN"), reach for `jq` or SQLite against the
saved file before reaching for the CLI again.

## Save-and-reuse pattern

```bash
censys search "host.services.protocol=SSH" --max-pages 5 -O json > /tmp/ssh_hosts.json
censys view 8.8.8.8 -O json > /tmp/host_detail.json
censys enrich --input-file ips.txt -O json > /tmp/enriched.json
censys history 1.2.3.4 --duration 30d -O json > /tmp/timeline.json

# NDJSON streaming for large result sets (one JSON object per line)
censys search "host.services.port=443" --max-pages -1 --streaming > /tmp/https_hosts.ndjson
```

Prefer `--streaming` with NDJSON output for anything over a few thousand results —
it avoids buffering the whole array in memory on either end, and NDJSON is easy to
process a line at a time with `jq -c`.

## jq recipes

CQL search fields and JSON output paths differ for some signals (e.g., cert fingerprint is `host.services.tls.certificates.leaf_fp_sha_256` in CQL but `.tls.fingerprint_sha256` in JSON output). See `censys-cql` for the full mapping table.

Validate first: `jq '.' /tmp/ssh_hosts.json > /dev/null` — a syntax error here means
malformed/truncated JSON, not a bad filter.

```bash
# 1. Extract all IPs from search results
jq -r '.[].host.ip' /tmp/ssh_hosts.json

# 2. Filter hosts by country
jq '[.[] | select(.host.location.country_code == "US")]' /tmp/ssh_hosts.json

# 3. Extract unique cert fingerprints across all services
jq -r '[.[].host.services[]? | .tls?.fingerprint_sha256? // empty] | unique | .[]' \
  /tmp/ssh_hosts.json

# 4. Count hosts per country
jq 'group_by(.host.location.country_code) |
    map({country: .[0].host.location.country_code, count: length}) |
    sort_by(-.count)' /tmp/ssh_hosts.json

# 5. Extract a services summary for one host
jq '.[0].services | map({port, protocol, transport_protocol})' /tmp/host_detail.json

# 6. Filter enrichment results by reputation
jq '[.[] | select(.reputation?.malicious == true)]' /tmp/enriched.json

# 7. NDJSON processing — one object per line, no top-level array
cat /tmp/https_hosts.ndjson | jq -r '.host.ip' | sort -u
cat /tmp/https_hosts.ndjson | jq -c 'select(.host.location.country_code == "DE")'
```

## SQLite loading

For anything that feels like "group by / join / having" rather than a one-shot
filter, load the results into SQLite and use its JSON functions (SQLite 3.38+
required for `json_extract`/`json_each`).

```bash
# Create a table and load search results, one JSON blob per row
sqlite3 /tmp/censys.db "CREATE TABLE IF NOT EXISTS hosts (data JSON);"
jq -c '.[]' /tmp/ssh_hosts.json | while IFS= read -r line; do
  sqlite3 /tmp/censys.db "INSERT INTO hosts VALUES (json('$(echo "$line" | sed "s/'/''/g")'));"
done

# Count hosts per ASN
sqlite3 /tmp/censys.db <<'SQL'
SELECT json_extract(data, '$.host.autonomous_system.asn') AS asn,
       json_extract(data, '$.host.autonomous_system.name') AS as_name,
       COUNT(*) AS host_count
FROM hosts
GROUP BY asn
ORDER BY host_count DESC
LIMIT 20;
SQL

# Find hosts with a specific port open (unnest the services array with json_each)
sqlite3 /tmp/censys.db <<'SQL'
SELECT json_extract(data, '$.host.ip') AS ip
FROM hosts, json_each(json_extract(data, '$.host.services')) AS svc
WHERE json_extract(svc.value, '$.port') = 8443;
SQL
```

Reach for SQLite over jq when the query needs a join across two loaded tables, a
`HAVING`-style post-aggregation filter, or repeated ad-hoc queries against the same
data — jq recompiles the whole filter each run, SQLite lets you query the same
loaded table as many times as needed.

## Batch certificate workflows

```bash
# Extract all unique cert fingerprints from search results
jq -r '[.[].host.services[]? | .tls?.fingerprint_sha256? // empty] | unique | .[]' \
  /tmp/ssh_hosts.json > /tmp/cert_fps.txt

# Batch view certs — chunk into groups of ~50 to keep each invocation manageable
split -l 50 /tmp/cert_fps.txt /tmp/cert_chunk_
for chunk in /tmp/cert_chunk_*; do
  CERTS=$(paste -sd, "$chunk")
  censys view "$CERTS" -O json >> /tmp/all_certs.json
done

# Certs expiring soon
jq '[.[] | select(.parsed.validity_period.not_after < "2025-09-01T00:00:00Z") |
     {cn: .parsed.subject.common_name[0], expires: .parsed.validity_period.not_after,
      fp: .fingerprint_sha256}]' /tmp/all_certs.json

# Extract all SANs across certs
jq -r '[.[].parsed.extensions.subject_alt_name.dns_names[]?] | unique | .[]' /tmp/all_certs.json
```

Always chunk batch cert lookups (~50 per call) — a single call with hundreds of
comma-separated fingerprints is more likely to hit request-size limits and harder
to retry piecemeal on partial failure.

## Cross-referencing result sets

```bash
# IPs present in search results AND flagged with bad reputation in enrichment
comm -12 \
  <(jq -r '.[].host.ip' /tmp/ssh_hosts.json | sort) \
  <(jq -r '[.[] | select(.reputation?.malicious == true)] | .[].ip' /tmp/enriched.json | sort)

# Correlate censeye pivots with a fresh targeted search
censys censeye 1.2.3.4 -O json > /tmp/pivots.json
jq -r '.[] | select(.interesting == true) | .query' /tmp/pivots.json | while read -r query; do
  echo "=== Pivot: $query ==="
  censys search "$query" -n 5 -O json | jq '.[].host.ip'
done
```

`comm` requires both inputs sorted — always pipe through `sort` before diffing.
For joins beyond a simple set intersection (e.g. matching on ASN plus port), load
both sets into SQLite tables and `JOIN` on the extracted fields instead.

## Selective field extraction

```bash
# Have the CLI itself narrow the response before it ever hits disk
censys search --fields host.ip,host.location.country "host.services.port=443" -O json

# Trim an already-saved record down to just what's needed downstream
censys view 8.8.8.8 -O json | \
  jq '.[0] | {ip, services: [.services[] | {port, protocol}], location}' > /tmp/trimmed.json
```

Prefer `--fields` at query time when the full record isn't needed — it reduces
payload size and API cost. Use post-hoc `jq` trimming when the full record was
already saved and only a subset is needed for the next processing step.

## Error handling

- **jq syntax errors** — validate first with `jq '.' file.json`; a parse failure
  usually means truncated or non-JSON output (check the CLI didn't error mid-run).
- **SQLite JSON functions unavailable** — `json_extract`/`json_each` require
  SQLite 3.38+; check with `sqlite3 --version`.
- **Large NDJSON files** — process line-by-line with `jq -c`, never load the whole
  file as a single JSON array (it isn't one).
- **Batch cert lookups failing** — chunk into groups of ~50; a large comma-separated
  list is more likely to exceed request limits or fail atomically.

## Cross-references

- For generating the underlying data, see `censys-search` and `censys-view`.
- For temporal analysis and change detection over a window, see `censys-timeline`.
- For the broader multi-step investigation workflow this analysis slots into, see
  `censys-investigate`.
