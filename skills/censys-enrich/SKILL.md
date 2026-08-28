---
name: censys-enrich
description: Use when the user wants fast, credit-free IP context for SOC/triage work via the Censys CLI — e.g. "censys enrich," "censys enrich this IP," "censys bulk enrich," "censys triage IP," "censys SOC lookup," "is this IP interesting per censys," "censys check this IP for scanning activity," or "censys reputation on this address." Wraps `censys enrich` for single/bulk IP enrichment (location, AS, WHOIS, DNS, labels, GreyNoise, reputation, network/privacy classification, third-party verdicts). Not for full host records with all services and raw banners (see censys-view) or criteria-based search (see censys-search).
version: 0.1.0
---

# censys-enrich

## When to use

Use this skill when the user has one or more IP addresses and wants a quick answer
to "is this IP interesting?" rather than a full host document. Typical asks:

- "censys enrich 104.168.107.43"
- "censys triage this list of IPs"
- "censys bulk enrich these addresses from a feed"
- "censys SOC lookup on 8.8.8.8"
- "does censys flag this IP as a known scanner"

`enrich` returns a curated subset built for triage: location, AS, WHOIS, DNS,
behavioral labels, GreyNoise classification, reputation score, network/privacy
classification (residential/datacenter/VPN/proxy/Tor), a trimmed services list,
and third-party verdicts (e.g. MalloryAI). It does **not** return the full host
record — no complete service list, no raw banners, no TLS certificate detail.
For that, use `censys-view` instead. See "Enrich vs. view" below.

## Invocation

```bash
censys enrich <ip> [flags]
```

Accepts:

| Input form | Example |
|---|---|
| Single IP | `censys enrich 104.168.107.43` |
| Comma-separated list | `censys enrich 104.168.107.43,8.8.8.8` |
| `--input-file <path>` | `censys enrich --input-file ips.txt` |
| stdin (via `--input-file -`) | `cat ips.txt \| censys enrich --input-file -` |

Defanged IPs are accepted and normalized automatically, e.g. `104[.]168[.]107[.]43`
→ `104.168.107.43`.

### Requirements

- **Censys Core plan.** `enrich` is not available on lower-tier plans.
- **Organization ID handling depends on auth method:**
  - **PAT (Personal Access Token):** Org ID is required. Set it once with
    `censys config org-id`, or pass `--org-id`/`-o <id>` on each call.
  - **OAuth (`censys auth login`):** The organization is fixed at login
    time. `--org-id` is not accepted and will error. If you need to target
    a different org, re-run `censys auth login` and select the org on the
    consent screen.

### Credits

`enrich` is **credit-free** — it does not draw from search/view credit balances.
A **daily rate limit** applies instead. If you hit it, wait for the daily reset;
there's no credit purchase that unblocks it faster. Use `censys credits` or
`censys org credits` to check *search/view* credit balances (not relevant to
enrich's own limit, but useful if the user is also planning follow-up `view`/
`search` calls).

### Output format

| Flag | Values |
|---|---|
| `--output-format`, `-O` | `json` (default), `yaml`, `tree`, `short` |
| `--streaming`, `-S` | Emit NDJSON (one JSON object per line) instead of a single JSON array — use for bulk enrichment so results stream as they resolve |

### Other global CLI flags

These apply to `enrich` as they do to any `censys` subcommand:

- `--quiet`, `-q` — suppress non-essential output
- `--debug` — verbose diagnostic logging
- `--no-color` — disable ANSI color in terminal output
- `--no-spinner` — disable progress spinner (useful when piping/redirecting)
- `--timeout-http <duration>` — override the HTTP client timeout

## Common patterns

```bash
# Single IP triage
censys enrich 104.168.107.43

# Multiple IPs in one call (comma-separated)
censys enrich 104.168.107.43,8.8.8.8

# Bulk enrichment from a file (one IP per line)
censys enrich --input-file ips.txt

# Bulk enrichment from stdin
cat ips.txt | censys enrich --input-file -

# Compact, human-scannable output for a single IP
censys enrich 8.8.8.8 -O short

# Bulk enrichment, streamed as NDJSON so results appear incrementally
censys enrich 8.8.8.8,9.9.9.9 --streaming
```

