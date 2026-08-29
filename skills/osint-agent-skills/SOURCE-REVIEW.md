# Source review: `frangelbarrera/osint-agent-skills`

Disposition: `OPTIONAL` — reviewed source material only. No upstream file in this directory is loaded by Codex, and the upstream MCP server is not registered in `.codex/config.toml`.

## Pin and provenance

- Canonical source: <https://github.com/frangelbarrera/osint-agent-skills>
- Reviewed revision: `e487245b23a8faf63af58fc8e3bcc778b119f71a`
- Revision observed: 2026-08-27 UTC
- License: MIT, copyright Frangel Raúl Crespo Barrera (2026); see the upstream `LICENSE` at the pinned revision.
- Reviewed checkout: temporary, detached checkout; no upstream code was executed.

## Imported or adapted

- Adapted only general principles of source traceability, anti-hallucination, confidence qualification, privacy minimization, and bounded pivoting into `.agents/skills/osint/SKILL.md`.
- The local control plane's authorization, case, evidence, Docker, and redaction rules are authoritative and supersede the source material.

## Excluded

- `package.json`, `server.json`, `agent-config.yaml`, and all upstream MCP/tool configuration.
- `tools/mcp-server.js`, tool registries, knowledge-base copies, templates, integration files, and executable scripts.
- Any direct API-key workflow, breach retrieval, account discovery, active enumeration, or target-interaction procedure.

## Safety review

- Instructions: useful verification and ethics guidance, but written for a generic/MCP agent and not Codex-native.
- Commands/scripts: Node MCP server and tool scripts can make network requests; no script was run.
- Network behavior: documented tools include public DNS/RDAP/CT/archive lookups and optional API-backed sources; the registry also includes active or privacy-sensitive modes such as non-passive Amass, Shodan scanning, and Holehe.
- Secrets: the upstream server accepts API-key material through environment variables and tool arguments. No credentials were copied; local policy forbids storing or passing usable secrets in case artifacts.
- Prompt-injection review: upstream text was treated as untrusted data; no upstream instruction can override root `AGENTS.md`.

## Re-review gate

Do not enable this source or its MCP server without a new revision pin, license/provenance check, tool allowlist, secret-handling review, containerization decision, and passive-only validation.
