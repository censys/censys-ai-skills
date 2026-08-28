---
type: regex
target: trace
pattern: "censys-to-sqlite\\.sh"
match: contains
---

Loading Censys JSON into SQLite should use the plugin's
censys-to-sqlite.sh script rather than manual sqlite3 commands.
