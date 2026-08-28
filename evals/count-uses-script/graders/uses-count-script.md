---
type: regex
target: trace
pattern: "censys-count\\.sh"
match: contains
---

Host counting must use the plugin's censys-count.sh script, which pages
the full result set and detects the 10,000-result ceiling. The agent
must NOT count by using --page-size 1 --max-pages 1 (returns one record,
no total) or by summing aggregate buckets (the -n default of 25 truncates
the bucket list).
