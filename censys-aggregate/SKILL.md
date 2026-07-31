---
name: censys-aggregate
description: Use when the user wants to aggregate, bucket, or count censys search results by field, censys break down results by field, censys top ports for a query, censys count by country, censys distribution of a field, or the equivalent of the Censys Platform Report Builder. Wraps the `censys aggregate` CLI subcommand. Trigger phrases include "censys aggregate," "censys break down by," "censys top ports for," "censys count by country," and "censys distribution of." Do not use for returning raw matching records (see censys-search) or for single-record lookup by identifier (see censys-view).
version: 0.1.0
---

# Censys Aggregate

## When to use

Use this skill whenever the user wants bucketed counts of a field's values across matching Censys documents, rather than the raw matching records themselves. This is the CLI equivalent of the Censys Platform Report Builder. Covers requests like:

- "censys aggregate SSH hosts by port"
- "censys break down HTTP services by country"
- "censys top ports for hosts in Germany"
- "censys count by country for port 443"
- "censys distribution of protocols on port 22"

If the user wants the actual matching records (not counts), that's `censys-search`. If the user has a specific IP, cert SHA-256, or FQDN and wants a single-record lookup, that's `censys-view`. If the user needs help writing or debugging the CQL query itself, defer to `censys-cql`.

## Invocation

Base form:

```bash
censys aggregate "<CQL query>" "<field>" [flags]
```

The query selects the document set; the field is the dotted field path to bucket on (e.g. `host.services.port`, `host.location.country`).

### Aggregate-specific flags

| Flag | Alias | Description |
|---|---|---|
| `--num-buckets` | `-n` | Number of buckets to return (default: 25, range: 1-2000) |
| `--count-by-level` | `-l` | Document level to count at, for nested fields (e.g. count at the service level vs. the host level) |
| `--filter-by-query` | `-f` | Limit aggregation to field values that also match the query (rather than aggregating across all values present on matching documents) |
| `--collection-id` | `-c` | Aggregate within a specific collection (UUID) |
| `--interactive` | `-i` | Open an interactive TUI table for browsing buckets |

### Output format

Unlike most other `censys` subcommands, `aggregate` defaults to `-O short` rather than `json`. Pass `--output-format`/`-O` explicitly with `json`, `yaml`, `tree`, or `short` to override. `-O template` is not supported for `aggregate` and exits with code 2.

### Global CLI flags

These apply to every `censys` subcommand, not just `aggregate`:

- `--output-format`, `-O` — output format (`json`, `yaml`, `tree`, `short`; `template` not supported here)
- `--streaming`, `-S` — emit NDJSON instead of a JSON array
- `--quiet`, `-q` — suppress non-essential output
- `--debug` — verbose diagnostic logging
- `--no-color` — disable ANSI color in terminal output
- `--no-spinner` — disable progress spinner (useful when piping or in CI)
- `--timeout-http` — override the HTTP client timeout
- `--org-id`, `-o` — explicitly set the organization ID for the request

**PAT users:** if you authenticated with a Personal Access Token (`censys config auth add`) rather than OAuth (`censys auth login`), the CLI cannot always infer which organization to scope the request to. If an aggregation returns an org-related auth error or an empty bucket set you didn't expect, pass `--org-id <org-id>` explicitly (or set it once via `censys config org-id`).

## Common patterns

```bash
# Top 10 SSH ports
censys aggregate "host.services.protocol=SSH" "host.services.port" -n 10

# Country breakdown for hosts on port 443
censys aggregate "host.services.port: 443" "host.location.country"

# Protocol distribution on port 22, limited to values matching the query
censys aggregate "host.services.port=22" "host.services.protocol" --filter-by-query

# Country breakdown for HTTP hosts, as JSON for downstream processing
censys aggregate "host.services.protocol=HTTP" "host.location.country" -O json

# Interactive TUI table for browsing protocol buckets on port 22
censys aggregate "host.services.port=22" "host.services.protocol" -i
```

## Interpreting results

Each result is a bucket with two fields:

- `key` — the field value for that bucket (e.g. a port number, country name, or protocol string)
- `count` — the number of matching documents with that value

Notes on shaping the bucket set:

- `--count-by-level`/`-l` matters for nested fields where a host can have multiple services. Counting at the service level counts every matching service occurrence; counting at the host level counts each host once regardless of how many matching services it has. Pick the level that matches what the user actually means by "count" (e.g. "how many hosts run SSH" vs. "how many SSH services exist").
- `--filter-by-query`/`-f` restricts aggregation to field values that also satisfy the query itself, rather than aggregating across every value present on the matching document set. Use this when the user wants the breakdown scoped strictly to the condition they searched for (e.g. protocol distribution only among the ports the query matched), not a broader profile of the matching hosts.
- `--num-buckets`/`-n` is a hard cap on returned buckets, not a sample size — if the true cardinality of the field exceeds `-n`, only the top buckets by count are returned. Raise `-n` (up to 2000) if the user wants the long tail.
- **Total population count** — to get the total number of matching hosts across all buckets: `censys aggregate "<query>" "<field>" -O json | jq '[.[].count] | add'`.

## Error handling

- **`-O template` requested**: aggregate does not support template output and exits with code 2. Fall back to `-O json` and post-process with `jq`, or use `-O short`/`-O tree` for direct review.
- **Invalid CQL syntax**: the CLI returns an error message that includes the malformed part of the query. Check `censys-cql` for field paths, operators, and syntax reference before retrying.
- **Invalid field path**: aggregating on a field that doesn't exist for the queried document type returns an error or an empty bucket set — verify the field path (e.g. `host.services.port` vs. `host.location.country`) against `censys-cql`'s field reference.
- **`--num-buckets` out of range**: values outside 1-2000 are rejected; clamp the request before retrying.
- **Auth expired / unauthorized**: run `censys auth login` to re-authenticate (OAuth), or verify the PAT is still valid via `censys config auth add` if using a token.
- **Empty results with a PAT and multi-org access**: pass `--org-id`/`-o` explicitly — the query may be scoping to the wrong (or no) organization.

## Caveats

- Aggregation counts are computed server-side across the full matching document set — they are not derived from a sample of the first page of search results, so counts can differ from what you'd get by paginating `censys-search` and tallying with `jq` on a partial pull.
- Bucketing on a high-cardinality field (e.g. raw IP address) without a meaningful `-n` cap will silently truncate to the top values by count; confirm with the user whether they want the full distribution before running such an aggregation.
- `--collection-id` requires a valid collection UUID that the authenticated identity has access to; an unrecognized or unauthorized UUID returns an error rather than an empty bucket set.
- The default output (`short`) is meant for quick terminal review of `key`/`count` pairs; switch to `-O json` before piping into `jq` or other tooling.

## Cross-references

- **censys-cql** — CQL syntax, field paths, operators, and query cookbook. Defer here for help constructing the query string or identifying the correct field path to aggregate on.
- **censys-search** — returns raw matching records instead of bucketed counts.
- **censys-view** — single-record lookup by IP/SHA-256/FQDN (not a query or aggregation).
- **censys-analyze** — deeper post-retrieval analysis: jq recipes, SQLite, batch cert analysis, cross-referencing.
