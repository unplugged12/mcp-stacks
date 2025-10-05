# tools/agents/Agent01_FixAutomaticVars.ps1
[CmdletBinding(SupportsShouldProcess)]
param(
  [switch]$Apply
)

$branch = 'lint/auto-var-sanitizer'
$patterns = @(
  # Assignments to automatic variables that should never be assigned.
  # Start conservative: $error =
  @{ Name = 'error';  Regex = '(^|\s)(\$error)\s*='; Replacement = '$errMsg ='; Scope='line' }
)

function Ensure-Branch {
  if (-not (git rev-parse --is-inside-work-tree 2>$null)) { throw "Run from repo root." }
  git checkout -B $branch
}

function Get-TargetFiles {
  # Start with the known failing file and then scan the repo in case others exist.
  $files = git ls-files '*.ps1'
  return $files
}

function Process-File {
  param($path)
  $text = Get-Content -LiteralPath $path -Raw
  $orig = $text
  foreach ($p in $patterns) {
    $text = [System.Text.RegularExpressions.Regex]::Replace(
      $text, $p.Regex, { param($m) $m.Value -replace [regex]::Escape($m.Groups[2].Value), $p.Replacement },
      [System.Text.RegularExpressions.RegexOptions]::Multiline
    )
  }
  if ($text -ne $orig) {
    Write-Host "Would update: $path"
    if ($Apply) {
      Set-Content -LiteralPath $path -Value $text -Encoding UTF8
    }
  }
}

Ensure-Branch
Get-TargetFiles | ForEach-Object { Process-File $_ }

if ($Apply) {
  git add .
  git commit -m "lint: avoid assignment to automatic vars (e.g., $error) per PSSA"
  Write-Host "Branch ready: $branch"
} else {
  Write-Host "Dry run complete. Re-run with -Apply to write changes."
}
