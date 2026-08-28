---
name: censys-timeline
description: Use when the user wants temporal analysis of how a Censys-tracked asset changed over time — e.g. "censys timeline," "censys host history," "censys what changed on this host," "censys when did this service appear," "censys change detection," "censys temporal analysis," "censys track cert rotations," or "censys did this host change hands." Wraps `censys history` for hosts, web properties, and certificates. Not for current-state lookups (see censys-view) or criteria search (see censys-search).
version: 0.1.0
---

# censys-timeline

## When to use

Use this skill when the user wants to understand how an asset changed across a
window of time, rather than its current state. Typical asks:

- "censys timeline for 8.8.8.8"
- "censys host history — what changed on this box last month"
- "censys when did port 8443 first appear on this IP"
- "censys change detection over the last 90 days"
- "censys temporal analysis of this web property"
- "did this host change hands, per censys"

Do **not** use this for a single point-in-time lookup (`censys-view`), for
criteria-based search (`censys-search`), or for post-retrieval jq/SQLite recipes
on data you already have (`censys-analyze`, which this skill hands off to once
timeline JSON is pulled). This skill covers pulling and interpreting `censys
history` output specifically.

## Invocation

```bash
censys history <asset> [flags]
```

`<asset>` type is auto-detected, same rules as `censys view`:

| Input pattern | Resolved as |
|---|---|
| IP address (e.g. `8.8.8.8`) | Host |
| `hostname:port` | Web property |
| 64-character hex string | Certificate (SHA-256 fingerprint) — requires Threat Hunting module access |

### Skill-specific flags

| Flag | Purpose |
|---|---|
| `--duration`, `-d <window>` | Time window ending now, e.g. `24h`, `7d` (default), `4w`, `1y` |
| `--start`, `-s <RFC3339>` | Absolute window start |
| `--end`, `-e <RFC3339>` | Absolute window end |

`--start`/`--end` and `--duration` compose (per CLI help examples):

| Flags given | Window |
|---|---|
| `--duration` only | now − duration → now |
| `--start` + `--duration` | start → start + duration |
| `--end` + `--duration` | end − duration → end |
| `--start` + `--end` | exact window; `--duration` ignored if also passed |

### Global CLI flags (apply to all `censys` subcommands)

| Flag | Purpose |
|---|---|
| `--output-format`, `-O <fmt>` | `json` (default), `yaml`, `tree`. **`short` and `template` are not supported for `history`** (exit code 2). |
| `--streaming`, `-S` | Emit NDJSON as events arrive rather than buffering the full array |
| `--quiet`, `-q` | Suppress non-essential output |
| `--debug` | Verbose diagnostic logging |
| `--no-color` | Disable ANSI color in terminal output |
| `--no-spinner` | Disable the progress spinner (useful when piping/redirecting) |
| `--timeout-http <duration>` | Override the HTTP client timeout |
| `--org-id`, `-o <id>` | Target a specific organization ID |

## Event model

A host timeline is a sequence of discrete events, each with an `event_time` and
a typed payload key. Treat the timeline as a diff stream, not a series of full
snapshots — each event describes what changed, not the whole host state at that
moment.

### Event types and their JSON structure

Each event has `event_time` plus exactly one of these payload keys (verified against cencli 1.1.3 output, 2026-08):

| Payload key | What it captures | Protocol field |
|---|---|---|
| `endpoint_scanned` | HTTP/banner-level observation (headers, body, HTML title) | `.endpoint_scanned.scan.endpoint_type` |
| `service_scanned` | Service-level observation (TLS, SSH, RDP, protocol ID) | `.service_scanned.scan.protocol` |
| `jarm_scanned` | JARM fingerprint observation | `.jarm_scanned.scan.fingerprint` |
| `forward_dns_resolved` | DNS A/AAAA resolution change | — |
| `reverse_dns_resolved` | Reverse DNS (PTR) change | — |
| `whois_updated` | WHOIS registration change | — |

Note that `endpoint_scanned` and `service_scanned` use **different field names** for the protocol (`endpoint_type` vs `protocol`). A single port can produce both event types, and can show multiple protocols (e.g. port 8888 responding as both `HTTP` and `DVR_IP` depending on the probe).

### Semantic categories

Use event types to classify changes:

