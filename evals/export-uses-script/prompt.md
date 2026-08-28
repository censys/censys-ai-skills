---
name: Export uses plugin script
tags: [search, export, scripts]
plugins: ["../.."]
runs: 3
max_turns: 5
timeout_seconds: 120
allowed_tools: [Bash, Read]
---

Export all censys hosts with port 443 open in Germany as a list of IPs
to a file called german_https.txt.
