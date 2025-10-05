#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Post-deployment validation checks
.DESCRIPTION
    Verifies MCP containers are running and healthy after deployment.
.PARAMETER StackPrefix
    Stack name prefix (e.g., "mcp-desktop", "mcp-laptop")
.EXAMPLE
    .\post-deploy-check.ps1 -StackPrefix "mcp-desktop"
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$StackPrefix = "mcp"
)

$ErrorActionPreference = "Stop"

Write-Host "✅ MCP Post-Deployment Validation" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Checking containers with prefix: $StackPrefix" -ForegroundColor Yellow
Write-Host ""

$passedChecks = 0
$failedChecks = 0

# Expected MCP containers
$expectedContainers = @(
    "mcp-context7",
    "mcp-dockerhub",
    "mcp-playwright",
    "mcp-sequentialthinking"
)

Write-Host "Fetching running containers..." -ForegroundColor Cyan
try {
    $runningContainers = docker ps --format "{{.Names}}" | Where-Object { $_ -like "*$StackPrefix*" }

    if ($runningContainers) {
        Write-Host "✓ Found $(($runningContainers | Measure-Object).Count) containers" -ForegroundColor Green
        Write-Host ""
    } else {
        Write-Host "⚠️  No containers found with prefix '$StackPrefix'" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "This could mean:" -ForegroundColor Yellow
        Write-Host "• Stack not yet deployed" -ForegroundColor White
        Write-Host "• Stack uses a different naming convention" -ForegroundColor White
        Write-Host "• Containers failed to start" -ForegroundColor White
        Write-Host ""
        exit 1
    }
} catch {
    Write-Host "✗ Failed to query Docker: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Check each expected container
foreach ($containerName in $expectedContainers) {
    $fullName = $runningContainers | Where-Object { $_ -match $containerName }

    if ($fullName) {
        Write-Host "[$containerName]" -ForegroundColor Cyan

        # Get container status
        $status = docker inspect $fullName --format "{{.State.Status}}"
        $health = docker inspect $fullName --format "{{.State.Health.Status}}" 2>$null

        if ($status -eq "running") {
            Write-Host "  ✓ Status: Running" -ForegroundColor Green
            $passedChecks++

            # Show health if available
            if ($health -and $health -ne "<no value>") {
                if ($health -eq "healthy") {
                    Write-Host "  ✓ Health: $health" -ForegroundColor Green
                } else {
                    Write-Host "  ⚠️  Health: $health" -ForegroundColor Yellow
                }
            }

            # Try to show environment variables loaded (if accessible)
            $envCount = docker inspect $fullName --format "{{len .Config.Env}}"
            Write-Host "  ✓ Environment variables loaded: $envCount" -ForegroundColor Green

        } else {
            Write-Host "  ✗ Status: $status (not running)" -ForegroundColor Red
            $failedChecks++
        }

        Write-Host ""
    } else {
        Write-Host "[$containerName]" -ForegroundColor Cyan
        Write-Host "  ✗ Container not found" -ForegroundColor Red
        $failedChecks++
        Write-Host ""
    }
}

# Summary
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Validation Summary:" -ForegroundColor Cyan
Write-Host "  Running: $passedChecks/$($expectedContainers.Count)" -ForegroundColor $(if ($passedChecks -eq $expectedContainers.Count) { "Green" } else { "Yellow" })
Write-Host "  Failed: $failedChecks" -ForegroundColor $(if ($failedChecks -gt 0) { "Red" } else { "Green" })
Write-Host ""

if ($failedChecks -eq 0 -and $passedChecks -eq $expectedContainers.Count) {
    Write-Host "🎉 All MCP containers are running!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "• Verify MCP servers are accessible" -ForegroundColor White
    Write-Host "• Check container logs: docker logs <container-name>" -ForegroundColor White
    Write-Host "• Test MCP functionality via your client" -ForegroundColor White
    exit 0
} else {
    Write-Host "⚠️  Some containers are not running. Check logs for details:" -ForegroundColor Yellow
    Write-Host "  docker logs <container-name>" -ForegroundColor White
    exit 1
}
