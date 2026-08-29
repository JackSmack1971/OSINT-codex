# Evidence handling

## Case layout and provenance

Use an immutable case ID and ISO-8601 UTC timestamps. Store raw captures under `cases/<case-id>/raw/`, processed derivatives under `processed/`, source metadata in `sources.jsonl`, findings in the case finding store, and entity relationships in `entities.jsonl` and `relationships.jsonl`. Keep reports and IOC exports linked to the case.

Every source records: source ID, URL when applicable, provider, tool, retrieval timestamp, publication or observation timestamp when known, raw evidence path, SHA-256 content hash, reliability rating, and notes. Compute and record the hash before processing; never overwrite raw evidence.

## Findings and audit

Every factual finding references one or more existing source IDs and evidence files. Record finding type (observed, derived, assessment, hypothesis, or unknown), claim, rationale, timestamp, confidence, and contradictions. Relationships require supporting source IDs and confidence. Distinguish no evidence from evidence of absence.

Log every MCP/tool invocation to `cases/<case-id>/audit/tool-invocations.jsonl` with invocation ID, UTC timestamp, case ID, agent, tool, container/service, image or digest, sanitized arguments, reproducible command where available, exit code, duration, stdout/stderr hashes, evidence files, and status. Hash raw output before further processing.

Never write API keys, passwords, tokens, cookies, private keys, or usable secrets to cases, reports, exports, or logs. Secret findings contain only presence, type, location, and a redacted fingerprint such as `ghp_abcd…[REDACTED]`. Minimize and redact personal data before dissemination.
