[CmdletBinding()]
param(
    [ValidateSet('All', 'FormatCheck', 'FormatFix', 'Analyze')]
    [string]$Mode = 'All',

    [switch]$UpdateWarningBaseline,

    [switch]$FailOnNewWarnings
)

$ErrorActionPreference = 'Stop'

function Ensure-PSScriptAnalyzer {
    if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
        Write-Host 'Installing PSScriptAnalyzer module...' -ForegroundColor Yellow
        Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser | Out-Null
    }

    if (-not (Get-Module -Name PSScriptAnalyzer)) {
        Import-Module -Name PSScriptAnalyzer -Force
    }
}

function Get-RepositoryRoot {
    $scriptRoot = if ($PSScriptRoot) {
        $PSScriptRoot
    }
    elseif ($PSCommandPath) {
        Split-Path -Path $PSCommandPath -Parent
    }
    elseif ($MyInvocation.MyCommand.Path) {
        Split-Path -Path $MyInvocation.MyCommand.Path -Parent
    }
    else {
        throw 'Unable to determine lint.ps1 location.'
    }

    $rootPath = Join-Path -Path $scriptRoot -ChildPath '..'
    return (Resolve-Path -Path $rootPath).Path
}

function Get-FormatterTargets {
    param(
        [string]$Root
    )

    $patterns = @('*.ps1', '*.psm1', '*.psd1')
    return Get-ChildItem -Path $Root -Recurse -File -Include $patterns
}

function Invoke-FormatCheck {
    param(
        [string]$Root,
        [string]$SettingsPath,
        [switch]$Apply
    )

    $targets = Get-FormatterTargets -Root $Root
    $needsFormatting = @()

    foreach ($file in $targets) {
        $original = Get-Content -Path $file.FullName -Raw
        $formatted = Invoke-Formatter -ScriptDefinition $original -Settings $SettingsPath

        if ($formatted -ne $original) {
            if ($Apply.IsPresent) {
                Set-Content -Path $file.FullName -Value $formatted -Encoding UTF8
                Write-Host "Formatted ${file}" -ForegroundColor Green
            }
            else {
                $needsFormatting += $file.FullName
            }
        }
    }

    if (-not $Apply.IsPresent -and $needsFormatting.Count -gt 0) {
        foreach ($file in $needsFormatting) {
            Write-Host "::notice::Invoke-Formatter would update '$file'" -ForegroundColor Yellow
        }
        throw "Formatting required for $($needsFormatting.Count) file(s)."
    }

    if (-not $Apply.IsPresent) {
        Write-Host '✓ All PowerShell sources are properly formatted.'
    }
}

function ConvertTo-WarningBaselineKey {
    param(
        [Parameter(Mandatory)]
        $Diagnostic
    )

    return '{0}|{1}|{2}' -f $Diagnostic.RuleName, ($Diagnostic.ScriptPath ?? ''), ($Diagnostic.Line ?? 0)
}

function Load-WarningBaseline {
    param(
        [string]$BaselinePath
    )

    if (-not (Test-Path -Path $BaselinePath)) {
        return @{}
    }

    $raw = Get-Content -Path $BaselinePath -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return @{}
    }

    $data = $raw | ConvertFrom-Json
    if ($null -eq $data) {
        return @{}
    }

    $map = @{}
    foreach ($item in $data) {
        $key = '{0}|{1}|{2}' -f $item.RuleName, ($item.ScriptPath ?? ''), ($item.Line ?? 0)
        $map[$key] = $true
    }

    return $map
}

function Save-WarningBaseline {
    param(
        [string]$BaselinePath,
        $Diagnostics
    )

    $payload = $Diagnostics |
        Sort-Object RuleName, ScriptPath, Line |
        Select-Object RuleName, ScriptPath, Line, Message |
        ConvertTo-Json -Depth 3

    Set-Content -Path $BaselinePath -Value $payload
}

