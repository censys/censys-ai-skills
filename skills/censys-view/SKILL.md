---
name: censys-view
description: Use when the user wants detailed point-lookup data on a single asset via the Censys CLI — e.g. "censys view," "censys look up this IP," "censys host details for," "view this cert on censys," "censys what services does X run," "censys view this cert," "look this host up on censys," "censys pull the record for," "what does censys show for this hostname," "what's running on this IP," "profile this host," or "show me this host's services." Wraps `censys view` for hosts, certificates, and web properties. This is the right skill for any single-asset lookup — use censys-investigate only when the user explicitly asks for a multi-step investigation. Not for search-by-criteria (see censys-search) or time-series history (see censys-timeline).
version: 0.1.0
---

# censys-view

## When to use

Use this skill when the user already has a specific asset in hand — an IP address, a
hostname (with or without a port), or a certificate SHA-256 fingerprint — and wants
the current (or a point-in-time) detailed record for it. Typical asks:

- "censys view 8.8.8.8"
- "censys host details for 203.0.113.5"
- "what services does platform.censys.io run, per censys"
- "view this cert on censys: 3daf2843a77b..."
- "censys look up this IP as of last September"

Do **not** use this for criteria-based search ("find hosts running X" — that's
`censys-search`), field aggregation/reporting (`censys-aggregate`), or historical
timelines and change detection across snapshots (`censys-timeline`, backed by
`censys history`). This skill covers a single-shot lookup of one or more known assets.

## Invocation

```bash
censys view <asset> [flags]
```

`<asset>` type is auto-detected:

| Input pattern | Resolved as |
|---|---|
| IP address (e.g. `8.8.8.8`) | Host |
| `hostname:port` | Web property |
| bare hostname (no port) | Web property, defaults to port `443` |
| 64-character hex string | Certificate (SHA-256 fingerprint) |

Defanged IPs are accepted and normalized automatically, e.g. `8[.]8[.]8[.]8` →
`8.8.8.8`.

### Skill-specific flags

| Flag | Purpose |
|---|---|
| `--input-file <path>` | Read one asset per line from a file instead of the CLI arg. Use `-` to read from stdin. |
| `--at-time`, `--at`, `-a <RFC3339>` | Return the record as it existed at a specific point in time instead of the current snapshot. **Not supported for certificates** — certs are content-addressed and don't have a "point in time" state. |

Multiple assets can be passed comma-separated in a single invocation
(`censys view 8.8.8.8,9.9.9.9`), via `--input-file`, or piped through stdin.

### Global CLI flags

See `references/cli-globals.md` for the full global flags reference (output
format, streaming, diagnostics, org-id, and PAT vs OAuth notes).

## Common patterns

```bash
# Basic host lookup
censys view 8.8.8.8

# Compact, human-scannable output instead of full JSON
censys view 8.8.8.8 -O short

# Web property lookup — bare hostname defaults to :443
censys view platform.censys.io

# Web property lookup — explicit port
censys view platform.censys.io:80

# Multiple assets in one call (comma-separated)
censys view 8.8.8.8,9.9.9.9

# Historical snapshot of a host at a specific time
censys view 8.8.8.8 --at-time 2025-09-15T14:30:00Z

# Certificate lookup by SHA-256 fingerprint
censys view 3daf2843a77b6f4e6af43cd9b6f6746053b8c928e056e8a724808db8905a94cf

# Bulk lookup from a file (one asset per line), streaming results out
censys view --input-file hosts.txt -S

# Bulk lookup from stdin
cat hosts.txt | censys view --input-file - -O short
```

## Output structure

`censys view` always wraps its JSON result in an **array**, even for a single asset — all jq paths must start with `.[0]`:

```bash
# Correct — index into the array first
censys view 8.8.8.8 -O json | jq '.[0].services[] | {port, protocol}'

# Wrong — this returns null
censys view 8.8.8.8 -O json | jq '.services[]'
```

## Interpreting results

- **Services** — each entry has a port, transport protocol (`tcp`/`udp`), and
  detected application protocol (e.g. `HTTP`, `SSH`, `TLS`). This is the primary
  "what's running here" signal.
- **AS info** (`autonomous_system.asn`, `autonomous_system.name`) — identifies the
  network operator/ISP hosting the asset. Useful for attributing infrastructure to
  a hosting provider vs. an enterprise network.
- **Location** — city/province/country derived from GeoIP. Treat as approximate;
  it reflects the IP's registered/geolocated position, not necessarily the
  physical location of whoever controls the asset.
- **WHOIS** — organization name and abuse contacts for the network block. Useful
  for abuse reporting or ownership context, but can lag real-world reassignments.
- **Labels** — Censys-applied tags such as `remote-access`, `database`,
  `login-page`. These are heuristic classifications, not guarantees; use them to
  triage/prioritize, not as ground truth.

## Output guidance

- Default to `json` when the result will be parsed further (piped to `jq`, fed
  into another tool, or when the user wants "raw data").
- Use `-O short` when a human just wants a quick read of what an asset is running
  — it drops nested detail in favor of scannable summary lines.
- Use `-O tree` for visually inspecting nested structure (e.g. all services and
  their sub-fields) without writing a jq filter.
- Use `-O yaml` when the user wants something diffable/readable but still
  structured.
- For multi-asset lookups where the user wants to review-and-move-on rather than
  post-process, use `-S` (streaming) so results appear incrementally as NDJSON.
  `-S` and `-O` cannot be combined — streaming is the output format.

## Error handling

| Error | Cause | Resolution |
|---|---|---|
| `[Invalid Asset ID]` | Input isn't a valid IP, `hostname:port`, bare hostname, or 64-char SHA-256 | Confirm the asset string — check for typos, stray whitespace, or a truncated hash |
| `[Invalid Timestamp]` | `--at-time` value isn't valid RFC3339 | Reformat as `YYYY-MM-DDTHH:MM:SSZ` (or with an explicit UTC offset) |
| `[At-Time Not Supported]` | `--at-time` was passed with a certificate asset | Drop `--at-time` for cert lookups, or use `censys history` if temporal cert data is genuinely needed |

If a lookup returns no record for a host/web property, that generally means Censys
has no current scan data for that asset (it may be down, filtered, or simply
unobserved) — this is distinct from an error and won't raise one of the above.

## Caveats

- Bare hostnames silently resolve to port `443`. If the user means a different
  port, they must specify it explicitly (`hostname:8080`).
- GeoIP location is approximate and can be wrong for satellite links, VPNs, CDNs,
  and cloud provider ranges — don't present it as authoritative.
- `--at-time` reconstructs the record as of that snapshot; it is not the same as
  a diff or change log. For "what changed between two dates," use `censys history`
  instead.
- Certificates have no temporal dimension in `view` — a cert's fields (issuer,
  validity window, SANs) are fixed by the cert itself, not by when Censys observed
  it.
- Labels and classifications are Censys-derived heuristics and can lag or
  misclassify; corroborate with raw service/banner data before acting on a label
  alone.

## Cross-references

- For time-series historical data, snapshot diffing, or change detection over a
  window, use `censys history` — see the `censys-timeline` skill.
- For finding assets matching criteria (rather than looking up a known asset),
  see the `censys-search` skill.
- For deeper investigative workflows that chain multiple lookups together, see
  the `censys-investigate` skill.
