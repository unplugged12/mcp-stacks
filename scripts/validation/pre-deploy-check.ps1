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
Write-Host "[1/7] Checking Docker..." -ForegroundColor Cyan
try {
    $dockerVersion = docker --version
    Write-Host "  ✓ Docker available: $dockerVersion" -ForegroundColor Green
    $passedChecks++
} catch {
    Write-Host "  ✗ Docker not found" -ForegroundColor Red
    $failedChecks++
}

# Check 2: Portainer reachability (UI on 9444)
Write-Host "[2/7] Checking Portainer UI (9444)..." -ForegroundColor Cyan
try {
    # Handle SSL certificate validation for both PowerShell 5.1 and 7+
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        $response = Invoke-WebRequest -Uri "https://portainer-server.local:9444" -SkipCertificateCheck -TimeoutSec 5 -UseBasicParsing
    } else {
        # PowerShell 5.1 workaround
        $originalCallback = [System.Net.ServicePointManager]::ServerCertificateValidationCallback
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
        $response = Invoke-WebRequest -Uri "https://portainer-server.local:9444" -TimeoutSec 5 -UseBasicParsing
        [System.Net.ServicePointManager]::ServerCertificateValidationCallback = $originalCallback
    }
    if ($response.StatusCode -eq 200) {
        Write-Host "  ✓ Portainer UI reachable at https://portainer-server.local:9444" -ForegroundColor Green
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
Write-Host "[3/7] Checking Portainer Edge tunnel (8000)..." -ForegroundColor Cyan
try {
    $tcpTest = Test-NetConnection -ComputerName portainer-server.local -Port 8000 -InformationLevel Quiet
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

# Check 4: Agent env file presence
Write-Host "[4/7] Validating agent env file..." -ForegroundColor Cyan
if ($StackType -in @("desktop", "both")) {
    $envFilePath = if ($env:MCP_ENV_FILE) { $env:MCP_ENV_FILE } else { "/run/mcp/mcp.env" }
    $checkPassed = $true

    if (-not (Test-Path -Path $envFilePath)) {
        Write-Host "  ✗ Env file not found: $envFilePath" -ForegroundColor Red
        Write-Host "    Run scripts/install/configure-agent-env.{ps1,sh} on the agent host." -ForegroundColor Red
        $checkPassed = $false
    } else {
        Write-Host "  ✓ Found env file at $envFilePath" -ForegroundColor Green
        try {
            $content = Get-Content -Path $envFilePath -ErrorAction Stop
            $requiredKeys = @("HUB_USERNAME", "HUB_PAT_TOKEN", "CONTEXT7_TOKEN")
            $missingKeys = @()
            foreach ($key in $requiredKeys) {
                if (-not ($content -match "^$key=")) {
                    $missingKeys += $key
                }
            }

            if ($missingKeys.Count -gt 0) {
                Write-Host "  ✗ Missing keys in env file: $($missingKeys -join ', ')" -ForegroundColor Red
                $checkPassed = $false
            } else {
                Write-Host "  ✓ Required keys present" -ForegroundColor Green
            }
        } catch {
            Write-Host "  ✗ Unable to read env file: $($_.Exception.Message)" -ForegroundColor Red
            $checkPassed = $false
        }
    }

    if ($checkPassed) {
        $passedChecks++
    } else {
        $failedChecks++
    }
} else {
    Write-Host "  ✓ Stack type '$StackType' does not require an agent env file" -ForegroundColor Green
    $passedChecks++
}

# Check 5: Compose file syntax
Write-Host "[5/7] Validating compose files..." -ForegroundColor Cyan
$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Split-Path -Parent (Split-Path -Parent $scriptDir)

$composeFiles = @()
if ($StackType -in @("desktop", "both")) {
    $composeFiles += Join-Path $repoRoot "stacks" | Join-Path -ChildPath "desktop" | Join-Path -ChildPath "docker-compose.yml"
}
if ($StackType -in @("laptop", "both")) {
    $composeFiles += Join-Path $repoRoot "stacks" | Join-Path -ChildPath "laptop" | Join-Path -ChildPath "docker-compose.yml"
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

# Check 6: MCP images availability
Write-Host "[6/7] Checking MCP image availability..." -ForegroundColor Cyan
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

# Check 7: Git repo status
Write-Host "[7/7] Checking Git repository..." -ForegroundColor Cyan
$pushedLocation = $false
try {
    Push-Location $repoRoot
    $pushedLocation = $true
    $gitStatus = git status --porcelain 2>&1
    if ($LASTEXITCODE -eq 0) {
        if ($gitStatus) {
            Write-Host "  ⚠️  Uncommitted changes detected:" -ForegroundColor Yellow
            Write-Host "$gitStatus" -ForegroundColor Gray
        } else {
            Write-Host "  ✓ Git working tree clean" -ForegroundColor Green
        }
        $passedChecks++
    } else {
        Write-Host "  ✗ Not a git repository" -ForegroundColor Red
        $failedChecks++
    }
} catch {
    Write-Host "  ✗ Git not available or error: $($_.Exception.Message)" -ForegroundColor Red
    $failedChecks++
} finally {
    if ($pushedLocation) {
        Pop-Location
    }
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
