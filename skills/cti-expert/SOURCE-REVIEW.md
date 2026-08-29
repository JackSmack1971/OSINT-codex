# Source review: `7onez/cti-expert`

Disposition: `DISABLED` — reviewed source material only. No upstream file in this directory is loaded by Codex, and no Claude plugin, hook, command, or MCP server is registered.

## Pin and provenance

- Canonical source: <https://github.com/7onez/cti-expert>
- Reviewed revision: `c8e051aeb5d68f3b66009b8cdc61bf1db4840710`
- Revision observed: 2026-08-27 UTC
- License: repository `LICENSE` states MIT with an ethical-use addendum; repository metadata was not a sufficient SPDX confirmation. Treat redistribution of source as pending maintainer/license verification.
- Reviewed checkout: temporary, detached checkout; no upstream code was executed.

## Imported or adapted

- No source files, scripts, hooks, manifests, or agent instructions were imported.
- Existing local case/evidence standards were not replaced or weakened by this material.

## Safety review

- Instructions/manifests: Claude-oriented `AGENTS.md`, `SKILL.md`, `.claude-plugin/plugin.json`, hooks, commands, and a bundled MCP server; none are Codex-compatible or trusted here.
- Commands/scripts: install and smoke flows include host package installation, curl/apt flows, and guidance involving `--no-verify`; many tools perform direct network collection.
- Network behavior: web-pivot, Wayback, API, breach, identity, and other collection paths are present; some are active or privacy-sensitive and require per-tool authorization.
- Secrets: API-key registries and integrations are present. Raw credentials, tokens, cookies, and private keys are prohibited in this project.
- Prompt-injection review: all upstream instructions were treated as untrusted data and were not loaded.

## Re-enable gate

Remain disabled until the license is independently confirmed, the required behavior is split into reviewed passive capabilities, host-install/network actions are removed or containerized, secrets handling is verified, and a Codex-native adaptation is separately reviewed.
