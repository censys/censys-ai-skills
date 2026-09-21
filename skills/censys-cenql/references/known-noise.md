# Known Noise Indicators

Indicators that look distinctive but return too many unrelated matches for
attribution (from investigation data). Check this list during indicator triage
before building pivot queries.

| Indicator | Why it's noise |
|---|---|
| `WIN-*` hostname in cert CN on Hetzner (AS24940) | Default Windows VPS hostname. Hundreds of hosts share each variant. Not operator-specific. |
| Default Create-React-App favicon hash | Matches any CRA-scaffolded app that hasn't customized the favicon. |
| Express.js 404 body hash (`Cannot GET /`) | Default Express error page. Extremely common across all Express deployments. |
| Common JARM fingerprints for Node.js/Express | Too many matches for attribution when used as the sole pivot. Combine with other indicators. |
| Font Awesome CDN SRI hashes | Shared CDN resource. Referenced by millions of pages. |
| Generic inline CSS (`width: 100vw; height: 100vh; display: flex`) | Common layout pattern. Produces false positives from firewall/appliance UIs. |
| Cobalt Strike watermark `987654321` | Cracked/leaked CS license. 77+ hosts globally (predominantly Chinese cloud: Tencent, Alibaba, Huawei). Shared across unrelated operators — not attribution-grade. |
| Cobalt Strike empty-404 banner hash | Default CS HTTP listener response: `Server: Apache`, 0-byte body, 404 status. Matches any default-config CS listener globally. |

This list should grow as investigations reveal new noise patterns.
