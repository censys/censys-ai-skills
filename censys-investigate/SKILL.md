---
name: censys-investigate
description: >-
  Use when the user wants to run a broader censys investigation rather than a
  single lookup — e.g. "censys investigate," "censys deep dive into," "trace
  this infrastructure with censys," "censys pivot chain," "full censys
  investigation," "investigate this IP," "profile this host," "what's running
  on this IP," "analyze this IP's infrastructure," or "/censys-investigate."
  Structured as a baseline collection phase (always run: host profile, historical
  timeline, domain/DNS chase, indicator triage) followed by decision trees that
  branch on what the baseline reveals (unique artifact pivots, behavioral
  compounds, body content search, deep-dive assessment). Prescribes a findings
  template and data preservation convention. Not for a single command invocation —
  see the per-command skills for that.
version: 0.2.0
---

# censys-investigate

## When to use

Fires on multi-command investigation requests — asks that span more than one
Censys command and need a methodology, not just a flag reference. Typical
triggers:

- "censys investigate 1.2.3.4"
- "censys deep dive into this actor's infrastructure"
- "trace this infrastructure with censys"
- "profile this host"
- "what's running on this IP"
- "analyze this IP's infrastructure"
- "/censys-investigate 203.0.113.5"

NOT for a single lookup (`censys-view`), a single search (`censys-search`), or
a censhi-only history request (`censhi`). Go straight to the matching
per-command skill for those instead of this one.

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
censhi <IP> -d 1y -f -o json > data/censhi_host_<IP>.json
```

Alternative: `censys history <IP> --duration 1y -O json` via the
`censys-timeline` skill.

Parse: service uptime intervals, service changes, signal rotations, ownership
events, reverse DNS. Populate **Infrastructure Timeline**.

### Step 4 — Domain/DNS chase

For each associated domain:

```bash
censhi <domain> -d 1y -o json > data/censhi_dns_<domain>.json
```

Skip if no domains. Document DNS resolution history, flag previous IPs.

### Step 5 — Indicator triage

Extract all pivotable indicators from steps 2–4. Categorize using
`censys-cql`'s known-noise section:

- **Unique** — body hashes, banner hashes, cert fingerprints, build artifact
  strings, custom ETags
- **Broad / Noise** — common software versions, default hostnames, shared CDN
  hashes, framework defaults
- **Unknown** — run a quick count: `censys search '<query>' --page-size 1
  --max-pages 1`. 0–5 hits → unique. 25+ → broad.

Populate **Indicator Triage**. Output = a prioritized indicator list for the
decision trees below.

## Data preservation

All raw data, censhi dumps, and pivot query results are saved to `data/`.
Nothing is discarded.

Naming convention:

- `data/censys_view_<IP>.json`
- `data/censhi_host_<IP>.json`
- `data/censhi_dns_<domain>.json`
- `data/censhi_cert_<sha256_prefix>.json`
- `data/censys_history_<IP>.json`
- `data/pivot_results/<query_name>.json`
- `data/pivot_results/<query_name>.err`

Rules:

- Never discard results, even 0-hit. Zero hits = "this indicator is unique to
  target."
- The **Data Files** section of `findings.md` references every file in
  `data/`.

## Decision trees

These operate on the baseline's outputs. The analyst picks the relevant
tree(s) for what the baseline revealed — multiple trees may apply, and trees
feed back into each other as new candidates surface. Every path terminates in
documentation; nothing is silently dropped.

**Tree 1: "I have unique artifacts"**

Entry: Indicator triage found unique body/banner/cert/build-string
indicators.

```
Run censys search for each unique indicator (excluding target IP)
  ├─ Hits found → for each hit:
  │   ├─ Run censhi on the hit IP (save to data/)
  │   ├─ Compare: timeline overlap? shared signals? same stack?
  │   │   ├─ Strong overlap → linked infrastructure. Add indicators, re-enter Tree 1
  │   │   └─ Weak/no overlap → coincidence, document why
  │   └─ Check for ownership boundary before shared indicator appeared
  └─ No hits → "unique to target" (this IS a finding)
```

**Tree 2: "Everything is common/default"**

Entry: All indicators broad or noise.

```
Build behavioral compound queries (2-3 broad indicators combined)
  ├─ Start tight: software + protocol + ASN + port pattern
  │   ├─ < 25 hits → viable pivot set, deep-dive each (Tree 4)
  │   ├─ 25-200 hits → too broad, add constraint or try Tree 3
  │   └─ 200+ hits → noise, different combination
  └─ Try body content search (Tree 3) in parallel
```

**Tree 3: "Body content string search"**

Entry: From Tree 1 (supplementary) or Tree 2 (primary). Target has HTTP
services.

```
Extract distinctive strings from HTTP response bodies:
  ├─ Build artifact filenames (Vite/Webpack content hashes)
  ├─ Application-specific titles, meta tags, inline config
  ├─ Custom error messages or API response patterns
Search: host.services.endpoints.http.body:"<string>"
  ├─ Hits → evaluate same as Tree 1
  └─ No hits → unique, document
