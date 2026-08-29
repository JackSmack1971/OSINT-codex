[CmdletBinding()]
param()

# Windows-native bootstrap for a clean checkout. This script never writes Codex
# user configuration and does not enable optional OSINT integrations.
#requires -Version 5.1

$ErrorActionPreference = 'Continue'
$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$composeFile = Join-Path $root 'mcp/docker-compose.yml'
$failures = [System.Collections.Generic.List[string]]::new()

function Write-Check {
  param([string]$Name, [ValidateSet('PASS', 'WARN', 'FAIL', 'INFO')][string]$Status, [string]$Detail)
  Write-Host ('[{0}] {1}: {2}' -f $Status, $Name, $Detail)
}

function Add-Failure([string]$Message) {
  $failures.Add($Message)
  Write-Check 'Required check' 'FAIL' $Message
}

function Protect-Output([string]$Text) {
  if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
  $safe = $Text
  $safe = [regex]::Replace($safe, '(?i)(api[_-]?key|secret|token|password|authorization)(\s*[:=]\s*)([^\s,;]+)', '$1$2[REDACTED]')
  $safe = [regex]::Replace($safe, '(?i)(https?://)([^/@\s]+):([^/@\s]+)@', '$1[REDACTED]@')
  return $safe.Trim()
}

function Invoke-Native {
  param([string]$Command, [string[]]$Arguments)
  $output = (& $Command @Arguments 2>&1 | Out-String).Trim()
  [pscustomobject]@{ ExitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }; Output = $output }
}

function Assert-File([string]$Path, [string]$Description) {
  if (Test-Path -LiteralPath $Path -PathType Leaf) {
    Write-Check $Description 'PASS' $Path.Substring($root.Length + 1)
    return $true
  }
  Add-Failure "Missing $Description ($Path)."
  return $false
}

function Get-OptionalIntegrations {
  $readme = Join-Path $root 'README.md'
  if (Test-Path -LiteralPath $readme -PathType Leaf) {
    $disabled = @(Get-Content -LiteralPath $readme | ForEach-Object {
        if ($_ -match '^\|\s*([^|]+?)\s*\|.*\|\s*`DISABLED`') { $Matches[1].Trim() }
      })
    if ($disabled.Count -gt 0) { Write-Check 'Disabled integrations' 'INFO' ($disabled -join ', ') }
  }

  $envFile = Join-Path $root '.env'
  $configured = [System.Collections.Generic.List[string]]::new()
  $optionalKeys = @('SHODAN_API_KEY', 'VT_API_KEY', 'ST_API_KEY', 'CENSYS_API_ID', 'CENSYS_API_SECRET', 'HIBP_API_KEY')
  foreach ($key in $optionalKeys) {
    $isSet = -not [string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($key))
    if (-not $isSet -and (Test-Path -LiteralPath $envFile -PathType Leaf)) {
      $isSet = @(Select-String -LiteralPath $envFile -Pattern ('^\s*' + [regex]::Escape($key) + '\s*=\s*[^#\s].*$') -Quiet)
    }
    if ($isSet) { $configured.Add($key) }
  }
  if ($configured.Count -eq 0) {
    Write-Check 'Optional API integrations' 'INFO' 'none configured; keyless/public sources remain available.'
  } else {
    Write-Check 'Optional API integrations' 'INFO' ("configured providers: " + ($configured -join ', ') + '; values withheld')
  }
}