## Interpreting results

- **GreyNoise** — flags the IP as a known scanner, a benign/verified service
  (e.g. a CDN or search engine crawler), or part of mass internet-wide scanning
  activity. A GreyNoise "benign" tag is a strong signal to deprioritize.
- **Reputation** — contains `model_version` and `score_level` (e.g.
  `benign`) (observed on cencli 1.1.3, 2026-08). Treat as one signal among several, not a verdict on its own.
- **Network/privacy classification** — residential, datacenter, VPN, proxy, or
  Tor. Datacenter + no legitimate hosting context is more suspicious than
  residential; VPN/proxy/Tor often explain otherwise-odd geolocation or
  reputation results rather than confirming malice.
- **Labels** — Censys-applied behavioral tags. Heuristic, not ground truth —
  use them to prioritize triage order, not as a final determination.
- **Third-party verdicts** — assessments from vendors such as MalloryAI and
  others Censys aggregates. Cross-check these against GreyNoise/reputation
  rather than relying on any single source.
- **Location / AS / WHOIS / DNS** — standard attribution context (geolocation,
  network operator, registration org, resolved hostnames). Same caveats as
  elsewhere in Censys tooling: GeoIP is approximate, WHOIS can lag real-world
  reassignment.

**Output structure note:** enrichment results use **flat top-level paths** (`.ip`, `.reputation`, `.location`), not the `.host.`-prefixed structure of `censys search` and `censys view` output. Don't reuse jq paths across commands without adjusting for this.

## Enrich vs. view

| | `censys enrich` | `censys view` |
|---|---|---|
| Purpose | Curated SOC triage subset | Full host document |
| Credits | Credit-free (daily rate limit) | Consumes view credits |
| Services | Trimmed list | Complete, with raw banners |
| TLS detail | Not included | Full certificate detail |
| Best for | "Is this IP interesting?" — fast first pass | "Tell me everything about this host" |

Start with `enrich` for initial triage across a batch of IPs; escalate to `view`
only for the IPs that warrant a deeper look.

## Error handling

| Error | Cause | Resolution |
|---|---|---|
| `[Invalid Host]` | Input isn't a valid IP address | Check for typos, stray whitespace, or a non-IP value (hostnames aren't accepted by `enrich`) |
| `[No Hosts Provided]` | No IP given via argument, `--input-file`, or stdin | Supply at least one IP, or verify the input file/stdin actually contains data |
| `[No Organization ID]` | Org ID not configured and not passed explicitly | PAT users: run `censys config org-id` or pass `--org-id`. OAuth users: the org is fixed at login — re-run `censys auth login` to switch orgs |
| Rate limited | Daily enrich rate limit reached | Wait for the daily reset — this limit is separate from search/view credits and can't be bypassed by purchasing more credits |

## Caveats

- `enrich` only accepts IP addresses — no hostnames, CQL queries, or certificate
  fingerprints. Route those to `censys-view` or `censys-search` instead.
- Org ID is mandatory for every `enrich` call, even single-IP lookups — this
  differs from subcommands where org scoping can be inferred from a PAT.
- Being credit-free does not mean unlimited: the daily rate limit is a separate
  ceiling from the org's search/view credit balance.
- Labels, GreyNoise classification, reputation, and third-party verdicts are all
  heuristic/derived signals. Corroborate with `censys-view`'s raw service and
  banner data before treating any single field as a final verdict.
- The services list returned by `enrich` is intentionally trimmed for speed —
  absence of a service here does not mean `view` won't show it.

## Cross-references

- **censys-view** — full host document: complete service list, raw banners,
  TLS certificate detail. Use after `enrich` flags an IP as worth a deeper look.
- **censys credits** / **censys org credits** — check search/view credit
  balances (not the enrich daily rate limit, which is separate).
- **censys-search** — criteria-based search across hosts/certs, rather than
  point lookups on known IPs.
