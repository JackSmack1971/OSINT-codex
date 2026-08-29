---
title: "config.md"
source_url: "https://github.com/openai/codex/blob/main/docs/config.md"
host: "github.com"
depth: 1
selector: "article,main"
fetched_at: "2026-08-08T19:15:54.620Z"
---
[openai](https://github.com/openai) / **[codex](https://github.com/openai/codex)** Public

-   [Notifications](https://github.com/login?return_to=%2Fopenai%2Fcodex) You must be signed in to change notification settings
-   [Fork 15.9k](https://github.com/login?return_to=%2Fopenai%2Fcodex)
-   [Star 105k](https://github.com/login?return_to=%2Fopenai%2Fcodex)


 ## Files

main

# config.md

Blame

Blame

## Latest commit

## History

[History](https://github.com/openai/codex/commits/main/docs/config.md)

[](https://github.com/openai/codex/commits/main/docs/config.md)

15 lines (10 loc) · 726 Bytes

main

# config.md

Top

## File metadata and controls

-   Preview

-   Code

-   Blame


15 lines (10 loc) · 726 Bytes

[Raw](https://github.com/openai/codex/raw/refs/heads/main/docs/config.md)

# Configuration

[](https://github.com/openai/codex/blob/main/docs/config.md#configuration)

For basic configuration instructions, see [this documentation](https://developers.openai.com/codex/config-basic).

For advanced configuration instructions, see [this documentation](https://developers.openai.com/codex/config-advanced).

For a full configuration reference, see [this documentation](https://developers.openai.com/codex/config-reference).

## Lifecycle hooks

[](https://github.com/openai/codex/blob/main/docs/config.md#lifecycle-hooks)

Admins can set top-level `allow_managed_hooks_only = true` in `requirements.toml` to ignore user, project, and session hook configs while still allowing managed hooks from requirements and managed config layers. This setting is only supported in `requirements.toml`; putting it in `config.toml` does not enable managed-hooks-only mode.
