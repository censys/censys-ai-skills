---
type: tool_used
tool: Skill
input_match: '"skill":\s*"(?:[\w-]+:)?censys-enrich"'
min: 1
---

A bulk IP triage or reputation check request must route to censys-enrich,
not censys-view (which is single-host) or censys-search (which runs CenQL
queries, not IP enrichment).