function Invoke-PowerShellAnalyzer {
    param(
        [string]$Root,
        [string]$SettingsPath,
        [string]$BaselinePath,
        [switch]$UpdateBaseline,
        [switch]$FailOnNewWarnings
    )

    $results = Invoke-ScriptAnalyzer -Path $Root -Recurse -Settings $SettingsPath -ReportSummary

    if ($results) {
        $results |
            Sort-Object Severity, ScriptPath, Line |
            Select-Object Severity, RuleName, ScriptPath, Line, Message |
            Format-Table -AutoSize | Out-String | Write-Host
    }
    else {
        Write-Host '✓ Invoke-ScriptAnalyzer returned no diagnostics.'
    }

    $errors = @()
    $warnings = @()

    foreach ($diagnostic in $results) {
        switch ($diagnostic.Severity) {
            'Error' { $errors += $diagnostic }
            'Warning' { $warnings += $diagnostic }
        }
    }

    if ($UpdateBaseline) {
        if ($warnings.Count -gt 0) {
            Write-Host "Updating warning baseline at $BaselinePath" -ForegroundColor Yellow
            Save-WarningBaseline -BaselinePath $BaselinePath -Diagnostics $warnings
        }
        elseif (Test-Path -Path $BaselinePath) {
            Write-Host "No warnings found; removing existing baseline at $BaselinePath" -ForegroundColor Yellow
            Remove-Item -Path $BaselinePath
        }
    }

    $newWarnings = @()
    $baselineExists = Test-Path -Path $BaselinePath
    if ($warnings.Count -gt 0 -and $baselineExists) {
        $existingKeys = Load-WarningBaseline -BaselinePath $BaselinePath
        foreach ($warning in $warnings) {
            $key = ConvertTo-WarningBaselineKey -Diagnostic $warning
            if (-not $existingKeys.ContainsKey($key)) {
                $newWarnings += $warning
            }
        }
    }
    elseif ($FailOnNewWarnings -and -not $baselineExists) {
        Write-Host 'Warning baseline not found; skipping new-warning enforcement.' -ForegroundColor Yellow
    }

    if ($errors.Count -gt 0) {
        throw "PSScriptAnalyzer reported $($errors.Count) error(s)."
    }

    if ($FailOnNewWarnings -and $newWarnings.Count -gt 0) {
        $details = $newWarnings |
            Select-Object RuleName, ScriptPath, Line, Message |
            Format-Table -AutoSize | Out-String
        throw "New warning diagnostics detected:\n$details"
    }

    if ($warnings.Count -gt 0) {
        Write-Host "Warnings detected: $($warnings.Count)" -ForegroundColor Yellow
        if ($newWarnings.Count -eq 0 -and $FailOnNewWarnings) {
            Write-Host 'All warnings are part of the established baseline.' -ForegroundColor Yellow
        }
    }
}

Ensure-PSScriptAnalyzer
$repoRoot = Get-RepositoryRoot
$settingsPath = Join-Path -Path $repoRoot -ChildPath '.PSScriptAnalyzerSettings.psd1'
$baselinePath = Join-Path -Path $repoRoot -ChildPath '.pssa-warning-baseline.json'

switch ($Mode) {
    'FormatFix' {
        Invoke-FormatCheck -Root $repoRoot -SettingsPath $settingsPath -Apply
    }
    'FormatCheck' {
        Invoke-FormatCheck -Root $repoRoot -SettingsPath $settingsPath
    }
    'Analyze' {
        Invoke-PowerShellAnalyzer -Root $repoRoot -SettingsPath $settingsPath -BaselinePath $baselinePath -UpdateBaseline:$UpdateWarningBaseline.IsPresent -FailOnNewWarnings:$FailOnNewWarnings.IsPresent
    }
    Default {
        Invoke-FormatCheck -Root $repoRoot -SettingsPath $settingsPath
        Invoke-PowerShellAnalyzer -Root $repoRoot -SettingsPath $settingsPath -BaselinePath $baselinePath -UpdateBaseline:$UpdateWarningBaseline.IsPresent -FailOnNewWarnings:$FailOnNewWarnings.IsPresent
    }
}