```

**Tree 4: "Deep-dive assessment"**

Entry: Any pivot returned candidate matches.

```
For each candidate:
  ├─ Run censhi (host history + cert follow, save to data/)
  ├─ Check ownership timeline:
  │   ├─ Change detected → shared indicator before or after boundary?
  │   │   ├─ Before → previous tenant. Exclude.
  │   │   └─ After → possible same operator. Continue.
  │   └─ No change → single operator, continue.
  ├─ Compare against target:
  │   ├─ Shared signals? Timeline overlap? Port pattern? Same ASN? Same apps?
  ├─ Assess confidence:
  │   ├─ Multiple shared indicators + timeline overlap → HIGH
  │   ├─ One shared indicator + behavioral similarity → MODERATE
  │   ├─ Only behavioral match → LOW (likely coincidence)
  │   └─ Different apps, different timeline → UNRELATED
  └─ If HIGH/MODERATE: add hit's indicators, re-enter Tree 1
```

**Tree 5: "Domain and DNS chase"**

Entry: Baseline found domains with previous IPs, or pivots revealed new
domains.

```
For each previous IP:
  ├─ Run censhi host history (save to data/)
  ├─ Shared hosting/parking → dead end, document
  ├─ Similar service profile → enter Tree 4
  └─ Unrelated → document and move on
For each new domain:
  ├─ Run censhi DNS history (save to data/)
  ├─ Other IPs → re-enter this tree
  └─ Note registration patterns
```

**Tree 6: "No linked infrastructure found"**

Entry: All paths exhausted.

```
Document explicitly:
  ├─ What was searched and ruled out
  ├─ Likely explanation:
  │   ├─ Unique tooling per node
  │   ├─ Single host only
  │   └─ Outside Censys visibility
  ├─ External sources that could extend:
  │   ├─ Domain registration / WHOIS
  │   ├─ Network flow data
  │   ├─ Threat intel feeds
  │   ├─ Application-layer analysis
  │   └─ Payment / billing records
  └─ Open questions for re-investigation
```

## Findings template

```markdown
# <IP> — Investigation

**Started:** YYYY-MM-DD
**Updated:** YYYY-MM-DD
**Status:** In Progress | Complete | Exhausted
**Constraint:** [e.g., Censys data only / passive recon only]

---

## Host Profile

| Attribute | Value |
|---|---|
| IP | |
| Location | |
| ASN | |
| OS | |
| Domain(s) | |
| Active Services | |
| Censys Reputation | |
| Earliest Observed | |
| Ownership Changes | |

---

## Current Services

| Port | Proto | Description | First Seen | Notes |
|---|---|---|---|---|

### Decommissioned Services

| Port | Proto | Description | Active Window | Notes |
|---|---|---|---|---|

---

## Infrastructure Timeline

| Date | Event |
|---|---|

---

## Key Observations

[Analyst notes: unusual stack, suspicious services, behavioral patterns]

---

## DNS History

[Per-domain resolution history, previous IPs, registrar info]

---

## TLS Certificate History

| Cert SHA256 | Subject CN | Port | Active Window |
|---|---|---|---|

---

## Indicator Triage

### Unique

| Indicator Type | Value | CQL Query | Hits | Result |
|---|---|---|---|---|

### Broad / Noise

| Indicator Type | Value | Why Noise |
|---|---|---|

---

## Pivot Results

[Decision tree outcomes — what was searched, what was found, what was ruled out.
Organized by tree traversal path.]

---

## Assessment

[Synthesis: linked infrastructure found? Operator characterization? Confidence level?]

---

## Open Questions

- [ ] ...

---

## Data Files

| File | Description |
|---|---|

---

## Progress Log

| Date | Action | Result |
|---|---|---|
```

## Pivoting patterns

Condensed appendix of the tactical pivot techniques — the "how to execute"
for each decision tree's search steps.

1. **Certificate pivot** — shared leaf cert = shared operator (or CDN
   default). Extract fingerprint from `censys view` output, search
   `host.services.tls.certificates.leaf_fp_sha_256`.
2. **Banner pivot** — unique/custom banner string. Search
   `host.services.banner:`.
3. **SSH host key pivot** — nearly as strong as cert. Search
   `host.services.ssh.server_host_key.fingerprint_sha256`.
4. **JARM pivot** — TLS stack fingerprint, useful when certs differ but
   backend is same. Search `host.services.jarm`.
5. **Body content pivot** — distinctive strings inside HTTP response bodies.
   Search `host.services.endpoints.http.body:"<string>"`. Especially
   effective for build artifact hashes (Vite/Webpack content hashes).
6. **Cross-provider cluster detection** — same signal across 3+ unrelated
   ASNs on VPS providers = likely single operator. Aggregate by ASN to check
   distribution.

Always aggregate (`censys aggregate`) before pulling full results to check
population size and distribution.

Reference `censys-cql` for field paths, `censys-search` for CLI execution.

## Cross-references

- **censys-view** — single host lookup for baseline Step 2.
- **censys-search** — pivot query execution for all decision trees.
- **censys-aggregate** — scope a pivot before pulling full results.
- **censys-censeye** — automated rarity-bounded pivot discovery as alternative to manual indicator triage.
- **censys-enrich** — fast bulk triage of candidate lists from pivot results.
- **censys-timeline** — temporal analysis via `censys history` for baseline Step 3 and deep-dive (Tree 4).
- **censhi** (user skill) — historical host/cert/DNS reports via censhi CLI. Alternative to censys-timeline for baseline Step 3; provides ownership-change analysis.
- **censys-cql** — CQL field paths, query syntax, known-noise indicators. Consulted during indicator triage (baseline Step 5) and pivot construction.
- **censys-analyze** — post-retrieval jq/SQLite analysis of saved pivot results.
