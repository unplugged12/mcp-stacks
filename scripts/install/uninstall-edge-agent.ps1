#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Uninstall Portainer Edge Agent from laptop
.DESCRIPTION
    Stops and removes the Portainer Edge Agent container.
    Requires confirmation before removal.
.EXAMPLE
    .\uninstall-edge-agent.ps1
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host "🗑️  Portainer Edge Agent Uninstaller" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Check if edge agent exists
$existingAgent = docker ps -a --filter "name=portainer_edge_agent" --format "{{.Names}}"
if (!$existingAgent) {
    Write-Host "✓ No Portainer Edge Agent found. Nothing to uninstall." -ForegroundColor Green
    exit 0
}

$agentStatus = docker ps -a --filter "name=portainer_edge_agent" --format "{{.Status}}"
Write-Host "Found edge agent: $existingAgent" -ForegroundColor Yellow
Write-Host "Status: $agentStatus" -ForegroundColor Yellow
Write-Host ""

if (!$Force) {
    $response = Read-Host "Remove Portainer Edge Agent? This will disconnect from Portainer server. (y/N)"
    if ($response -ne 'y') {
        Write-Host "Uninstall cancelled." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "Stopping edge agent..." -ForegroundColor Cyan
docker stop portainer_edge_agent 2>$null
Write-Host "✓ Edge agent stopped" -ForegroundColor Green

Write-Host "Removing edge agent..." -ForegroundColor Cyan
docker rm portainer_edge_agent 2>$null
Write-Host "✓ Edge agent removed" -ForegroundColor Green

Write-Host ""
Write-Host "🎉 Portainer Edge Agent uninstalled successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Remember to remove this environment from Portainer UI:" -ForegroundColor Yellow
Write-Host "https://portainer-server.local:9444 → Environments → Remove this laptop" -ForegroundColor White
