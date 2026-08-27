# Censys Skills Plugin

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) plugin for
working with [Censys](https://censys.io) internet intelligence data via the
[Censys CLI](https://github.com/Censys/cencli).

## Install

```bash
/plugin install censys
```

### Prerequisites

The plugin requires the [Censys CLI](https://github.com/Censys/cencli) (`censys`):

```bash
pip install censys
# or
brew install censys/homebrew-censys/censys
```

See the [Censys CLI README](https://github.com/Censys/cencli#readme) for full install options.

### Authenticate

```bash
censys auth login          # OAuth (interactive)
# or
censys config auth add     # PAT (non-interactive)
```

### Additional config

- For enrich: `censys config org-id`
- For censeye / cert history: Threat Hunting module access required

## What is Censys?

[Censys](https://censys.io) continuously scans the global IPv4 address space
and popular services, building a searchable dataset of every reachable host,
certificate, and web property on the internet. Use cases include threat
hunting, exposure management, attack surface discovery, and infrastructure
research. See [What is Censys?](https://censys.io/what-is-censys/) for a
full overview.

## Skills

Each skill is a standalone markdown file (`SKILL.md`) with YAML frontmatter
that Claude Code loads on demand based on trigger phrases in the user's
request. Skills fall into three layers:

| Layer | Skills | Purpose |
|---|---|---|
| **Command wrappers** | censys-search, censys-view, censys-aggregate, censys-enrich, censys-censeye, censys-timeline | Translate a user request into the right CLI command, flags, and output handling. One skill per `censys` subcommand. |
| **Reference** | censys-cql | Query language syntax, field paths, operators, known noise. Consulted by other skills when constructing queries — not a CLI wrapper itself. |
| **Methodology** | censys-investigate, censys-analyze | Multi-step workflows that orchestrate the command skills. `censys-investigate` runs a baseline collection phase then branches through decision trees; `censys-analyze` handles post-retrieval jq/SQLite analysis. |

Skills reference each other via cross-reference sections — a methodology
skill like `censys-investigate` will call out to `censys-search` for pivot
queries, `censys-timeline` for historical analysis, and `censys-cql` for
field path lookups. The command wrappers are self-contained and can be used
independently for one-off tasks.

### Command skills

- [censys-search](skills/censys-search/SKILL.md) — Search Censys data with CQL queries
- [censys-view](skills/censys-view/SKILL.md) — View hosts, certificates, and web properties
- [censys-aggregate](skills/censys-aggregate/SKILL.md) — Aggregate results by field (Report Builder)
- [censys-enrich](skills/censys-enrich/SKILL.md) — Credit-free IP enrichment for SOC triage
- [censys-censeye](skills/censys-censeye/SKILL.md) — Pivot analysis with rarity bounds
- [censys-timeline](skills/censys-timeline/SKILL.md) — Temporal analysis, change detection, attribution boundaries

### Reference

- [censys-cql](skills/censys-cql/SKILL.md) — CQL syntax, field paths, operators, query cookbook

### Methodology & Analysis

- [censys-investigate](skills/censys-investigate/SKILL.md) — Investigation methodology, pivoting patterns, multi-step workflows
- [censys-analyze](skills/censys-analyze/SKILL.md) — Post-retrieval analysis: jq recipes, SQLite, batch certs, cross-referencing
