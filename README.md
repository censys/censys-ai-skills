# Censys AI Skills

AI-assisted [Censys](https://censys.io) internet intelligence via the
[Censys CLI](https://github.com/Censys/cencli). Ships as a
[Claude Code](https://docs.anthropic.com/en/docs/claude-code) plugin and
works with other AI coding tools — see
[Usage with other AI tools](#usage-with-other-ai-tools).

## Install (Claude Code)

```bash
claude plugin marketplace add censys/censys-ai-skills
claude plugin install censys
```

### Prerequisites

The plugin requires [cencli](https://github.com/Censys/cencli) ≥ 1.0:

```bash
# Homebrew (macOS/Linux)
brew install --cask censys/tap/cencli

# Or download the release binary directly
# https://github.com/censys/cencli/releases/latest
```

Verify the install:

```bash
censys version   # should print JSON with a 1.x version
```

> **Note:** `pip install censys` installs [censys-python](https://github.com/censys/censys-python)
> (the legacy Search API wrapper), not cencli. The two are different tools with
> different CLIs. There is no pip package for cencli.

### Authenticate

```bash
censys auth login          # OAuth (interactive)
# or
censys config auth add     # PAT (non-interactive)
```

### Additional config

- For enrich: `censys config org-id`
- For censeye / cert history: Threat Hunting module access required

## Usage with other AI tools

The skills are standalone markdown files that work with any AI coding
assistant that supports custom instructions. The Claude Code plugin
system handles skill loading and path resolution automatically; other
tools require manual setup.

### Cursor / Windsurf / other AI editors

Clone the repo and reference the skills from your project instructions:

```bash
git clone https://github.com/censys/censys-ai-skills.git
```

Then include individual skill files in your editor's instruction system:

| Editor | Instruction file | Include syntax |
|---|---|---|
| Cursor | `.cursorrules` or `.cursor/rules/*.md` | Paste skill content or reference the file path |
| Windsurf | `.windsurfrules` | Paste skill content |
| Cline | `.clinerules` | Paste skill content |

Pick the skills relevant to your workflow. For most users:
- `skills/censys-search/SKILL.md` and `skills/censys-view/SKILL.md` for basic queries
- `skills/censys-cql/SKILL.md` for query syntax reference
- `skills/censys-investigate/SKILL.md` for full investigation methodology

### Codex / agents without a plugin system

Clone the repo into your project or reference it from your agent's
system prompt. Each skill folder (`skills/<name>/`) is self-contained
with its own `SKILL.md` and `references/` directory.

```bash
# Example: include in an AGENTS.md or system prompt
@censys-ai-skills/skills/censys-search/SKILL.md
@censys-ai-skills/skills/censys-cql/SKILL.md
```

### Notes for non-Claude Code harnesses

- **Path variables**: Skills reference files using `${CLAUDE_SKILL_DIR}`
  and `${CLAUDE_PLUGIN_ROOT}`. These are Claude Code-specific. On other
  harnesses, resolve them relative to the skill folder and repo root
  respectively. The model can typically infer the correct paths from
  context.
- **Scripts**: The `scripts/` directory contains shell helpers
  (`censys-count.sh`, `censys-export.sh`, `censys-to-sqlite.sh`).
  These work on any harness with bash access — reference them by their
  path relative to the repo root.
- **Hooks**: The `hooks/` directory provides advisory warnings for
  Claude Code's hook system. Other harnesses can ignore this directory.
- **Skill content**: The methodology, CQL syntax, CLI flags, and
  operational caveats in each skill are plain markdown. They work as
  reference material regardless of the harness.

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
| **Command wrappers** | censys-search, censys-view, censys-aggregate, censys-enrich, censys-censeye, censys-timeline | Translate a user request into the right CLI command, flags, and output handling. One skill per data-retrieval subcommand. |
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
| censys-search | 1 per page | Default is 1 page (100 results). `--max-pages -1` fetches up to 100 pages (10,000 results at page-size 100) — not unbounded. |
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
- Use `censys-aggregate` to see distribution before pulling full results — it shows the shape of the data, not an exact total
- Limit pivot depth in `censys-investigate` by narrowing indicator scope early
