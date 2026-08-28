---
name: Aggregate excludes streaming flag
tags: [aggregate, correctness]
plugins: ["../.."]
runs: 3
max_turns: 5
timeout_seconds: 120
allowed_tools: [Bash, Read]
---

Use censys to show me the top 10 countries for hosts running SSH.
