[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateNotNullOrEmpty()]
  [string]$CasePath
)

$ErrorActionPreference = 'Stop'
$authorizationLibrary = Join-Path $PSScriptRoot 'authorization.ps1'
. $authorizationLibrary
$errors = [System.Collections.Generic.List[string]]::new()
$caseRoot = $null

function Add-ValidationError([string]$Message) { [void]$errors.Add($Message) }

function Get-Property($Object, [string]$Name) {
  if ($null -eq $Object) { return $null }
  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) { return $null }
  Write-Output -NoEnumerate -InputObject $property.Value
}

function Has-Text($Object, [string]$Name) {
  $value = Get-Property $Object $Name
  return $null -ne $value -and -not ($value -is [System.Array]) -and -not [string]::IsNullOrWhiteSpace([string]$value)
}

function Has-Array($Object, [string]$Name, [bool]$AllowEmpty = $false) {
  $value = Get-Property $Object $Name
  if ($null -eq $value -or -not ($value -is [System.Collections.IEnumerable]) -or $value -is [string]) { return $false }
  if (-not $AllowEmpty -and $value.Count -eq 0) { return $false }
  return $true
}

function Test-UtcTimestamp($Value) {
  if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return $false }
  $text = [string]$Value
  if ($text -notmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+]00:00)$') { return $false }
  $parsed = [DateTimeOffset]::MinValue
  return [DateTimeOffset]::TryParse($text, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind, [ref]$parsed) -and $parsed.Offset -eq [TimeSpan]::Zero
}

function Test-Sha256([string]$Value) {
  return -not [string]::IsNullOrWhiteSpace($Value) -and $Value -match '^(?i:sha256:)[0-9a-f]{64}$'
}

function Resolve-CasePath([string]$RelativePath, [string]$Description) {
  if ([string]::IsNullOrWhiteSpace($RelativePath) -or [IO.Path]::IsPathRooted($RelativePath)) {
    Add-ValidationError "$Description must be a relative case path"
    return $null
  }
  try { $resolved = [IO.Path]::GetFullPath((Join-Path $caseRoot $RelativePath)) } catch {
    Add-ValidationError "$Description is not a valid case path"
    return $null
  }
  $rootWithSlash = $caseRoot.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
  if (-not $resolved.StartsWith($rootWithSlash, [StringComparison]::OrdinalIgnoreCase)) {
    Add-ValidationError "$Description escapes the case folder"
    return $null
  }
  return $resolved
}

function Read-JsonLines([string]$RelativePath, [string]$Label) {
  $path = Join-Path $caseRoot $RelativePath
  $records = [System.Collections.Generic.List[object]]::new()
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @() }
  $lineNumber = 0
  foreach ($line in Get-Content -LiteralPath $path) {
    $lineNumber++
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    try { [void]$records.Add(($line | ConvertFrom-Json -NoEnumerate -DateKind String -ErrorAction Stop)) } catch {
      Add-ValidationError "$Label line $lineNumber is not valid JSON"
    }
  }
  return @($records)
}

function Test-UniqueIds($Records, [string]$Property, [string]$Label) {
  $seen = @{}
  foreach ($record in $Records) {
    $id = [string](Get-Property $record $Property)
    if ([string]::IsNullOrWhiteSpace($id)) { continue }
    if ($seen.ContainsKey($id)) { Add-ValidationError "$Label contains duplicate $Property" } else { $seen[$id] = $true }
  }
}

function Test-References($Object, [string]$Property, $KnownIds, [string]$Label, [bool]$Required = $true) {
  if (-not (Has-Array $Object $Property (-not $Required))) {
    if ($Required) { Add-ValidationError "$Label is missing $Property" }
    return
  }
  $references = Get-Property $Object $Property
  foreach ($id in $references) {
    if ([string]::IsNullOrWhiteSpace([string]$id) -or $KnownIds -notcontains [string]$id) {
      Add-ValidationError "$Label references an unknown source ID"
    }
  }
}

if (-not (Test-Path -LiteralPath $CasePath -PathType Container)) {
  Write-Error 'Case path must be an existing directory.'
  exit 1
}
$caseRoot = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $CasePath).Path)

