---
type: llm
target: trace
criteria: |
  The agent must NOT attempt to count hosts by summing censys aggregate
  bucket values. The aggregate command's -n flag limits the bucket list
  (default 25), so the sum can be far below the true total.

  Score 1.0 if the agent uses censys-count.sh or pages search results.
  Score 0.5 if it uses censys search with --max-pages -1 and counts
  with jq (correct but doesn't use the provided script).
  Score 0.0 if it uses censys aggregate to count.
focus: Does the agent avoid using aggregate as a counting method?
---
