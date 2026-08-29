---
title: "install.md"
source_url: "https://github.com/openai/codex/blob/main/docs/install.md"
host: "github.com"
depth: 1
selector: "article,main"
fetched_at: "2026-08-08T19:15:56.537Z"
---
[openai](https://github.com/openai) / **[codex](https://github.com/openai/codex)** Public

-   [Notifications](https://github.com/login?return_to=%2Fopenai%2Fcodex) You must be signed in to change notification settings
-   [Fork 15.9k](https://github.com/login?return_to=%2Fopenai%2Fcodex)
-   [Star 105k](https://github.com/login?return_to=%2Fopenai%2Fcodex)


 ## Files

main

# install.md

Blame

Blame

## Latest commit

## History

[History](https://github.com/openai/codex/commits/main/docs/install.md)

[](https://github.com/openai/codex/commits/main/docs/install.md)

65 lines (48 loc) · 2.67 KB

main

# install.md

Top

## File metadata and controls

-   Preview

-   Code

-   Blame


65 lines (48 loc) · 2.67 KB

[Raw](https://github.com/openai/codex/raw/refs/heads/main/docs/install.md)

## Installing & building

[](https://github.com/openai/codex/blob/main/docs/install.md#installing--building)

### System requirements

[](https://github.com/openai/codex/blob/main/docs/install.md#system-requirements)

| Requirement | Details |
| --- | --- |
| Operating systems | macOS 12+, Ubuntu 20.04+/Debian 10+, or Windows 11 **via WSL2** |
| Git (optional, recommended) | 2.23+ for built-in PR helpers |
| RAM | 4-GB minimum (8-GB recommended) |

### DotSlash

[](https://github.com/openai/codex/blob/main/docs/install.md#dotslash)

The GitHub Release also contains a [DotSlash](https://dotslash-cli.com/) file for the Codex CLI named `codex`. Using a DotSlash file makes it possible to make a lightweight commit to source control to ensure all contributors use the same version of an executable, regardless of what platform they use for development.

### Build from source

[](https://github.com/openai/codex/blob/main/docs/install.md#build-from-source)

```shell
# Clone the repository and navigate to the root of the Cargo workspace.
git clone https://github.com/openai/codex.git
cd codex/codex-rs

# Install the Rust toolchain, if necessary.
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"
rustup component add rustfmt
rustup component add clippy
# Install helper tools used by the workspace justfile:
cargo install --locked just
# DotSlash fetches pinned development tools such as buildifier on first use.
cargo install --locked dotslash
# Install nextest for the `just test` helper.
cargo install --locked cargo-nextest

# Build Codex.
cargo build

# Launch the TUI with a sample prompt.
cargo run --bin codex -- "explain this codebase to me"

# After making changes, use the root justfile helpers (they default to codex-rs):
just fmt
just fix -p <crate-you-touched>

# Run the relevant tests (project-specific is fastest), for example:
just test -p codex-tui
# `just test` runs the test suite via nextest:
just test
# Avoid `--all-features` for routine local runs because it increases build
# time and `target/` disk usage by compiling additional feature combinations.
```

## Tracing / verbose logging

[](https://github.com/openai/codex/blob/main/docs/install.md#tracing--verbose-logging)

Codex is written in Rust, so it honors the `RUST_LOG` environment variable to configure its logging behavior.

The TUI records diagnostics in bounded local stores by default. Set `log_dir` explicitly to enable a plaintext TUI log for a run:

```shell
codex -c log_dir=./.codex-log
tail -F ./.codex-log/codex-tui.log
```

The non-interactive mode (`codex exec`) defaults to `RUST_LOG=error`, but messages are printed inline, so there is no need to monitor a separate file.

See the Rust documentation on [`RUST_LOG`](https://docs.rs/env_logger/latest/env_logger/#enabling-logging) for more information on the configuration options.