$requiredFiles = @(
  'case.json', 'roe.md', 'collection-plan.md', 'timeline.jsonl', 'findings.jsonl',
  'entities.jsonl', 'relationships.jsonl', 'sources.jsonl', 'hypotheses.md', 'gaps.md',
  'audit/tool-invocations.jsonl', 'reports/intelligence-report.md',
  'reports/intelligence-report.html', 'exports/ioc-bundle.json'
)
foreach ($relativePath in $requiredFiles) {
  if (-not (Test-Path -LiteralPath (Join-Path $caseRoot $relativePath) -PathType Leaf)) { Add-ValidationError "Missing required file: $relativePath" }
}
foreach ($directory in @('raw', 'processed', 'audit', 'reports', 'exports')) {
  if (-not (Test-Path -LiteralPath (Join-Path $caseRoot $directory) -PathType Container)) { Add-ValidationError "Missing required directory: $directory" }
}

$case = $null
$caseFile = Join-Path $caseRoot 'case.json'
if (Test-Path -LiteralPath $caseFile -PathType Leaf) {
  try { $case = Get-Content -LiteralPath $caseFile -Raw | ConvertFrom-Json -NoEnumerate -DateKind String -ErrorAction Stop } catch { Add-ValidationError 'case.json is not valid JSON' }
}
if ($null -ne $case) {
  foreach ($field in @('case_id', 'target', 'scope', 'authorization_timestamp_utc', 'user_confirmation')) {
    if (-not (Has-Text $case $field)) { Add-ValidationError "case.json is missing authorization field: $field" }
  }
  $authorizationStatus = Get-CaseAuthorizationStatus $case -AllowSyntheticDryRun
  if (-not $authorizationStatus.Valid) { foreach ($message in $authorizationStatus.Errors) { Add-ValidationError "case.json authorization: $message" } }
  $caseId = [string](Get-Property $case 'case_id')
  if ((Has-Text $case 'case_id') -and -not ($caseId -match '^CASE-[0-9]{8}-[0-9]{6}-.+$')) { Add-ValidationError 'case.json case_id does not match the required CASE timestamp format' }
  if ((Has-Text $case 'authorization_timestamp_utc') -and -not (Test-UtcTimestamp (Get-Property $case 'authorization_timestamp_utc'))) { Add-ValidationError 'case.json authorization timestamp is not a parseable UTC timestamp' }
  $controls = Get-Property $case 'collection_controls'
  if ($null -eq $controls) { Add-ValidationError 'case.json collection_controls is required' }
  else {
    if ((Get-Property $controls 'keyless_first') -ne $true) { Add-ValidationError 'collection_controls.keyless_first must be true' }
    $budget = Get-Property $controls 'paid_query_budget'
    if ($null -eq $budget -or $budget -is [bool] -or -not ($budget -is [ValueType]) -or [int]$budget -lt 0) { Add-ValidationError 'collection_controls.paid_query_budget must be a non-negative number' }
    if (-not (Has-Array $controls 'paid_query_ledger' $true)) { Add-ValidationError 'collection_controls.paid_query_ledger must be an array' }
  }
}

$roeFile = Join-Path $caseRoot 'roe.md'
if (Test-Path -LiteralPath $roeFile -PathType Leaf) {
  $roe = Get-Content -LiteralPath $roeFile -Raw
  foreach ($marker in @('Target', 'Scope', 'Authorization timestamp', 'Allowed collection types', 'Prohibited activity', 'User confirmation')) { if ($roe -notmatch [regex]::Escape($marker)) { Add-ValidationError "roe.md is missing authorization section: $marker" } }
  if ($roe -notmatch '(?i)legal authority|legitimate lawful basis') { Add-ValidationError 'roe.md lacks lawful-authority acknowledgement' }
}

