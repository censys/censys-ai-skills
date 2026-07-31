---
name: censys-cql
description: Use when the user needs help with CQL syntax, censys query syntax, how to write a censys query, what censys fields are available, or censys query help — field paths, operators, quoting/escaping rules, or example queries for hosts, certificates, and web properties. Trigger phrases include "CQL syntax," "censys query syntax," "how do I write a censys query," "what censys fields are available," and "censys query help." This is a reference skill, not a CLI wrapper — defer to censys-search, censys-aggregate, or censys-view to actually execute the query once it's constructed.
version: 0.2.0
---

# Censys CQL Reference

## When to use

Use this skill whenever the user needs help constructing, debugging, or understanding a Censys Query Language (CQL) query — field paths, operators, grouping, quoting, or example patterns. This covers requests like:

- "What's the CQL syntax for matching a port?"
- "How do I write a censys query for SSH hosts not on 22?"
- "What censys fields are available for TLS certificates?"
- "Why is my censys query failing to parse?"

This skill is a reference only — it does not execute queries. Once the query string is built, hand it to `censys-search` (raw search), `censys-aggregate` (counts/breakdowns), or `censys-view` (single-record lookup) to actually run it.

## Syntax fundamentals

- **Field paths** are dot-separated and mirror the JSON document structure: `host.services.port`, `cert.parsed.subject.common_name`.
- **Operators**:
  - `=` — exact match (the field value must equal the given term exactly)
  - `:` — contains / flexible match (substring, tokenized, or "in" semantics depending on field type)
  - `and`, `or` — boolean combinators
  - `not` — negation
- **Grouping**: use parentheses to scope compound expressions, especially when combining `and`/`or` across nested fields: `host.services: (protocol=SSH and port: 22)`.
- **CIDR notation**: IP range queries use CIDR blocks quoted as strings: `host.ip: '198.51.100.0/24'`.
- **Quoting**: wrap any value containing spaces, colons, slashes, or CQL keywords in single quotes: `cert.parsed.issuer.organization: 'Let''s Encrypt'`.
- **Nested field grouping**: `host.services: (...)` scopes all conditions inside the parens to the *same* service entry on the host — critical when a host has multiple services and you don't want conditions matching across unrelated services.

## Host fields

- **Network**: `host.ip`, `host.services.port`, `host.services.protocol`, `host.services.transport_protocol`
- **Banners/headers**: `host.services.banner`, `host.services.http.response.headers.*`. Note: for HTTP body, title, and favicon content, use the Endpoint HTTP fields below — `host.services.http.response.body` does NOT work in CQL v2.
- **TLS/certs**: `host.services.tls.certificates.leaf_fp_sha_256`, `host.services.tls.certificates.leaf_data.*`
- **SSH**: `host.services.ssh.server_host_key.fingerprint_sha256`
- **Fingerprints**: `host.services.jarm`, `host.services.tls.ja3s`
- **Location**: `host.location.country`, `host.location.city`, `host.location.province`, `host.location.country_code`
- **Network identity**: `host.autonomous_system.asn`, `host.autonomous_system.name`
- **Classification**: `labels` (top-level, not `host.labels`)
- **WHOIS**: `host.whois.organization.name`
- **Software**: `host.services.software.vendor`, `host.services.software.product`, `host.services.software.version`
- **Host metadata**: `host.service_count` (number of services — useful for profiling hosts with a specific service footprint)

### Endpoint HTTP fields

These fields query HTTP response content at the endpoint level. Note the
`endpoints.` path component — `host.services.http.*` does NOT work for these;
the extra nesting is required.

| Field | Path |
|---|---|
| Body hash (SHA-256) | `host.services.endpoints.http.body_hash_sha256` |
| HTML title | `host.services.endpoints.http.html_title` |
| Body content (text search) | `host.services.endpoints.http.body` |
| Favicon hash (SHA-256) | `host.services.endpoints.http.favicons.hash_sha256` |
| HTML tags | `host.services.endpoints.http.html_tags` |

## Certificate fields

- **Identity**: `cert.names`, `cert.parsed.subject.common_name`, `cert.parsed.subject.organization`
- **Issuer**: `cert.parsed.issuer.common_name`, `cert.parsed.issuer.organization`
- **Validity**: `cert.parsed.validity_period.not_before`, `cert.parsed.validity_period.not_after`
- **Fingerprint/trust**: `cert.fingerprint_sha256`, `cert.validation_level`

## Web property fields

