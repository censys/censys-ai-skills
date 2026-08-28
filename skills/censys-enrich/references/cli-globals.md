# Global CLI flags

These flags apply to every `censys` subcommand. Per-command exceptions are
noted inline.

## Output format flags

| Flag | Alias | Description | Default | Exceptions |
|---|---|---|---|---|
| `--output-format` | `-O` | Output format: `json`, `yaml`, `tree`, `short`, `template` | `json` for most; `short` for `aggregate` and `censeye` | `history` does not support `short` or `template` (exit code 2). `aggregate` and `censeye` do not support `template`. |
| `--streaming` | `-S` | Emit NDJSON (one JSON object per line) instead of a single JSON array | off | Only supported on `search`, `view`, `history`, and `enrich`. Not available on `aggregate` or `censeye`. |

`-O` and `-S` are **mutually exclusive** — streaming is the output format
when `-S` is active, so passing both is redundant and may error depending on
the subcommand.

## Diagnostic flags

| Flag | Alias | Description |
|---|---|---|
| `--quiet` | `-q` | Suppress non-essential output (status line, response metadata) |
| `--debug` | | Verbose diagnostic logging |
| `--no-color` | | Disable ANSI color in terminal output |
| `--no-spinner` | | Disable the progress spinner (useful when piping or in CI) |
| `--timeout-http` | | Override the HTTP client timeout |

## Organization flag

| Flag | Alias | Description |
|---|---|---|
| `--org-id` | `-o` | Explicitly set the organization ID for the request |

**PAT users:** if you authenticated with a Personal Access Token
(`censys config auth add`) rather than OAuth (`censys auth login`), the CLI
cannot always infer which organization to scope the request to. If a command
returns an org-related auth error or empty results you didn't expect, pass
`--org-id <org-id>` explicitly (or set it once via `censys config org-id`).

**OAuth users and `enrich`:** when authenticated via OAuth, the organization
is fixed at login time. `--org-id` is not accepted by `enrich` under OAuth
and will error. Re-run `censys auth login` to switch orgs.
