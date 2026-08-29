Set-StrictMode -Version Latest

function Protect-SensitiveOutput {
  param([AllowNull()][string]$Text)
  if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
  $safe = $Text
  $patterns = @(
    @{ Pattern = '(?i)(api[_-]?key|secret|token|password|authorization|cookie|private[_-]?key)(\s*[:=]\s*)(["'']?)[^\s,;"'']+'; Replacement = '$1$2$3[REDACTED]' },
    @{ Pattern = '(?i)(https?://)([^/@\s]+):([^/@\s]+)@'; Replacement = '$1[REDACTED]@' },
    @{ Pattern = '(?i)\b(?:gh[pousr]_|github_pat_|glpat-)[A-Za-z0-9_\-]{12,}'; Replacement = '[REDACTED-GIT-TOKEN]' },
    @{ Pattern = '(?i)\b(?:AKIA|ASIA)[0-9A-Z]{16}\b'; Replacement = '[REDACTED-AWS-KEY]' },
    @{ Pattern = '(?i)\b(?:xox[baprs]-|AIza)[A-Za-z0-9_\-]{16,}'; Replacement = '[REDACTED-PROVIDER-TOKEN]' },
    @{ Pattern = '(?i)\b(?:bearer|basic)\s+[A-Za-z0-9+/=_\-.]{20,}'; Replacement = '$1 [REDACTED]' },
    @{ Pattern = '(?i)\beyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}\b'; Replacement = '[REDACTED-JWT]' },
    @{ Pattern = '(?i)-----BEGIN\s+(?:RSA|OPENSSH|EC|DSA|PGP)\s+PRIVATE KEY-----[\s\S]*?-----END\s+(?:RSA|OPENSSH|EC|DSA|PGP)\s+PRIVATE KEY-----'; Replacement = '[REDACTED-PRIVATE-KEY]' }
  )
  foreach ($item in $patterns) { $safe = [regex]::Replace($safe, $item.Pattern, $item.Replacement) }
  return $safe.Trim()
}
