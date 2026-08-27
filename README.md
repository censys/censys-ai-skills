# Censys Skills Plugin

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) plugin for
working with [Censys](https://censys.io) internet intelligence data via the
[Censys CLI](https://github.com/Censys/cencli).

## Install

```bash
claude plugin marketplace add Blevene/censys_skills
claude plugin install censys
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

## API usage estimates

Each skill wraps one or more `censys` CLI subcommands. Every subcommand
invocation is one Censys API call unless pagination is involved.

### Per-skill breakdown

| Skill | API calls per invocation | Notes |
|---|---|---|
| censys-view | 1 | Single host/cert/domain lookup. Batch via `--input-file` is still 1 call. |
| censys-enrich | 1 | Single or batch IP enrichment. Credit-free. |
| censys-aggregate | 1 | Single aggregation query, no pagination. |
| censys-censeye | 1 per host | `--input-file` with N hosts = N calls. |
| censys-search | 1 per page | Default is 1 page (100 results). `--max-pages -1` fetches all pages — unbounded. |
| censys-timeline | 1–N | Depends on history depth and time window. Streaming mode pages automatically. |
| censys-cql | 0 | Reference skill only — no CLI calls. |
| censys-analyze | 0 | Post-processing skill. Operates on saved output from other skills. |
| censys-investigate | 10–50+ | Orchestrates multiple skills. See breakdown below. |

### Investigation workflow (censys-investigate)

A full investigation runs through a baseline collection phase and then
branches into decision trees based on findings. A typical session:

| Phase | Commands | Calls |
|---|---|---|
| Baseline view | 1 `view` | 1 |
| Host history | 1 `history` | 1 |
| Domain chase | 1 `history` per domain | 1–5 |
| Indicator triage | 1 `search` + 1 `aggregate` per indicator | 2–10 |
| Pivot trees | 1 `search` + 1 `history` per hit | 5–30+ |

A moderate investigation with 3 indicators and 2 hits each runs roughly
**20–25 API calls**. Deep investigations with many pivots can exceed 150.

### Observed usage (from real investigations)

Based on analysis of 15 investigation sessions:

| Metric | API calls |
|---|---|
| Median per session | 27 |
| Average per session | 53 |
| Lightest session | 5 |
| Heaviest session | 185 |

Call distribution by subcommand:

| Subcommand | Share |
|---|---|
| `censys search` | 63% |
| `censys view` | 32% |
| `censys history` | 5% |
| `censys censeye` | 1% |
| `censys aggregate` | < 1% |

### Controlling costs

The biggest driver of API usage is `censys search` (two-thirds of all
calls). To limit consumption:

- Use `--max-pages` to cap search pagination (default is 1 page / 100 results)
- Use `censys-aggregate` for counting before committing to full result pulls
- Limit pivot depth in `censys-investigate` by narrowing indicator scope early
