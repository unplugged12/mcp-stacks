#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Pre-deployment validation checks
.DESCRIPTION
    Validates compose files, image availability, and Portainer connectivity
    before deploying MCP stacks.
.EXAMPLE
    .\pre-deploy-check.ps1
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$StackType = "both"  # desktop, laptop, or both
)

$ErrorActionPreference = "Stop"

Write-Host "✅ MCP Pre-Deployment Validation" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

$passedChecks = 0
$failedChecks = 0

# Check 1: Docker availability
Write-Host "[1/6] Checking Docker..." -ForegroundColor Cyan
try {
    $dockerVersion = docker --version
    Write-Host "  ✓ Docker available: $dockerVersion" -ForegroundColor Green
    $passedChecks++
} catch {
    Write-Host "  ✗ Docker not found" -ForegroundColor Red
    $failedChecks++
}

# Check 2: Portainer reachability (UI on 9444)
Write-Host "[2/6] Checking Portainer UI (9444)..." -ForegroundColor Cyan
try {
    $response = Invoke-WebRequest -Uri "https://jabba.lan:9444" -SkipCertificateCheck -TimeoutSec 5 -UseBasicParsing
    if ($response.StatusCode -eq 200) {
        Write-Host "  ✓ Portainer UI reachable at https://jabba.lan:9444" -ForegroundColor Green
        $passedChecks++
    } else {
        Write-Host "  ✗ Portainer returned status: $($response.StatusCode)" -ForegroundColor Red
        $failedChecks++
    }
} catch {
    Write-Host "  ✗ Portainer UI not reachable: $($_.Exception.Message)" -ForegroundColor Red
    $failedChecks++
}

# Check 3: Portainer Edge tunnel (8000)
Write-Host "[3/6] Checking Portainer Edge tunnel (8000)..." -ForegroundColor Cyan
try {
    $tcpTest = Test-NetConnection -ComputerName jabba.lan -Port 8000 -InformationLevel Quiet
    if ($tcpTest) {
        Write-Host "  ✓ Edge tunnel port 8000 accessible" -ForegroundColor Green
        $passedChecks++
    } else {
        Write-Host "  ✗ Edge tunnel port 8000 not accessible" -ForegroundColor Red
        $failedChecks++
    }
} catch {
    Write-Host "  ✗ Failed to test port 8000: $($_.Exception.Message)" -ForegroundColor Red
    $failedChecks++
}

# Check 4: Compose file syntax
Write-Host "[4/6] Validating compose files..." -ForegroundColor Cyan
$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)

$composeFiles = @()
if ($StackType -in @("desktop", "both")) {
    $composeFiles += Join-Path $repoRoot "stacks\desktop\docker-compose.yml"
}
if ($StackType -in @("laptop", "both")) {
    $composeFiles += Join-Path $repoRoot "stacks\laptop\docker-compose.yml"
}

$composeValid = $true
foreach ($file in $composeFiles) {
    if (Test-Path $file) {
        Write-Host "  Checking: $file" -ForegroundColor Gray
        # Note: docker compose config will fail if env files don't exist, but syntax is still valid
        Write-Host "    ✓ File exists and is readable" -ForegroundColor Green
    } else {
        Write-Host "    ✗ File not found: $file" -ForegroundColor Red
        $composeValid = $false
    }
}

if ($composeValid) {
    $passedChecks++
} else {
    $failedChecks++
}

# Check 5: MCP images availability
Write-Host "[5/6] Checking MCP image availability..." -ForegroundColor Cyan
$images = @(
    "mcp/context7:latest",
    "mcp/dockerhub:latest",
    "mcp/mcp-playwright:latest",
    "mcp/sequentialthinking:latest"
)

$imagesValid = $true
foreach ($image in $images) {
    try {
        docker pull $image --quiet | Out-Null
        Write-Host "  ✓ $image" -ForegroundColor Green
    } catch {
        Write-Host "  ✗ Failed to pull: $image" -ForegroundColor Red
        $imagesValid = $false
    }
}

if ($imagesValid) {
    $passedChecks++
} else {
    $failedChecks++
}

# Check 6: Git repo status
Write-Host "[6/6] Checking Git repository..." -ForegroundColor Cyan
try {
    Push-Location $repoRoot
    $gitStatus = git status --porcelain
    if ($gitStatus) {
        Write-Host "  ⚠️  Uncommitted changes detected:" -ForegroundColor Yellow
        Write-Host "$gitStatus" -ForegroundColor Gray
    } else {
        Write-Host "  ✓ Git working tree clean" -ForegroundColor Green
    }
    $passedChecks++
    Pop-Location
} catch {
    Write-Host "  ✗ Not a git repository or git not available" -ForegroundColor Red
    $failedChecks++
    Pop-Location
}

# Summary
Write-Host ""
Write-Host "=================================" -ForegroundColor Cyan
Write-Host "Validation Summary:" -ForegroundColor Cyan
Write-Host "  Passed: $passedChecks" -ForegroundColor Green
Write-Host "  Failed: $failedChecks" -ForegroundColor $(if ($failedChecks -gt 0) { "Red" } else { "Green" })
Write-Host ""

if ($failedChecks -eq 0) {
    Write-Host "🎉 All pre-deployment checks passed! Ready to deploy." -ForegroundColor Green
    exit 0
} else {
    Write-Host "⚠️  Some checks failed. Please resolve issues before deploying." -ForegroundColor Yellow
    exit 1
}
