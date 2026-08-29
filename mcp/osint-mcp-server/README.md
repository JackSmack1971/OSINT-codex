# badchars/osint-mcp-server

Status: **OPTIONAL / ENABLED** as a project-scoped, local Docker build.

The pinned upstream commit is `7611f70e6a82425f1aa1e40d964057ed5f0dcb60` and
the upstream license is MIT. The upstream server is MCP over local STDIO; this
integration preserves that transport by running its native `node dist/index.js`
process through ephemeral `docker compose run --rm -T`. It does not add an HTTP
wrapper or invent an endpoint.

Only the upstream tools reviewed as public/passive metadata lookups are exposed
through `.codex/config.toml`. Shodan, VirusTotal, SecurityTrails, Censys,
`osint_domain_recon`, and other non-allowlisted tools remain unavailable at the
Codex boundary. Optional API keys are passed only from environment variables
and are not stored in this repository.

Build and verify from the repository root:

```powershell
docker compose -f .\mcp\docker-compose.yml --profile mcp build badchars-osint-mcp
docker compose -f .\mcp\docker-compose.yml --profile mcp run --rm -T badchars-osint-mcp
```

The second command intentionally stays attached because it is the native MCP
STDIO session; Codex starts it from the checked-in project configuration.
