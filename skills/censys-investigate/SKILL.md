---
name: censys-investigate
description: >-
  Use when the user explicitly requests a multi-step Censys investigation —
  e.g. "censys investigate," "censys deep dive into," "trace this
  infrastructure with censys," "censys pivot chain," "full censys
  investigation," "hunt for related infrastructure," or
  "/censys-investigate." This is a heavyweight methodology skill (typically
  20–50+ API calls) — do NOT fire on simple lookups like "what's running on
  this IP" or "profile this host" (use censys-view for those). Structured as
  a baseline collection phase followed by decision trees that branch on what
  the baseline reveals. Prescribes a findings template and data preservation
  convention. Always confirms scope and estimated cost with the user before
  starting.
version: 0.3.0
---

# censys-investigate

## When to use

Fires on explicit multi-command investigation requests — asks that need a
methodology spanning several Censys commands, not just a single lookup.
Typical triggers:

- "censys investigate 203.0.113.10"
- "censys deep dive into this actor's infrastructure"
- "trace this infrastructure with censys"
- "hunt for related infrastructure"
- "full censys investigation on this range"
- "/censys-investigate 203.0.113.5"

NOT for a single lookup (`censys-view`), a single search (`censys-search`), or
a single history request (`censys-timeline`). If the user says "what's running
on this IP," "profile this host," or "show me this host's services" — use
`censys-view`, not this skill.

**Before starting:** confirm with the user the investigation target, estimated
API call count (typically 20–50+ for a standard investigation, 100+ for deep
pivoting), and whether they want the full methodology or a lighter pass.

**Precedence:** If guidance in this skill conflicts with a command skill
(censys-search, censys-view, censys-aggregate, etc.), the command skill wins.
Command skills own the facts about their own CLI behavior; this skill owns
the investigation methodology.

## Prerequisites

