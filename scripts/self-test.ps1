[CmdletBinding()]
param(
  [switch]$DryRun,
  [string]$CasePath,
  [switch]$AcknowledgeNetworkCollection,
  [int]$NetworkTimeoutSec = 20
)

#requires -Version 5.1

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$authorizationLibrary = Join-Path $PSScriptRoot 'authorization.ps1'
. $authorizationLibrary
. (Join-Path $PSScriptRoot 'redaction.ps1')
$target = 'example.com'
$startedAt = [DateTimeOffset]::UtcNow
$caseId = $null
$caseRoot = $null
$results = [System.Collections.Generic.List[object]]::new()
$audit = [System.Collections.Generic.List[object]]::new()
$sourceRecords = [System.Collections.Generic.List[object]]::new()
$findingRecords = [System.Collections.Generic.List[object]]::new()
$entityRecords = [System.Collections.Generic.List[object]]::new()
$componentStatuses = [System.Collections.Generic.List[object]]::new()
$invocationNumber = 0

function Write-Check {
  param([string]$Name, [ValidateSet('PASS', 'FAIL', 'SKIP', 'DRY-RUN')][string]$Status, [string]$Detail)
  [void]$results.Add([pscustomobject]@{ name = $Name; status = $Status; detail = $Detail })
  Write-Host ('[{0}] {1}: {2}' -f $Status, $Name, $Detail)
}

function Protect-Output([string]$Text) {
  return Protect-SensitiveOutput $Text
}

function Get-Hash([string]$Path) { return 'sha256:' + (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Get-EmptyHash {
  $sha = [Security.Cryptography.SHA256]::Create()
  try { return 'sha256:' + ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes('')))).Replace('-', '').ToLowerInvariant() }
  finally { $sha.Dispose() }
}
function Write-Json([string]$Path, $Value) { $Value | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path -Encoding UTF8 }
function Write-JsonLine([string]$Path, $Value) { ($Value | ConvertTo-Json -Depth 12 -Compress) | Add-Content -LiteralPath $Path -Encoding UTF8 }
function Add-ComponentStatus {
  param([string]$Component, [string]$Status, [string]$AttemptedAction, [string]$Error, [string]$ProbableCause, [string]$RemediationCommand)
  [void]$componentStatuses.Add([ordered]@{
    component = $Component; status = $Status; attempted_action = $AttemptedAction
    error = $Error; probable_cause = $ProbableCause; remediation_command = $RemediationCommand
  })
}

function Invoke-Native {
  param([string]$Command, [string[]]$Arguments)
  $output = (& $Command @Arguments 2>&1 | Out-String).Trim()
  [pscustomobject]@{ ExitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }; Output = Protect-Output $output }
}

function Add-Audit {
  param([string]$ToolName, [string]$Container, [string]$Image, [string]$Arguments, [string]$Command,
    [int]$ExitCode, [int]$DurationMs, [string]$StdoutHash, [string]$StderrHash, [string[]]$EvidenceFiles, [string]$Status)
  $script:invocationNumber++
  [void]$audit.Add([ordered]@{
    invocation_id = 'INV-{0:D4}' -f $script:invocationNumber
    timestamp_utc = [DateTimeOffset]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
    case_id = $caseId; agent = 'self-test'; tool_name = $ToolName; container = $Container
    container_image_or_digest = $Image; sanitized_arguments = $Arguments
    exact_reproducible_command_when_available = $Command; exit_code = $ExitCode; duration_ms = $DurationMs
    stdout_sha256 = $StdoutHash; stderr_sha256 = $StderrHash; evidence_files = @($EvidenceFiles); status = $Status
  })
}

function Quote-ProcessArgument([string]$Value) {
  if ($Value -notmatch '[\s"]') { return $Value }
  return '"' + $Value.Replace('"', '\"') + '"'
}

