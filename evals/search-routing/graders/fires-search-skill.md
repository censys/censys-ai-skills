---
type: tool_used
tool: Skill
input_match: '"skill":\s*"(?:[\w-]+:)?censys-search"'
min: 1
---

The agent must invoke the censys-search skill (not censys-cenql, censys-view,
or censys-aggregate) for a query that asks to search for hosts matching
a condition.
