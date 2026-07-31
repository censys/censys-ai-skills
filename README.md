# Censys CLI Skills

Skills for interacting with the Censys CLI (`censys`/`cencli`). One data purchase serves Security Operations (reactive) and Exposure Management (proactive) use cases in one place.

## Command Reference Skills

- [censys-search](censys-search/SKILL.md) — Search Censys data with CQL queries
- [censys-view](censys-view/SKILL.md) — View hosts, certificates, and web properties
- [censys-aggregate](censys-aggregate/SKILL.md) — Aggregate results by field (Report Builder)
- [censys-enrich](censys-enrich/SKILL.md) — Credit-free IP enrichment for SOC triage
- [censys-censeye](censys-censeye/SKILL.md) — Pivot analysis with rarity bounds

## Reference

- [censys-cql](censys-cql/SKILL.md) — CQL syntax, field paths, operators, query cookbook

## Methodology & Analysis

- [censys-investigate](censys-investigate/SKILL.md) — Investigation methodology, pivoting patterns, multi-step workflows
- [censys-timeline](censys-timeline/SKILL.md) — Temporal analysis, change detection, attribution boundaries
- [censys-analyze](censys-analyze/SKILL.md) — Post-retrieval analysis: jq recipes, SQLite, batch certs, cross-referencing

## Prerequisites

All skills require the [Censys CLI](https://github.com/censys/censys-cli) (`censys`).

### Install

```bash
pip install censys
# or
brew install censys/homebrew-censys/censys
```

See the [Censys CLI README](https://github.com/censys/censys-cli#readme) for full install options.

### Authenticate

```bash
censys auth login          # OAuth (interactive)
# or
censys config auth add     # PAT (non-interactive)
```

### Additional config

- For enrich: `censys config org-id`
- For censeye / cert history: Threat Hunting module access required