- **Identity**: `webproperty.hostname`, `webproperty.endpoints.ip`, `webproperty.endpoints.port`
- **Response/classification**: `webproperty.endpoints.http.status_code`, `webproperty.labels`
- **Software**: `webproperty.software.vendor`, `webproperty.software.product`

## Query cookbook

```bash
# 1. SSH hosts on the standard port
censys search "host.services: (protocol=SSH and port: 22)"

# 2. Hosts serving a specific TLS leaf certificate by SHA-256
censys search "host.services.tls.certificates.leaf_fp_sha_256: <sha256>"

# 3. Hosts within a CIDR range
censys search "host.ip: '198.51.100.0/24'"

# 4. Hosts on a specific autonomous system
censys search "host.autonomous_system.asn: 13335"

# 5. Hosts with an nginx Server header
censys search "host.services.http.response.headers.server: nginx"

# 6. Certificates issued by Let's Encrypt (quoted apostrophe)
censys search "cert.parsed.issuer.organization: 'Let'\''s Encrypt'"

# 7. Non-standard-port SSH hosts in Germany (negation + compound grouping)
censys search "host.services: (protocol=SSH and not port: 22) and host.location.country: Germany"

# 8. Hosts matching a JARM TLS fingerprint
censys search "host.services.jarm: <jarm_hash>"

# 9. Hosts labeled as remote-access exposed
censys search 'labels="remote-access"'

# 10. Web properties running Apache
censys search "webproperty.software.product: Apache"

# 11. Hosts with a specific HTTP body hash (e.g., a custom web app)
censys search 'host.services.endpoints.http.body_hash_sha256="<sha256>"'

# 12. Hosts with a specific string in the HTTP response body
censys search 'host.services.endpoints.http.body:"index-Bv1WZ4hk.js"'

# 13. Hosts with a specific HTML title
censys search 'host.services.endpoints.http.html_title="Connection Manager"'
```

## Query construction patterns

The cookbook above gives copy-paste examples. This section teaches how to _think about_ building queries — especially when combining conditions across nested fields.

### Compound service matching

Without scoping, conditions on service sub-fields match independently across _all_ services on a host:

```bash
# WRONG: matches hosts with RDP on ANY port AND port 7070 running ANY protocol
censys search "host.services.protocol=RDP and host.services.port=7070"

# RIGHT: scopes both conditions to the SAME service entry
censys search 'host.services: (protocol=RDP and port=7070)'
```

Use separate `host.services: (...)` blocks to require _different_ services on the same host:

```bash
# Hosts with RDP on 3389 AND AnyDesk on 7070 (two distinct services)
censys search 'host.services: (protocol="RDP" and port: 3389) and host.services: (software.product: "AnyDesk" and port: 7070)'
```

This finds hosts that have both services, but doesn't constrain the _total_ number of services — see `host.service_count` below.

### Service footprint profiling

Combine compound matching with `host.service_count` to find hosts with a _specific_ service combination and nothing else:

```bash
# Hosts running EXACTLY RDP:3389 + AnyDesk:7070, no other services
censys search 'host.services: (protocol="RDP" and port: 3389) and host.services: (software.product: "AnyDesk" and port: 7070) and host.service_count=2'
```

Purpose-built infrastructure (C2 panels, relay boxes, proxy nodes) tends to have minimal service footprints. Filtering by `service_count` surfaces these among the noise of multi-service hosts.

### Operator choice: `=` vs `:`

- `=` — exact match: the field value must equal the term exactly
- `:` — flexible match: substring, tokenized, or "in" semantics depending on field type

When it matters: on string fields, `:` can match substrings (`host.services.http.response.headers.server: nginx` matches "nginx/1.27.4"), while `=` requires the full value. On enum-like fields (protocol, transport_protocol), both behave the same in practice.

Rule of thumb: use `=` when you know the exact value you're looking for; use `:` when exploring or when the value might appear as a substring of a longer string.

## CQL field → JSON output path mapping

CQL search fields do NOT always match the JSON paths in `censys view` / `censys search` output. Use the CQL column for queries, the jq column for extracting from results:

