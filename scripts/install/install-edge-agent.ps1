#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Install Portainer Edge Agent on laptop/roaming hosts
.DESCRIPTION
    Executes the docker run command from Portainer's Edge Agent wizard.
    Paste the exact command when prompted.
.EXAMPLE
    .\install-edge-agent.ps1
.EXAMPLE
    .\install-edge-agent.ps1 -DockerCommand "docker run -d ..."
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$DockerCommand,

    [Parameter()]
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host "🔧 Portainer Edge Agent Installer (Laptop)" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# Check Docker
try {
    $dockerVersion = docker --version
    Write-Host "✓ Docker detected: $dockerVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Docker not found. Please install Docker Desktop first." -ForegroundColor Red
    exit 1
}

# Check if edge agent already running
$existingAgent = docker ps -a --filter "name=portainer_edge_agent" --format "{{.Names}}"
if ($existingAgent -and !$Force) {
    Write-Host "⚠️  Portainer Edge Agent already exists: $existingAgent" -ForegroundColor Yellow
    $response = Read-Host "Remove and reinstall? (y/N)"
    if ($response -ne 'y') {
        Write-Host "Installation cancelled." -ForegroundColor Yellow
        exit 0
    }
    $Force = $true
}

if ($Force -and $existingAgent) {
    Write-Host "Removing existing edge agent..." -ForegroundColor Yellow
    docker stop portainer_edge_agent 2>$null
    docker rm portainer_edge_agent 2>$null
    Write-Host "✓ Removed existing edge agent" -ForegroundColor Green
}

# Get docker command if not provided
if ([string]::IsNullOrWhiteSpace($DockerCommand)) {
    Write-Host ""
    Write-Host "Instructions:" -ForegroundColor Cyan
    Write-Host "1. Log into Portainer at https://jabba.lan:9444" -ForegroundColor White
    Write-Host "2. Navigate to Environments → Add environment" -ForegroundColor White
    Write-Host "3. Select 'Docker Standalone' → 'Edge Agent' → 'Standard'" -ForegroundColor White
    Write-Host "4. Configure:" -ForegroundColor White
    Write-Host "   - Name: <laptop-name>" -ForegroundColor White
    Write-Host "   - Portainer server URL: https://jabba.lan:9444" -ForegroundColor White
    Write-Host "   - Edge Group: laptops" -ForegroundColor White
    Write-Host "5. Copy the generated 'docker run' command" -ForegroundColor White
    Write-Host ""
    Write-Host "Paste the complete docker run command below:" -ForegroundColor Yellow
    Write-Host "(It should start with 'docker run -d ...')" -ForegroundColor Yellow
    Write-Host ""
    $DockerCommand = Read-Host "Command"
}

# Validate command
if ($DockerCommand -notmatch "^docker run") {
    Write-Host "✗ Invalid command. Must start with 'docker run'" -ForegroundColor Red
    exit 1
}

if ($DockerCommand -notmatch "portainer/agent.*--edge") {
    Write-Host "⚠️  Warning: This doesn't look like an Edge Agent command" -ForegroundColor Yellow
    $response = Read-Host "Continue anyway? (y/N)"
    if ($response -ne 'y') {
        Write-Host "Installation cancelled." -ForegroundColor Yellow
        exit 0
    }
}

# Execute command
Write-Host ""
Write-Host "Deploying Edge Agent..." -ForegroundColor Cyan
Write-Host ""

Invoke-Expression $DockerCommand

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✓ Edge Agent deployed successfully" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "✗ Edge Agent deployment failed" -ForegroundColor Red
    exit 1
}

# Verify agent is running
Start-Sleep -Seconds 2
$agentStatus = docker ps --filter "name=portainer_edge_agent" --format "{{.Status}}"
if ($agentStatus) {
    Write-Host "✓ Edge Agent status: $agentStatus" -ForegroundColor Green
} else {
    Write-Host "⚠️  Warning: Edge Agent container not found" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🎉 Portainer Edge Agent installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "The Edge Agent will:" -ForegroundColor Cyan
Write-Host "• Connect to https://jabba.lan:9444 via tunnel port 8000" -ForegroundColor White
Write-Host "• Poll for commands every 5 seconds (default)" -ForegroundColor White
Write-Host "• Check in periodically even when off-LAN" -ForegroundColor White
Write-Host ""
Write-Host "Verify in Portainer:" -ForegroundColor Cyan
Write-Host "• Environments → Check for this laptop (green = online)" -ForegroundColor White
Write-Host "• Edge Configurations → Deploy mcp.env config to 'laptops' group" -ForegroundColor White
Write-Host "• Edge Stacks → Deploy MCP stack from Git" -ForegroundColor White
