# Pivoting patterns

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
7. **C2 framework pivot** — for hosts running Cobalt Strike, Sliver, or other
   C2 frameworks with extracted configs: search the framework-specific endpoint
   fields (`host.services.endpoints.cobalt_strike.x64.*`, etc.). Population-check
   watermarks/license IDs first — shared cracked licenses produce false clusters
   (e.g., CS watermark `987654321` spans 77+ unrelated hosts). The framework's
   *public key* and *beacon config URIs* are more operator-specific than the
   watermark. Note: endpoint fields only index currently-active listeners — dark
   infrastructure won't appear.

Always aggregate (`censys aggregate`) before pulling full results to check
population size and distribution.

## Bulk verification

When an investigation surfaces a large candidate cluster (10+ hosts), verify
membership efficiently:

1. **Batch history pulls.** Budget time generously for bulk history pulls.
   Even with streaming, a 90-day pull on an active host takes 60–180 seconds,
   so 50 hosts sequentially is measured in hours, not minutes. Save every
   result to `data/`.
2. **Multi-signal confirmation.** Require at least two independent indicators
   (e.g., SSH key + CS watermark, or SSH key + port rotation pattern) before
   confirming cluster membership. A single shared indicator can be coincidence.
3. **Track verification rate.** Report confirmed/total (e.g., "50/50 verified")
   in the findings. A 100% rate on a large candidate set is itself a signal — it
   suggests the cluster definition is correct and the operator provisions from
   a template.

Reference `censys-cenql` for field paths, `censys-search` for CLI execution.
