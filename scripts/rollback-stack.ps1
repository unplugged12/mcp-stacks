#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Rollback Portainer stack to previous Git commit
.DESCRIPTION
    Reverts a Portainer stack to a specific Git commit hash.
    Works with Agent-based stacks using GitOps polling.
.PARAMETER PortainerUrl
    Portainer server URL (default: https://portainer-server.lan:9444)
.PARAMETER ApiKey
    Portainer API key
.PARAMETER StackName
    Name of the stack to rollback
.PARAMETER CommitHash
    Git commit hash to revert to (optional - will show recent commits if not provided)
.EXAMPLE
    .\rollback-stack.ps1 -ApiKey "ptr_xxxx" -StackName "mcp-desktop"
.EXAMPLE
    .\rollback-stack.ps1 -ApiKey "ptr_xxxx" -StackName "mcp-desktop" -CommitHash "abc123"
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$PortainerUrl = "https://portainer-server.lan:9444",

    [Parameter(Mandatory)]
    [string]$ApiKey,

    [Parameter(Mandatory)]
    [string]$StackName,

    [Parameter()]
    [string]$CommitHash
)

$ErrorActionPreference = "Stop"

Write-Host "⏮️  Portainer Stack Rollback Helper" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

# Get repo root and show recent commits
$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Split-Path -Parent $scriptDir

Write-Host "Repository: $repoRoot" -ForegroundColor Yellow
Write-Host ""

# Show recent commits if commit hash not provided
if ([string]::IsNullOrWhiteSpace($CommitHash)) {
    Write-Host "Recent commits:" -ForegroundColor Cyan
    Push-Location $repoRoot
    git log --oneline -10
    Pop-Location
    Write-Host ""

    $CommitHash = Read-Host "Enter commit hash to rollback to"
    if ([string]::IsNullOrWhiteSpace($CommitHash)) {
        Write-Host "✗ No commit hash provided. Aborting." -ForegroundColor Red
        exit 1
    }
}

# Validate commit exists
Write-Host "Validating commit hash..." -ForegroundColor Cyan
Push-Location $repoRoot
try {
    $commitInfo = git show --no-patch --format="%h - %s (%cr)" $CommitHash 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✗ Invalid commit hash: $CommitHash" -ForegroundColor Red
        Pop-Location
        exit 1
    }
    Write-Host "✓ Target commit: $commitInfo" -ForegroundColor Green
    Pop-Location
} catch {
    Write-Host "✗ Failed to validate commit: $($_.Exception.Message)" -ForegroundColor Red
    Pop-Location
    exit 1
}

# Confirm rollback
Write-Host ""
Write-Host "⚠️  WARNING: This will rollback stack '$StackName' to commit $CommitHash" -ForegroundColor Yellow
Write-Host "This operation will:" -ForegroundColor Yellow
Write-Host "• Create a new commit reverting to the specified state" -ForegroundColor White
Write-Host "• Trigger Portainer to redeploy from the new commit" -ForegroundColor White
Write-Host ""

$confirm = Read-Host "Proceed with rollback? (type 'yes' to confirm)"
if ($confirm -ne 'yes') {
    Write-Host "Rollback cancelled." -ForegroundColor Yellow
    exit 0
}

# Perform Git rollback (revert to commit)
Write-Host ""
Write-Host "Creating rollback commit..." -ForegroundColor Cyan
Push-Location $repoRoot

try {
    # Create a revert commit
    git revert --no-commit $CommitHash..HEAD
    git commit -m "Rollback to $CommitHash"

    Write-Host "✓ Rollback commit created" -ForegroundColor Green

    # Push to remote
    Write-Host "Pushing to remote..." -ForegroundColor Cyan
    git push origin main

    Write-Host "✓ Pushed to remote" -ForegroundColor Green
    Pop-Location

} catch {
    Write-Host "✗ Git rollback failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "To abort the rollback:" -ForegroundColor Yellow
    Write-Host "  cd $repoRoot && git revert --abort" -ForegroundColor White
    Pop-Location
    exit 1
}

# Trigger Portainer redeploy via API
Write-Host ""
Write-Host "Triggering Portainer redeploy..." -ForegroundColor Cyan

$headers = @{
    "X-API-Key" = $ApiKey
    "Content-Type" = "application/json"
}

if ($PSVersionTable.PSVersion.Major -ge 6) {
    $PSDefaultParameterValues['Invoke-RestMethod:SkipCertificateCheck'] = $true
} else {
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
}

try {
    # Get stack info
    $stacks = Invoke-RestMethod -Uri "$PortainerUrl/api/stacks" -Headers $headers -Method Get
    $stack = $stacks | Where-Object { $_.Name -eq $StackName }

    if (!$stack) {
        Write-Host "✗ Stack '$StackName' not found in Portainer" -ForegroundColor Red
        Write-Host "GitOps will eventually sync, or manually redeploy in Portainer UI" -ForegroundColor Yellow
        exit 1
    }

    $stackId = $stack.Id
    $endpointId = $stack.EndpointId

    # Trigger redeploy
    $body = @{
        RepositoryAuthentication = $false
        RepositoryReferenceName = "refs/heads/main"
        Prune = $false
        PullImage = $true
    } | ConvertTo-Json

    Invoke-RestMethod `
        -Uri "$PortainerUrl/api/stacks/$stackId/git/redeploy?endpointId=$endpointId" `
        -Headers $headers `
        -Method Put `
        -Body $body | Out-Null

    Write-Host "✓ Portainer redeploy triggered" -ForegroundColor Green

} catch {
    Write-Host "⚠️  Failed to trigger Portainer redeploy via API" -ForegroundColor Yellow
    Write-Host "Reason: $($_.Exception.Message)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "GitOps polling will sync the rollback automatically," -ForegroundColor Yellow
    Write-Host "or manually redeploy in Portainer UI:" -ForegroundColor Yellow
    Write-Host "  $PortainerUrl/#!/stacks" -ForegroundColor White
}

Write-Host ""
Write-Host "🎉 Rollback complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Verify deployment:" -ForegroundColor Cyan
Write-Host "• Check Portainer UI: $PortainerUrl/#!/stacks" -ForegroundColor White
Write-Host "• Run: .\scripts\validation\post-deploy-check.ps1" -ForegroundColor White
