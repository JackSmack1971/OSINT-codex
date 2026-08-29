# OSINT-Codex OSINT Control Plane

Status: baseline scaffold complete (2026-08-27). This repository provides a Windows/PowerShell-friendly, passive-only, evidence-driven Codex project layout. The verified `badchars/osint-mcp-server` integration is enabled as an optional local Docker build; other optional integrations remain disabled until their source, transport, and safety are re-verified.

## Local environment

| Item | Verified result |
|---|---|
| Operating system | Windows 10 Pro, Windows build `22631` (reported by Codex as Windows 11 Professional), x64 |
| PowerShell | PowerShell 7.6.2 (`pwsh`); Windows PowerShell 5.1 is also installed |
| Host architecture | x64 / `X64` process |
| Git | `2.53.0.windows.2` |
| Docker CLI | `29.4.2`, context `desktop-linux` |
| Docker Compose | v5.1.3 (Docker CLI plugin) |
| Docker Desktop | Installed at `C:\Program Files\Docker\Docker\Docker Desktop.exe`, version `26.820.7780.0`; not running. The `com.docker.service` service is stopped and `docker info` cannot connect to the Linux engine. Docker-dependent work is therefore unavailable until Desktop is started. |
| Codex CLI | `codex-cli 0.150.0`, npm installation, Windows x86_64 executable. `0.150.1` was offered by the CLI at inspection time. |

`codex doctor` completed with 19 OK, 1 idle, 6 notes, 4 warnings, and 0 failures. Relevant warnings are only host readiness concerns: approximately 2.6 GiB free on both `CODEX_HOME` and the worktree, Microsoft Defender exclusions not verified, and the worktree is not on a Windows Dev Drive. Authentication is configured through ChatGPT-managed tokens; no credentials are stored in this repository.

## Codex compatibility decisions

The following decisions are based on the installed CLI help/behavior and the current official documentation and OpenAI Codex repository. These are the conventions to use for later phases:

| Requested surface | Verified current behavior / decision |
|---|---|
| Repository instructions | Use root or nested `AGENTS.md`. `AGENTS.override.md` is supported and takes precedence over `AGENTS.md` in the same directory. Codex walks from project root to the current directory and merges one applicable file per directory. The default combined instruction limit is 32 KiB. |
| Trusted project config | Use project-scoped `.codex/config.toml`. It is loaded only for a trusted project. Untrusted projects skip project-local config, hooks, and rules; user/system configuration still loads. Project-local config has documented restrictions on machine-local provider/auth/host metadata keys. |
| Custom agents | Use one TOML file per agent under `.codex/agents/` for project scope (or `~/.codex/agents/` for personal scope). Required fields are `name`, `description`, and `developer_instructions`; supported session keys include `model`, `model_reasoning_effort`, `sandbox_mode`, `mcp_servers`, and `skills.config`. |
| Repository skills | Use `.agents/skills/<name>/SKILL.md`. `SKILL.md` requires `name` and `description`; scripts, references, and assets are optional. Explicit CLI invocation uses `/skills` or `$skill-name`; implicit invocation is also supported. |
| `[agents]` settings | Supported keys verified in the current config reference are `enabled`, `interrupt_message`, `default_subagent_model`, `default_subagent_reasoning_effort`, `max_concurrent_threads_per_session`, and legacy alias `max_threads`. Custom role declarations are also supported in the `[agents]` table. This scaffold uses the canonical `max_concurrent_threads_per_session` key. |
| MCP configuration | Use `[mcp_servers.<id>]`. Current supported transports are local STDIO (`command`) and Streamable HTTP (`url`); current docs do not establish SSE as a transport for this CLI. Useful verified controls include `enabled`, `required`, `enabled_tools`, `disabled_tools`, `startup_timeout_sec`, `tool_timeout_sec`, bearer-token environment variables, static/environment HTTP headers, OAuth settings, and per-server/per-tool approval modes. |
| MCP approvals | `default_tools_approval_mode` and `tools.<tool>.approval_mode` support `auto`, `prompt`, `writes`, and `approve`. `writes` prompts for tools not marked read-only. These are separate from shell command approval and sandbox policy. |
| MCP CLI | `codex mcp` exposes `list`, `get`, `add`, `remove`, `login`, and `logout`. Verified add syntax is `codex mcp add <name> --url <url>` for Streamable HTTP or `codex mcp add <name> -- <command> ...` for STDIO; `codex mcp list` and `codex mcp --help` work locally. The current user config contains one disabled, unsupported Context7 Streamable HTTP entry. |
| Non-interactive execution | Use `codex exec`. Current help verifies `--json`, `--output-last-message`/`-o`, `--output-schema`, `--ephemeral`, `--ignore-user-config`, `--sandbox`, `--cd`, `--add-dir`, `--strict-config`, and `--skip-git-repo-check`. Official docs verify JSONL output and structured output workflows. |

