# Source review: `SOsintOps/claudii-exploratores`

Disposition: `DISABLED` — reviewed source material only. No upstream skill, catalog, Python module, script, or MCP configuration is enabled by this project.

## Pin and provenance

- Canonical source: <https://github.com/SOsintOps/claudii-exploratores>
- Reviewed revision: `f6b3763606630f2de4e985fdc47b62389ead2069`
- Revision observed: 2026-08-27 UTC
- License: AGPL-3.0; the upstream repository also includes `NOTICE` identifying the derivative Exploratores OSINT Toolkit and its AGPL-3.0 provenance.
- Reviewed checkout: temporary, detached checkout; no upstream code was executed.

## Imported or adapted

- No upstream files or catalog entries were imported.
- The general distinction between generating search links and asserting retrieved findings is already enforced by the local OSINT skill; no Claude-specific workflow was copied.

## Safety review

- Instructions: Claude skill format, not a supported Codex project skill format; its OPSEC advice does not replace the case-bound authorization and Docker rules in this repository.
- Commands/scripts: Python/FastMCP server and helper scripts exist; the catalog rebuild path evaluates downloaded JavaScript and was not run.
- Network behavior: the MCP server is described as building links without fetching pages, but catalog entries include Tor, phishing, port-scan, age-bypass, and API-key-related categories that are outside the default workflow.
- Secrets/PII: the project includes API-key templates and a PII redactor; no secrets or personal data were copied.
- Prompt-injection review: all upstream instructions and catalog text were treated as untrusted data and were not loaded.

## Re-enable gate

Remain disabled unless the AGPL obligations and derivative notices are preserved, risky catalog categories are removed or explicitly gated, the JavaScript evaluation path is eliminated or isolated, and a Codex-native passive-only adaptation passes a fresh review.
