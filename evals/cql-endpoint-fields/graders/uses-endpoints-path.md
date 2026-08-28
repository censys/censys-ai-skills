---
type: regex
target: last_message
pattern: "host\\.services\\.endpoints\\.http\\.favicons\\.hash_sha256"
match: contains
---

The response must use the correct endpoint field path for favicon hash:
host.services.endpoints.http.favicons.hash_sha256

A common mistake is omitting the endpoints. level, which returns a 422.