$sources = Read-JsonLines 'sources.jsonl' 'sources.jsonl'
Test-UniqueIds $sources 'source_id' 'sources.jsonl'
$sourceIds = @($sources | ForEach-Object { [string](Get-Property $_ 'source_id') } | Where-Object { $_ })
foreach ($source in $sources) {
  foreach ($field in @('source_id', 'provider', 'tool', 'retrieved_at_utc', 'raw_evidence_path', 'content_hash', 'reliability', 'notes')) { if (-not (Has-Text $source $field)) { Add-ValidationError "Source is missing required field: $field" } }
  if ((Has-Text $source 'retrieved_at_utc') -and -not (Test-UtcTimestamp (Get-Property $source 'retrieved_at_utc'))) { Add-ValidationError 'Source has an invalid UTC retrieval timestamp' }
  $resolvedSource = $null
  if (Has-Text $source 'raw_evidence_path') {
    $resolvedSource = Resolve-CasePath ([string](Get-Property $source 'raw_evidence_path')) 'Source evidence path'
    if ($null -ne $resolvedSource -and -not (Test-Path -LiteralPath $resolvedSource -PathType Leaf)) { Add-ValidationError 'Source evidence file does not exist' }
  }
  if ((Has-Text $source 'content_hash') -and -not (Test-Sha256 ([string](Get-Property $source 'content_hash')))) { Add-ValidationError 'Source content_hash must be sha256 followed by 64 hexadecimal characters' }
  if ((Has-Text $source 'content_hash') -and $null -ne $resolvedSource -and (Test-Path -LiteralPath $resolvedSource -PathType Leaf) -and (Test-Sha256 ([string](Get-Property $source 'content_hash')))) {
    $actual = 'sha256:' + (Get-FileHash -LiteralPath $resolvedSource -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne ([string](Get-Property $source 'content_hash')).ToLowerInvariant()) { Add-ValidationError 'Source content_hash does not match its evidence file' }
  }
}

$findings = Read-JsonLines 'findings.jsonl' 'findings.jsonl'
Test-UniqueIds $findings 'finding_id' 'findings.jsonl'
$classifications = @('observed', 'derived', 'assessment', 'hypothesis', 'unknown')
$confidenceLevels = @('high', 'medium', 'low')
foreach ($finding in $findings) {
  foreach ($field in @('finding_id', 'case_id', 'timestamp_utc', 'agent', 'statement', 'classification', 'confidence', 'confidence_score', 'tool', 'evidence_path', 'rationale', 'notes')) { if (-not (Has-Text $finding $field)) { Add-ValidationError "Finding is missing required field: $field" } }
  if ((Has-Text $finding 'case_id') -and $null -ne $case -and [string](Get-Property $finding 'case_id') -ne [string](Get-Property $case 'case_id')) { Add-ValidationError 'Finding case_id does not match case.json' }
  if ((Has-Text $finding 'classification') -and $classifications -notcontains [string](Get-Property $finding 'classification')) { Add-ValidationError 'Finding has an invalid classification' }
  if ((Has-Text $finding 'confidence') -and $confidenceLevels -notcontains [string](Get-Property $finding 'confidence')) { Add-ValidationError 'Finding has an invalid confidence value' }
  $score = Get-Property $finding 'confidence_score'
  if ($null -eq $score -or $score -is [bool] -or -not ($score -is [ValueType]) -or [double]$score -lt 0 -or [double]$score -gt 1) { Add-ValidationError 'Finding confidence_score must be a number from 0 to 1' }
  if ((Has-Text $finding 'timestamp_utc') -and -not (Test-UtcTimestamp (Get-Property $finding 'timestamp_utc'))) { Add-ValidationError 'Finding has an invalid UTC timestamp' }
  $isUnknown = [string](Get-Property $finding 'classification') -eq 'unknown'
  Test-References $finding 'source_ids' $sourceIds 'Finding' (-not $isUnknown)
  if ($isUnknown -and (Has-Array $finding 'source_ids' $true)) { Test-References $finding 'source_ids' $sourceIds 'Finding' $false }
  if (Has-Text $finding 'evidence_path') {
    $resolvedFinding = Resolve-CasePath ([string](Get-Property $finding 'evidence_path')) 'Finding evidence path'
    if ($null -ne $resolvedFinding -and -not (Test-Path -LiteralPath $resolvedFinding -PathType Leaf)) { Add-ValidationError 'Finding evidence file does not exist' }
  }
}

