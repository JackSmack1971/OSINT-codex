# Domain to infrastructure

Use only authorized, passive sources: RDAP/WHOIS, passive DNS, certificate transparency and crt.sh, historical DNS, public ASN/netblock registries, public archives, and passive Shodan/Censys data when available. External utilities run in Docker and active-probing modes remain disabled unless separately authorized under a documented low-impact ROE.

## Workflow

1. Normalize the domain and record the requested indicator and collection time.
2. Collect registrations, nameservers, passive DNS, certificate names and fingerprints, historical resolutions, ASN/netblock ownership, and passive technology observations.
3. Store each observation with source ID, provider/tool, retrieval timestamp, observation or publication time, raw evidence path, SHA-256, reliability, and notes.
4. Mark every observation `current`, `historical`, or `unknown`; do not silently merge time periods.
5. Build auditable domain, hostname, IP, ASN, netblock, certificate, organization, and technology entities and relationships with supporting source IDs and confidence.
6. Corroborate material claims across genuinely independent providers. Shared hosting, nameservers, certificates, or upstream datasets are leads, not proof of common ownership.

Separate observed infrastructure from derived relationships and assessments. Report `no data found` exactly when an approved source yields no usable evidence, and list unresolved ownership, attribution, or historical gaps explicitly.
