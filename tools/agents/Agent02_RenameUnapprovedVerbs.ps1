# tools/agents/Agent02_RenameUnapprovedVerbs.ps1
[CmdletBinding(SupportsShouldProcess)]
param(
  [switch]$Apply
)

$branch = 'lint/approved-verbs'
$renameMap = @{
  'Record-Pass'    = 'Add-TestPass'
  'Record-Fail'    = 'Add-TestFail'
  'Record-Warning' = 'Write-TestWarning'
}
$target = 'scripts\smoke-test.ps1'

function Ensure-Branch {
  if (-not (git rev-parse --is-inside-work-tree 2>$null)) { throw "Run from repo root." }
  git checkout -B $branch
}

function Replace-All {
  param($path, [hashtable]$map)
  $text = Get-Content -LiteralPath $path -Raw
  $orig = $text
  foreach ($k in $map.Keys) {
    # function definitions
    $text = $text -replace "(?m)^\s*function\s+$([regex]::Escape($k))\b", "function $($map[$k])"
    # call sites
    $text = $text -replace "(?<![\w-])$([regex]::Escape($k))\b", $map[$k]
  }
  if ($text -ne $orig) {
    Write-Host "Would update: $path"
    if ($Apply) {
      Set-Content -LiteralPath $path -Value $text -Encoding UTF8
    }
  }
}

Ensure-Branch
if (Test-Path $target) { Replace-All -path $target -map $renameMap }

if ($Apply) {
  git add $target
  git commit -m "lint: rename unapproved verbs -> approved (Add/Write) in smoke-test.ps1"
  Write-Host "Branch ready: $branch"
} else {
  Write-Host "Dry run complete. Re-run with -Apply to write changes."
}
