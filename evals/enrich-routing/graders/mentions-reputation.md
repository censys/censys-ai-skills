---
type: regex
target: last_message
pattern: "reputation|score_level"
flags: i
match: contains
---

The response should reference reputation scoring (the enrich endpoint's
key differentiator from view) since the user asked specifically about
bad reputation.
