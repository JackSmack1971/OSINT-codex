# Containerized OSINT utilities

Every utility runs as an ephemeral Compose service. The Windows host needs only
Docker Desktop, Git, PowerShell, and Codex; Python, Go, and the utilities stay
inside images.

The services require `OSINT_CASE_ID`, `OSINT_TARGET`, and `OSINT_SCOPE`, plus a
mounted cases directory containing structured `case.json` authorization.
Sherlock, Maigret, and Holehe additionally require
`OSINT_ENABLE_SENSITIVE=1`; `httpx` requires `OSINT_ENABLE_LOW_IMPACT_HTTP=1`;
and `nuclei` requires `OSINT_ENABLE_VULN_TEMPLATES=1`. Those variables are
deliberately absent from `.env.example`.

Run a utility only after the authorization skill has created a current ROE:

```powershell
$env:OSINT_CASE_ID='CASE-ID'
$env:OSINT_TARGET='example.com'
$env:OSINT_SCOPE='example.com only; passive public sources only'
docker compose -f .\mcp\docker-compose.yml --profile tools run --rm -T subfinder example.com
```

The Compose file pins verified registry digests and source commits. Services
have no host ports, no Docker socket, read-only roots, dropped capabilities,
and no privilege escalation. Secret scanners always request native redaction;
`redact-output.sh` is also available for downstream JSON processing.
