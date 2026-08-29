# Contributing

OSINT-Codex is maintained as a defensive, passive-only OSINT and
cyber-threat-intelligence control plane. Contributions must preserve lawful,
target-specific authorization, passive collection, evidence provenance,
redaction, Docker isolation for external utilities, and reproducible
validation.

## Before opening a pull request

- Read `AGENTS.md` and the applicable playbooks.
- Keep changes focused and do not commit `.env`, credentials, cookies, private
  keys, case data, or generated local audit artifacts.
- Update documentation when behavior, safety boundaries, or commands change.
- Run the relevant existing self-test and validation scripts.
- Do not add active scanning, exploitation, credential testing, host-installed
  OSINT tooling, or bypasses of authorization and approval controls.

## Pull requests

Open a pull request from a topic branch and explain the intent, affected
scope, safety impact, tests run, documentation changes, and any known gaps.
Link the relevant issue or explain why one is not applicable. Maintainers use
the repository's squash-merge workflow after review; direct pushes to `main`
are restricted by repository settings.

## Issues and security reports

Use the issue templates for ordinary bugs, feature proposals, and support
questions. Report vulnerabilities privately according to `SECURITY.md`.

## Licensing status

The repository currently has no project license. Do not assume that source,
documentation, or bundled third-party material may be redistributed under an
unselected license; proposed contributions must be original or accompanied by
clear permission.
