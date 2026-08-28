# CQL Query Cookbook

Copy-paste CQL examples for common query patterns. See the parent skill
(`censys-cql`) for field paths, operators, and syntax fundamentals.

```bash
# 1. SSH hosts on the standard port
censys search "host.services: (protocol=SSH and port: 22)"

# 2. Hosts serving a specific TLS leaf certificate by SHA-256
censys search "host.services.tls.certificates.leaf_fp_sha_256: <sha256>"

# 3. Hosts within a CIDR range
censys search "host.ip: '198.51.100.0/24'"

# 4. Hosts on a specific autonomous system
censys search "host.autonomous_system.asn: 13335"

# 5. Hosts running nginx (use software field — header queries return 422; see Gotcha #3)
censys search "host.services.software.product: nginx"

# 6. Certificates issued by Let's Encrypt (quoted apostrophe)
censys search "cert.parsed.issuer.organization: 'Let'\''s Encrypt'"

# 7. Non-standard-port SSH hosts in Germany (negation + compound grouping)
censys search "host.services: (protocol=SSH and not port: 22) and host.location.country: Germany"

# 8. Hosts matching a JARM TLS fingerprint
censys search "host.services.jarm: <jarm_hash>"

# 9. Hosts labeled as remote-access exposed
censys search 'labels="remote-access"'

# 10. Web properties running Apache
censys search "webproperty.software.product: Apache"

# 11. Hosts with a specific HTTP body hash (e.g., a custom web app)
censys search 'host.services.endpoints.http.body_hash_sha256="<sha256>"'

# 12. Hosts with a specific string in the HTTP response body
censys search 'host.services.endpoints.http.body:"index-Bv1WZ4hk.js"'

# 13. Hosts with a specific HTML title
censys search 'host.services.endpoints.http.html_title="Connection Manager"'

# 14. Hosts running Cobalt Strike with a specific watermark
censys search 'host.services.endpoints.cobalt_strike.x64.watermark=987654321'

# 15. Hosts running Cobalt Strike with a specific public key
censys search 'host.services.endpoints.cobalt_strike.x64.public_key="<base64_key>"'
```
