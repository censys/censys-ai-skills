---
name: censys-search
description: Use when the user wants to run a censys search, censys search for hosts or certificates, search censys for hosts/certs/web properties, find censys hosts with a given condition, run a censys query for hosts, or search for certificates on censys using CQL. Wraps the `censys search` CLI subcommand. Trigger phrases include "censys search," "search censys for," "find censys hosts with," "censys query for hosts," and "search for certificates on censys." Do not use for viewing a single known host/cert/domain by identifier (see censys-view) or for aggregating/counting by field (see censys-aggregate).
version: 0.1.0
---

# Censys Search

## When to use

Use this skill whenever the user wants to run a full-text or structured Censys Query Language (CQL) query against Censys host, certificate, or web-property data via the `censys search` CLI command. This covers requests like:

- "censys search for SSH hosts not on port 22"
- "search censys for certificates matching censys.com"
- "find censys hosts with port 443 open in Germany"
- "censys query for hosts running HTTP"

If the user already has a specific IP, cert SHA-256, or FQDN and wants a single-record lookup (not a query), that's `censys-view`, not this skill. If the user wants counts/breakdowns by field value rather than raw matching records, that's `censys-aggregate`. If the user needs help writing or debugging the CQL query itself, defer to `censys-cql`.

## Invocation

Base form:

```bash
censys search "<CQL query>" [flags]
```

### Search-specific flags

| Flag | Alias | Description |
|---|---|---|
| `--fields` | `-f` | Comma-separated list of fields to return (reduces payload size and speeds up parsing) |
| `--page-size` | `-n` | Results per page (default: 100) |
| `--max-pages` | `-p` | Max pages to fetch (default: 1; use `-1` for exhaustive/all pages) |
| `--collection-id` | `-c` | Restrict the search to a specific collection (UUID) |

### Output format

Pass `--output-format`/`-O` with one of: `json` (default), `yaml`, `tree`, `short`, `template`. For streaming/pipeline use, pass `--streaming`/`-S` to emit NDJSON (one JSON object per line) instead of a single JSON array — this is required for piping into `jq` over exhaustive result sets without buffering the whole array in memory.

### Global CLI flags

These apply to every `censys` subcommand, not just `search`:

- `--output-format`, `-O` — output format (`json`, `yaml`, `tree`, `short`, `template`)
- `--streaming`, `-S` — emit NDJSON instead of a JSON array
- `--quiet`, `-q` — suppress non-essential output
- `--debug` — verbose diagnostic logging
- `--no-color` — disable ANSI color in terminal output
- `--no-spinner` — disable progress spinner (useful when piping or in CI)
- `--timeout-http` — override the HTTP client timeout
- `--org-id`, `-o` — explicitly set the organization ID for the request

**PAT users:** if you authenticated with a Personal Access Token (`censys config auth add`) rather than OAuth (`censys auth login`), the CLI cannot always infer which organization to scope the request to. If a search returns an org-related auth error or empty results you didn't expect, pass `--org-id <org-id>` explicitly (or set it once via `censys config org-id`).

## Common patterns

```bash
# Find SSH hosts not on port 22
censys search 'host.services: (protocol=SSH and not port: 22)' -O short

# Search with specific fields returned
censys search --fields host.ip,host.location.country "host.services.protocol=HTTP"

# Exhaustive export to NDJSON, extract IPs with jq
censys search "host.services.port: 443 and host.location.country: Germany" \
  --max-pages -1 --streaming | jq -r '.host.ip'

# Search within a specific collection
censys search -c <collection-uuid> "host.services.protocol=SSH"

# Paginated results (5 pages of 50 each = up to 250 results)
censys search --page-size 50 --max-pages 5 "cert.names=censys.com"
```

## Post-retrieval filtering

Once results are retrieved, use `jq` for filtering, projecting, and counting rather than trying to encode every condition in CQL:

```bash
# Extract specific fields from JSON output
censys search "host.services.port=22" | jq '.[].host.ip'

# Filter results by condition
censys search "host.services.port=443" -O json | \
  jq '[.[] | select(.host.location.country_code == "US")]'

# Count results matching a sub-condition
censys search "host.services.protocol=SSH" --max-pages 3 -O json | \
  jq '[.[] | select(.host.services[]? | .port == 22)] | length'
```