$entities = Read-JsonLines 'entities.jsonl' 'entities.jsonl'
Test-UniqueIds $entities 'entity_id' 'entities.jsonl'
$entityIds = @($entities | ForEach-Object { [string](Get-Property $_ 'entity_id') } | Where-Object { $_ })
foreach ($entity in $entities) {
  foreach ($field in @('entity_id', 'case_id', 'type', 'confidence')) { if (-not (Has-Text $entity $field)) { Add-ValidationError "Entity is missing required field: $field" } }
  if (-not (Has-Array $entity 'source_ids')) { Add-ValidationError 'Entity must have supporting source_ids' } else { Test-References $entity 'source_ids' $sourceIds 'Entity' $true }
  if ((Has-Text $entity 'case_id') -and $null -ne $case -and [string](Get-Property $entity 'case_id') -ne [string](Get-Property $case 'case_id')) { Add-ValidationError 'Entity case_id does not match case.json' }
  if ((Has-Text $entity 'confidence') -and $confidenceLevels -notcontains [string](Get-Property $entity 'confidence')) { Add-ValidationError 'Entity has an invalid confidence value' }
}

$relationships = Read-JsonLines 'relationships.jsonl' 'relationships.jsonl'
Test-UniqueIds $relationships 'relationship_id' 'relationships.jsonl'
foreach ($relationship in $relationships) {
  foreach ($field in @('relationship_id', 'case_id', 'from_entity_id', 'relationship', 'to_entity_id', 'confidence', 'rationale')) { if (-not (Has-Text $relationship $field)) { Add-ValidationError "Relationship is missing required field: $field" } }
  if (-not (Has-Array $relationship 'source_ids')) { Add-ValidationError 'Relationship must have supporting source_ids' } else { Test-References $relationship 'source_ids' $sourceIds 'Relationship' $true }
  if ((Has-Text $relationship 'from_entity_id') -and $entityIds -notcontains [string](Get-Property $relationship 'from_entity_id')) { Add-ValidationError 'Relationship references an unknown source entity' }
  if ((Has-Text $relationship 'to_entity_id') -and $entityIds -notcontains [string](Get-Property $relationship 'to_entity_id')) { Add-ValidationError 'Relationship references an unknown target entity' }
  if ((Has-Text $relationship 'case_id') -and $null -ne $case -and [string](Get-Property $relationship 'case_id') -ne [string](Get-Property $case 'case_id')) { Add-ValidationError 'Relationship case_id does not match case.json' }
  if ((Has-Text $relationship 'confidence') -and $confidenceLevels -notcontains [string](Get-Property $relationship 'confidence')) { Add-ValidationError 'Relationship has an invalid confidence value' }
}

$timeline = Read-JsonLines 'timeline.jsonl' 'timeline.jsonl'
Test-UniqueIds $timeline 'event_id' 'timeline.jsonl'
foreach ($event in $timeline) {
  foreach ($field in @('event_id', 'case_id', 'timestamp_utc', 'classification', 'description')) { if (-not (Has-Text $event $field)) { Add-ValidationError "Timeline event is missing required field: $field" } }
  if ((Has-Text $event 'timestamp_utc') -and -not (Test-UtcTimestamp (Get-Property $event 'timestamp_utc'))) { Add-ValidationError 'Timeline event has an invalid UTC timestamp' }
  if (Has-Array $event 'source_ids' $true) { Test-References $event 'source_ids' $sourceIds 'Timeline event' $false }
  if (Has-Array $event 'evidence_paths' $true) { foreach ($path in @(Get-Property $event 'evidence_paths')) { $resolvedTimeline = Resolve-CasePath ([string]$path) 'Timeline evidence path'; if ($null -ne $resolvedTimeline -and -not (Test-Path -LiteralPath $resolvedTimeline -PathType Leaf)) { Add-ValidationError 'Timeline evidence file does not exist' } } }
}