- **Service events** (`service_scanned`) — a port opened, closed, or its
  transport/application protocol changed.
- **Endpoint events** (`endpoint_scanned`) — the `Server` header, raw banner,
  HTML title, or other application-layer text changed.
- **Certificate events** (`service_scanned` with `.tls`) — the TLS certificate
  rotated. Note: cert fingerprint lives at `.service_scanned.scan.tls.fingerprint_sha256` (an extra `.scan` level compared to `censys view` output).
- **Infrastructure events** (`whois_updated`, DNS events) — the announcing AS
  changed, WHOIS registration updated, or DNS resolution shifted.

## Common patterns

```bash
# Last 30 days — always save to file for reuse across jq passes
censys history 8.8.8.8 --duration 30d -O json > data/timeline.json

# Bounded window for incident investigation
censys history 8.8.8.8 --start 2025-06-01T00:00:00Z --end 2025-06-15T00:00:00Z -O json

# Web property history
censys history example.com:443 --duration 14d -O json

# Certificate observation history (Threat Hunting module required)
censys history <sha256> --start 2025-01-01T00:00:00Z --end 2025-06-01T00:00:00Z

# Stream events as NDJSON instead of buffering a full array
censys history 8.8.8.8 --duration 90d -S
```

## Temporal analysis with jq

```bash
# When did a specific port first appear?
jq '[.[] | select(.service_scanned.scan.port == 8443) | .event_time] | sort | .[0]' \
  data/timeline.json

# Track cert rotations over time (unique leaf fingerprints in order)
jq '[.[] | .service_scanned.scan.tls.fingerprint_sha256 // empty |
    {cert: .}] | unique_by(.cert)' data/timeline.json

# Find all service-level changes, chronologically
jq '[.[] | select(.service_scanned) | {time: .event_time,
    port: .service_scanned.scan.port,
    protocol: .service_scanned.scan.protocol}] | sort_by(.time)' \
  data/timeline.json

# Compare host state at two points in time (snapshot diff, not history events)
censys view 1.2.3.4 --at-time 2025-06-01T00:00:00Z -O json > data/before.json
censys view 1.2.3.4 -O json > data/after.json
diff <(jq -S '.[0].services | sort_by(.port)' data/before.json) \
     <(jq -S '.[0].services | sort_by(.port)' data/after.json)
```

For anything beyond these direct lookups — cross-referencing multiple hosts'
timelines, loading into SQLite for aggregation, batch cert analysis — hand off
to `censys-analyze` once the timeline JSON is on disk.

## Change detection workflow

1. Pull history with a wide window: `censys history <ip> --duration 90d -O json > data/timeline.json`.
2. Extract event timestamps and types with jq (see patterns above) to build a
   chronological list of what changed and when.
3. Look for **clusters** — multiple distinct event types (e.g. new cert + new
   SSH key + new open ports) landing within the same short window. A cluster
   across independent signals is a much stronger change signal than any single
   event in isolation.
4. For each cluster, snapshot before and after with `censys view --at-time`
   bracketing the cluster's start and end.
5. Diff the before/after snapshots (see the `diff` pattern above) to pin down
   exactly what changed, rather than inferring it from event summaries alone.

## Interpreting timeline data

- **Routine, low signal** — certificate renewals on a roughly 90-day cycle (Let's
  Encrypt and similar ACME issuers), minor banner version bumps, transient
  port flaps. Expected background noise on any long-lived host.
- **Significant, worth flagging** — SSH host key rotation, several services
  appearing or disappearing at the same time, an AS number change, or a
  wholesale change of certificate issuer (e.g. a self-signed cert replacing a
  publicly-trusted one, or vice versa).
- **Attribution boundaries** — when a cluster of simultaneous changes lines up
  (new SSH host key + new certificates + new service set appearing together),
  treat that cluster as a probable operator/tenant boundary. Activity observed
  before the cluster and activity observed after it may belong to different
  actors entirely — don't attribute both sides of the boundary to the same
  operator without corroborating evidence.
- **Service lifecycle** — a service that has been present across the entire
  queried window is "normal" for that host. A service that first appears
  partway through the window (especially one atypical for the host's apparent
  role) is a candidate for new deployment or compromise, and warrants closer
  inspection of what else changed around the same `event_time`.

## Performance characteristics

