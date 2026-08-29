[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
. (Join-Path $PSScriptRoot 'authorization.ps1')
$casesRoot = Join-Path $root 'cases'
$caseDirectory = Get-ChildItem -LiteralPath $casesRoot -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($null -eq $caseDirectory) { throw 'MCP execution denied: no active case exists' }
$caseFile = Join-Path $caseDirectory.FullName 'case.json'
if (-not (Test-Path -LiteralPath $caseFile -PathType Leaf)) { throw 'MCP execution denied: active case.json is missing' }
$case = Get-Content -LiteralPath $caseFile -Raw | ConvertFrom-Json -ErrorAction Stop
$authorization = Assert-CaseAuthorization $case -ExpectedCaseId ([string]$case.case_id) -ExpectedTarget ([string]$case.target)
$docker = (Get-Command docker -ErrorAction Stop).Source
$composeFile = Join-Path $root 'mcp/docker-compose.yml'
$arguments = @('compose', '-f', $composeFile, '--profile', 'mcp', 'run', '--rm', '-T', '--no-deps',
  '--env', "OSINT_CASE_ID=$($authorization.CaseId)", '--env', "OSINT_TARGET=$($authorization.Target)", '--env', "OSINT_SCOPE=$($authorization.Scope)", 'badchars-osint-mcp')
$exitCode = 1
try {
  & $docker @arguments
  $exitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
} finally {
  & $docker compose -f $composeFile --profile mcp rm --force --stop badchars-osint-mcp *> $null
  if ($LASTEXITCODE -ne 0) { $exitCode = 1 }
  $leaked = @(& $docker compose -f $composeFile --profile mcp ps -aq badchars-osint-mcp 2>$null | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  if ($leaked.Count -gt 0) { $exitCode = 1; Write-Error 'MCP cleanup failed: ephemeral container remains' }
}
exit $exitCode
