---
type: regex
target: trace
pattern: "censys\\s+history"
match: contains
---

The agent must use the `censys history` subcommand for temporal queries,
not `censys view` or `censys search`.
