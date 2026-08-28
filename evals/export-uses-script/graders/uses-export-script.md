---
type: regex
target: trace
pattern: "censys-export\\.sh"
match: contains
---

The export workflow must use the plugin's censys-export.sh script rather
than inline jq pipelines. The script handles streaming, format selection,
and output file writing.
