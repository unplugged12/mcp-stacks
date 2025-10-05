#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Run MCP Stacks test suite with Pester
.DESCRIPTION
    Executes unit and/or integration tests with optional code coverage reporting.
    Requires Pester v5+ to be installed.
.PARAMETER TestType
    Type of tests to run: 'Unit', 'Integration', or 'All' (default: All)
.PARAMETER CodeCoverage
    Generate code coverage report
.PARAMETER OutputFormat
    Output format: 'Detailed', 'Minimal', 'Diagnostic' (default: Detailed)
.PARAMETER CI
    Run in CI mode with JUnit XML output
.EXAMPLE
    .\run-tests.ps1
.EXAMPLE
    .\run-tests.ps1 -TestType Unit -CodeCoverage
.EXAMPLE
    .\run-tests.ps1 -CI
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Unit', 'Integration', 'All')]
    [string]$TestType = 'All',

    [Parameter()]
    [switch]$CodeCoverage,

    [Parameter()]
    [ValidateSet('Detailed', 'Minimal', 'Diagnostic')]
    [string]$OutputFormat = 'Detailed',

    [Parameter()]
    [switch]$CI
)

$ErrorActionPreference = "Stop"

# Colors
$cyan = [ConsoleColor]::Cyan
$green = [ConsoleColor]::Green
$yellow = [ConsoleColor]::Yellow
$red = [ConsoleColor]::Red

Write-Host "🧪 MCP Stacks Test Suite" -ForegroundColor $cyan
Write-Host "=========================" -ForegroundColor $cyan
Write-Host ""

# Check Pester installation
try {
    $pesterVersion = (Get-Module -ListAvailable Pester | Sort-Object Version -Descending | Select-Object -First 1).Version
    if ($pesterVersion.Major -lt 5) {
        Write-Host "⚠️  Pester v5+ required. Current version: $pesterVersion" -ForegroundColor $yellow
        Write-Host "Install with: Install-Module -Name Pester -Force -SkipPublisherCheck" -ForegroundColor $yellow
        exit 1
    }
    Write-Host "✓ Pester $pesterVersion detected" -ForegroundColor $green
} catch {
    Write-Host "✗ Pester not installed" -ForegroundColor $red
    Write-Host "Install with: Install-Module -Name Pester -Force -SkipPublisherCheck" -ForegroundColor $yellow
    exit 1
}

# Paths
$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Split-Path -Parent $scriptDir
$testsDir = Join-Path $repoRoot "tests"
$outputDir = Join-Path $repoRoot "TestResults"

# Create output directory
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

# Determine test paths
$testPaths = @()
switch ($TestType) {
    'Unit' {
        $testPaths += Join-Path $testsDir "unit"
        Write-Host "Test Type: Unit tests only" -ForegroundColor $yellow
    }
    'Integration' {
        $testPaths += Join-Path $testsDir "integration"
        Write-Host "Test Type: Integration tests only" -ForegroundColor $yellow
    }
    'All' {
        $testPaths += Join-Path $testsDir "unit"
        $testPaths += Join-Path $testsDir "integration"
        Write-Host "Test Type: All tests (Unit + Integration)" -ForegroundColor $yellow
    }
}

Write-Host "Coverage: $(if ($CodeCoverage) { 'Enabled' } else { 'Disabled' })" -ForegroundColor $yellow
Write-Host "Output: $OutputFormat" -ForegroundColor $yellow
Write-Host ""

# Build Pester configuration
$pesterConfig = @{
    Run = @{
        Path = $testPaths
        PassThru = $true
    }
    Output = @{
        Verbosity = $OutputFormat
    }
}

# Add code coverage if requested
if ($CodeCoverage) {
    $pesterConfig.CodeCoverage = @{
        Enabled = $true
        Path = @(
            (Join-Path $repoRoot "scripts" "*.ps1"),
            (Join-Path $repoRoot "scripts" "**" "*.ps1")
        )
        OutputFormat = 'JaCoCo'
        OutputPath = Join-Path $outputDir "coverage.xml"
    }
}

# CI mode: Add JUnit XML output
if ($CI) {
    $pesterConfig.TestResult = @{
        Enabled = $true
        OutputFormat = 'JUnitXml'
        OutputPath = Join-Path $outputDir "test-results.xml"
    }
    Write-Host "CI Mode: Enabled (JUnit XML output)" -ForegroundColor $yellow
    Write-Host ""
}

# Create Pester configuration object
$config = New-PesterConfiguration -Hashtable $pesterConfig

# Run tests
Write-Host "Running tests..." -ForegroundColor $cyan
Write-Host ""

$result = Invoke-Pester -Configuration $config

# Summary
Write-Host ""
Write-Host "=========================" -ForegroundColor $cyan
Write-Host "Test Summary" -ForegroundColor $cyan
Write-Host "=========================" -ForegroundColor $cyan
Write-Host "Total Tests: $($result.TotalCount)" -ForegroundColor $yellow
Write-Host "Passed: $($result.PassedCount)" -ForegroundColor $green
Write-Host "Failed: $($result.FailedCount)" -ForegroundColor $(if ($result.FailedCount -gt 0) { $red } else { $green })
Write-Host "Skipped: $($result.SkippedCount)" -ForegroundColor $yellow

if ($CodeCoverage -and $result.CodeCoverage) {
    $coverage = $result.CodeCoverage
    $coveredPercent = if ($coverage.CommandsAnalyzed -gt 0) {
        [Math]::Round(($coverage.CommandsExecuted / $coverage.CommandsAnalyzed) * 100, 2)
    } else { 0 }

    Write-Host ""
    Write-Host "Code Coverage:" -ForegroundColor $cyan
    Write-Host "  Commands Analyzed: $($coverage.CommandsAnalyzed)" -ForegroundColor $yellow
    Write-Host "  Commands Executed: $($coverage.CommandsExecuted)" -ForegroundColor $yellow
    Write-Host "  Coverage: $coveredPercent%" -ForegroundColor $(if ($coveredPercent -ge 80) { $green } elseif ($coveredPercent -ge 60) { $yellow } else { $red })
    Write-Host "  Report: $(Join-Path $outputDir 'coverage.xml')" -ForegroundColor $yellow
}

if ($CI) {
    Write-Host ""
    Write-Host "JUnit XML: $(Join-Path $outputDir 'test-results.xml')" -ForegroundColor $yellow
}

Write-Host ""

# Exit with appropriate code
if ($result.FailedCount -gt 0) {
    Write-Host "❌ Tests failed" -ForegroundColor $red
    exit 1
} else {
    Write-Host "✅ All tests passed!" -ForegroundColor $green
    exit 0
}
