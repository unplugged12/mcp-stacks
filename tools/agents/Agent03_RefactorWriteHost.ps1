# tools/agents/Agent03_RefactorWriteHost.ps1
[CmdletBinding(SupportsShouldProcess)]
param(
  [switch]$Apply,
  [string[]]$Include = @('*.ps1'),
  [string[]]$Exclude = @('scripts\smoke-test.ps1')  # pass 1 excludes smoke-test
)

$branch = 'lint/logging-refactor'
$modulePath = 'scripts\modules\Out.psm1'

$wrapper = @'
Set-StrictMode -Version Latest

function Write-Status {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Message,
    [ValidateSet('Info','Warn','Error','Verbose')][string]$Level = 'Info'
  )
  switch ($Level) {
    'Verbose' { Write-Verbose $Message; return }
    'Warn'    { Write-Warning $Message; return }
    'Error'   { Write-Error $Message; return }
    default   { Write-Information $Message; return }
  }
}
Export-ModuleMember -Function Write-Status
'@

function Ensure-BranchAndModule {
  if (-not (git rev-parse --is-inside-work-tree 2>$null)) { throw "Run from repo root." }
  git checkout -B $branch
  if (-not (Test-Path $modulePath)) {
    New-Item -ItemType Directory -Force -Path (Split-Path $modulePath) | Out-Null
    Set-Content -LiteralPath $modulePath -Value $wrapper -Encoding UTF8
    Write-Host "Added wrapper module: $modulePath"
  }
}

function Get-TargetFiles {
  $all = git ls-files $Include
  if ($Exclude) {
    $ex = $Exclude | ForEach-Object { $_.ToLower() }
    $all = $all | Where-Object { $ex -notcontains $_.ToLower() }
  }
  return $all
}

function Refactor-File {
  param($path)
  $text = Get-Content -LiteralPath $path -Raw
  $orig = $text

  # Ensure module import once near top if we touch the file
  $touched = $false

  # Replace simple Write-Host "msg" -> Write-Status -Level Info -Message "msg"
  $text = [regex]::Replace($text,
    '(?m)^\s*Write-Host\s+("?)([^"\r\n]+)\1\s*$',
    { param($m) $script:touched = $true; "Write-Status -Level Info -Message $($m.Groups[1].Value)$($m.Groups[2].Value)$($m.Groups[1].Value)" })

  # Replace Write-Host with interpolated text or parameters -> crude but safe fallback
  $text = $text -replace '(?m)^\s*Write-Host\b', { $script:touched = $true; 'Write-Status -Level Info -Message' }

  if ($touched -and $text -notmatch '(?m)^\s*Import-Module\s+\.\\scripts\\modules\\Out\.psm1\b') {
    $text = "Import-Module .\scripts\modules\Out.psm1`r`n" + $text
  }

  if ($text -ne $orig) {
    Write-Host "Would update: $path"
    if ($Apply) {
      Set-Content -LiteralPath $path -Value $text -Encoding UTF8
    }
  }
}

Ensure-BranchAndModule
Get-TargetFiles | ForEach-Object { Refactor-File $_ }

if ($Apply) {
  git add .
  git commit -m "lint: replace Write-Host with Write-Status wrapper (Information/Verbose-safe)"
  Write-Host "Branch ready: $branch"
} else {
  Write-Host "Dry run complete. Re-run with -Apply to write changes."
}
