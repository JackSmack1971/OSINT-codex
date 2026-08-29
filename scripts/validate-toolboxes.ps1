[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$compose = Get-Content -Raw (Join-Path $root 'mcp/docker-compose.yml')
$guard = Get-Content -Raw (Join-Path $root 'mcp/toolboxes/guard.sh')
$required = @('sherlock','holehe','maigret','theharvester','spiderfoot','amass','subfinder','httpx','nuclei','gitleaks','trufflehog')

foreach ($tool in $required) {
  if ($compose -notmatch "(?m)^  ${tool}:") { throw "Missing Compose service: $tool" }
  if ($compose -notmatch "OSINT_TOOL=$tool") { throw "Missing guard binding: $tool" }
}
foreach ($digest in @('9d6602b98179fb15ceab88433626fb0ae603ae9880e13cab886970317fe1475f','927e9c59def511f56837171253b9c96ef0467c6f95df2fd5dc5c0ed5b0f089b6','a7596ae99637be30b43959d3e6f85d2051671662b49fb6388c5a4625db5eb505','3f28ec2fb6ee5faf608d140ab10d685b8cc8c7791d8f6a3bb7a2e47c62135ef0','8f5f5ccf479bdbefadb3de7dfb7e20870d9c76e414a21393d0aa78095461a951','9fd705284ac4b5f721fa1e23bf366f26e985cd4ec65927fe9a53cb3fcb0417a6','b109bc5f8f76a38196a3e413704fc5b9e3c32360bce4e4b603bd6f45b3721dbb','da3365e98ab735336733fc90cc22af8413a6d9fc1e6da5412e781daeb2d14663')) {
  if ($compose -notmatch [regex]::Escape("sha256:$digest")) { throw "Missing verified image digest: $digest" }
}
foreach ($marker in @('OSINT_CASE_ID','OSINT_TARGET','OSINT_SCOPE','case.json','state','authorized','OSINT_ENABLE_SENSITIVE','OSINT_ENABLE_LOW_IMPACT_HTTP','OSINT_ENABLE_VULN_TEMPLATES','enum -passive','-silent','sfp_dnsresolve','--redact','no-new-privileges')) {
  if ($guard -notmatch [regex]::Escape($marker) -and $compose -notmatch [regex]::Escape($marker)) { throw "Missing safety marker: $marker" }
}
if ($compose -match '(?m)^\s+ports:|docker\.sock|privileged:\s*true') { throw 'Unsafe host exposure found in Compose' }
Write-Output 'PASS toolbox validation'