function Invoke-McpStdio {
  param([string]$Docker, [string]$ComposeFile, [string]$StdoutPath, [string]$StderrPath)
  $request = @(
    '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"osint-control-plane-self-test","version":"1.0"}}}',
    '{"jsonrpc":"2.0","method":"notifications/initialized"}',
    '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
  ) -join "`n"
  $arguments = @('compose', '-f', $ComposeFile, '--profile', 'mcp', 'run', '--rm', '-T', 'badchars-osint-mcp')
  $psi = [Diagnostics.ProcessStartInfo]::new(); $psi.FileName = $Docker
  $psi.Arguments = (($arguments | ForEach-Object { Quote-ProcessArgument $_ }) -join ' ')
  $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true; $psi.RedirectStandardInput = $true
  $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
  $process = [Diagnostics.Process]::new(); $process.StartInfo = $psi
  $clock = [Diagnostics.Stopwatch]::StartNew()
  try {
    [void]$process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.StandardInput.WriteLine($request); $process.StandardInput.Close()
    if (-not $process.WaitForExit(30000)) {
      try { $process.Kill() } catch {}
      $process.WaitForExit()
      [IO.File]::WriteAllText($StdoutPath, $stdoutTask.GetAwaiter().GetResult())
      [IO.File]::WriteAllText($StderrPath, ($stderrTask.GetAwaiter().GetResult() + "`nMCP transport timeout"))
      return [pscustomobject]@{ ExitCode = 124; DurationMs = [int]$clock.ElapsedMilliseconds; Output = 'MCP transport timeout' }
    }
    [IO.File]::WriteAllText($StdoutPath, (Protect-Output $stdoutTask.GetAwaiter().GetResult()))
    [IO.File]::WriteAllText($StderrPath, (Protect-Output $stderrTask.GetAwaiter().GetResult()))
    return [pscustomobject]@{ ExitCode = $process.ExitCode; DurationMs = [int]$clock.ElapsedMilliseconds; Output = Protect-Output (Get-Content -LiteralPath $StdoutPath -Raw) }
  } catch {
    [IO.File]::WriteAllText($StdoutPath, ''); [IO.File]::WriteAllText($StderrPath, (Protect-Output $_.Exception.Message))
    return [pscustomobject]@{ ExitCode = 1; DurationMs = [int]$clock.ElapsedMilliseconds; Output = Protect-Output $_.Exception.Message }
  } finally {
    $clock.Stop(); $process.Dispose()
    try {
      & $Docker compose -f $ComposeFile --profile mcp rm --force --stop badchars-osint-mcp *> $null
      $remaining = @(& $Docker compose -f $ComposeFile --profile mcp ps -aq badchars-osint-mcp 2>$null | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
      if ($remaining.Count -gt 0) { throw 'ephemeral MCP container remains after cleanup' }
    } catch { Write-Check 'MCP ephemeral cleanup' 'FAIL' (Protect-Output $_.Exception.Message) }
  }
}

function Add-Source {
  param([string]$SourceId, [string]$Provider, [string]$Tool, [string]$Url, [string]$EvidencePath, [string]$Reliability, [string]$Notes)
  $hash = Get-Hash (Join-Path $caseRoot $EvidencePath)
  [void]$sourceRecords.Add([ordered]@{
    source_id = $SourceId; url = $Url; provider = $Provider; tool = $Tool
    retrieved_at_utc = [DateTimeOffset]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
    raw_evidence_path = $EvidencePath; content_hash = $hash; reliability = $Reliability; notes = $Notes
  })
  return $hash
}

$now = [DateTimeOffset]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ')
$confirmation = 'I confirm that I have legal authority or a legitimate lawful basis to conduct passive OSINT collection against this target and will comply with applicable law and terms of service.'
if ($DryRun) {
  $caseId = 'CASE-{0}-{1}-example-com' -f $startedAt.ToString('yyyyMMdd'), $startedAt.ToString('HHmmss-fff')
  $caseRoot = Join-Path $root ('cases\' + $caseId)
  New-Item -ItemType Directory -Force -Path @('raw', 'processed', 'audit', 'reports', 'exports' | ForEach-Object { Join-Path $caseRoot $_ }) | Out-Null
  $scope = 'example.com only; passive public sources only; one request per approved source'
  $case = [ordered]@{
    case_id = $caseId; target = $target; created_at_utc = $now; scope = $scope
    authorization_timestamp_utc = $now; user_confirmation = $confirmation
    authorization = [ordered]@{
      state = 'synthetic-dry-run'; case_id = $caseId; target = $target; scope = $scope
      purpose = 'validate the defensive OSINT control-plane workflow without network collection'
      confirmation = $confirmation; valid_from_utc = $now
      valid_until_utc = ([DateTimeOffset]::UtcNow.AddMinutes(15).ToString('yyyy-MM-ddTHH:mm:ssZ'))
      allowed_collection_types = @('offline fixture generation')
      prohibited_activity = @('all network collection', 'identity collection', 'breach acquisition', 'credential validation', 'intrusive probing', 'vulnerability scanning')
    }
    collection_controls = [ordered]@{ keyless_first = $true; paid_query_budget = 0; paid_query_ledger = @() }
    test = $true; dry_run_requested = $true
  }
  Write-Json (Join-Path $caseRoot 'case.json') $case
  @('# Rules of Engagement', '', "Target: $target", "Scope: $scope", "Authorization timestamp: $now", 'Legitimate purpose: validate the defensive OSINT control-plane workflow without network collection', 'Allowed collection types: synthetic non-networked dry run', 'Prohibited activity: all network collection and intrusive activity', "User confirmation: $confirmation") | Set-Content -LiteralPath (Join-Path $caseRoot 'roe.md') -Encoding UTF8
  @('# Collection plan', '', 'Approved target: example.com', 'Synthetic dry run only; no network sources.', 'Limits: no network, no pivots, no identity or breach sources, no active scanning, no credentials.', '') | Set-Content (Join-Path $caseRoot 'collection-plan.md') -Encoding UTF8
  @('# Hypotheses', '', 'The self-test should preserve provenance and distinguish live evidence from dry-run output.', '') | Set-Content (Join-Path $caseRoot 'hypotheses.md') -Encoding UTF8
  @('# Collection gaps', '', 'no data found', '') | Set-Content (Join-Path $caseRoot 'gaps.md') -Encoding UTF8
  $authorizationStatus = Assert-CaseAuthorization $case -AllowSyntheticDryRun
  Write-Check 'Case and passive authorization' 'PASS' "$caseId (synthetic dry-run only)"
} else {
  if (-not $AcknowledgeNetworkCollection) { Write-Error 'Live self-test requires -AcknowledgeNetworkCollection.'; exit 64 }
  if ([string]::IsNullOrWhiteSpace($CasePath) -or -not (Test-Path -LiteralPath $CasePath -PathType Container)) { Write-Error 'Live self-test requires an existing authorized -CasePath.'; exit 64 }
  $caseRoot = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $CasePath).Path)
  $caseFile = Join-Path $caseRoot 'case.json'
  if (-not (Test-Path -LiteralPath $caseFile -PathType Leaf)) { Write-Error 'Live self-test case.json is missing.'; exit 64 }
  $case = Get-Content -LiteralPath $caseFile -Raw | ConvertFrom-Json -ErrorAction Stop
  $caseId = [string]$case.case_id; $target = [string]$case.target
  $authorizationStatus = Assert-CaseAuthorization $case -ExpectedCaseId $caseId -ExpectedTarget $target
  if ($target -ne 'example.com') { Write-Error 'Live self-test is limited to the example.com fixture target.'; exit 64 }
  New-Item -ItemType Directory -Force -Path @('raw', 'processed', 'audit', 'reports', 'exports' | ForEach-Object { Join-Path $caseRoot $_ }) | Out-Null
  Write-Check 'Case and passive authorization' 'PASS' "$caseId (existing structured authorization)"
}

