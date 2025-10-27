#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Uninstall Portainer Agent from desktop
.DESCRIPTION
    Stops and removes the Portainer Agent container.
    Requires confirmation before removal.
.EXAMPLE
    .\uninstall-agent.ps1
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host "🗑️  Portainer Agent Uninstaller" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan
Write-Host ""

# Check if agent exists
$existingAgent = docker ps -a --filter "name=portainer_agent" --format "{{.Names}}"
if (!$existingAgent) {
    Write-Host "✓ No Portainer Agent found. Nothing to uninstall." -ForegroundColor Green
    exit 0
}

$agentStatus = docker ps -a --filter "name=portainer_agent" --format "{{.Status}}"
Write-Host "Found agent: $existingAgent" -ForegroundColor Yellow
Write-Host "Status: $agentStatus" -ForegroundColor Yellow
Write-Host ""

if (!$Force) {
    $response = Read-Host "Remove Portainer Agent? This will disconnect from Portainer server. (y/N)"
    if ($response -ne 'y') {
        Write-Host "Uninstall cancelled." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "Stopping agent..." -ForegroundColor Cyan
docker stop portainer_agent 2>$null
Write-Host "✓ Agent stopped" -ForegroundColor Green

Write-Host "Removing agent..." -ForegroundColor Cyan
docker rm portainer_agent 2>$null
Write-Host "✓ Agent removed" -ForegroundColor Green

Write-Host ""
Write-Host "🎉 Portainer Agent uninstalled successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Remember to remove this environment from Portainer UI:" -ForegroundColor Yellow
Write-Host "https://portainer-server.local:9444 → Environments → Remove this host" -ForegroundColor White
