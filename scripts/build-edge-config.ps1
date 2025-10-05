#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Build Edge Config bundle for Portainer laptop deployments
.DESCRIPTION
    Creates a ZIP bundle containing mcp.env with secrets for Edge Config delivery.
    Prompts interactively for values; NEVER commits secrets to Git.
.EXAMPLE
    .\build-edge-config.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

# Paths
$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Split-Path -Parent $scriptDir
$edgeConfigDir = Join-Path $repoRoot "edge-configs"
$outputZip = Join-Path $edgeConfigDir "laptops.zip"
$tempDir = Join-Path $env:TEMP "mcp-edge-config-$(Get-Random)"

Write-Host "🔧 MCP Edge Config Bundle Builder" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

# Create directories if they don't exist
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
New-Item -ItemType Directory -Path $edgeConfigDir -Force | Out-Null
Write-Host "✓ Created temp directory: $tempDir" -ForegroundColor Green

# Template env file
$envTemplate = @"
# MCP Server Environment Variables
# Delivered via Portainer Edge Config to /var/edge/configs/mcp.env

# Docker Hub MCP Server
HUB_USERNAME=
HUB_PAT_TOKEN=

# Context7 MCP Server
CONTEXT7_TOKEN=

# Playwright MCP Server (typically no auth required)
# Add any Playwright-specific vars here if needed

# Sequential Thinking MCP Server (typically no auth required)
# Add any vars here if needed

"@

$envPath = Join-Path $tempDir "mcp.env"
$envTemplate | Out-File -FilePath $envPath -Encoding UTF8 -NoNewline

Write-Host "✓ Created template mcp.env" -ForegroundColor Green
Write-Host ""

# Interactive prompts
Write-Host "Enter values for secrets (leave blank to skip):" -ForegroundColor Yellow
Write-Host ""

$hubUsername = Read-Host "Docker Hub Username"
$hubPat = Read-Host "Docker Hub PAT Token" -AsSecureString
$hubPatPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($hubPat)
)

$context7Token = Read-Host "Context7 API Token" -AsSecureString
$context7TokenPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($context7Token)
)

# Build final env file
$finalEnv = @"
# MCP Server Environment Variables
# Delivered via Portainer Edge Config to /var/edge/configs/mcp.env

# Docker Hub MCP Server
HUB_USERNAME=$hubUsername
HUB_PAT_TOKEN=$hubPatPlain

# Context7 MCP Server
CONTEXT7_TOKEN=$context7TokenPlain

# Playwright MCP Server (typically no auth required)
# Add any Playwright-specific vars here if needed

# Sequential Thinking MCP Server (typically no auth required)
# Add any vars here if needed

"@

$finalEnv | Out-File -FilePath $envPath -Encoding UTF8 -NoNewline
Write-Host ""
Write-Host "✓ Updated mcp.env with provided values" -ForegroundColor Green

# Create ZIP
if (Test-Path $outputZip) {
    Remove-Item $outputZip -Force
}

Compress-Archive -Path $envPath -DestinationPath $outputZip -Force
Write-Host "✓ Created bundle: $outputZip" -ForegroundColor Green

# Cleanup
Remove-Item $tempDir -Recurse -Force
Write-Host "✓ Cleaned up temp files" -ForegroundColor Green
Write-Host ""

Write-Host "🎉 Edge Config bundle ready!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Log into Portainer at https://jabba.lan:9444" -ForegroundColor White
Write-Host "2. Navigate to Edge Configurations" -ForegroundColor White
Write-Host "3. Create new configuration targeting 'laptops' Edge Group" -ForegroundColor White
Write-Host "4. Upload: $outputZip" -ForegroundColor White
Write-Host ""
Write-Host "⚠️  Remember: Never commit $outputZip to Git!" -ForegroundColor Yellow
