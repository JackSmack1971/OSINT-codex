Set-StrictMode -Version Latest

function Get-CaseProperty {
  param($Object, [string]$Name)
  if ($null -eq $Object) { return $null }
  if ($Object -is [System.Collections.IDictionary]) {
    if ($Object.Contains($Name)) { return $Object[$Name] }
    return $null
  }
  $property = $Object.PSObject.Properties[$Name]
  if ($null -eq $property) { return $null }
  return $property.Value
}

function Test-UtcAuthorizationTimestamp {
  param($Value)
  $parsed = [DateTimeOffset]::MinValue
  return $null -ne $Value -and [DateTimeOffset]::TryParse(
    [string]$Value,
    [Globalization.CultureInfo]::InvariantCulture,
    [Globalization.DateTimeStyles]::RoundtripKind,
    [ref]$parsed
  ) -and $parsed.Offset -eq [TimeSpan]::Zero
}

function Get-CaseAuthorizationStatus {
  param(
    $Case,
    [string]$ExpectedCaseId,
    [string]$ExpectedTarget,
    [string]$ExpectedScope,
    [switch]$AllowSyntheticDryRun
  )

  $errors = [System.Collections.Generic.List[string]]::new()
  $authorization = Get-CaseProperty $Case 'authorization'
  $state = [string](Get-CaseProperty $authorization 'state')
  $caseId = [string](Get-CaseProperty $Case 'case_id')
  $authCaseId = [string](Get-CaseProperty $authorization 'case_id')
  $target = [string](Get-CaseProperty $Case 'target')
  $authTarget = [string](Get-CaseProperty $authorization 'target')
  $scope = [string](Get-CaseProperty $Case 'scope')
  $authScope = [string](Get-CaseProperty $authorization 'scope')
  $confirmation = [string](Get-CaseProperty $authorization 'confirmation')
  $validFrom = Get-CaseProperty $authorization 'valid_from_utc'
  $validUntil = Get-CaseProperty $authorization 'valid_until_utc'
  $allowed = @(Get-CaseProperty $authorization 'allowed_collection_types')
  $prohibited = @(Get-CaseProperty $authorization 'prohibited_activity')

  if ([string]::IsNullOrWhiteSpace($caseId)) { [void]$errors.Add('case_id is required') }
  if ([string]::IsNullOrWhiteSpace($target)) { [void]$errors.Add('target is required') }
  if ([string]::IsNullOrWhiteSpace($scope)) { [void]$errors.Add('scope is required') }
  if ($null -eq $authorization) { [void]$errors.Add('structured authorization is required') }
  if ($state -eq 'synthetic-dry-run' -and -not $AllowSyntheticDryRun) { [void]$errors.Add('synthetic authorization is valid only for a dry run') }
  elseif ($state -ne 'authorized' -and $state -ne 'synthetic-dry-run') { [void]$errors.Add('authorization.state must be authorized') }
  if ($state -eq 'synthetic-dry-run') {
    if ((Get-CaseProperty $Case 'test') -ne $true -or (Get-CaseProperty $Case 'dry_run_requested') -ne $true) { [void]$errors.Add('synthetic authorization requires an explicitly labeled dry-run case') }
    if (@($allowed | Where-Object { [string]$_ -match '(?i)network|https?://|dns|http' }).Count -gt 0) { [void]$errors.Add('synthetic authorization cannot permit network collection') }
  }
  if ($authCaseId -ne $caseId) { [void]$errors.Add('authorization.case_id does not match case_id') }
  if ($authTarget -ne $target) { [void]$errors.Add('authorization.target does not match target') }
  if ($authScope -ne $scope) { [void]$errors.Add('authorization.scope does not match scope') }
  if ([string](Get-CaseProperty $Case 'authorization_timestamp_utc') -ne [string]$validFrom) { [void]$errors.Add('authorization_timestamp_utc does not match authorization.valid_from_utc') }
  if ($ExpectedCaseId -and $caseId -ne $ExpectedCaseId) { [void]$errors.Add('case_id does not match the active case') }
  if ($ExpectedTarget -and $target -ne $ExpectedTarget) { [void]$errors.Add('target does not match the requested target') }
  if ($ExpectedScope -and $scope -ne $ExpectedScope) { [void]$errors.Add('scope does not match the requested scope') }
  if ($confirmation -ne 'I confirm that I have legal authority or a legitimate lawful basis to conduct passive OSINT collection against this target and will comply with applicable law and terms of service.') { [void]$errors.Add('authorization.confirmation is missing the required acknowledgement') }
  if (-not (Test-UtcAuthorizationTimestamp $validFrom)) { [void]$errors.Add('authorization.valid_from_utc must be UTC') }
  if (-not (Test-UtcAuthorizationTimestamp $validUntil)) { [void]$errors.Add('authorization.valid_until_utc must be UTC') }
  if ((Test-UtcAuthorizationTimestamp $validFrom) -and (Test-UtcAuthorizationTimestamp $validUntil) -and ([DateTimeOffset]$validUntil -le [DateTimeOffset]$validFrom)) { [void]$errors.Add('authorization validity window is empty') }
  if ((Test-UtcAuthorizationTimestamp $validUntil) -and ([DateTimeOffset]$validUntil -lt [DateTimeOffset]::UtcNow) -and $state -eq 'authorized') { [void]$errors.Add('authorization is expired') }
  if ($null -eq $allowed -or $allowed -is [string] -or @($allowed).Count -eq 0) { [void]$errors.Add('authorization.allowed_collection_types must be non-empty') }
  if ($null -eq $prohibited -or $prohibited -is [string] -or @($prohibited).Count -eq 0) { [void]$errors.Add('authorization.prohibited_activity must be non-empty') }

  [pscustomobject]@{ Valid = $errors.Count -eq 0; CaseId = $caseId; Target = $target; Scope = $scope; State = $state; Errors = @($errors) }
}

function Assert-CaseAuthorization {
  param(
    $Case,
    [string]$ExpectedCaseId,
    [string]$ExpectedTarget,
    [string]$ExpectedScope,
    [switch]$AllowSyntheticDryRun
  )
  $status = Get-CaseAuthorizationStatus @PSBoundParameters
  if (-not $status.Valid) { throw ('Authorization denied: ' + ($status.Errors -join '; ')) }
  return $status
}

function Assert-PaidQueryAllowed {
  param($Case, [string]$Provider, [string]$Reason, [string]$QueryFingerprint)
  $controls = Get-CaseProperty $Case 'collection_controls'
  $budget = Get-CaseProperty $controls 'paid_query_budget'
  $ledger = @(Get-CaseProperty $controls 'paid_query_ledger')
  if ([string]::IsNullOrWhiteSpace($Provider) -or [string]::IsNullOrWhiteSpace($Reason) -or [string]::IsNullOrWhiteSpace($QueryFingerprint)) { throw 'Paid query denied: provider, reason, and query fingerprint are required' }
  if ($null -eq $budget -or [int]$budget -le 0) { throw 'Paid query denied: no paid-query budget is approved for this case' }
  if ($ledger.Count -ge [int]$budget) { throw 'Paid query denied: per-case paid-query budget is exhausted' }
  if (@($ledger | Where-Object { [string](Get-CaseProperty $_ 'query_fingerprint') -eq $QueryFingerprint }).Count -gt 0) { throw 'Paid query denied: equivalent query fingerprint already exists in this case' }
  return [pscustomobject]@{ provider = $Provider; reason = $Reason; query_fingerprint = $QueryFingerprint; paid_approved = $true }
}