$audit = Read-JsonLines 'audit/tool-invocations.jsonl' 'audit/tool-invocations.jsonl'
Test-UniqueIds $audit 'invocation_id' 'audit/tool-invocations.jsonl'
foreach ($event in $audit) {
  foreach ($field in @('invocation_id', 'timestamp_utc', 'case_id', 'agent', 'tool_name', 'container', 'container_image_or_digest', 'sanitized_arguments', 'exact_reproducible_command_when_available', 'exit_code', 'duration_ms', 'stdout_sha256', 'stderr_sha256', 'status')) { if (-not (Has-Text $event $field)) { Add-ValidationError "Audit event is missing required field: $field" } }
  if (-not (Has-Array $event 'evidence_files' $true)) { Add-ValidationError 'Audit event evidence_files must be an array' }
  if ((Has-Text $event 'timestamp_utc') -and -not (Test-UtcTimestamp (Get-Property $event 'timestamp_utc'))) { Add-ValidationError 'Audit event has an invalid UTC timestamp' }
  foreach ($hashField in @('stdout_sha256', 'stderr_sha256')) { if ((Has-Text $event $hashField) -and -not (Test-Sha256 ([string](Get-Property $event $hashField)))) { Add-ValidationError "Audit $hashField must be sha256 followed by 64 hexadecimal characters" } }
  foreach ($path in @(Get-Property $event 'evidence_files')) { $resolvedAudit = Resolve-CasePath ([string]$path) 'Audit evidence path'; if ($null -ne $resolvedAudit -and -not (Test-Path -LiteralPath $resolvedAudit -PathType Leaf)) { Add-ValidationError 'Audit evidence file does not exist' } }
}
$paidEvents = @($audit | Where-Object { [string](Get-Property $_ 'provider_type') -eq 'paid' })
if ($null -ne $case) {
  $controls = Get-Property $case 'collection_controls'
  $budgetValue = Get-Property $controls 'paid_query_budget'
  if ($null -ne $budgetValue -and $paidEvents.Count -gt [int]$budgetValue) { Add-ValidationError 'Paid query count exceeds the per-case budget' }
  $fingerprints = @{}
  foreach ($event in $paidEvents) {
    foreach ($field in @('paid_reason', 'paid_provider', 'query_fingerprint', 'paid_approved')) { if (-not (Has-Text $event $field)) { Add-ValidationError "Paid audit event is missing $field" } }
    if ((Get-Property $event 'paid_approved') -ne $true) { Add-ValidationError 'Paid audit event is not approved' }
    $fingerprint = [string](Get-Property $event 'query_fingerprint')
    if ($fingerprint -and $fingerprints.ContainsKey($fingerprint)) { Add-ValidationError 'Duplicate paid query fingerprint detected' } elseif ($fingerprint) { $fingerprints[$fingerprint] = $true }
  }
}

$iocFile = Join-Path $caseRoot 'exports/ioc-bundle.json'
if (Test-Path -LiteralPath $iocFile -PathType Leaf) {
  try { $ioc = Get-Content -LiteralPath $iocFile -Raw | ConvertFrom-Json -NoEnumerate -DateKind String -ErrorAction Stop } catch { $ioc = $null; Add-ValidationError 'IOC bundle is not valid JSON' }
  if ($null -ne $ioc) {
    if (-not (Has-Text $ioc 'case_id')) { Add-ValidationError 'IOC bundle is missing case_id' }
    if (-not (Has-Array $ioc 'iocs' $true)) { Add-ValidationError 'IOC bundle iocs must be an array' }
    $iocItems = Get-Property $ioc 'iocs'
    if ($null -ne $iocItems -and $iocItems.Count -gt 0) { foreach ($item in @($iocItems)) {
      foreach ($field in @('value', 'type', 'first_observed', 'last_observed', 'confidence', 'case_id', 'context')) { if (-not (Has-Text $item $field)) { Add-ValidationError 'IOC is missing a required field' } }
      if (-not (Has-Array $item 'source_ids')) { Add-ValidationError 'IOC must have supporting source_ids' } else { Test-References $item 'source_ids' $sourceIds 'IOC' $true }
      if ((Has-Text $item 'type') -and @('domain', 'hostname', 'ip', 'url', 'hash', 'asn', 'certificate_fingerprint') -notcontains [string](Get-Property $item 'type')) { Add-ValidationError 'IOC has an invalid type' }
      if ((Has-Text $item 'confidence') -and $confidenceLevels -notcontains [string](Get-Property $item 'confidence')) { Add-ValidationError 'IOC has an invalid confidence value' }
      foreach ($timestamp in @('first_observed', 'last_observed')) { if ((Has-Text $item $timestamp) -and -not (Test-UtcTimestamp (Get-Property $item $timestamp))) { Add-ValidationError 'IOC has an invalid UTC observation timestamp' } }
      if ((Has-Text $item 'case_id') -and $null -ne $case -and [string](Get-Property $item 'case_id') -ne [string](Get-Property $case 'case_id')) { Add-ValidationError 'IOC case_id does not match case.json' }
    } }
  }
}

