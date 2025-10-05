#!/usr/bin/env pwsh
<#!
.SYNOPSIS
    Configure the MCP agent environment file with required secrets.
.DESCRIPTION
    Prompts for Docker Hub and Context7 credentials and writes them to
    /run/mcp/mcp.env on Linux-based agent hosts.
.EXAMPLE
    sudo pwsh ./configure-agent-env.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$envFile = '/run/mcp/mcp.env'
$envDir = Split-Path -Path $envFile -Parent

if ($IsWindows) {
    throw "This script must be run on a Linux agent host (PowerShell 7+)."
}

try {
    $uid = (id -u)
} catch {
    throw "Unable to determine current user. Ensure coreutils are installed."
}

if ($uid -ne 0) {
    throw "This script must be run as root. Re-run with sudo."
}

Write-Host "🔐 MCP Agent Environment Configuration" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

$overwrite = $true
if (Test-Path -Path $envFile) {
    $response = Read-Host "An existing env file was found at $envFile. Overwrite? (y/N)"
    if ([string]::IsNullOrWhiteSpace($response)) {
        $response = 'n'
    }
    if ($response -notin @('y','Y')) {
        Write-Host "⚠️  Aborting without modifying $envFile." -ForegroundColor Yellow
        return
    }
}

function Read-RequiredSecret {
    param(
        [string]$Prompt,
        [switch]$Secret
    )

    while ($true) {
        if ($Secret) {
            $value = Read-Host -Prompt $Prompt -AsSecureString
            $value = [Runtime.InteropServices.Marshal]::PtrToStringBSTR(
                [Runtime.InteropServices.Marshal]::SecureStringToBSTR($value)
            )
        } else {
            $value = Read-Host -Prompt $Prompt
        }

        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return $value.Trim()
        }
        Write-Host "Value cannot be empty." -ForegroundColor Yellow
    }
}

function Escape-ForEnv {
    param([string]$Value)

    $escaped = $Value -replace '\\', '\\\\'
    $escaped = $escaped -replace '"', '\\"'
    return $escaped
}

$hubUsername = Read-RequiredSecret -Prompt 'Docker Hub username'
$hubPat = Read-RequiredSecret -Prompt 'Docker Hub PAT' -Secret
$context7Token = Read-RequiredSecret -Prompt 'Context7 API token' -Secret

New-Item -ItemType Directory -Path $envDir -Force | Out-Null
chmod 700 $envDir | Out-Null

$tmpFile = [System.IO.Path]::GetTempFileName()
try {
    $content = @(
        "HUB_USERNAME=\"$(Escape-ForEnv $hubUsername)\"",
        "HUB_PAT_TOKEN=\"$(Escape-ForEnv $hubPat)\"",
        "CONTEXT7_TOKEN=\"$(Escape-ForEnv $context7Token)\""
    ) -join "`n"
    Set-Content -LiteralPath $tmpFile -Value ($content + "`n")
    chmod 600 $tmpFile | Out-Null
    Move-Item -Path $tmpFile -Destination $envFile -Force
} finally {
    if (Test-Path $tmpFile) {
        Remove-Item $tmpFile -Force
    }
}

Write-Host "✓ MCP env file written to $envFile" -ForegroundColor Green
Write-Host "✓ Permissions set to 600" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Ensure the Portainer agent is registered for this host."
Write-Host "  2. Deploy or redeploy the desktop stack so containers read the new secrets."
