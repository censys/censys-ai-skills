---
type: regex
target: trace
pattern: "censys censeye"
match: contains
---

The agent must invoke the `censys censeye` CLI subcommand, not
`censys search` or `censys view`.
