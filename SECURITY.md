# Security Policy

## Scope

OSINT-Codex is a defensive, passive-only OSINT and cyber-threat-intelligence
control plane. Reports should describe security defects in the repository,
its scripts, Docker/MCP boundary, authorization controls, evidence handling,
or privacy protections.

The project does not authorize exploitation, credential testing, intrusive
scanning, or collection against targets without a current lawful authorization
and target-specific scope.

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting or a private GitHub
Security Advisory for this repository. Do not open a public issue for an
unfixed vulnerability, and do not include credentials, tokens, cookies,
private keys, personal data, or unredacted evidence in a report.

Include the affected path or component, a concise impact statement, the
smallest safe reproduction or proof, and any suggested mitigation. Reports
that require active testing should stop at the minimum evidence needed to
explain the risk.

If private reporting is unavailable, contact the repository owner through
GitHub and request a private reporting channel before sharing sensitive
details.

## Response

The maintainer will acknowledge a report when practicable, validate it within
the repository's passive-only constraints, and coordinate remediation or
disclosure timing with the reporter. Please do not publish exploit details
while a fix or mitigation is being prepared.

## Secrets and case data

Never commit usable credentials or local case data. Use blank placeholders in
`.env.example`, keep active case artifacts under ignored paths, and redact
secrets and personal data from logs, evidence, reports, and exports.