| Signal | CQL search field | jq extraction path |
|---|---|---|
| Cert fingerprint | `host.services.tls.certificates.leaf_fp_sha_256` | `.services[].tls.fingerprint_sha256` or `.services[].cert.fingerprint_sha256` |
| JARM fingerprint | `host.services.jarm` | `.services[].jarm.fingerprint` |
| Server header | `host.services.http.response.headers.server` | `.services[].endpoints[].http.headers.Server.headers[]` |
| HTTP body | `host.services.endpoints.http.body` (see Gotchas #2) | `.services[].endpoints[].http.body` |
| SSH host key | `host.services.ssh.server_host_key.fingerprint_sha256` | `.services[].ssh.server_host_key.fingerprint_sha256` (same) |
| Banner hash | `host.services.banner_hash_sha256` | `.services[].banner_hash_sha256` (same) |
| Labels | `labels` (top-level) | `.labels` (top-level, NOT `host.labels`) |
| Body hash | `host.services.endpoints.http.body_hash_sha256` | `.services[].endpoints[].http.body_hash_sha256` |
| HTML title | `host.services.endpoints.http.html_title` | `.services[].endpoints[].http.html_title` |
| Body content | `host.services.endpoints.http.body` | `.services[].endpoints[].http.body` |
| Favicon hash | `host.services.endpoints.http.favicons.hash_sha256` | `.services[].endpoints[].http.favicons[].hash_sha256` |

## Escaping rules

- Values containing spaces, colons, slashes, hyphens, or other special characters must be wrapped in single quotes or double quotes: `'value with spaces'`, `"remote-access"`. Hyphens are especially treacherous — `labels: remote-access` fails because the parser reads `-access` as negation.
- CQL keywords (`and`, `or`, `not`) appearing *as literal values* (not as operators) must be quoted, or the parser will treat them as boolean operators.
- Single quotes inside a quoted value are escaped by doubling them in CQL itself (`'Let''s Encrypt'`); when that same string is passed through a shell command line, the shell's own quoting also needs escaping, which produces the doubled pattern `'\''` seen in example 6 above — one layer for the shell, one for CQL.
- When in doubt, quote the value. Quoting an already-safe token (e.g., a bare number or single word) is harmless; failing to quote a token that needs it causes a parse error or a silently wrong match.

## Gotchas

1. **`host.` prefix required in CLI.** CQL v2 via the CLI requires `host.` on all
   host field paths. The Censys web UI does not — queries that work in the browser
   will fail with a 422 on the CLI.

2. **`endpoints.` level for HTTP content fields.** HTTP response body, title, and
   favicon fields live under `host.services.endpoints.http.*`, NOT
   `host.services.http.*`. The extra `endpoints.` nesting is required. See the
   Endpoint HTTP fields table above.

3. **No direct header-based queries.** Compound queries on specific HTTP headers
   (e.g., `host.services.http.headers.(key=X-Powered-By and value.headers=Express)`)
   return 422. Use `host.services.software.product` instead — Censys extracts
   software identity from headers into the software field.

4. **Body text search uses `:`, not `=`.** Use
   `host.services.endpoints.http.body:"search string"` (colon, flexible match) for
   substring/text search within body content. Use `=` only for exact match on hash
   fields like `body_hash_sha256`.

5. **`software.product` values are lowercase.** `software.product="AnyDesk"` returns
   nothing; use `software.product: "AnyDesk"` (`:` is case-insensitive) or
   `software.product="anydesk"` (exact lowercase).

## Known noise

Indicators that look distinctive but return too many unrelated matches for
attribution. Check this list during indicator triage before building pivot queries.

| Indicator | Why it's noise |
|---|---|
| `WIN-*` hostname in cert CN on Hetzner (AS24940) | Default Windows VPS hostname. Hundreds of hosts share each variant. Not operator-specific. |
| Default Create-React-App favicon hash | Matches any CRA-scaffolded app that hasn't customized the favicon. |
| Express.js 404 body hash (`Cannot GET /`) | Default Express error page. Extremely common across all Express deployments. |
| Common JARM fingerprints for Node.js/Express | Too many matches for attribution when used as the sole pivot. Combine with other indicators. |
| Font Awesome CDN SRI hashes | Shared CDN resource. Referenced by millions of pages. |
| Generic inline CSS (`width: 100vw; height: 100vh; display: flex`) | Common layout pattern. Produces false positives from firewall/appliance UIs. |

This section should grow as investigations reveal new noise patterns.

## Cross-references

- **censys-search** — execute a constructed CQL query and return matching raw records.
- **censys-aggregate** — execute a CQL query and return counts/breakdowns by field instead of raw records.
- **censys-view** — single-record lookup by IP/SHA-256/FQDN; does not take a CQL query.
- **censys-censeye** — pivot analysis with rarity bounds, useful once a CQL query surfaces an interesting field value worth exploring further.
- **censys-investigate** — investigation methodology and multi-step pivoting patterns that build on CQL queries.
