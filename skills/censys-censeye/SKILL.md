---
name: censys-censeye
description: Use when the user wants to run censys censeye, censys pivot analysis, censys rarity analysis, censys find related infrastructure, or run censeye on a host. Wraps the `censys censeye` CLI subcommand to analyze a single host and generate pivotable threat-hunting queries bounded by rarity (how many other hosts share each attribute). Trigger phrases include "censys censeye," "censys pivot analysis," "censys rarity analysis," "censys find related infrastructure," and "run censeye on." Requires Threat Hunting feature access on the organization. Not for criteria-based search (see censys-search) or single-record point lookups (see censys-view).
version: 0.1.0
---

# censys-censeye

## When to use

Use this skill when the user has one (or a handful) of known hosts and wants Censys
to surface which of that host's attributes are distinctive enough to be useful
pivot points for finding related infrastructure. Typical asks:

- "censys censeye 8.8.8.8"
- "run censeye on this IP"
- "censys pivot analysis for 1.1.1.1"
- "censys find related infrastructure to this host"
- "censys rarity analysis on 203.0.113.5"

`censeye` inspects a host's fields (certificates, JARM/JA3 fingerprints, banners,
software, favicon hashes, etc.), counts how many other hosts on the internet share
each one, and returns candidate CQL queries ranked by that shared-host count. Low
counts are distinctive (good pivots); very high counts are generic noise (e.g.
common software versions) and get filtered out by the rarity bounds.

Do **not** use this for open-ended criteria search (`censys-search`), a plain
point-in-time record lookup (`censys-view`), or field-level aggregation across many
hosts (`censys-aggregate`). This skill starts from one known host and radiates
outward into pivot candidates; it does not itself execute those pivot queries.

**Requires Threat Hunting feature access** on the authenticated organization. If
the org doesn't have this entitlement, every invocation fails regardless of flags.

## Invocation

```bash
censys censeye <asset> [flags]
```

`<asset>` is a host IP address. Defanged IPs (e.g. `8[.]8[.]8[.]8`) are accepted and
normalized automatically.

### Skill-specific flags

| Flag | Alias | Description |
|---|---|---|
| `--rarity-min` | `-m` | Minimum host count for a result to be flagged `interesting` (default: `2`) |
| `--rarity-max` | `-M` | Maximum host count for a result to be flagged `interesting` (default: `100`) |
| `--interactive` | `-I` | Launch an interactive TUI for exploring results (note: capital `-I`) |
| `--include-url` | | Include a Platform search URL for each pivot query in the output |
| `--input-file` | `-i` | Read host IPs from a file, one per line; use `-` to read from stdin |

### Output format

Supports `--output-format`/`-O` with `short` (default), `json`, `yaml`, or `tree`.
**`template` is not supported** for this subcommand and will fail with a non-zero
exit code — see Error handling.

### Global CLI flags (apply to all `censys` subcommands)

| Flag | Purpose |
|---|---|
| `--output-format`, `-O <fmt>` | `short` (default), `json`, `yaml`, or `tree` for censeye |
| `--quiet`, `-q` | Suppress non-essential output |
| `--debug` | Verbose diagnostic logging |
| `--no-color` | Disable ANSI color in terminal output |
| `--no-spinner` | Disable the progress spinner (useful when piping/redirecting) |
| `--timeout-http <duration>` | Override the HTTP client timeout |
| `--org-id`, `-o <id>` | Target a specific organization ID |

## Common patterns

```bash
# Basic pivot analysis with default rarity bounds (2-100)
censys censeye 8.8.8.8

# Narrow the rarity window for tightly related infrastructure
censys censeye --rarity-min 2 --rarity-max 25 1.1.1.1

# Machine-readable output with Platform search URLs included
censys censeye --output-format json --include-url 203.0.113.5

# Interactive TUI for exploring pivot candidates
censys censeye 8.8.8.8 -I

# Widen the rarity ceiling to catch larger campaigns/botnets
censys censeye 8.8.8.8 --rarity-max 200

# Bulk analysis from a file, one host per line
censys censeye --input-file hosts.txt

# Bulk analysis from stdin
echo "8.8.8.8" | censys censeye --input-file -
```

