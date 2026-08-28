---
type: tool_used
tool: Skill
input_match: '"skill":\s*"(?:[\w-]+:)?censys-view"'
min: 1
---

A single-host lookup ("what's running on this IP") must route to
censys-view, not censys-investigate. The investigate skill is for
multi-step methodology requests, not simple lookups.
