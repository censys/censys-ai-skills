---
name: Search skill routing
tags: [routing, search]
plugins: ["../.."]
runs: 3
max_turns: 5
timeout_seconds: 120
allowed_tools: [Bash, Read]
---

Search censys for hosts running SSH on a non-standard port in Germany.
