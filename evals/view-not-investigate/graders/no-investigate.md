---
type: tool_used
tool: Skill
input_match: '"skill":\s*"(?:[\w-]+:)?censys-investigate"'
max: 0
---

The censys-investigate skill must NOT fire for a simple host lookup.
Investigate is heavyweight (20-50+ API calls) and only appropriate when
the user explicitly requests a multi-step investigation.