$codex = (Get-Command codex -ErrorAction SilentlyContinue).Source
$docker = (Get-Command docker -ErrorAction SilentlyContinue).Source
$composeFile = Join-Path $root 'mcp/docker-compose.yml'; $configFile = Join-Path $root '.codex/config.toml'
foreach ($requiredPath in @((Join-Path $root 'AGENTS.md'), $configFile, $composeFile)) {
  if (Test-Path -LiteralPath $requiredPath -PathType Leaf) { Write-Check ('Project file ' + [IO.Path]::GetFileName($requiredPath)) 'PASS' 'present' }
  else { Write-Check ('Project file ' + [IO.Path]::GetFileName($requiredPath)) 'FAIL' 'missing' }
}
$agentFiles = @(Get-ChildItem -LiteralPath (Join-Path $root '.codex/agents') -Filter '*.toml' -File -ErrorAction SilentlyContinue)
if ($agentFiles.Count -gt 0 -and @($agentFiles | Where-Object { $t = Get-Content -Raw $_.FullName; $t -notmatch '(?m)^\s*name\s*=' -or $t -notmatch '(?m)^\s*description\s*=' -or $t -notmatch '(?m)^\s*developer_instructions\s*=' }).Count -eq 0) { Write-Check 'Project agents' 'PASS' "$($agentFiles.Count) valid TOML definitions" }
else { Write-Check 'Project agents' 'FAIL' 'missing agents or required fields' }
$skillFiles = @(Get-ChildItem -LiteralPath (Join-Path $root '.agents/skills') -Filter 'SKILL.md' -File -Recurse -ErrorAction SilentlyContinue)
if ($skillFiles.Count -gt 0 -and @($skillFiles | Where-Object { $t = Get-Content -Raw $_.FullName; $t -notmatch '(?m)^name:\s*\S+' -or $t -notmatch '(?m)^description:\s*\S+' }).Count -eq 0) { Write-Check 'Repository skills' 'PASS' "$($skillFiles.Count) valid SKILL.md files" }
else { Write-Check 'Repository skills' 'FAIL' 'missing skills or required metadata' }