## Windows sandbox and approval evidence

The installed CLI reports the effective interactive configuration as native Windows sandboxing with a restricted filesystem and restricted network, elevated backend, and `OnRequest` approval. `codex sandbox cmd /c echo CODEX_SANDBOX_OK` succeeded, confirming the native sandbox command path is provisioned.

An ephemeral, read-only smoke test succeeded:

```text
codex exec --ephemeral --sandbox read-only --ignore-user-config -C "C:\TEST repos\OSINT-Codex" "Reply with exactly CODEX_EXEC_OK and do not use tools."
=> CODEX_EXEC_OK; exit 0
```

The top-level help displays `--ask-for-approval`, but Codex 0.150.0 rejects that option when placed after `exec` (and also rejects `-a` there). Placing the documented global option before the subcommand works: `codex --ask-for-approval never exec ...`. This is recorded as an installed-CLI syntax quirk; later automation should either place the global option before `exec` or use a verified configuration/approved profile. A deliberate write-denial test was not run because the smoke test only required read-only execution; write behavior remains an explicit follow-up verification item.

## Trust and scaffold constraints

This worktree is a Git repository and Codex identifies it as `OSINT-Codex`. The root `AGENTS.md`, project `.codex/config.toml`, eight project agents, and three repository skills are now present. Project configuration is loaded only after the repository is trusted. The installed user config contains an unrelated disabled Context7 entry; it remains outside this project configuration and is not modified here. Isolated strict parsing of the project configuration succeeds with `codex exec --ignore-user-config --strict-config ...`.

## Evidence sources

