---
name: Enrich skill routing
tags: [routing, enrich]
plugins: ["../.."]
runs: 3
max_turns: 5
timeout_seconds: 120
allowed_tools: [Bash, Read]
---

I have a list of IPs from a threat feed. Use censys to enrich them and
tell me which ones have a bad reputation.