## JSON output structure

```json
[
  {
    "count": 42,
    "query": "host.services.tls.certificates.leaf_fp_sha_256: abc123...",
    "interesting": true,
    "search_url": "https://platform.censys.io/search?q=..."
  }
]
```

- `count` — number of hosts across Censys that share this attribute.
- `query` — a ready-to-run CQL pivot query for that attribute.
- `interesting` — `true` when `count` falls within `[--rarity-min, --rarity-max]`.
- `search_url` — Platform search link for the query; only present when
  `--include-url` is passed.

## Interpreting results

- Each result represents one candidate pivot: a query that would surface every
  other host sharing a specific attribute with the analyzed host.
- `count` is the key signal — **lower is more distinctive**. A `count` of 3 means
  only 3 hosts total (including this one) share that fingerprint; a `count` of
  50,000 means the attribute is common and not worth pivoting on.
- `interesting: true` results are the ones worth acting on; results outside the
  rarity bounds are still returned but deprioritized/flagged as noise.
- Rarity tuning:
  - Start with the defaults (`2`-`100`) for a general first pass.
  - Narrow `--rarity-max` (e.g. `25`) when hunting for a small, tightly related
    cluster of infrastructure (shared C2 panel, same actor's staging boxes).
  - Widen `--rarity-max` (e.g. `200`+) when investigating a large campaign or
    botnet where the shared attribute is expected to fan out across many hosts.
  - Leave `--rarity-min` at `2` (the default) unless there's a specific reason to
    go lower — a `count` of `1` means the attribute is unique to this host alone
    and has nothing else to pivot to.
- Treat each returned `query` as a starting point, not a conclusion — run it
  through `censys-search` to see the actual matching hosts before drawing
  conclusions about shared infrastructure or attribution.

## Error handling

| Error | Cause | Resolution |
|---|---|---|
| Non-zero exit (exit code 2) with a format error | `--output-format template` was requested | `template` is not implemented for `censeye`; use `short`, `json`, `yaml`, or `tree` instead |
| Threat Hunting / entitlement error | The authenticated org doesn't have the Threat Hunting module enabled | Confirm module access with the org owner; no flag combination works around this |
| `[Invalid Asset ID]` | Input isn't a valid IP | Check for typos, stray whitespace, or a defanged IP that didn't normalize |
| Empty result set | Host has no fields with a distinctive-enough footprint, or none fall within the rarity bounds | Widen `--rarity-max`, lower `--rarity-min`, or confirm the host has recent Censys scan data via `censys-view` |

## Caveats

- `censeye` analyzes **one host's current snapshot** — it is not historical; pair
  with `censys-timeline`/`censys history` if the user wants to know how a host's
  pivotable attributes changed over time.
- Rarity counts are internet-wide and reflect Censys's current index; they shift
  over time as hosts come online/offline, so a query that was rare last week may
  not be this week.
- `--interactive`/`-I` opens a TUI and is not suitable for scripting, piping, or
  non-interactive/CI contexts — use the default or JSON output for those.
- A returned pivot `query` is a hypothesis, not a confirmed relationship — shared
  infrastructure (e.g. a common CDN certificate or hosting-provider default
  banner) can produce false-positive-feeling pivots. Corroborate with other
  signals before attributing hosts to the same actor.
- `--include-url` only affects output shape; it does not change which results are
  returned or which are marked `interesting`.
- Bulk mode (`--input-file`) runs the same single-host analysis independently for
  each line — it does not compare hosts against each other or look for attributes
  shared across the input set.

## Cross-references

- **censys-search** — run the pivot queries this skill surfaces to see the actual
  matching hosts.
- **censys-view** — point lookup of a single host, cert, or web property (no
  pivot/rarity analysis).
- **censys-timeline** — historical/time-series view of a host, for when the
  question is "how has this changed" rather than "what else is related."
- **censys-investigate** — broader investigation methodology that chains
  censeye pivots with search and analysis into a full workflow.
- **censys-cql** — syntax reference for hand-editing or extending a pivot query
  returned by censeye.