- Installed CLI: `codex --help`, `codex exec --help`, `codex mcp --help`, `codex mcp add --help`, `codex mcp list`, `codex sandbox --help`, `codex doctor`, and the smoke-test commands above.
- Official OpenAI documentation: [AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md), [configuration reference](https://learn.chatgpt.com/docs/config-file/config-reference), [subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents), [build skills](https://learn.chatgpt.com/docs/build-skills), [MCP](https://learn.chatgpt.com/docs/extend/mcp?surface=cli), and [non-interactive mode](https://learn.chatgpt.com/docs/non-interactive-mode).
- Official OpenAI repository: [openai/codex docs](https://github.com/openai/codex/tree/main/docs), including [config](https://github.com/openai/codex/blob/main/docs/config.md), [sandbox](https://github.com/openai/codex/blob/main/docs/sandbox.md), [exec](https://github.com/openai/codex/blob/main/docs/exec.md), and [skills](https://github.com/openai/codex/blob/main/docs/skills.md).

The repository's pre-existing `docs/official-docs-pack-codex-cli/` is retained as supporting material, but current official documentation and the installed CLI are authoritative when they differ.

## Phase B: third-party integration verification

Status values below describe this project’s disposition, not merely whether an upstream repository exists. The allowed vocabulary is `READY`, `OPTIONAL`, `DISABLED`, `UNAVAILABLE`, and `FAILED`; no candidate is currently `FAILED`, and `UNAVAILABLE` is used for missing evidence such as an unverified image or license. The Phase B verification itself did not install or execute candidates; the verified `badchars/osint-mcp-server` candidate is now registered as an optional project integration. Repository pins are the default-branch commit observed on 2026-08-27. Docker Hub digests are amd64/Linux manifest digests where the queried tag existed.

| Candidate | Canonical source and verified capability | License | Docker evidence / practical pin | Disposition |
|---|---|---|---|---|
| `badchars/osint-mcp-server` | [GitHub](https://github.com/badchars/osint-mcp-server); MCP server, launched with `npx`, therefore local STDIO. README advertises 37 tools and optional API sources. | MIT | No maintained image found; build locally from source if selected. Commit `7611f70e6a82425f1aa1e40d964057ed5f0dcb60`; release `v0.2.0`. | `OPTIONAL` — viable only behind a locally built image and a passive `enabled_tools` allowlist. |
| `rjn32s/osint-mcp` | [GitHub](https://github.com/rjn32s/osint-mcp); MCP-native Python server over STDIO. Its documented first run auto-installs OSINT binaries and exposes port-scan and secrets-scan tools. | MIT | No maintained image found. Commit `dbf9ca6d430428869b0d92bc1c275b38026a3354`. | `DISABLED` — conflicts with host-install prohibition and requires stronger tool-boundary review. |
| Clearfront MCP | [Canonical GitHub](https://github.com/scottmartinanderson/clearfront) and [PyPI](https://pypi.org/project/clearfront/); package `clearfront` includes a native MCP server over local STDIO. PyPI documents 30 tools, including passive and sensitive/active-capable sources. | MIT; bundled WhatsMyName dataset is CC BY-SA 4.0. | PyPI documents `docker compose up --build`, but no independently maintained registry image was verified. Source tag `v2.7.3` commit `a40182dd1c52772790faf17bd217f5f261f64640`; main at inspection `4fa50326283c77fad0d84e93d0367b50944fb8e3`. Package sdist SHA-256 `3f606c6edf4c0205aaa5fab80a1361bfbcf208b47cafd2dd13e48f11ef1f43c3`. | `DISABLED` — native dependency installation and broad breach/identity/scraping capabilities require containerization and an explicit passive allowlist. |
| OpenOSINT MCP | [GitHub](https://github.com/OpenOSINT/OpenOSINT); Python/FastMCP MCP server over STDIO, with a Dockerfile and Compose file in the canonical repository. README advertises 19 tools. | MIT | Canonical Dockerfile exists; no registry image was verified. Commit `2ea6538e2d63e1b73d088f6dab644deb68636f48`; release `v2.27.0`. | `DISABLED` — includes breach/identity lookup and agent-directed collection; requires explicit passive allowlisting and privacy review. |
| Sherlock | [GitHub](https://github.com/sherlock-project/sherlock); username search CLI, not MCP. | MIT | Official-looking `sherlock/sherlock:0.16.0` exists, digest `sha256:9d6602b98179fb15ceab88433626fb0ae603ae9880e13cab886970317fe1475f`; image last updated 2025-11-02, behind repository activity. Commit `9100f9d40a3274bd46f4ce903c5c6fee6f3745bc`. | `OPTIONAL` — prefer a local build from the pinned source; do not treat username matches as identity corroboration. |
| Holehe | [GitHub](https://github.com/megadose/holehe); email-account existence checks, not MCP. Canonical repository contains a Dockerfile. | GPL-3.0 | No maintained registry image verified; local build is practical from commit `14da70f588538936b20d238783c5e28a0772a2b3`. | `DISABLED` — privacy-sensitive account-existence probing is not in the default passive workflow. |
| Maigret | [GitHub](https://github.com/soxoj/maigret); username search CLI, not MCP. | MIT | `soxoj/maigret` is maintained, but uses moving commit-style tags; observed `af3de56` digest `sha256:927e9c59def511f56837171253b9c96ef0467c6f95df2fd5dc5c0ed5b0f089b6`. Source commit `af3de564c706e677221ab9f82f90166bb8b346ea`. | `DISABLED` — identity/username collection requires target-specific authorization and minimization. |
| theHarvester | [GitHub](https://github.com/laramies/theHarvester); OSINT harvesting CLI and local web/API components, not MCP. Canonical repository documents Docker Compose and passive sources, but also active DNS/HTTP actions. | No SPDX license detected in repository metadata; legal status requires maintainer clarification. | Canonical Dockerfile/Compose exist; no trustworthy registry image verified. Commit `c44b8fde57e98d5b0c7e69910f6adee8cfc6dcff`; release `4.11.1`. | `DISABLED` — license uncertainty plus active options and breach-related sources. |
| SpiderFoot | [GitHub](https://github.com/smicallef/spiderfoot); modular OSINT CLI/web application, not MCP. | MIT | No canonical maintained image verified. `kasmweb/spiderfoot` exists but is a third-party Kasm image, not the upstream project. Commit `0f815a203afebf05c98b605dba5cf0475a0ee5fd`; release `v4.0` is stale. | `DISABLED` — modules and web operation need per-module passive review. |
| Amass | [GitHub](https://github.com/owasp-amass/amass); passive enumeration mode is documented; not MCP. | Repository metadata reports `NOASSERTION`; license must be confirmed from the source before distribution. | `owaspamass/amass:v5.1.1` exists, digest `sha256:a7596ae99637be30b43959d3e6f85d2051671662b49fb6388c5a4625db5eb505`. Commit `79299dce87b0085db0f2f4ef3e9c52cccb49f514`. | `OPTIONAL` — passive mode only, after license confirmation. |
| Subfinder | [GitHub](https://github.com/projectdiscovery/subfinder); explicitly passive subdomain enumeration, not MCP. | MIT | `projectdiscovery/subfinder:v2.16.0`, digest `sha256:3f28ec2fb6ee5faf608d140ab10d685b8cc8c7791d8f6a3bb7a2e47c62135ef0`; commit `65bd1b3a832fbc19b8edc79ee7772c56556f65a2`. | `READY` — strongest utility candidate for a passive, container-only wrapper. |
| httpx | [GitHub](https://github.com/projectdiscovery/httpx); HTTP probing utility, not MCP. | MIT | `projectdiscovery/httpx:v1.10.0`, digest `sha256:8f5f5ccf479bdbefadb3de7dfb7e20870d9c76e414a21393d0aa78095461a951`; commit `b614009352389e3d2df890c5afd72a971bafa09c`. | `DISABLED` — probing is not default passive collection. |
| nuclei | [GitHub](https://github.com/projectdiscovery/nuclei); template-based scanner, not MCP. | MIT | `projectdiscovery/nuclei:v3.11.1`, digest `sha256:9fd705284ac4b5f721fa1e23bf366f26e985cd4ec65927fe9a53cb3fcb0417a6`; commit `da279d42a37fa2cee5d320907f24405ab4cbe406`. | `DISABLED` — vulnerability scanning is explicitly outside the default workflow. |
| gitleaks | [GitHub](https://github.com/gitleaks/gitleaks); secret scanner, not MCP. | MIT | `zricethezav/gitleaks:v8.30.1`, digest `sha256:b109bc5f8f76a38196a3e413704fc5b9e3c32360bce4e4b603bd6f45b3721dbb`; commit `b58d3f102cf3a2c84cb7f923d05c25c9b1aed84b`. | `OPTIONAL` — only authorized public repositories or explicitly authorized local material; report presence and redacted fingerprints, never values. |
| trufflehog | [GitHub](https://github.com/trufflesecurity/trufflehog); secret scanner, not MCP. | AGPL-3.0 | `trufflesecurity/trufflehog:3.97.1`, amd64 digest `sha256:da3365e98ab735336733fc90cc22af8413a6d9fc1e6da5412e781daeb2d14663`; commit `0c952ace0f842f11c75775922d7400335cf60bc6`. | `DISABLED` — same authorization/redaction gate as gitleaks, with AGPL obligations. |
| `frangelbarrera/osint-agent-skills` | [GitHub](https://github.com/frangelbarrera/osint-agent-skills); knowledge base plus Node MCP server/config material, not a native Codex skill package. | MIT | No image verified. Commit `e487245b23a8faf63af58fc8e3bcc778b119f71a`. | `OPTIONAL` — source material only; selectively adapt after review. |
| `7onez/cti-expert` | [GitHub](https://github.com/7onez/cti-expert); Claude-oriented skill/agent toolkit with a `codex/` directory, scripts, hooks, and an MCP server. | Repository metadata reports `NOASSERTION`; do not redistribute until the license is confirmed. | No image verified. Commit `c8e051aeb5d68f3b66009b8cdc61bf1db4840710`. | `DISABLED` — inspected material contains host package-install instructions, curl/apt flows, active/credential-oriented playbooks, and `--no-verify` guidance. |
| `SOsintOps/claudii-exploratores` | [GitHub](https://github.com/SOsintOps/claudii-exploratores); Claude skill plus Python/FastMCP MCP server over STDIO. It builds links and does not fetch pages. | AGPL-3.0 | No image verified. Commit `f6b3763606630f2de4e985fdc47b62389ead2069`. | `DISABLED` — explicitly alpha; catalog includes port-scan, phishing, age-bypass, Tor, and API-key templates. Source material only. |

## Containerized utilities

`mcp/docker-compose.yml` provides reproducible, ephemeral Docker paths for all
11 verified utility candidates. Registry-backed services use the verified
amd64 digest from the table above; Sherlock, Holehe, Maigret, theHarvester, and
SpiderFoot use pinned upstream source commits in `mcp/toolboxes/Dockerfile`.

All utility services are opt-in Compose profiles and require a current,
case-bound ROE. `mcp/toolboxes/guard.sh` enforces authorization, mounts the
case read-only, applies passive defaults to Amass/Subfinder/theHarvester/
SpiderFoot, and gates sensitive or active-capable utilities. Nuclei and httpx
remain unavailable unless their explicit approval environment variables are
provided. Gitleaks and TruffleHog scan only the mounted case and redact output.

```powershell
$env:OSINT_CASE_ID='CASE-ID'
$env:OSINT_TARGET='example.com'
$env:OSINT_SCOPE='example.com only; passive public sources only'
docker compose -f .\mcp\docker-compose.yml --profile tools run --rm -T subfinder example.com
```

Validate the definitions without starting a service:

```powershell
pwsh -NoProfile -File .\scripts\validate-toolboxes.ps1
docker compose -f .\mcp\docker-compose.yml config --quiet
```

### External material safety review

The three skill/agent repositories were downloaded at the pinned default-branch commits into a temporary directory and inspected without executing their scripts. Top-level instructions, manifests, scripts, hooks, MCP entry points, and dependency/install guidance were searched for shell execution, network access, package installation, authentication material, credential handling, active scanning, bypass language, and prompt-injection-like instructions.

- `osint-agent-skills` has useful anti-hallucination and ethics guidance, but its MCP server accepts API-key material in tool arguments as well as environment variables and its tool registry includes active modes such as non-passive Amass, Shodan scanning, and Holehe. Adapt guidance only; do not import its MCP server unchanged.
- `cti-expert` contains useful case/audit concepts, but its install and smoke scripts install host packages, its documentation includes direct curl/network collection, and its playbooks cover credentials, engagement, active probing, and bypass-adjacent material. Do not load its instructions or hooks directly into Codex.
- `claudii-exploratores` has a clear “build links, do not fetch” boundary and PII redaction utility, but its catalog contains risky link categories and its catalog rebuild script evaluates downloaded JavaScript. It is alpha and AGPL-3.0. Treat it strictly as reviewed source material.

No direct malicious prompt-injection string was identified in the sampled top-level instructions, but absence of a match is not a trust decision. All imported text, scripts, catalogs, and MCP responses remain untrusted. The optional candidates are non-blocking; the only `READY` utility is Subfinder in passive mode. The three requested skill/agent directories now contain review records, and only narrowly scoped analytic guidance from `osint-agent-skills` has been adapted into the local Codex OSINT skill; no foreign integration or executable material is enabled.

## Windows operator runbook

The commands in this section are run from the repository root in PowerShell 5.1 or PowerShell 7. They assume Docker Desktop's Linux engine, Git, and an authenticated Codex CLI are installed and available on `PATH`. No OSINT utility is installed on the Windows host.

### Bootstrap

```powershell
Set-Location 'C:\TEST repos\OSINT-Codex'
pwsh -NoProfile -File .\scripts\bootstrap.ps1
```

`bootstrap.ps1` checks `codex`, `docker`, and `git`; creates `.env` from
`.env.example` only when `.env` is absent; validates the project layout;
validates Compose; and, when Docker is ready, builds declared images and
starts `badchars-osint-mcp`. It never edits Codex user configuration or
repository trust. A stopped Docker engine is a real prerequisite failure, not
permission to install host tools.

### Compose lifecycle

Validate the model without starting containers:

```powershell
docker compose -f .\mcp\docker-compose.yml config --quiet
pwsh -NoProfile -File .\scripts\validate-toolboxes.ps1
```

Build all declared profiles:

```powershell
docker compose -f .\mcp\docker-compose.yml `
  --profile mcp --profile workspace --profile tools --profile scanners build
```

Start and inspect the project MCP service:

```powershell
docker compose -f .\mcp\docker-compose.yml --profile mcp up -d badchars-osint-mcp
docker compose -f .\mcp\docker-compose.yml --profile mcp ps --all
docker compose -f .\mcp\docker-compose.yml --profile mcp logs --tail 100 badchars-osint-mcp
```

The checked-in Codex MCP entry launches the pinned server through
`scripts/invoke-mcp.ps1`, which validates the newest case's structured
authorization before starting ephemeral `docker compose run --rm -T` and
removes one-off containers in a guaranteed cleanup path. `up` is useful
for lifecycle diagnostics; it is not proof that an MCP tool call is safe or
authorized. No HTTP wrapper, published port, or SSE transport is enabled or
verified.

### Codex verification and launch

The project config is loaded only after Codex trusts this repository. Approve
the trust prompt in Codex; do not copy project config into the user profile.
The installed CLI verified this read-only project-config probe:

```powershell
codex exec --ephemeral --ignore-user-config --strict-config --sandbox read-only `
  --cd (Get-Location).Path `
  'Reply with exactly CODEX_EXEC_OK and do not use tools.'
```

The verified smoke result was `CODEX_EXEC_OK` with exit code 0. Codex CLI
`0.150.0` rejects `--ask-for-approval` after `exec`; the verified placement
is before the subcommand:

```powershell
codex --ask-for-approval never exec --ephemeral --sandbox read-only `
  --cd (Get-Location).Path 'Reply with exactly CODEX_EXEC_OK and do not use tools.'
```

Inspect the configured MCP registry separately:

```powershell
codex mcp list
codex mcp --help
```

The project entry is `badchars_osint`; its health is proven only when the
Docker-backed STDIO self-test completes successfully.

Launch an interactive project session:

```powershell
codex -C (Get-Location).Path
```

Inside that Codex session, these are skill invocations rather than PowerShell
commands:

```text
$authorize example.com
$osint example.com
$osint-status
```

`$authorize` requires explicit lawful-purpose acknowledgement and writes a
target- and scope-specific ROE before collection. `$osint` is blocked when
the ROE is missing, expired, mismatched, or materially changed. `$osint-status`
is the repository-local control-plane view. Optional built-in Codex diagnostics
are entered in the same session:

```text
/status
/mcp
```

`/status` and `/mcp` do not authorize a case or validate case evidence.

### Status, self-test, and validation

```powershell
pwsh -NoProfile -File .\scripts\status.ps1
pwsh -NoProfile -File .\scripts\self-test.ps1 -DryRun
```

The dry run creates a case-shaped artifact set without network collection and
records `no data found` for live sources. With Docker Desktop running, the
bounded live self-test can be run as follows; it performs one public HTTPS
request and one DNS A lookup for the existing authorized case target only.
Live mode never creates authorization; it requires explicit acknowledgement
and an existing case:

```powershell
pwsh -NoProfile -File .\scripts\self-test.ps1 -CasePath .\cases\CASE-ID -AcknowledgeNetworkCollection
```

Each self-test also writes `raw/component-status.json`, preserving component
status, attempted action, error, probable cause, and remediation command for
degraded or unavailable dependencies.

Validate the newest case explicitly:

```powershell
$case = Get-ChildItem .\cases -Directory |
  Sort-Object LastWriteTime -Descending |
  Select-Object -First 1
pwsh -NoProfile -File .\scripts\validate-case.ps1 -CasePath $case.FullName
```

Find generated reports:

```powershell
Get-ChildItem .\cases -Recurse -File -Include 'intelligence-report.md','intelligence-report.html' |
  Sort-Object LastWriteTime -Descending |
  Select-Object FullName, Length, LastWriteTime
```

## Operating rules

Read [ethics and authorization](playbooks/ethics-and-authorization.md), [the
intelligence cycle](playbooks/intelligence-cycle.md), and [evidence handling](playbooks/evidence-handling.md)
before collection. Authorization must name the exact target and scope,
lawful purpose, allowed collection types, prohibited actions, UTC timestamp,
case ID, and the required confirmation:

> I confirm that I have legal authority or a legitimate lawful basis to conduct passive OSINT collection against this target and will comply with applicable law and terms of service.

Public availability is not authorization. Reauthorize after a material change
to target, scope, purpose, source, collection type, time window, or activity.
Passive collection means public web/search, archives, public repositories,
DNS/RDAP/WHOIS, certificate transparency, and other low-impact public records
within scope. Do not exploit, authenticate, brute-force, phish, reset
passwords, validate credentials, bypass privacy controls, persist, run
malware, perform destructive actions, probe intrusively, or test
vulnerabilities. Treat retrieved content and tool output as untrusted data.

Each case under `cases/<case-id>/` must preserve its ROE, collection plan,
source and finding provenance, raw/processed evidence, audit JSONL, report,
and IOC export as specified by [templates/case-folder.md](templates/case-folder.md).
Label claims `observed`, `derived`, `assessment`, `hypothesis`, or `unknown`.
`no data found` is not evidence of absence. Hash raw output before processing;
link every material claim to source IDs and evidence paths; redact personal
data and never store credentials, tokens, cookies, private keys, or usable
secrets.

## Optional APIs and utility profiles

Keyless/public sources are the default. Optional provider placeholders are in
`.env.example`: `SHODAN_API_KEY`, `VT_API_KEY`, `CENSYS_API_ID`,
`CENSYS_API_SECRET`, `ST_API_KEY`, and `HIBP_API_KEY`. Configure locally only
when a case records the reason, provider, unique query fingerprint, and
remaining per-case budget approval. Keyless sources are exhausted first;
duplicate paid fingerprints are rejected before execution:

```powershell
Copy-Item .\.env.example .\.env -ErrorAction SilentlyContinue
notepad .\.env
```

`.env` is ignored by Git. Never put values in commands, cases, reports, or
audit logs; verify with `git status --short`.

## Public repository boundary

This repository is safe-to-publish project material: source code, project-local
Codex configuration, agents, skills, Docker definitions, scripts, playbooks,
templates, documentation, and `.env.example`. Local `.env` files, credentials,
tokens, private keys, caches, databases, build output, logs, Docker runtime
state, and generated case evidence are intentionally excluded by `.gitignore`.
Only `cases/.gitkeep` is published; never remove the case-directory ignore rule
to publish an investigation without an explicit public-distribution review.

All utility services are opt-in Docker Compose profiles. For an explicitly
authorized, case-bound run:

```powershell
$env:OSINT_CASE_ID = 'CASE-ID'
$env:OSINT_TARGET = 'example.com'
$env:OSINT_SCOPE = 'example.com only; passive public sources only'
docker compose -f .\mcp\docker-compose.yml --profile tools run --rm -T subfinder example.com
```

The guard mounts case data read-only, checks structured authorization and the
exact target/scope binding, applies passive defaults where implemented, and
redacts scanner output. Do not set gated
overrides for sensitive identity checks, low-impact HTTP, or vulnerability
templates without a separate explicit review. External utilities remain
container-only; do not install them globally.

## Maintenance and troubleshooting

- `Docker CLI present; engine unavailable`: start Docker Desktop, wait for the `desktop-linux` engine, then rerun `bootstrap.ps1` or `docker info`.
- Trust/config or skill discovery is missing: approve repository trust in Codex and rerun the read-only strict-config probe; project configuration is intentionally not copied to user scope.
- MCP is `UNKNOWN` or unavailable: run `docker compose ... config --quiet`, rebuild `badchars-osint-mcp`, inspect `logs`, then run `self-test.ps1`; TCP reachability alone is not protocol health.
- Case validation fails: preserve the evidence, inspect the exact validator error, repair the case contract or provenance, and rerun `validate-case.ps1`; do not delete raw evidence to make validation pass.
- Low disk space: `codex doctor` reported approximately 2.6 GiB free on the Codex/worktree volumes; free space before image builds and case capture.

For routine maintenance, review the pinned integration matrix and source
reviews after upstream changes, rerun `validate-toolboxes.ps1`, rerun the
Compose config check, and run the dry-run self-test. Do not update image
digests, upstream commits, enabled MCP tools, or disabled integrations without
recording new provenance, license status, transport behavior, and safety
review.

## Explicit deviations and unavailable components

- The enabled MCP source had no maintained upstream image, so this project builds it locally from the pinned source commit. The native STDIO transport is preserved; no unverified HTTP/SSE adapter was added.
- `rjn32s/osint-mcp`, Clearfront, OpenOSINT MCP, Holehe, Maigret, theHarvester, SpiderFoot, httpx, nuclei, TruffleHog, and reviewed Claude-oriented integrations are disabled or source-only as recorded in the matrix. Missing registry images, license uncertainty, host-install behavior, active/probing features, breach/identity exposure, and unsafe breadth are not silently treated as support.
- The only `READY` utility disposition is Subfinder in passive mode; `OPTIONAL` does not mean enabled or generally safe for every case.
- The current Codex CLI format uses `.codex/agents/*.toml`, `.agents/skills/*/SKILL.md`, and `[mcp_servers.<id>]`; requested SSE and unsupported project/user configuration assumptions were not implemented.
- Docker-dependent build and transport verification was unavailable during the recorded environment inspection because Docker Desktop was stopped. The repository contains validation and self-test paths, but this README does not claim a live Docker result for that machine.

## Source and license record

The detailed verified matrix above links each candidate’s canonical source,
license finding, commit/image pin, and disposition. Supporting official Codex
documentation and provenance are retained in
`docs/official-docs-pack-codex-cli/`; installed CLI behavior is authoritative
when it differs from older documentation. Imported skill material is retained
only with review records under `skills/`; only narrowly scoped analytic
guidance was adapted into the local Codex skill. See
`skills/*/SOURCE-REVIEW.md` before considering any re-enable decision.
