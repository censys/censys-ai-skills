---
name: Analyze routing
tags: [analyze, routing]
plugins: ["../.."]
runs: 3
max_turns: 5
timeout_seconds: 120
allowed_tools: [Bash, Read]
---

I have a file called search_results.json with Censys search output. Load it into SQLite so I can query the results with SQL.
