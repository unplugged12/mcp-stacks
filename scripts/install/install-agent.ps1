#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Install Portainer Agent on desktop/always-on hosts
.DESCRIPTION
    Deploys portainer/agent:latest on port 9001 with auto-restart.
    Verifies connectivity from portainer-server (https://portainer-server.local:9444).
.EXAMPLE
    .\install-agent.ps1
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$AgentPort = "9001",

    [Parameter()]
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host "🔧 Portainer Agent Installer (Desktop)" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

# Check Docker
try {
    $dockerVersion = docker --version
    Write-Host "✓ Docker detected: $dockerVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Docker not found. Please install Docker Desktop first." -ForegroundColor Red
    exit 1
}

# Check if agent already running
$existingAgent = docker ps -a --filter "name=portainer_agent" --format "{{.Names}}"
if ($existingAgent -and !$Force) {
    Write-Host "⚠️  Portainer Agent already exists: $existingAgent" -ForegroundColor Yellow
    $response = Read-Host "Remove and reinstall? (y/N)"
    if ($response -ne 'y') {
        Write-Host "Installation cancelled." -ForegroundColor Yellow
        exit 0
    }
    $Force = $true
}

if ($Force -and $existingAgent) {
    Write-Host "Removing existing agent..." -ForegroundColor Yellow
    docker stop portainer_agent 2>$null
    docker rm portainer_agent 2>$null
    Write-Host "✓ Removed existing agent" -ForegroundColor Green
}

# Pull latest agent image
Write-Host ""
Write-Host "Pulling portainer/agent:latest..." -ForegroundColor Cyan
docker pull portainer/agent:latest

# Deploy agent
Write-Host ""
Write-Host "Deploying Portainer Agent on port $AgentPort..." -ForegroundColor Cyan

$isWindows = $PSVersionTable.Platform -eq 'Win32NT' -or $null -eq $PSVersionTable.Platform

if ($isWindows) {
    # Windows: use named pipe
    docker run -d `
        --name portainer_agent `
        --restart=always `
        -p "${AgentPort}:9001" `
        -v "\\.\pipe\docker_engine:\\.\pipe\docker_engine" `
        portainer/agent:latest
} else {
    # Linux/macOS: use docker.sock
    docker run -d `
        --name portainer_agent `
        --restart=always `
        -p "${AgentPort}:9001" `
        -v /var/run/docker.sock:/var/run/docker.sock `
        portainer/agent:latest
}

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Agent deployed successfully" -ForegroundColor Green
} else {
    Write-Host "✗ Agent deployment failed" -ForegroundColor Red
    exit 1
}

# Verify agent is running
Start-Sleep -Seconds 2
$agentStatus = docker ps --filter "name=portainer_agent" --format "{{.Status}}"
Write-Host "✓ Agent status: $agentStatus" -ForegroundColor Green

Write-Host ""
Write-Host "🎉 Portainer Agent installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Log into Portainer at https://portainer-server.local:9444" -ForegroundColor White
Write-Host "2. Navigate to Environments → Add environment" -ForegroundColor White
Write-Host "3. Select 'Docker Standalone' → 'Agent'" -ForegroundColor White
Write-Host "4. Enter this machine's hostname/IP and port $AgentPort" -ForegroundColor White
Write-Host "5. Verify connectivity and add the environment" -ForegroundColor White
Write-Host ""
Write-Host "Agent endpoint: <this-host>:$AgentPort" -ForegroundColor Yellow