Push-Location $root
try {
  Write-Host "Bootstrap root: $root"

  $requiredCommands = @('codex', 'docker', 'git')
  $commands = @{}
  foreach ($name in $requiredCommands) {
    $command = Get-Command $name -ErrorAction SilentlyContinue
    if ($null -eq $command) {
      Add-Failure "Required command '$name' is not on PATH."
    } else {
      $commands[$name] = $command.Source
      Write-Check "Prerequisite $name" 'PASS' $command.Source
    }
  }

  if ($PSVersionTable.PSVersion.Major -lt 5) { Add-Failure 'PowerShell 5.1 or newer is required.' }
  else { Write-Check 'PowerShell' 'PASS' $PSVersionTable.PSVersion.ToString() }

  if ($commands.ContainsKey('git')) {
    $gitRoot = Invoke-Native $commands['git'] @('rev-parse', '--show-toplevel')
    if ($gitRoot.ExitCode -eq 0 -and [System.IO.Path]::GetFullPath($gitRoot.Output) -eq $root.TrimEnd('\')) {
      Write-Check 'Git repository' 'PASS' 'current checkout is the project root.'
    } else { Add-Failure 'The script must run from a Git checkout with the expected project root.' }
  }

  $requiredFiles = @(
    @{ Path = (Join-Path $root 'AGENTS.md'); Description = 'repository instructions' },
    @{ Path = (Join-Path $root '.codex/config.toml'); Description = 'project Codex config' },
    @{ Path = $composeFile; Description = 'Docker Compose file' },
    @{ Path = (Join-Path $root '.env.example'); Description = '.env.example' }
  )
  foreach ($requiredFile in $requiredFiles) { [void](Assert-File $requiredFile.Path $requiredFile.Description) }

  if (-not (Test-Path -LiteralPath (Join-Path $root '.env') -PathType Leaf)) {
    if (Test-Path -LiteralPath (Join-Path $root '.env.example') -PathType Leaf) {
      Copy-Item -LiteralPath (Join-Path $root '.env.example') -Destination (Join-Path $root '.env')
      Write-Check '.env' 'PASS' 'created from .env.example because .env was absent.'
    }
  } else { Write-Check '.env' 'PASS' 'preserved existing file.' }

  if ($commands.ContainsKey('codex')) {
    $version = Invoke-Native $commands['codex'] @('--version')
    if ($version.ExitCode -eq 0) { Write-Check 'Codex version' 'PASS' (Protect-Output $version.Output) }
    else { Add-Failure 'Codex --version failed.' }

    $execHelp = Invoke-Native $commands['codex'] @('exec', '--help')
    $supportsStrict = $execHelp.ExitCode -eq 0 -and $execHelp.Output -match '--strict-config'
    if ($supportsStrict) {
      Write-Check 'Codex project-config validation' 'INFO' 'strict-config is supported; running a read-only ephemeral probe.'
      $probe = Invoke-Native $commands['codex'] @('exec', '--ephemeral', '--ignore-user-config', '--strict-config', '--sandbox', 'read-only', '--cd', $root, 'Reply with exactly CODEX_BOOTSTRAP_OK and do not use tools.')
      $probeText = Protect-Output $probe.Output
      if ($probe.ExitCode -eq 0) {
        Write-Check 'Codex project config' 'PASS' 'strict parsing and read-only probe succeeded.'
      } elseif ($probeText -match '(?i)trust|trusted|untrusted') {
        Write-Check 'Trusted project requirement' 'WARN' 'Codex did not load or verify project-local config because this checkout may require trust.'
        Write-Host '       Action: open this repository in Codex and approve the repository trust prompt; this script will not change trust or global config.'
      } elseif ($probeText -match '(?i)auth|login|credential|sign.?in') {
        Write-Check 'Codex project config' 'WARN' 'strict probe reached Codex but authentication is unavailable; CLI validation could not continue.'
        Write-Host '       Action: authenticate Codex, then rerun this script.'
      } else {
        Add-Failure "Codex strict project-config probe failed: $probeText"
      }
    } else {
      Write-Check 'Codex project-config validation' 'WARN' 'installed CLI does not expose --strict-config; file/layout checks are the available validation.'
    }
  }

  $agentFiles = @(Get-ChildItem -LiteralPath (Join-Path $root '.codex/agents') -Filter '*.toml' -File -ErrorAction SilentlyContinue)
  if ($agentFiles.Count -gt 0) {
    $invalidAgents = @($agentFiles | Where-Object {
        $text = Get-Content -LiteralPath $_.FullName -Raw
        $text -notmatch '(?m)^\s*name\s*=' -or $text -notmatch '(?m)^\s*description\s*=' -or $text -notmatch '(?m)^\s*developer_instructions\s*='
      })
    if ($invalidAgents.Count -eq 0) { Write-Check 'Project agents' 'PASS' "$($agentFiles.Count) TOML agent definitions found with required fields." }
    else { Add-Failure "Project agents missing required fields: $($invalidAgents.Name -join ', ')." }
  } else { Add-Failure 'No project agents found under .codex/agents.' }

  $skillFiles = @(Get-ChildItem -LiteralPath (Join-Path $root '.agents/skills') -Filter 'SKILL.md' -File -Recurse -ErrorAction SilentlyContinue)
  if ($skillFiles.Count -gt 0) {
    $invalidSkills = @($skillFiles | Where-Object {
        $text = Get-Content -LiteralPath $_.FullName -Raw
        $text -notmatch '(?m)^name:\s*\S+' -or $text -notmatch '(?m)^description:\s*\S+'
      })
    if ($invalidSkills.Count -eq 0) { Write-Check 'Repository skills' 'PASS' "$($skillFiles.Count) SKILL.md files found with name and description metadata." }
    else { Add-Failure "Repository skills missing required metadata: $($invalidSkills.FullName -join ', ')." }
  } else { Add-Failure 'No repository skills found under .agents/skills.' }
  Write-Check 'Codex discovery checks' 'INFO' 'AGENTS.md, project agents, and skills verified structurally; this CLI has no dedicated discovery-list command.'
  Write-Host '       Trust note: project .codex/config.toml, agents, and project skills are loaded only for a trusted repository.'

  if ($commands.ContainsKey('docker')) {
    $dockerInfo = Invoke-Native $commands['docker'] @('info', '--format', '{{.ServerVersion}}')
    if ($dockerInfo.ExitCode -ne 0) {
      $detail = Protect-Output $dockerInfo.Output
      Add-Failure "Docker Desktop/Linux engine is unavailable; attempted 'docker info --format {{.ServerVersion}}'; error: $detail; probable cause: the Docker CLI cannot reach the configured engine; remediation: start Docker Desktop, wait for the desktop-linux engine, then rerun 'pwsh -NoProfile -File .\scripts\bootstrap.ps1'."
    } else {
      Write-Check 'Docker Desktop engine' 'PASS' ("server " + (Protect-Output $dockerInfo.Output))
      $context = Invoke-Native $commands['docker'] @('context', 'show')
      if ($context.ExitCode -eq 0) { Write-Check 'Docker context' 'INFO' (Protect-Output $context.Output) }
      else { Write-Check 'Docker context' 'WARN' 'unable to determine the active Docker context.' }
    }
  }

  if ($failures.Count -eq 0 -and $commands.ContainsKey('docker')) {
    $compose = @('compose', '-f', '.\mcp\docker-compose.yml')
    $config = Invoke-Native $commands['docker'] ($compose + @('config', '--quiet'))
    if ($config.ExitCode -ne 0) {
      Add-Failure "Docker Compose config failed: $(Protect-Output $config.Output)"
    } else {
      Write-Check 'Docker Compose config' 'PASS' 'validated.'
      $build = Invoke-Native $commands['docker'] ($compose + @('--profile', 'mcp', 'build', 'badchars-osint-mcp'))
      if ($build.ExitCode -ne 0) { Add-Failure "Required MCP image build failed: $(Protect-Output $build.Output)" }
      else { Write-Check 'Required MCP image' 'PASS' 'badchars-osint-mcp build completed; optional profiles remain opt-in.' }

      $start = Invoke-Native $commands['docker'] ($compose + @('--profile', 'mcp', 'up', '-d', 'badchars-osint-mcp'))
      if ($start.ExitCode -ne 0) { Add-Failure "Long-running MCP service failed to start: $(Protect-Output $start.Output)" }
      else { Write-Check 'Long-running services' 'PASS' 'badchars-osint-mcp started; utility and scanner profiles remain opt-in.' }
    }
  }

  if ($commands.ContainsKey('codex')) {
    $mcp = Invoke-Native $commands['codex'] @('mcp', 'list')
    if ($mcp.ExitCode -eq 0) { Write-Check 'Codex MCP registry' 'PASS' (Protect-Output $mcp.Output) }
    else { Write-Check 'Codex MCP registry' 'WARN' "codex mcp list unavailable or not authenticated: $(Protect-Output $mcp.Output)" }
  }

  Get-OptionalIntegrations
  Write-Check 'Optional Compose profiles' 'INFO' 'workspace, tools, and scanners are disabled/not started; enable them only for a current authorized case and explicit safe use.'
  if ($failures.Count -gt 0) {
    Write-Host "Bootstrap FAILED with $($failures.Count) required issue(s)."
    exit 1
  }
  Write-Host 'Bootstrap COMPLETE. Next: review the trust prompt in Codex, then run .\scripts\self-test.ps1.'
} finally {
  Pop-Location
}
