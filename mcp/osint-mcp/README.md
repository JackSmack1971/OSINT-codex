# rjn32s/osint-mcp

Status: **DISABLED / NOT ENABLED**.

Phase B verified a Python MCP server over STDIO, but its documented first run
auto-installs OSINT binaries and exposes port-scan and secrets-scan tools. That
conflicts with the repository's Docker-only host policy and passive-only tool
boundary. No Codex registration, wrapper, image, or invented transport is
provided. Reconsider only after a separately reviewed container build and
explicit passive allowlist are verified.
