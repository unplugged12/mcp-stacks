#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Trigger Portainer stack redeploy via API
.DESCRIPTION
    Redeploys Agent or Edge stacks by pulling latest from Git.
    Supports both regular stacks (Agent) and Edge stacks.
.PARAMETER PortainerUrl
    Portainer server URL (default: https://jabba.lan:9444)
.PARAMETER ApiKey
    Portainer API key (X-API-Key header)
.PARAMETER StackName
    Name of the stack to redeploy
.PARAMETER Type
    Stack type: 'agent' or 'edge' (default: agent)
.EXAMPLE
    .\redeploy-stack.ps1 -ApiKey "ptr_xxxx" -StackName "mcp-desktop"
.EXAMPLE
    .\redeploy-stack.ps1 -ApiKey "ptr_xxxx" -StackName "mcp-laptop" -Type edge
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$PortainerUrl = "https://jabba.lan:9444",

    [Parameter(Mandatory)]
    [string]$ApiKey,

    [Parameter(Mandatory)]
    [string]$StackName,

    [Parameter()]
    [ValidateSet('agent', 'edge')]
    [string]$Type = 'agent'
)

$ErrorActionPreference = "Stop"

Write-Host "🔄 Portainer Stack Redeploy Helper" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Target: $StackName ($Type)" -ForegroundColor Yellow
Write-Host "Server: $PortainerUrl" -ForegroundColor Yellow
Write-Host ""

# Headers
$headers = @{
    "X-API-Key" = $ApiKey
    "Content-Type" = "application/json"
}

# Disable SSL verification for self-signed certs
if ($PSVersionTable.PSVersion.Major -ge 6) {
    $PSDefaultParameterValues['Invoke-RestMethod:SkipCertificateCheck'] = $true
    $PSDefaultParameterValues['Invoke-WebRequest:SkipCertificateCheck'] = $true
} else {
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
}

try {
    if ($Type -eq 'agent') {
        # Regular stack (Agent endpoints)
        Write-Host "Fetching stack list..." -ForegroundColor Cyan
        $stacks = Invoke-RestMethod -Uri "$PortainerUrl/api/stacks" -Headers $headers -Method Get

        $stack = $stacks | Where-Object { $_.Name -eq $StackName }
        if (!$stack) {
            Write-Host "✗ Stack '$StackName' not found" -ForegroundColor Red
            Write-Host ""
            Write-Host "Available stacks:" -ForegroundColor Yellow
            $stacks | ForEach-Object { Write-Host "  - $($_.Name) (ID: $($_.Id))" }
            exit 1
        }

        $stackId = $stack.Id
        $endpointId = $stack.EndpointId

        Write-Host "✓ Found stack: $StackName (ID: $stackId)" -ForegroundColor Green

        # Trigger Git pull and redeploy
        Write-Host "Triggering Git pull and redeploy..." -ForegroundColor Cyan

        $body = @{
            RepositoryAuthentication = $false
            RepositoryReferenceName = "refs/heads/main"
            Prune = $false
            PullImage = $true
        } | ConvertTo-Json

        $response = Invoke-RestMethod `
            -Uri "$PortainerUrl/api/stacks/$stackId/git/redeploy?endpointId=$endpointId" `
            -Headers $headers `
            -Method Put `
            -Body $body

        Write-Host "✓ Redeploy triggered successfully" -ForegroundColor Green
        Write-Host ""
        Write-Host "Stack updated from Git. Check Portainer UI for status:" -ForegroundColor Cyan
        Write-Host "$PortainerUrl/#!/stacks/$stackId" -ForegroundColor White

    } elseif ($Type -eq 'edge') {
        # Edge stack
        Write-Host "Fetching Edge stack list..." -ForegroundColor Cyan
        $edgeStacks = Invoke-RestMethod -Uri "$PortainerUrl/api/edge_stacks" -Headers $headers -Method Get

        $edgeStack = $edgeStacks | Where-Object { $_.Name -eq $StackName }
        if (!$edgeStack) {
            Write-Host "✗ Edge stack '$StackName' not found" -ForegroundColor Red
            Write-Host ""
            Write-Host "Available Edge stacks:" -ForegroundColor Yellow
            $edgeStacks | ForEach-Object { Write-Host "  - $($_.Name) (ID: $($_.Id))" }
            exit 1
        }

        $edgeStackId = $edgeStack.Id

        Write-Host "✓ Found Edge stack: $StackName (ID: $edgeStackId)" -ForegroundColor Green
        Write-Host ""
        Write-Host "⚠️  Note: Edge stack Git sync is a Business feature in Portainer CE." -ForegroundColor Yellow
        Write-Host "For CE, please use Portainer UI to manually Pull and redeploy:" -ForegroundColor Yellow
        Write-Host "1. Go to $PortainerUrl/#!/edge/stacks" -ForegroundColor White
        Write-Host "2. Select '$StackName'" -ForegroundColor White
        Write-Host "3. Click 'Pull and redeploy'" -ForegroundColor White
        Write-Host ""
        Write-Host "Alternatively, upgrade to Portainer Business for API-based Edge GitOps." -ForegroundColor Cyan
    }

} catch {
    Write-Host "✗ API request failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "• Verify API key is valid (create at $PortainerUrl/#!/settings)" -ForegroundColor White
    Write-Host "• Check Portainer is reachable: $PortainerUrl" -ForegroundColor White
    Write-Host "• Ensure stack exists with correct name" -ForegroundColor White
    exit 1
}