Requires the [Censys CLI](https://github.com/Censys/cencli) installed
and authenticated. See the [repo README](../../README.md#prerequisites) for
install and auth steps.

## Structure

This skill runs in two phases:

1. **Baseline collection** (always run) — a fixed sequence that establishes
   what the target is, what it has done historically, what it's connected to,
   and which of its indicators are worth pivoting on.
2. **Decision trees** (branch on findings) — the baseline's output determines
   which tree(s) apply. Trees can feed into each other as new candidates
   surface.

Every query result is saved to `data/`. The audit trail has three layers:
`findings.md` holds conclusions, `data/` holds raw observations, and the
commands embedded throughout this skill are the methodology that connects
one to the other.

## Baseline collection

### Step 1 — Scaffold

Create the task directory:

```
YYYY-MM-DD_description/
├── data/
│   └── pivot_results/
├── analysis/
│   └── findings.md    ← initialized from template
└── src/
```

### Step 2 — Raw host profile

```bash
censys view <IP> -O json > data/censys_view_<IP>.json
```

Parse: services (port, protocol, software), TLS certs, DNS names, ASN/location,
OS indicators. Populate **Host Profile** and **Current Services** in
`findings.md`.

### Step 3 — Historical timeline

```bash
censys history <IP> --duration 30d -S > data/censys_history_<IP>.ndjson
```

Start with 30 days and widen only if the baseline reveals a signal worth
chasing further back. Always use streaming (`-S`) — buffered output on a
large history can take minutes or fail to complete. Widen incrementally:
`30d` → `90d` → `1y`.

See `censys-timeline` for flag details, event model, and interpretation
guidance.

Parse: service uptime intervals, service changes, signal rotations, ownership
events, reverse DNS. Populate **Infrastructure Timeline**.

### Step 4 — Domain/DNS chase

For each associated domain:

```bash
censys history <domain>:443 --duration 30d -S > data/censys_history_<domain>.ndjson
```

Skip if no domains. Document DNS resolution history, flag previous IPs.

### Step 5 — Indicator triage

Extract all pivotable indicators from steps 2–4. Categorize using
`censys-cql`'s known-noise section:

- **Unique** — body hashes, banner hashes, cert fingerprints, build artifact
  strings, custom ETags
- **Broad / Noise** — common software versions, default hostnames, shared CDN
  hashes, framework defaults
- **Unknown** — count the hosts that match, then classify. 0–5 hits → unique.
  25+ → broad.

  ```bash
  "${CLAUDE_PLUGIN_ROOT}/scripts/censys-count.sh" '<query>'
  ```

  The script pages the full result set and prints the count. It exits 2 with
  a warning if the count hits the 10,000-result API ceiling — treat that
  number as a floor, not a total.

  Do not count with `--page-size 1 --max-pages 1`. That command returns one
  record and no total. Do not count by adding `censys aggregate` buckets either:
  `-n` limits the bucket list and the default is 25, so the sum can be far below
  the true total. See `censys-aggregate` for measured evidence.

**Shared-tooling pitfall:** C2 framework identifiers (Cobalt Strike watermarks,
Sliver implant IDs, Mythic callback tokens) can be shared across unrelated
operators via cracked/leaked licenses or shared builders. Always run a
population count before classifying as unique — e.g., CS watermark `987654321`
appears on 77+ unrelated hosts globally. Treat these as Broad unless the
population is very small (< 5 hosts). The C2 framework's *public key* or
*beacon config URIs* are more likely to be operator-specific than the license
watermark.

**Hosting-provider fleet artifact:** a provider can run its own service on every
VPS it rents. That service then appears on every host in the cluster you hunt,
and it looks like operator tradecraft. It is not. It carries no attribution
weight, and a query that uses it is locked to that provider even when the query
contains no ASN filter — so the query returns zero after the operator changes
provider.

Before you classify any port, banner, or service as operator-specific, sweep the
host's own ASN for it:

```bash
censys aggregate 'host.autonomous_system.asn = <asn> and host.services.port = "<port>"' \
  host.operating_system.product -n 25
```

Read the result this way:

- The port appears **only** on hosts that match your cluster → possible operator
  artifact. Continue.
- The port appears on unrelated hosts, and above all on a **different operating
  system** (for example bare Windows/RDP hosts when your cluster is Linux) →
  provider fleet service. Exclude it from the indicator set and from every
  hunting query.

A real case: port 17500 returned a TLS `unrecognized_name` fatal alert on all six
hosts of a Linux C2 cluster. The banner suggested a deliberate SNI gate. A sweep
of the ASN returned 19 hosts with the identical banner hash. 13 were bare
Windows/RDP VPS with no relation to the cluster. Port 17500 was the provider's
own service.

**Dark infrastructure caveat:** CQL endpoint fields (e.g., Cobalt Strike
watermark/public key) only match hosts with **currently active** listeners.
If a cluster's services are offline, these searches return 0 — which means
"not currently visible," not "unique to target." Verify the field is indexed
by running a wildcard query (`field:*`) before interpreting 0 results.

Populate **Indicator Triage**. Output = a prioritized indicator list for the
decision trees below.

## Data preservation

All raw data, history dumps, and pivot query results are saved to `data/`.
Nothing is discarded.

Naming convention:

- `data/censys_view_<IP>.json`
- `data/censys_history_<IP>.ndjson`
- `data/censys_history_<domain>.ndjson`
- `data/censys_history_cert_<sha256_prefix>.ndjson`
- `data/pivot_results/<query_name>.json`
- `data/pivot_results/<query_name>.err`

Rules:

- Never discard results, even 0-hit. Zero hits is a finding worth saving — it
  means not currently visible. Confirm the field is indexed with `field:*`
  before calling anything unique.
- The **Data Files** section of `findings.md` references every file in
  `data/`.

## Decision trees

The baseline's outputs determine which decision tree(s) to enter. Multiple
trees may apply, and trees feed back into each other as new candidates surface.

For the full decision tree flowcharts (Trees 1–6), see
[${CLAUDE_SKILL_DIR}/references/decision-trees.md](${CLAUDE_SKILL_DIR}/references/decision-trees.md).

## Findings template

Initialize `analysis/findings.md` from the template in
[${CLAUDE_SKILL_DIR}/references/findings-template.md](${CLAUDE_SKILL_DIR}/references/findings-template.md) at the start
of every investigation.

## Pivoting patterns

Tactical pivot techniques and bulk verification procedures are in
[${CLAUDE_SKILL_DIR}/references/pivot-patterns.md](${CLAUDE_SKILL_DIR}/references/pivot-patterns.md).

## Cross-references

- **censys-view** — single host lookup for baseline Step 2.
- **censys-search** — pivot query execution for all decision trees.
- **censys-aggregate** — scope a pivot before pulling full results.
- **censys-censeye** — automated rarity-bounded pivot discovery as alternative to manual indicator triage.
- **censys-enrich** — fast bulk triage of candidate lists from pivot results.
- **censys-timeline** — temporal analysis via `censys history` for baseline Step 3 and deep-dive (Tree 4).
- **censys-cql** — CQL field paths, query syntax, known-noise indicators. Consulted during indicator triage (baseline Step 5) and pivot construction.
- **censys-analyze** — post-retrieval jq/SQLite analysis of saved pivot results.