if ($null -eq $codex) { Write-Check 'Codex CLI checks' 'SKIP' 'codex is not installed' }
else {
  $version = Invoke-Native $codex @('--version')
  if ($version.ExitCode -eq 0) { Write-Check 'Codex CLI' 'PASS' $version.Output } else { Write-Check 'Codex CLI' 'FAIL' $version.Output }
  $execHelp = Invoke-Native $codex @('exec', '--help')
  if ($execHelp.ExitCode -ne 0) { Write-Check 'Codex non-interactive checks' 'SKIP' 'codex exec help unavailable' }
  elseif ($execHelp.Output -match '--strict-config') {
    $probe = Invoke-Native $codex @('exec', '--ephemeral', '--ignore-user-config', '--strict-config', '--sandbox', 'read-only', '--cd', $root, 'Reply with exactly CODEX_SELF_TEST_OK and do not use tools.')
    if ($probe.ExitCode -eq 0 -and $probe.Output -match 'CODEX_SELF_TEST_OK') { Write-Check 'Codex strict config' 'PASS' 'read-only ephemeral probe succeeded' }
    elseif ($probe.Output -match '(?i)trust|auth|login|credential') { Write-Check 'Codex strict config' 'DRY-RUN' 'CLI reached a trust or authentication boundary; no write or collection attempted' }
    else { Write-Check 'Codex strict config' 'FAIL' $probe.Output }
  } else { Write-Check 'Codex strict config' 'SKIP' 'installed CLI does not expose --strict-config' }
  $mcpList = Invoke-Native $codex @('mcp', 'list')
  if ($mcpList.ExitCode -eq 0) { Write-Check 'Codex MCP registry' 'PASS' 'codex mcp list succeeded' } else { Write-Check 'Codex MCP registry' 'SKIP' 'registry listing unavailable' }
}