## Output guidance

- Default to `-O short` for quick human review of a handful of results in the terminal.
- Use the default `json` (or `-O json` explicitly) when the output will be piped into `jq` or another tool for filtering/analysis.
- Use `--streaming` (NDJSON) whenever `--max-pages -1` (exhaustive) is combined with a pipeline — this avoids holding the full result set in memory as one JSON array and lets `jq` process records incrementally.
- `-O tree` is useful for visually inspecting the full nested structure of a single result during ad-hoc exploration.
- `-O template` supports custom output formatting when the user needs a specific text layout (e.g., for a report or script).

## Export workflow

For bulk exports, always aggregate first to check population size before spending credits on a full pull:

```bash
# Step 1: Check how many hosts match
censys aggregate "<query>" "host.location.country" -O json 2>/dev/null | \
  jq '[.[].count] | add'

# Step 2: Export (all three formats share the same backbone)
censys search "<query>" --max-pages -1 -S 2>/dev/null | jq <filter>
```

**IPs only** — plain text list:

```bash
censys search "<query>" --max-pages -1 -S 2>/dev/null | \
  jq -r '.host.ip' > hosts.txt
```

**Rich NDJSON** — one JSON object per line with host context:

```bash
censys search "<query>" --max-pages -1 -S 2>/dev/null | \
  jq -c '{
    ip: .host.ip,
    asn: .host.autonomous_system.asn,
    as_name: .host.autonomous_system.name,
    country: .host.location.country_code,
    city: .host.location.city,
    services: [.host.services[] | {port, protocol, software: [.software[]?.product] | join(",")}]
  }' > hosts.ndjson
```

**CSV** — spreadsheet-ready (prepend a header line):

```bash
echo "ip,asn,as_name,country,city,ports" > hosts.csv
censys search "<query>" --max-pages -1 -S 2>/dev/null | \
  jq -r '[
    .host.ip,
    (.host.autonomous_system.asn | tostring),
    .host.autonomous_system.name,
    .host.location.country_code,
    .host.location.city,
    ([.host.services[].port | tostring] | join(";"))
  ] | @csv' >> hosts.csv
```

### Export caveats

- **`--fields` and `-S` are incompatible** — combining them produces empty output. Use `-S` (streaming) and reshape with jq instead.
- **`software.product` values are lowercase** — `software.product="AnyDesk"` silently returns nothing; use `software.product: "AnyDesk"` (`:` is case-insensitive) or `software.product="anydesk"`. See `censys-cql` for `=` vs `:` guidance.
- **`2>/dev/null`** suppresses the status line (e.g. `200 (OK) - 1.2s`) that the CLI writes to stderr — without it, the status text can pollute piped output.

## Error handling

- **Invalid CQL syntax**: the CLI returns an error message that includes the malformed part of the query. Check `censys-cql` for field paths, operators, and syntax reference before retrying.
- **Auth expired / unauthorized**: run `censys auth login` to re-authenticate (OAuth), or verify the PAT is still valid via `censys config auth add` if using a token.
- **Rate limited**: back off and retry after a delay. Check remaining credits with `censys credits` before issuing another large/exhaustive query.
- **Empty results with a PAT and multi-org access**: pass `--org-id`/`-o` explicitly — the query may be scoping to the wrong (or no) organization.

## Parsing CLI output programmatically

When redirecting `censys search -O json` to a file and parsing it later:

1. **Status line on first line.** The CLI writes a status line to the output
   (e.g., `200 (OK) - 347ms - pages: 1`) before the JSON array. Skip or
   discard the first line before parsing JSON. In Python:
   `f.readline(); data = json.load(f)`.
2. **Result is a JSON array.** The output (after the status line) is a single
   JSON array `[...]`, not NDJSON — unless `--streaming`/`-S` is passed.
3. **Empty results may be `null`.** Some queries return `null` instead of `[]`
   for zero results. Defensive parsing: `data = json.load(f) or []`.
4. **`2>/dev/null` for clean piping.** The status line goes to stdout (not
   stderr) when using `-O json` without redirection. When piping directly into
   `jq`, use `2>/dev/null` to suppress any stderr diagnostics, but be aware the
   status line is in the JSON stream — `jq` will error on it unless the output
   is saved to a file and the first line is stripped.

