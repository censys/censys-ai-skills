---
type: regex
target: trace
pattern: "host\\.services.*protocol.*SSH.*not.*port.*22|host\\.services.*SSH.*not.*22"
flags: i
match: contains
---

The constructed CQL query must scope both SSH protocol and non-standard
port conditions, ideally using nested grouping:
host.services: (protocol=SSH and not port: 22).
