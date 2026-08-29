# Intelligence cycle

Follow the complete cycle: **Direction → Collection → Processing → Analysis → Dissemination**. Authorization and ROE precede Direction and remain a gate throughout.

## Direction

Create or reuse an immutable case. Parse and classify the target, state the lawful purpose and scope, define intelligence requirements, prohibited activity, time window, source limits, and stopping conditions. Set limits for pivot depth, repeat queries, concurrent agents, paid API spend, and collection iterations.

## Collection

Build a collection plan mapped to each requirement. Use keyless/public sources first and select only passive tools allowed by the ROE. Run independent tasks in parallel only when safe; keep subagents inside declared missions. For each invocation record sanitized arguments, exact reproducible command where available, container/service and image, timestamps, exit status, output hashes, and evidence paths. Never treat two tools backed by the same upstream dataset as independent corroboration.

## Processing and analysis

Hash raw evidence before processing, preserve raw and derived artifacts separately, normalize source IDs, findings, entities, and relationships, and label current versus historical observations. Assess source reliability, information credibility, directness, freshness, independence, consistency, and contradictions. Generate pivots only from existing evidence; the orchestrator approves additional collection. Never promote a plausible lead to fact.

## Dissemination

Produce a report whose judgments link to findings and source IDs. Include evidence, provenance, methodology, contradictions, confidence rationale, explicit unknowns, collection gaps, and defensive recommendations. Export only minimized/redacted material and validate the case, report, audit log, and IOC bundle before release. If a source yields no usable evidence, preserve the exact result `no data found`.
