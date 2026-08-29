# Repository Hygiene Notes

This document records durable policy decisions behind the repository hygiene
remediation. Generated audit reports, issue plans, and verification output
under `.repository-hygiene/` are local working artifacts and are ignored by
Git; they are not part of the public repository state.

## Dispositions

- `.env.example` is intentionally tracked. It contains only blank provider
  key placeholders and a non-secret local Compose project name. No credential
  rotation or history rewrite is warranted.
- A project license has not been selected. The baseline repository does not
  establish the owner's licensing intent, and the tree includes bundled
  third-party documentation with separate provenance. Adding a license without
  that decision would be misleading.
- The unused `accessibility` label is retained. The audit plan is not applied
  because label deletion is destructive and was explicitly excluded from this
  remediation.
- No worktree-prune operation is required; the reviewed worktree plan has zero
  operations.
