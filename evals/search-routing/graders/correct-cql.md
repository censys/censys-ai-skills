---
type: llm
target: trace
criteria: |
  The agent must construct a CQL query that finds SSH hosts on
  non-standard ports. A correct query includes:
  1. A condition matching SSH protocol (protocol=SSH or protocol:"SSH")
  2. A negation excluding port 22 (not port: 22 or not port=22)
  3. Ideally scoped within host.services: (...) grouping

  The conditions can appear in any order. Compound grouping
  (host.services: (protocol=SSH and not port: 22)) is preferred
  but not strictly required.

  Score 1.0 if the query correctly finds non-standard-port SSH hosts.
  Score 0.5 if it has the right conditions but poor scoping.
  Score 0.0 if it misses the SSH or non-standard-port condition.
focus: Is the CQL query correct for finding SSH on non-standard ports?
---

The constructed CQL query must scope both SSH protocol and non-standard
port conditions, ideally using nested grouping:
host.services: (protocol=SSH and not port: 22).
