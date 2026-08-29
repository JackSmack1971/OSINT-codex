---
name: osint-status
description: Show the compact, repository-local operational status of the OSINT control plane with `$osint-status`; does not replace or modify Codex `/status`.
---

# Operational status

Use this skill only for read-only status inspection. It is an OSINT control-plane view and does not replace, emulate, or modify Codex’s built-in `/status`. Do not invoke collection, start/stop services, alter configuration, read provider secret values, or change case artifacts.

Run the repository-relative PowerShell command `scripts/status.ps1` from the project root and report its compact table unchanged or with only harmless formatting. The table must include:

- active case and authorization state derived from the newest case directory and `case.json`;
- Docker Desktop/engine availability from a real `docker info` result, and Compose state from real `docker compose config` plus `docker compose ps` results;
- MCP server configuration from the project `.codex/config.toml`; report no configured servers as `DISABLED` and do not call a stdio process healthy without a protocol-level health result;
- disabled integrations from the repository’s recorded dispositions;
- configured optional API provider names only, never values, tokens, or secrets;
- latest tool execution from the active case audit log, plus findings, entities/relationships, unresolved contradictions, and intelligence gaps from case artifacts.

Use truthful degraded states such as `UNAVAILABLE`, `STOPPED`, `UNKNOWN`, or `FAILED` when signals are absent or a check cannot be completed. Never substitute a configured service, valid Compose file, process existence, or static documentation for runtime health. If Docker, Compose, MCP configuration, the active case, or optional providers are absent, report that fact and continue with the remaining checks.

The script must be Windows-native, use paths relative to the repository, exit without exposing secrets, and leave the built-in `/status` untouched.