function Test-ProhibitedSecret([string]$Text) {
  $patterns = @(
    '(?i)-----BEGIN\s+(?:RSA|OPENSSH|EC|DSA|PGP)\s+PRIVATE KEY-----',
    '(?i)\b(?:gh[pousr]_|github_pat_|glpat-)[A-Za-z0-9_\-]{20,}',
    '(?i)\bAKIA[0-9A-Z]{16}\b|\bASIA[0-9A-Z]{16}\b',
    '(?i)\b(?:xox[baprs]-|AIza)[A-Za-z0-9_\-]{16,}',
    '(?i)\b(?:sk|rk)_(?:live|test)_[A-Za-z0-9]{16,}\b|\bsk-(?:proj-)?[A-Za-z0-9_\-]{20,}\b',
    '(?i)\b(?:bearer|basic)\s+[A-Za-z0-9+/=_\-.]{20,}',
    '(?i)\beyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}\b',
    '(?i)\b(?:password|passwd|secret|api[_-]?key|access[_-]?token|refresh[_-]?token|session[_-]?(?:id|token)|client[_-]?secret|aws[_-]?secret[_-]?access[_-]?key)\s*[:=]\s*["'']?[A-Za-z0-9_\-/.+=]{12,}'
  )
  foreach ($pattern in $patterns) { if ($Text -match $pattern) { return $true } }
  return $false
}

foreach ($relativePath in @('reports/intelligence-report.md', 'reports/intelligence-report.html', 'audit/tool-invocations.jsonl')) {
  $path = Join-Path $caseRoot $relativePath
  if (Test-Path -LiteralPath $path -PathType Leaf) {
    if (Test-ProhibitedSecret (Get-Content -LiteralPath $path -Raw)) { Add-ValidationError "Prohibited secret material detected in $relativePath; values are intentionally not displayed" }
  }
}
$roeText = if (Test-Path -LiteralPath $roeFile -PathType Leaf) { Get-Content -LiteralPath $roeFile -Raw } else { '' }
if ($null -ne $case) {
  if ($roeText -and $roeText -notmatch [regex]::Escape("Target: $([string](Get-Property $case 'target'))")) { Add-ValidationError 'roe.md target does not match case.json' }
  if ($roeText -and $roeText -notmatch [regex]::Escape("Scope: $([string](Get-Property $case 'scope'))")) { Add-ValidationError 'roe.md scope does not match case.json' }
  $planFile = Join-Path $caseRoot 'collection-plan.md'
  if (Test-Path -LiteralPath $planFile -PathType Leaf) {
    $planText = Get-Content -LiteralPath $planFile -Raw
    if ($planText -notmatch [regex]::Escape([string](Get-Property $case 'target'))) { Add-ValidationError 'collection-plan.md target does not match case.json' }
  }
}
$reportMarkdown = Join-Path $caseRoot 'reports/intelligence-report.md'
if (Test-Path -LiteralPath $reportMarkdown -PathType Leaf) {
  $reportText = Get-Content -LiteralPath $reportMarkdown -Raw
  foreach ($section in @('Executive summary', 'Scope and ROE', 'Key judgments', 'Findings', 'Evidence', 'Timeline', 'Confidence', 'Intelligence gaps', 'What we do not know', 'Methodology', 'Source list')) {
    if ($reportText -notmatch '(?im)^#{1,3}\s+' + [regex]::Escape($section) + '\b') { Add-ValidationError "Report is missing required section: $section" }
  }
  if ($reportText -notmatch '(?i)source[_ ]?id|SRC-') { Add-ValidationError 'Report must contain source citations' }
}
$reportHtml = Join-Path $caseRoot 'reports/intelligence-report.html'
if (Test-Path -LiteralPath $reportHtml -PathType Leaf) {
  $htmlText = Get-Content -LiteralPath $reportHtml -Raw
  if ($htmlText -notmatch '(?i)Executive summary|Scope and ROE|Intelligence gaps|What we do not know|Methodology|Source list') { Add-ValidationError 'HTML report is missing required sections' }
  if ($htmlText -notmatch '(?i)SRC-') { Add-ValidationError 'HTML report must contain source citations' }
}

if ($errors.Count -gt 0) {
  foreach ($message in $errors) { Write-Error $message }
  exit 1
}
Write-Output "PASS case validation: $caseRoot"
