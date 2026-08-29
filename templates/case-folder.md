# Case folder contract

Create one immutable directory for each investigation:

`cases/<case-id>/`, where `<case-id>` is unique and uses `CASE-YYYYMMDD-HHMMSS-target`.

## Required structure

```text
case.json
roe.md
collection-plan.md
timeline.jsonl
findings.jsonl
entities.jsonl
relationships.jsonl
sources.jsonl
hypotheses.md
gaps.md
raw/
processed/
audit/tool-invocations.jsonl
reports/intelligence-report.md
reports/intelligence-report.html
exports/ioc-bundle.json
```

## File contracts

- `case.json`: case ID, target, created/updated UTC timestamps, purpose, authorization state, authorizer, authorization timestamp, scope, exclusions, and status. Authorization must be current, target-specific, and scope-specific before collection.
- `roe.md`: attributable authorization, lawful purpose, allowed passive sources, scope, exclusions, expiry, stop conditions, and approval record.
- `collection-plan.md`: intelligence requirements, approved sources/tools, passive collection limits, pivots, sequencing, and completion criteria.
- `timeline.jsonl`: one JSON event per line with `event_id`, `case_id`, `timestamp_utc`, `classification`, `description`, `source_ids`, and `evidence_paths`.
- `findings.jsonl`: one [finding contract](finding.json) per line. Every factual finding needs existing `source_ids` and an existing `evidence_path`; use `no data found` for sources with no usable evidence.
- `entities.jsonl`: one entity per line with `entity_id`, `case_id`, `type`, `value` or redacted value, timestamps, `source_ids`, and confidence.
- `relationships.jsonl`: one relationship per line with `relationship_id`, `case_id`, `from_entity_id`, `relationship`, `to_entity_id`, `source_ids`, confidence, and rationale. Never merge identity entities solely on username reuse.
- `sources.jsonl`: one provenance record per line with `source_id`, URL when applicable, provider, tool, retrieval timestamp, publication/observation timestamp when known, raw evidence path, SHA-256 content hash, reliability, and notes.
- `hypotheses.md` and `gaps.md`: explicitly separate hypotheses, contradictions, unknowns, collection gaps, and what would resolve each gap.
- `raw/`: immutable captures. Hash raw output before processing and never overwrite it.
- `processed/`: derived or normalized artifacts linked to their raw evidence.
- `audit/tool-invocations.jsonl`: one complete audit record per invocation; sanitize arguments and never store secrets.
- `reports/`: Markdown and rendered HTML reports containing every required report section and links from judgments to finding IDs and source IDs.
- `exports/ioc-bundle.json`: minimized, standards-friendly IOC export. Do not export usernames, personal email addresses, or phone numbers as malicious IOCs merely because they appeared.

All timestamps are ISO-8601 UTC. All factual statements must be labeled `observed`, `derived`, `assessment`, `hypothesis`, or `unknown` and be reproducible from case evidence. Tool-count agreement is not independent corroboration.
