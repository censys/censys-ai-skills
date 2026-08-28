# Decision trees

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
  │   ├─ Run censys history on the hit IP (save to data/)
  │   ├─ Compare: timeline overlap? shared signals? same stack?
  │   │   ├─ Strong overlap → linked infrastructure. Add indicators, re-enter Tree 1
  │   │   └─ Weak/no overlap → coincidence, document why
  │   └─ Check for ownership boundary before shared indicator appeared
  └─ No hits → distinguish two cases:
      ├─ Field is indexed AND target service is live → truly unique (this IS a finding)
      └─ Target service is dark/offline → "not currently visible," not necessarily unique
          └─ Verify field is indexed: run a wildcard query (field:*). If it returns
             results for OTHER hosts but not the target, the target's services are dark.
             Document as "potentially unique — unverifiable while dark" and flag for
             re-check when infrastructure reactivates.
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
  ├─ Run censys history (host history + cert follow, save to data/)
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
  ├─ Run censys history on the IP (save to data/)
  ├─ Shared hosting/parking → dead end, document
  ├─ Similar service profile → enter Tree 4
  └─ Unrelated → document and move on
For each new domain:
  ├─ Run censys history on the domain (save to data/)
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
