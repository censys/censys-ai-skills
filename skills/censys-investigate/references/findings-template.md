# Findings template

Initialize `analysis/findings.md` from this template at the start of every
investigation. Every section must be populated or explicitly marked N/A before
the investigation is marked complete.

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

| Indicator Type | Value | CenQL Query | Hits | Result |
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
