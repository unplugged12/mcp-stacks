# tools/agents/Agent04_NormalizeEncoding.ps1
[CmdletBinding(SupportsShouldProcess)]
param(
  [switch]$Apply
)

$branch = 'lint/encoding'

function Ensure-Branch {
  if (-not (git rev-parse --is-inside-work-tree 2>$null)) { throw "Run from repo root." }
  git checkout -B $branch
}

function Has-NonAscii {
  param([string]$Content)
  foreach ($ch in $Content.ToCharArray()) {
    if ([int][char]$ch -gt 127) { return $true }
  }
  return $false
}

function Set-Utf8Bom {
  param($path, $content)
  $enc = New-Object System.Text.UTF8Encoding($true) # BOM = true
  [System.IO.File]::WriteAllText((Resolve-Path $path), $content, $enc)
}

Ensure-Branch
$files = git ls-files '*.ps1'
foreach ($f in $files) {
  $c = Get-Content -LiteralPath $f -Raw
  if (Has-NonAscii $c) {
    Write-Host "Would re-encode as UTF8-BOM: $f"
    if ($Apply) { Set-Utf8Bom -path $f -content $c }
  }
}

if ($Apply) {
  git add .
  git commit -m "lint: normalize encoding to UTF-8 BOM for non-ASCII files to satisfy PSSA"
  Write-Host "Branch ready: $branch"
} else {
  Write-Host "Dry run complete. Re-run with -Apply to write changes."
}