## Caveats

- `--max-pages -1` performs an exhaustive pull across all matching pages — this can consume significant API credits on broad queries. Confirm scope with the user (or add tightening conditions) before running an unbounded exhaustive search on a broad query.
- `--page-size` above the platform's per-page maximum will be clamped by the API; there is no benefit to setting it above that ceiling.
- `--fields` only trims the returned payload — it does not change which records match the query. Filtering must still happen in the CQL query itself or via post-retrieval `jq` filtering.
- Results are subject to Censys data freshness/indexing lag; a very recent scan may not yet appear in search results.
- `--collection-id` requires a valid collection UUID that the authenticated identity has access to; an unrecognized or unauthorized UUID returns an error rather than an empty result set.
- **Run `censys` commands one at a time.** The CLI keeps a local cache database and takes a write lock on it. Two or more concurrent `censys` processes fail with `failed to set journal_mode WAL: database is locked (261)`. The command exits 0 and writes an empty output file, so the failure is easy to miss. Check that each output file is not empty before you use it. Run batches in a sequential loop, not with `&`.
- **To count matching hosts, page the query** and count the records:

  ```bash
  censys search '<query>' --max-pages -1 --page-size 100 -O json | jq 'length'
  ```

  Do not add `censys aggregate` buckets to get a total — `-n` limits the bucket list (default 25) and the sum can be far below the true total. See `censys-aggregate`.

## Managing collections (no CLI support)

`censys search` and `censys aggregate` can *read* a collection with `-c`, but the CLI cannot create, update, list, or delete one. Use the Platform API for that. Authenticate with the same environment variables the CLI uses (`CENSYS_PLATFORM_TOKEN`, `CENSYS_PLATFORM_ORGID`).

Base URL: `https://api.platform.censys.io/v3/collections`. Every request needs `?organization_id=$CENSYS_PLATFORM_ORGID`.

| Action | Method | Path |
|---|---|---|
| List | `GET` | `/v3/collections` |
| Read one | `GET` | `/v3/collections/<id>` |
| Create | `POST` | `/v3/collections` |
| **Update** | **`PUT`** | `/v3/collections/<id>` |

Create and update take the same JSON body: `{"name": ..., "description": ..., "query": ...}`.

```bash
# create
jq -n --arg n "My collection" --arg d "What it tracks" --arg q '<CQL>' \
  '{name:$n, description:$d, query:$q}' > /tmp/c.json
curl -sS -X POST -H "Authorization: Bearer $CENSYS_PLATFORM_TOKEN" \
  -H "Content-Type: application/json" --data @/tmp/c.json \
  "https://api.platform.censys.io/v3/collections?organization_id=$CENSYS_PLATFORM_ORGID"
```

Notes:

- **`PUT` is the update verb.** `PATCH` and `POST` against `/v3/collections/<id>` both return HTTP 405.
- Build the JSON body with `jq -n --arg`, not a shell heredoc. CQL queries contain double quotes and backslash escapes that break under manual shell quoting.
- **The list endpoint paginates.** It returns 100 collections per page plus `result.next_page_token`. Loop on that token until it is empty. A new collection does not always appear on page 1, so do not conclude that creation failed after checking one page.
- After a create or an update, `status` is `populating` and `total_assets` is `0`. The status becomes `active` and the count settles after a short delay. An update sets `status_reason` to `query_changed`.
- Verify membership with a collection-scoped search: `censys search -c <id> '<broad query>' --max-pages -1 -O json | jq 'length'`.
- Collections are visible to the whole organization. Write a description that explains what the collection tracks, which known-benign members it contains and why, and which indicators were deliberately left out.

## Cross-references

- **censys-cql** — CQL syntax, field paths, operators, and query cookbook. Defer here for help constructing or debugging the query string itself.
- **censys-view** — single-record lookup by IP/SHA-256/FQDN (not a query).
- **censys-aggregate** — aggregate/count results by field instead of returning raw records.
- **censys-analyze** — deeper post-retrieval analysis: jq recipes, SQLite, batch cert analysis, cross-referencing.
