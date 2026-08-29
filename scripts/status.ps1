[CmdletBinding()]
param(
  [string]$CaseRoot = (Join-Path (Split-Path $PSScriptRoot -Parent) 'cases')
)

$ErrorActionPreference = 'SilentlyContinue'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'authorization.ps1')
$rows = [System.Collections.Generic.List[object]]::new()

function Add-StatusRow([string]$Metric, [string]$Value, [string]$Status) {
  $rows.Add([pscustomobject]@{ Metric = $Metric; Value = $Value; Status = $Status })
}

function Read-JsonLines([string]$Path) {
  $items = [System.Collections.Generic.List[object]]::new()
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @() }
  foreach ($line in Get-Content -LiteralPath $Path) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    try { $items.Add(($line | ConvertFrom-Json -ErrorAction Stop)) } catch { }
  }
  return @($items)
}

function Get-ConfiguredProviderNames {
  $names = [System.Collections.Generic.List[string]]::new()
  $envExample = Join-Path $root '.env.example'
  $keys = @()
  if (Test-Path -LiteralPath $envExample -PathType Leaf) {
    $keys = @(Get-Content -LiteralPath $envExample | ForEach-Object {
      if ($_ -match '^\s*([A-Z][A-Z0-9_]*(?:API_KEY|API_ID|API_SECRET))\s*=') { $Matches[1] }
    })
  }
  $dotenv = Join-Path $root '.env'
  foreach ($key in $keys) {
    $configured = -not [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($key))
    if (-not $configured -and (Test-Path -LiteralPath $dotenv -PathType Leaf)) {
      $configured = @(Select-String -LiteralPath $dotenv -Pattern ("^\s*" + [regex]::Escape($key) + "\s*=\s*[^#\s].*$") -Quiet)
    }
    if ($configured) {
      $provider = ($key -replace '_API_(KEY|ID|SECRET)$','' -replace '_',' ')
      $names.Add((Get-Culture).TextInfo.ToTitleCase($provider.ToLowerInvariant()))
    }
  }
  return @($names | Sort-Object -Unique)
}

$case = $null
if (Test-Path -LiteralPath $CaseRoot -PathType Container) {
  $case = Get-ChildItem -LiteralPath $CaseRoot -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

$caseJson = $null
$findings = @()
$entities = @()
$relationships = @()
$audit = @()
$gapCount = 0
$contradictionCount = 0
$latestInvocation = 'none'
if ($case) {
  try { $caseJson = Get-Content -LiteralPath (Join-Path $case.FullName 'case.json') -Raw | ConvertFrom-Json -ErrorAction Stop } catch { }
  $findings = @(Read-JsonLines (Join-Path $case.FullName 'findings.jsonl'))
  $entities = @(Read-JsonLines (Join-Path $case.FullName 'entities.jsonl'))
  $relationships = @(Read-JsonLines (Join-Path $case.FullName 'relationships.jsonl'))
  $audit = @(Read-JsonLines (Join-Path $case.FullName 'audit/tool-invocations.jsonl'))
  $contradictionCount = @($findings | Where-Object {
    $null -ne $_.PSObject.Properties['contradictions'] -and @($_.contradictions).Count -gt 0
  }).Count
  $gapsFile = Join-Path $case.FullName 'gaps.md'
  if (Test-Path -LiteralPath $gapsFile -PathType Leaf) {
    $gapCount = @(Get-Content -LiteralPath $gapsFile | Where-Object {
      $_.Trim() -and $_ -notmatch '^\s*#' -and $_ -notmatch '^\s*<!--'
    }).Count
  }
  $latest = $audit | Where-Object { $_.timestamp_utc } | Sort-Object timestamp_utc | Select-Object -Last 1
  if ($latest) {
    $latestTimestamp = ([DateTimeOffset]$latest.timestamp_utc).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    $latestInvocation = "$($latest.invocation_id) / $($latest.tool_name) / $($latest.status) / $latestTimestamp"
  }
}

$activeCase = if ($case) { $case.Name } else { 'none' }
$authorizationStatus = if ($caseJson) { Get-CaseAuthorizationStatus $caseJson } else { $null }
$authValue = if ($authorizationStatus -and $authorizationStatus.Valid) { "valid structured authorization ($($authorizationStatus.State))" } elseif ($authorizationStatus) { 'invalid or stale structured authorization' } else { 'unknown' }
$authStatus = if ($authorizationStatus -and $authorizationStatus.Valid) { 'READY' } elseif ($authorizationStatus) { 'BLOCKED' } else { 'UNKNOWN' }
Add-StatusRow 'Active case' $activeCase 'INFO'
Add-StatusRow 'Authorization' $authValue $authStatus
if ($authorizationStatus -and -not $authorizationStatus.Valid) { Add-StatusRow 'Authorization defects' ($authorizationStatus.Errors -join '; ') 'BLOCKED' }

$dockerCommand = Get-Command docker -ErrorAction SilentlyContinue
$dockerVersion = $null
$dockerReady = $false
if ($dockerCommand) {
  $dockerVersion = (& $dockerCommand.Source info --format '{{.ServerVersion}}' 2>$null | Out-String).Trim()
  $dockerReady = ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($dockerVersion))
}
$dockerValue = if ($dockerReady) { "engine $dockerVersion" } elseif ($dockerCommand) { 'Docker CLI present; engine unavailable' } else { 'Docker CLI unavailable' }
$dockerStatus = if ($dockerReady) { 'READY' } elseif ($dockerCommand) { 'UNAVAILABLE' } else { 'UNAVAILABLE' }
Add-StatusRow 'Docker Desktop / engine' $dockerValue $dockerStatus