History volume depends heavily on the host and time window. A busy,
well-scanned host can produce thousands of events per day — measured:
8.8.8.8 returned 2,621 events for a single day (measured on cencli 1.1.3, 2026-08).

**Always use streaming (`-S`) for history pulls.** Buffered output (`-O json`
without `-S`) loads the entire result into memory before writing anything.
On a large history this can take minutes or never complete. Streaming emits
events as they arrive and completes in a fraction of the time.

For bulk history pulls across many hosts:

- **Start narrow.** Use `--duration 7d` or `--duration 30d` to confirm
  the signal is there before widening. A 1-year pull on an active host
  can produce hundreds of thousands of events.
- **Chunk into batches of 3–5** with extended timeouts (300s+) if doing
  sequential pulls. Save each result to `data/` as it completes.
- **Budget time generously.** Even with streaming, a 90-day pull on an
  active host can take 60–180 seconds.

## Parsing CLI output programmatically

When redirecting `censys history -O json` to a file and parsing it later:

1. **stdout is valid JSON.** The output (when using `-O json`) is a single
   JSON array starting on the first line. Parse it directly — no line-skipping
   needed. The status line goes to stderr and `-q` suppresses it.
2. **Empty results may be `null`.** Some hosts return `null` instead of `[]`
   for zero events. Defensive parsing: `data = json.load(f) or []`.
3. **Large outputs.** A 3000-event history can be several MB of JSON. For
   repeated analysis passes, save to disk and use `jq` or load into
   a Python dict once rather than re-pulling.

## Error handling

| Error | Cause | Resolution |
|---|---|---|
| Exit code 2, unsupported format | `-O short` or `-O template` passed to `history` | Use `json`, `yaml`, or `tree` instead |
| `[Threat Hunting Required]` (or similar entitlement error) | Certificate history requested without Threat Hunting module access | Confirm module entitlement, or fall back to host/web-property history if the cert itself isn't the actual target |
| Slow response / rate limited | Window too wide (e.g. `1y`) or too many concurrent history pulls | Start with `--duration 7d`, confirm the signal is there, then widen incrementally rather than jumping straight to a multi-year pull. See Performance characteristics above for expected times. |
| Empty result set | No events in the requested window | Widen the window, or confirm the asset had any Censys-observed activity at all via `censys view` first |

## Caveats

- History events are diffs against the prior observed state, not full
  snapshots — don't assume every field is repeated on every event. Use
  `censys view --at-time` when a complete point-in-time record is needed.
- Wide time windows are slow and count more heavily against rate limits. Widen
  incrementally (`7d` → `30d` → `90d`) rather than defaulting to a large window.
- GeoIP/location events reflect registry and geolocation data, which can lag or
  be imprecise — corroborate an apparent "location change" with the
  accompanying AS change before treating it as a strong reassignment signal.
- Labels and event classifications are Censys-derived heuristics; treat them as
  triage aids, not ground truth, especially for attribution calls.
- **A port can be absent from the whole event stream and still be open.** The
  history stream does not always cover every port on a host. A port can produce
  zero events across a full year — no success events and no failure events — while
  `censys view` shows the same port scanned on the same day, with a complete
  banner. Absence of events is not evidence that the service was down or
  intermittent.

  Confirm coverage before you make any claim about when a service started, stopped,
  or flapped:

  ```bash
  # ports present in the history stream
  jq -r '[.[].service_scanned.scan.port] | unique' history.json
  # ports open right now
  jq -r '[.[0].services[].port] | sort' view.json
  ```

  If a port is in the second list but not the first, the history stream does not
  cover that port. State this as an instrumentation gap. Two consequences follow:

  1. First-seen dates from history are a **lower bound**, and they are anchored
     only to the ports the stream does cover.
  2. Do not report the gap as intermittent service. A real case: ports 8085–8087
     produced zero events across one year on five of six C2 hosts, while the
     current snapshot showed all three ports scanned that morning. Reading the gap
     as intermittent C2 would have been a false finding.

## Cross-references

- For a single point-in-time snapshot (including `--at-time` on a specific
  date), see `censys-view`.
- For post-retrieval analysis of saved timeline JSON — jq recipes, SQLite
  loading, batch cert correlation, cross-referencing multiple assets — see
  `censys-analyze`.
- For the broader investigation workflow this fits into, see
  `censys-investigate`.
