---
type: regex
target: trace
pattern: "censys\\s+aggregate\\s+.*-S|censys\\s+aggregate\\s+.*--streaming"
match: not_contains
---

The censys aggregate command does not support -S (streaming). The agent
must not include -S or --streaming in any aggregate command.