$dockerReady = $false
$mcpOperational = $false
if ($null -eq $docker) {
  Add-ComponentStatus 'Docker Desktop/Linux engine' 'UNAVAILABLE' 'locate docker executable' 'Docker CLI is not installed' 'Docker prerequisite is missing' 'Install Docker Desktop through the approved workstation process, then rerun pwsh -NoProfile -File .\scripts\self-test.ps1'
  Write-Check 'Docker engine' 'SKIP' 'docker is not installed; Docker-dependent checks are not run'
}
else {
  $dockerInfo = Invoke-Native $docker @('info', '--format', '{{.ServerVersion}}')
  if ($dockerInfo.ExitCode -ne 0) {
    $dockerError = if ($dockerInfo.Output) { $dockerInfo.Output } else { 'docker info returned a non-zero exit code' }
    Add-ComponentStatus 'Docker Desktop/Linux engine' 'UNAVAILABLE' 'docker info --format {{.ServerVersion}}' $dockerError 'Docker CLI cannot reach the configured engine' 'Start Docker Desktop, wait for the desktop-linux engine, then rerun pwsh -NoProfile -File .\scripts\self-test.ps1'
    Write-Check 'Docker engine' 'DRY-RUN' ('Docker engine unavailable; ' + $dockerError)
  }
  else { $dockerReady = $true; Add-ComponentStatus 'Docker Desktop/Linux engine' 'READY' 'docker info --format {{.ServerVersion}}' '' '' ''; Write-Check 'Docker engine' 'PASS' ('server ' + $dockerInfo.Output) }
}
if ($null -ne $docker) {
  $composeConfig = Invoke-Native $docker @('compose', '-f', $composeFile, 'config', '--quiet')
  if ($composeConfig.ExitCode -eq 0) {
    Write-Check 'Docker Compose configuration' 'PASS' 'validated'
    if ($dockerReady) {
      $build = Invoke-Native $docker @('compose', '-f', $composeFile, '--profile', 'mcp', 'build', 'badchars-osint-mcp')
      if ($build.ExitCode -eq 0) {
        Write-Check 'Required MCP image build' 'PASS' 'badchars-osint-mcp built'
        $mcpStdout = Join-Path $caseRoot 'raw/mcp-transport.stdout.txt'; $mcpStderr = Join-Path $caseRoot 'raw/mcp-transport.stderr.txt'
        $transport = Invoke-McpStdio $docker $composeFile $mcpStdout $mcpStderr
        $transportStatus = if ($transport.ExitCode -eq 0 -and $transport.Output -match '"result"') { 'PASS' } else { 'FAIL' }
        Add-Audit 'badchars-osint-mcp' 'docker compose ephemeral STDIO' 'osint-control-plane/badchars-osint-mcp:7611f70' 'initialize and tools/list; no tool call' ('docker compose -f "' + $composeFile + '" --profile mcp run --rm -T badchars-osint-mcp') $transport.ExitCode $transport.DurationMs (Get-Hash $mcpStdout) (Get-Hash $mcpStderr) @('raw/mcp-transport.stdout.txt') $transportStatus
        if ($transportStatus -eq 'PASS') { $mcpOperational = $true; Write-Check 'MCP STDIO transport' 'PASS' 'initialize/tools-list exchange completed' }
        else {
          $transportError = if ($transport.Output) { $transport.Output } else { 'no valid MCP response' }
          Add-ComponentStatus 'badchars-osint-mcp STDIO transport' 'FAILED' 'initialize and tools/list over docker compose STDIO' $transportError 'The container started but did not complete the expected MCP handshake' ('docker compose -f .\mcp\docker-compose.yml --profile mcp run --rm -T badchars-osint-mcp')
          Write-Check 'MCP STDIO transport' 'FAIL' $transportError
        }
      } else {
        Add-ComponentStatus 'badchars-osint-mcp image' 'FAILED' 'docker compose -f .\mcp\docker-compose.yml --profile mcp build badchars-osint-mcp' $build.Output 'The pinned local image build failed' 'Start Docker Desktop, inspect the build output, then rerun pwsh -NoProfile -File .\scripts\self-test.ps1'
        Write-Check 'Required MCP image build' 'FAIL' $build.Output; Write-Check 'MCP STDIO transport' 'SKIP' 'image build failed'
      }
      } else { Write-Check 'Required MCP image build' 'DRY-RUN' 'Docker engine unavailable'; Write-Check 'MCP STDIO transport' 'DRY-RUN' 'Docker engine unavailable' }
  } else {
    Add-ComponentStatus 'Docker Compose configuration' 'FAILED' 'docker compose -f .\mcp\docker-compose.yml config --quiet' $composeConfig.Output 'The Compose file could not be parsed by Docker Compose' 'Repair the Compose configuration, then rerun pwsh -NoProfile -File .\scripts\self-test.ps1'
    Write-Check 'Docker Compose configuration' 'FAIL' $composeConfig.Output
    Write-Check 'Required MCP image build' 'SKIP' 'Compose configuration failed'
    Write-Check 'MCP STDIO transport' 'SKIP' 'Compose configuration failed'
  }
} else {
  Write-Check 'Docker Compose configuration' 'SKIP' 'docker is not installed'
  Write-Check 'Required MCP image build' 'DRY-RUN' 'not executed because Docker engine is unavailable'
  Write-Check 'MCP STDIO transport' 'DRY-RUN' 'not executed because Docker engine is unavailable'
}

if (-not $dockerReady) {
  $mcpDryRun = Join-Path $caseRoot 'raw/mcp-transport.stdout.txt'; Set-Content $mcpDryRun 'no data found' -Encoding UTF8
  $mcpDryErr = Join-Path $caseRoot 'raw/mcp-transport.stderr.txt'; Set-Content $mcpDryErr 'Docker engine unavailable' -Encoding UTF8
  Add-Audit 'badchars-osint-mcp' 'not started' 'not built' 'initialize and tools/list; no tool call' 'docker compose ... badchars-osint-mcp' 125 0 (Get-Hash $mcpDryRun) (Get-Hash $mcpDryErr) @('raw/mcp-transport.stdout.txt') 'DRY-RUN'
  Add-ComponentStatus 'badchars-osint-mcp' 'UNAVAILABLE' 'docker compose -f mcp/docker-compose.yml --profile mcp run --rm -T badchars-osint-mcp; initialize and tools/list' 'Docker engine unavailable' 'Docker-backed MCP cannot start while the Docker Linux engine is unavailable' 'Start Docker Desktop, wait for the desktop-linux engine, then rerun pwsh -NoProfile -File .\scripts\self-test.ps1'
}