$composeFile = Join-Path $root 'mcp/docker-compose.yml'
$composeValue = 'not checked; Docker engine unavailable'
$composeStatus = 'UNAVAILABLE'
if (-not (Test-Path -LiteralPath $composeFile -PathType Leaf)) {
  $composeValue = 'compose file missing'
  $composeStatus = 'FAILED'
} elseif ($dockerReady) {
  & $dockerCommand.Source compose -f $composeFile config --quiet 2>$null | Out-Null
  $configExit = $LASTEXITCODE
  if ($configExit -eq 0) {
    $composeRows = @(& $dockerCommand.Source compose -f $composeFile ps --all --format '{{.Service}}|{{.State}}' 2>$null)
    if ($LASTEXITCODE -ne 0) {
      $composeValue = 'config valid; project state unavailable'
      $composeStatus = 'UNKNOWN'
    } elseif ($composeRows.Count -eq 0) {
      $composeValue = 'config valid; no containers'
      $composeStatus = 'STOPPED'
    } else {
      $running = @($composeRows | Where-Object { $_ -match '\|running$|\|up$' }).Count
      $composeValue = if ($running -gt 0) { "$running running / $($composeRows.Count) defined" } else { "0 running / $($composeRows.Count) defined" }
      $composeStatus = if ($running -gt 0) { 'RUNNING' } else { 'STOPPED' }
    }
  } else {
    $composeValue = 'compose config invalid'
    $composeStatus = 'FAILED'
  }
}
Add-StatusRow 'Compose project' $composeValue $composeStatus

$codexConfig = Join-Path $root '.codex/config.toml'
$mcpConfigLines = @()
if (Test-Path -LiteralPath $codexConfig -PathType Leaf) {
  $mcpConfigLines = @(Get-Content -LiteralPath $codexConfig)
}
$mcpStarts = @()
for ($index = 0; $index -lt $mcpConfigLines.Count; $index++) {
  if ($mcpConfigLines[$index] -match '^\s*\[mcp_servers\.([^\]]+)\]\s*$') {
    $mcpStarts += [pscustomobject]@{ Name = $Matches[1]; Index = $index }
  }
}
if ($mcpStarts.Count -eq 0) {
  Add-StatusRow 'MCP servers / health' 'none configured in project config' 'DISABLED'
} else {
  for ($serverIndex = 0; $serverIndex -lt $mcpStarts.Count; $serverIndex++) {
    $server = $mcpStarts[$serverIndex]
    $end = if ($serverIndex + 1 -lt $mcpStarts.Count) { $mcpStarts[$serverIndex + 1].Index } else { $mcpConfigLines.Count }
    $section = @($mcpConfigLines[($server.Index + 1)..($end - 1)])
    $url = $null
    $command = $null
    foreach ($line in $section) {
      if ($line -match '^\s*url\s*=\s*"([^"]+)"') { $url = $Matches[1] }
      if ($line -match '^\s*command\s*=\s*"([^"]+)"') { $command = $Matches[1] }
    }
    if ($url) {
      try {
        $uri = [Uri]$url
        $port = if ($uri.IsDefaultPort) { if ($uri.Scheme -eq 'https') { 443 } else { 80 } } else { $uri.Port }
        $client = [System.Net.Sockets.TcpClient]::new()
        $connected = $client.ConnectAsync($uri.DnsSafeHost, $port).Wait(2000)
        $client.Dispose()
        if ($connected) {
          Add-StatusRow "MCP: $($server.Name)" "HTTP transport reachable at $($uri.DnsSafeHost):$port; protocol health unverified" 'UNKNOWN'
        } else {
          Add-StatusRow "MCP: $($server.Name)" "HTTP transport unreachable at $($uri.DnsSafeHost):$port" 'UNAVAILABLE'
        }
      } catch {
        Add-StatusRow "MCP: $($server.Name)" 'HTTP endpoint is invalid or unreachable' 'UNAVAILABLE'
      }
    } elseif ($command) {
      if ($command -eq 'docker' -and -not $dockerReady) {
        Add-StatusRow "MCP: $($server.Name)" 'Docker-backed STDIO unavailable because the Docker engine is unavailable' 'UNAVAILABLE'
      } else {
        Add-StatusRow "MCP: $($server.Name)" "stdio configured ($command); health not probeable" 'UNKNOWN'
      }
    } else {
      Add-StatusRow "MCP: $($server.Name)" 'configured without a recognized transport' 'UNKNOWN'
    }
  }
}

$disabled = @()
$readme = Join-Path $root 'README.md'
if (Test-Path -LiteralPath $readme -PathType Leaf) {
  $disabled = @(Get-Content -LiteralPath $readme | ForEach-Object {
    if ($_ -match '^\|\s*([^|]+?)\s*\|.*\|\s*`DISABLED`') { $Matches[1].Trim() }
  })
}
$disabledValue = if ($disabled.Count) { $disabled -join ', ' } else { 'none recorded' }
Add-StatusRow 'Disabled integrations' $disabledValue 'DISABLED'

$providers = @(Get-ConfiguredProviderNames)
$providerValue = if ($providers.Count) { $providers -join ', ' } else { 'none configured' }
Add-StatusRow 'Optional API providers' $providerValue 'INFO'
Add-StatusRow 'Latest tool execution' $latestInvocation 'INFO'
Add-StatusRow 'Findings' ([string]$findings.Count) 'INFO'
Add-StatusRow 'Entities / relationships' "$($entities.Count) / $($relationships.Count)" 'INFO'
Add-StatusRow 'Unresolved contradictions' ([string]$contradictionCount) 'INFO'
Add-StatusRow 'Intelligence gaps' ([string]$gapCount) 'INFO'

$rows | Format-Table -Property Metric,Value,Status -Wrap -AutoSize | Out-String -Width 140 | Write-Output
