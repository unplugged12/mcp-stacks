# tools/agents/Agent05_VariableHygiene.ps1
[CmdletBinding(SupportsShouldProcess)]
param(
  [switch]$Apply,
  [ValidateSet('remove','use','suppress')][string]$Mode = 'remove'
)

$branch = 'lint/var-hygiene'
$targets = @('scripts\smoke-test.ps1') # expand if more files pop

function Ensure-Branch {
  if (-not (git rev-parse --is-inside-work-tree 2>$null)) { throw "Run from repo root." }
  git checkout -B $branch
}

function Clean-File {
  param($path)
  $text = Get-Content -LiteralPath $path -Raw
  $orig = $text

  switch ($Mode) {
    'remove' {
      # Remove simple "expectedPort = ..." assignment line if not referenced elsewhere
      if ($text -match '(?m)^\s*\$expectedPort\s*=') {
        if ($text -notmatch '(?m)\$expectedPort[^\s=]') {
          $text = $text -replace '(?m)^\s*\$expectedPort\s*=.*\r?\n', ''
        }
      }
    }
    'use' {
      # Convert to intentional use (logs it once)
      if ($text -match '(?m)^\s*\$expectedPort\s*=\s*(.+)$') {
        if ($text -notmatch '(?m)\$expectedPort[^\s=]') {
          $text = $text -replace '(?m)^\s*\$expectedPort\s*=\s*(.+)$', '$expectedPort = $1' + "`r`n" + 'Write-Status -Level Verbose -Message "expectedPort=$expectedPort"'
          if ($text -notmatch '(?m)^\s*Import-Module\s+\.\\scripts\\modules\\Out\.psm1\b') {
            $text = "Import-Module .\scripts\modules\Out.psm1`r`n" + $text
          }
        }
      }
    }
    'suppress' {
      # Add a targeted suppression if the assignment is truly a placeholder
      $supp = "[Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssignments','Justification=""Placeholder for future checks""')]"
      if ($text -notmatch [regex]::Escape($supp)) {
        $text = $supp + "`r`n" + $text
      }
    }
  }

  if ($text -ne $orig) {
    Write-Host "Would update: $path"
    if ($Apply) {
      Set-Content -LiteralPath $path -Value $text -Encoding UTF8
    }
  }
}

Ensure-Branch
$targets | Where-Object { Test-Path $_ } | ForEach-Object { Clean-File $_ }

if ($Apply) {
  git add .
  git commit -m "lint: resolve declared-but-unused variables per PSUseDeclaredVarsMoreThanAssignments"
  Write-Host "Branch ready: $branch"
} else {
  Write-Host "Dry run complete. Re-run with -Apply to write changes."
}