$liveSources = -not $DryRun -and $mcpOperational
if ($DryRun) { Write-Check 'Live public collection' 'DRY-RUN' 'explicit -DryRun selected' }
elseif (-not $mcpOperational) { Write-Check 'Live public collection' 'DRY-RUN' 'network collection withheld because the required MCP control plane is unavailable' }
else { Write-Check 'Live public collection' 'PASS' 'bounded to example.com public HTTPS and DNS only' }

$pagePath = Join-Path $caseRoot 'raw/example-com.html'; $dnsPath = Join-Path $caseRoot 'raw/example-com-dns.json'
$usableSourceIds = [System.Collections.Generic.List[string]]::new()
if ($liveSources) {
  $pageClock = [Diagnostics.Stopwatch]::StartNew()
  try {
    $page = Invoke-WebRequest -Uri 'https://example.com/' -Method Get -MaximumRedirection 0 -TimeoutSec $NetworkTimeoutSec -UseBasicParsing
    if ([string]::IsNullOrWhiteSpace($page.Content)) { throw 'empty response body' }
    [IO.File]::WriteAllText($pagePath, (Protect-Output $page.Content)); [void]$usableSourceIds.Add('SRC-HTTPS-0001'); $pageStatus = 'PASS'; $pageExit = 0; $pageNote = 'public HTTPS page retrieved; content treated as untrusted data and redacted before persistence'
  } catch { [IO.File]::WriteAllText($pagePath, 'no data found'); $pageStatus = 'SKIP'; $pageExit = 1; $pageNote = 'no data found: ' + (Protect-Output $_.Exception.Message) }
  $pageClock.Stop(); $pageHash = Add-Source 'SRC-HTTPS-0001' 'example.com' 'Invoke-WebRequest' 'https://example.com/' 'raw/example-com.html' 'high' $pageNote
  Add-Audit 'public-https-page' 'host PowerShell' 'none' 'GET https://example.com/ (one request)' 'Invoke-WebRequest -Uri https://example.com/ -Method Get' $pageExit ([int]$pageClock.ElapsedMilliseconds) $pageHash (Get-EmptyHash) @('raw/example-com.html') $pageStatus
  Write-Check 'Public HTTPS source' $pageStatus $pageNote

  $dnsClock = [Diagnostics.Stopwatch]::StartNew()
  try {
    $dns = @(Resolve-DnsName -Name $target -Type A -ErrorAction Stop | Select-Object Name, Type, IPAddress)
    if ($dns.Count -eq 0) { $dnsJson = 'no data found'; $dnsStatus = 'SKIP'; $dnsExit = 1 } else { $dnsJson = $dns | ConvertTo-Json -Depth 4; [void]$usableSourceIds.Add('SRC-DNS-0001'); $dnsStatus = 'PASS'; $dnsExit = 0 }
  } catch { $dnsJson = 'no data found'; $dnsStatus = 'SKIP'; $dnsExit = 1 }
  [IO.File]::WriteAllText($dnsPath, $dnsJson); $dnsClock.Stop(); $dnsNote = if ($dnsStatus -eq 'PASS') { 'public DNS A lookup' } else { 'no data found' }; $dnsHash = Add-Source 'SRC-DNS-0001' 'system DNS resolver' 'Resolve-DnsName' 'dns:example.com/A' 'raw/example-com-dns.json' 'medium' $dnsNote
  Add-Audit 'public-dns-a' 'host PowerShell' 'none' 'A example.com (one lookup)' 'Resolve-DnsName -Name example.com -Type A' $dnsExit ([int]$dnsClock.ElapsedMilliseconds) $dnsHash (Get-EmptyHash) @('raw/example-com-dns.json') $dnsStatus
  Write-Check 'Public DNS source' $dnsStatus $dnsNote
} else {
  foreach ($source in @(
    @{ Id = 'SRC-HTTPS-0001'; Provider = 'example.com'; Tool = 'Invoke-WebRequest'; Url = 'https://example.com/'; Path = 'raw/example-com.html' },
    @{ Id = 'SRC-DNS-0001'; Provider = 'system DNS resolver'; Tool = 'Resolve-DnsName'; Url = 'dns:example.com/A'; Path = 'raw/example-com-dns.json' }
  )) {
    [IO.File]::WriteAllText((Join-Path $caseRoot $source.Path), 'no data found')
    $null = Add-Source $source.Id $source.Provider $source.Tool $source.Url $source.Path 'unknown' 'no data found; live collection was not executed'
    Write-Check ($source.Tool + ' source') 'DRY-RUN' 'no data found; live collection was not executed'
  }
}

