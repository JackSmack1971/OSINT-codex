# {{ title }}

- Case ID: `{{ case_id }}`
- Date: `{{ date_utc }}`
- Target: `{{ target }}`
- ROE / Scope: {{ scope }}

## Executive Summary
Evidence-backed summary only. Label each statement as `observed`, `derived`, `assessment`, `hypothesis`, or `unknown`; link factual claims to finding and source IDs. Do not put unsupported speculation here.

## Intelligence Requirements
- [ ] {{ requirement }} — status: {{ status }}

## Key Judgments
1. {{ judgment }} — confidence: {{ confidence }} — supporting findings: [F-0001](#findings); supporting sources: `SRC-0001`.

## Findings
| ID | Statement | Classification | Confidence | Sources | Evidence |
|---|---|---|---|---|---|
| F-0001 | {{ statement }} | observed | medium | SRC-0001 | `raw/example.json` |

## Evidence Table
| Source ID | Provider/tool | Retrieved UTC | SHA-256 | Reliability | Raw evidence |
|---|---|---|---|---|---|
| SRC-0001 | {{ provider }} / {{ tool }} | {{ retrieved_utc }} | `sha256:...` | {{ reliability }} | `raw/example.json` |

## Entity Relationships
Describe only source-supported relationships; include relationship IDs, entity IDs, supporting source IDs, confidence, and rationale. Do not merge identities solely because usernames match.

## Timeline
Chronological UTC events with event IDs, classification, source IDs, and evidence paths.

## Contradictions
State unresolved contradictions explicitly; do not treat absence of evidence as evidence of absence.

## Confidence Assessment
Apply `playbooks/confidence-scoring.md`. Explain source reliability, credibility, directness, freshness, independence, consistency, alternatives, and contradictions. Tool-count agreement is not independent corroboration.

## Intelligence Gaps
{{ gaps }}

## What We Do Not Know
{{ unknowns }}

## Defensive Recommendations
{{ recommendations }}

## Methodology
Passive sources, authorization boundary, collection dates, limits, tools/versions, processing steps, hashing method, and reproducible references. Record `no data found` exactly where applicable.

## Sources
List every source ID with provider, tool, URL when applicable, retrieval/publication timestamps, raw evidence path, SHA-256 hash, reliability, and notes.

## Appendices
IOC export and audit references. Include only applicable domains, hostnames, IPs, URLs, hashes, ASNs, and certificate fingerprints; never classify personal identifiers as malicious IOCs merely because they appeared.