$selfTestEvidencePath = 'raw/self-test-metadata.json'
Write-Json (Join-Path $caseRoot $selfTestEvidencePath) ([ordered]@{ case_id = $caseId; target = $target; generated_at_utc = $now; collection_mode = if ($liveSources) { 'live-bounded' } else { 'configuration/dry-run' }; note = if ($liveSources) { 'Control-plane metadata for the bounded passive self-test.' } else { 'no data found; live collection was not executed.' } })
$selfHash = Add-Source 'SRC-SELFTEST-0001' 'OSINT-Codex self-test' 'self-test' 'local:self-test' $selfTestEvidencePath 'high' 'Workflow metadata; not target intelligence.'
[ordered]@{ generated_at_utc = $now; components = @($componentStatuses) } | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $caseRoot 'raw/component-status.json') -Encoding UTF8
[void]$entityRecords.Add([ordered]@{ entity_id = 'ENT-0001'; case_id = $caseId; type = 'domain'; value = $target; label = 'approved self-test target'; confidence = 'high'; source_ids = @('SRC-SELFTEST-0001'); notes = 'Target identity is test input, not a malicious indicator.' })
if ($liveSources -and $usableSourceIds.Count -gt 0) {
  $findingEvidencePath = if ($usableSourceIds -contains 'SRC-HTTPS-0001') { 'raw/example-com.html' } else { 'raw/example-com-dns.json' }
  [void]$findingRecords.Add([ordered]@{ finding_id = 'F-0001'; case_id = $caseId; timestamp_utc = $now; agent = 'self-test'; statement = 'An approved passive public source returned usable evidence for example.com during this bounded self-test.'; classification = 'observed'; confidence = 'high'; confidence_score = 0.9; source_ids = @($usableSourceIds); tool = 'self-test'; evidence_path = $findingEvidencePath; rationale = 'Directly observed evidence from an approved public source; no security or ownership claim is made.'; contradictions = @(); notes = 'Self-test evidence only.' })
} else {
  [void]$findingRecords.Add([ordered]@{ finding_id = 'F-0001'; case_id = $caseId; timestamp_utc = $now; agent = 'self-test'; statement = 'no data found'; classification = 'unknown'; confidence = 'low'; confidence_score = 0.0; source_ids = @('SRC-SELFTEST-0001'); tool = 'self-test'; evidence_path = $selfTestEvidencePath; rationale = 'Live collection was unavailable or returned no usable evidence.'; contradictions = @(); notes = 'No negative inference is made.' })
}

if ($liveSources -and $usableSourceIds.Count -gt 0) {
  @('# Collection gaps', '', 'No additional collection was authorized.') | Set-Content (Join-Path $caseRoot 'gaps.md') -Encoding UTF8
}

$sourcesPath = Join-Path $caseRoot 'sources.jsonl'; foreach ($record in $sourceRecords) { Write-JsonLine $sourcesPath $record }
foreach ($record in $findingRecords) { Write-JsonLine (Join-Path $caseRoot 'findings.jsonl') $record }
foreach ($record in $entityRecords) { Write-JsonLine (Join-Path $caseRoot 'entities.jsonl') $record }
foreach ($path in @('timeline.jsonl', 'relationships.jsonl')) { New-Item -ItemType File -Force -Path (Join-Path $caseRoot $path) | Out-Null }
foreach ($record in $audit) { Write-JsonLine (Join-Path $caseRoot 'audit/tool-invocations.jsonl') $record }
foreach ($path in @('sources.jsonl', 'findings.jsonl', 'entities.jsonl', 'audit/tool-invocations.jsonl')) { New-Item -ItemType File -Force -Path (Join-Path $caseRoot $path) | Out-Null }

$summary = ($results | ForEach-Object { "- [$($_.status)] $($_.name): $($_.detail)" }) -join "`n"
$mode = if ($liveSources) { 'live-bounded' } else { 'configuration/dry-run' }
@("# Passive example.com self-test", '', "- Case ID: $caseId", "- Mode: $mode", "- Target: $target", "- Scope: passive public sources only", '', '## Executive summary', 'This is a bounded control-plane self-test; it makes no ownership, security, or attribution claim.', '', '## Scope and ROE', 'The case-bound structured authorization and passive-only restrictions define the scope.', '', '## Key judgments', 'No unsupported security judgment is made.', '', '## Findings', '- `F-0001`: ' + $findingRecords[0].statement, '', '## Evidence', '- Evidence is linked through the source IDs and raw evidence paths in the case records.', '', '## Timeline', 'No separate timeline events were generated by this self-test.', '', '## Infrastructure and identity relationships', 'No identity relationship was assessed.', '', '## Confidence', 'Confidence is recorded on the finding and source records.', '', '## Risks', 'No operational risk was assessed by this self-test.', '', '## Intelligence gaps', '- No identity, breach, credential, intrusive HTTP, vulnerability, or unrelated collection was attempted.', '- `gaps.md` records `no data found` where live collection was not executed or returned no usable evidence.', '', '## What we do not know', 'No inference is made from the absence of evidence.', '', '## Recommended defensive follow-up', 'Review the generated case artifacts and rerun validation before dissemination.', '', '## Methodology', 'The runner validates local configuration, uses the native MCP STDIO lifecycle when Docker is available, and limits live collection to one public HTTPS request and one DNS A lookup for example.com.', 'Component-level errors, probable causes, and remediation commands are recorded in `raw/component-status.json`.', '', '## Source list', 'See `sources.jsonl` for provider, tool, timestamp, hash, and evidence-path provenance.', '') | Set-Content (Join-Path $caseRoot 'reports/intelligence-report.md') -Encoding UTF8
$htmlSummary = [Net.WebUtility]::HtmlEncode($summary)
Set-Content (Join-Path $caseRoot 'reports/intelligence-report.html') ("<!doctype html><html><head><meta charset=""utf-8""><title>Passive example.com self-test</title></head><body><h1>Passive example.com self-test</h1><h2>Executive summary</h2><p>Bounded control-plane self-test.</p><h2>Scope and ROE</h2><p>Case-bound structured authorization.</p><h2>Findings</h2><pre>$htmlSummary</pre><h2>Intelligence gaps</h2><p>no data found where collection was not executed.</p><h2>What we do not know</h2><p>No inference is made from absence of evidence.</p><h2>Methodology</h2><p>Passive-only bounded checks.</p><h2>Source list</h2><p>SRC-SELFTEST-0001 and any approved source records.</p></body></html>") -Encoding UTF8
Write-Json (Join-Path $caseRoot 'exports/ioc-bundle.json') ([ordered]@{ case_id = $caseId; generated_at_utc = $now; iocs = @(); notes = 'example.com is the approved test target and is not classified as a malicious IOC.' })

$validator = Join-Path $PSScriptRoot 'validate-case.ps1'
$validatorCommand = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if ($null -eq $validatorCommand) { $validatorCommand = (Get-Command powershell -ErrorAction SilentlyContinue).Source }
if ($null -eq $validatorCommand) { Write-Check 'Case validation' 'FAIL' 'PowerShell executable unavailable'; $validationExit = 1 }
else {
  $validation = Invoke-Native $validatorCommand @('-NoProfile', '-File', $validator, '-CasePath', $caseRoot)
  $validationExit = $validation.ExitCode
  if ($validationExit -eq 0) { Write-Check 'Case validation' 'PASS' 'validate-case.ps1 succeeded' } else { Write-Check 'Case validation' 'FAIL' $validation.Output }
}

$failures = @($results | Where-Object { $_.status -eq 'FAIL' })
Write-Host ('Self-test case: {0}' -f $caseRoot)
Write-Host ('Self-test mode: {0}; failures: {1}' -f $mode, $failures.Count)
if ($failures.Count -gt 0 -or $validationExit -ne 0) { exit 1 }
exit 0
