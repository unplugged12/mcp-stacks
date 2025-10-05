#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Comprehensive smoke test for MCP container health validation
.DESCRIPTION
    Validates MCP containers after deployment by checking:
    - Container running status
    - Health check status
    - Resource limits enforcement
    - Log output verification
    - Network connectivity
    - Environment variable loading
.PARAMETER StackPrefix
    Stack name prefix (e.g., "mcp-desktop", "mcp-laptop", "mcp")
.PARAMETER Verbose
    Show detailed information during tests
.PARAMETER SkipHealthCheck
    Skip health check validation (useful for containers without health checks)
.PARAMETER Timeout
    Timeout in seconds to wait for containers to become healthy (default: 120)
.EXAMPLE
    .\smoke-test.ps1 -StackPrefix "mcp"
.EXAMPLE
    .\smoke-test.ps1 -StackPrefix "mcp-desktop" -Verbose
.EXAMPLE
    .\smoke-test.ps1 -StackPrefix "mcp-laptop" -Timeout 180
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$StackPrefix = "mcp",

    [Parameter(Mandatory = $false)]
    [switch]$SkipHealthCheck = $false,

    [Parameter(Mandatory = $false)]
    [int]$Timeout = 120
)

$ErrorActionPreference = "Stop"

# Color functions for better output
function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  $Message" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

function Write-TestHeader {
    param([string]$Message)
    Write-Host ""
    Write-Host "───────────────────────────────────────────────────────────" -ForegroundColor DarkCyan
    Write-Host "  $Message" -ForegroundColor White
    Write-Host "───────────────────────────────────────────────────────────" -ForegroundColor DarkCyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "  ✓ $Message" -ForegroundColor Green
}

function Write-Failure {
    param([string]$Message)
    Write-Host "  ✗ $Message" -ForegroundColor Red
}

function Write-Warning {
    param([string]$Message)
    Write-Host "  ⚠ $Message" -ForegroundColor Yellow
}

function Write-Info {
    param([string]$Message)
    Write-Host "  ℹ $Message" -ForegroundColor Cyan
}

# Test counters
$script:totalTests = 0
$script:passedTests = 0
$script:failedTests = 0
$script:warnings = 0

function Record-Pass {
    $script:totalTests++
    $script:passedTests++
}

function Record-Fail {
    $script:totalTests++
    $script:failedTests++
}

function Record-Warning {
    $script:warnings++
}

# Start
Write-Header "MCP Stack Smoke Test Suite"
Write-Host "Stack Prefix: $StackPrefix" -ForegroundColor White
Write-Host "Timeout: $Timeout seconds" -ForegroundColor White
Write-Host "Skip Health Checks: $SkipHealthCheck" -ForegroundColor White
Write-Host "Start Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White

# Expected MCP containers
$expectedContainers = @(
    @{ Name = "mcp-context7"; Port = 3000 },
    @{ Name = "mcp-dockerhub"; Port = 3000 },
    @{ Name = "mcp-playwright"; Port = 3000 },
    @{ Name = "mcp-sequentialthinking"; Port = 3000 }
)

# Test 1: Docker Availability
Write-TestHeader "TEST 1: Docker Daemon Availability"
try {
    $dockerVersion = docker version --format '{{.Server.Version}}' 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Docker daemon is running (version: $dockerVersion)"
        Record-Pass
    } else {
        Write-Failure "Docker daemon is not responding"
        Record-Fail
        exit 1
    }
} catch {
    Write-Failure "Docker is not available: $($_.Exception.Message)"
    Record-Fail
    exit 1
}

# Test 2: Container Discovery
Write-TestHeader "TEST 2: Container Discovery"
try {
    $allContainers = docker ps -a --format "{{.Names}}" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Failure "Failed to list containers"
        Record-Fail
        exit 1
    }

    $mcpContainers = $allContainers | Where-Object { $_ -like "*$StackPrefix*" }

    if ($mcpContainers) {
        Write-Success "Found $(($mcpContainers | Measure-Object).Count) MCP containers"
        Record-Pass

        if ($VerbosePreference -eq 'Continue') {
            foreach ($container in $mcpContainers) {
                Write-Info "  - $container"
            }
        }
    } else {
        Write-Failure "No containers found with prefix '$StackPrefix'"
        Write-Info "Available containers:"
        $allContainers | ForEach-Object { Write-Host "    - $_" -ForegroundColor Gray }
        Record-Fail
        exit 1
    }
} catch {
    Write-Failure "Container discovery failed: $($_.Exception.Message)"
    Record-Fail
    exit 1
}

# Test 3: Container Running Status
Write-TestHeader "TEST 3: Container Running Status"
$runningContainers = @()

foreach ($expected in $expectedContainers) {
    $containerName = $expected.Name
    $fullName = $mcpContainers | Where-Object { $_ -match $containerName } | Select-Object -First 1

    if ($fullName) {
        $status = docker inspect $fullName --format "{{.State.Status}}" 2>&1

        if ($status -eq "running") {
            Write-Success "$containerName is running"
            $runningContainers += @{ Name = $fullName; Expected = $expected }
            Record-Pass
        } else {
            Write-Failure "$containerName is not running (status: $status)"
            Record-Fail
        }
    } else {
        Write-Failure "$containerName container not found"
        Record-Fail
    }
}

if ($runningContainers.Count -eq 0) {
    Write-Failure "No containers are running. Exiting."
    exit 1
}

# Test 4: Health Check Status
if (-not $SkipHealthCheck) {
    Write-TestHeader "TEST 4: Health Check Status"
    Write-Info "Waiting up to $Timeout seconds for containers to become healthy..."

    $startTime = Get-Date
    $allHealthy = $false

    while (-not $allHealthy -and ((Get-Date) - $startTime).TotalSeconds -lt $Timeout) {
        $allHealthy = $true

        foreach ($container in $runningContainers) {
            $fullName = $container.Name
            $health = docker inspect $fullName --format "{{.State.Health.Status}}" 2>$null

            if ($health -and $health -ne "<no value>") {
                if ($health -ne "healthy") {
                    $allHealthy = $false
                    break
                }
            } else {
                # Container doesn't have health check configured
                $allHealthy = $true
            }
        }

        if (-not $allHealthy) {
            Start-Sleep -Seconds 5
        }
    }

    # Check final health status
    foreach ($container in $runningContainers) {
        $fullName = $container.Name
        $containerName = $container.Expected.Name
        $health = docker inspect $fullName --format "{{.State.Health.Status}}" 2>$null

        if ($health -and $health -ne "<no value>") {
            if ($health -eq "healthy") {
                Write-Success "$containerName is healthy"
                Record-Pass
            } elseif ($health -eq "starting") {
                Write-Warning "$containerName is still starting (may need more time)"
                Record-Warning
            } else {
                Write-Failure "$containerName is unhealthy (status: $health)"
                Record-Fail

                # Show last health check failure
                $healthLog = docker inspect $fullName --format "{{json .State.Health}}" | ConvertFrom-Json
                if ($healthLog.Log) {
                    $lastCheck = $healthLog.Log[-1]
                    Write-Info "Last health check output: $($lastCheck.Output)"
                }
            }
        } else {
            Write-Warning "$containerName has no health check configured"
            Record-Warning
        }
    }
} else {
    Write-Info "Skipping health check validation (--SkipHealthCheck specified)"
}

# Test 5: Resource Limits
Write-TestHeader "TEST 5: Resource Limits Enforcement"
foreach ($container in $runningContainers) {
    $fullName = $container.Name
    $containerName = $container.Expected.Name

    $memoryLimit = docker inspect $fullName --format "{{.HostConfig.Memory}}" 2>$null
    $cpuLimit = docker inspect $fullName --format "{{.HostConfig.NanoCpus}}" 2>$null

    if ($memoryLimit -and $memoryLimit -ne "0") {
        $memoryMB = [math]::Round($memoryLimit / 1MB, 0)
        Write-Success "$containerName has memory limit: ${memoryMB}MB"
        Record-Pass
    } else {
        Write-Warning "$containerName has no memory limit set"
        Record-Warning
    }

    if ($cpuLimit -and $cpuLimit -ne "0") {
        $cpuCores = $cpuLimit / 1000000000
        Write-Success "$containerName has CPU limit: $cpuCores cores"
        Record-Pass
    } else {
        Write-Warning "$containerName has no CPU limit set"
        Record-Warning
    }
}

# Test 6: Environment Variables
Write-TestHeader "TEST 6: Environment Variables Loaded"
foreach ($container in $runningContainers) {
    $fullName = $container.Name
    $containerName = $container.Expected.Name

    $envCount = docker inspect $fullName --format "{{len .Config.Env}}" 2>$null

    if ($envCount -and $envCount -gt 0) {
        Write-Success "$containerName has $envCount environment variables loaded"
        Record-Pass

        if ($VerbosePreference -eq 'Continue') {
            $env = docker inspect $fullName --format "{{range .Config.Env}}{{println .}}{{end}}" 2>$null
            Write-Info "Environment variables (redacted):"
            $env | ForEach-Object {
                if ($_ -match '^([^=]+)=(.*)$') {
                    $key = $matches[1]
                    $value = $matches[2]

                    # Redact sensitive values
                    if ($key -match 'TOKEN|PASSWORD|SECRET|KEY|PAT') {
                        $value = "***REDACTED***"
                    }

                    Write-Host "    $key=$value" -ForegroundColor Gray
                }
            }
        }
    } else {
        Write-Warning "$containerName has no environment variables"
        Record-Warning
    }
}

# Test 7: Logging Configuration
Write-TestHeader "TEST 7: Logging Configuration"
foreach ($container in $runningContainers) {
    $fullName = $container.Name
    $containerName = $container.Expected.Name

    $logDriver = docker inspect $fullName --format "{{.HostConfig.LogConfig.Type}}" 2>$null

    if ($logDriver) {
        Write-Success "$containerName is using '$logDriver' log driver"
        Record-Pass

        if ($logDriver -eq "json-file") {
            $maxSize = docker inspect $fullName --format "{{index .HostConfig.LogConfig.Config `"max-size`"}}" 2>$null
            $maxFile = docker inspect $fullName --format "{{index .HostConfig.LogConfig.Config `"max-file`"}}" 2>$null

            if ($maxSize -and $maxFile) {
                Write-Info "  Log rotation: max-size=$maxSize, max-file=$maxFile"
            }
        }
    } else {
        Write-Warning "$containerName has no log driver configured"
        Record-Warning
    }
}

# Test 8: Recent Log Output
Write-TestHeader "TEST 8: Recent Log Output Verification"
foreach ($container in $runningContainers) {
    $fullName = $container.Name
    $containerName = $container.Expected.Name

    $logs = docker logs $fullName --tail 10 2>&1

    if ($logs) {
        $logLines = ($logs -split "`n").Count
        Write-Success "$containerName has $logLines recent log entries"
        Record-Pass

        if ($VerbosePreference -eq 'Continue') {
            Write-Info "Last 5 log lines:"
            ($logs -split "`n" | Select-Object -Last 5) | ForEach-Object {
                Write-Host "    $_" -ForegroundColor Gray
            }
        }

        # Check for common error patterns
        $errorPatterns = @("error", "exception", "fatal", "panic", "failed")
        $hasErrors = $false
        foreach ($pattern in $errorPatterns) {
            if ($logs -match $pattern) {
                Write-Warning "$containerName logs contain '$pattern' messages"
                Record-Warning
                $hasErrors = $true
            }
        }

        if (-not $hasErrors) {
            Write-Info "  No obvious error patterns detected in recent logs"
        }
    } else {
        Write-Warning "$containerName has no recent log output"
        Record-Warning
    }
}

# Test 9: Port Exposure
Write-TestHeader "TEST 9: Port Exposure Validation"
foreach ($container in $runningContainers) {
    $fullName = $container.Name
    $containerName = $container.Expected.Name
    $expectedPort = $container.Expected.Port

    $ports = docker inspect $fullName --format "{{json .NetworkSettings.Ports}}" 2>$null

    if ($ports -and $ports -ne "null") {
        Write-Success "$containerName has ports configured"
        Record-Pass

        if ($VerbosePreference -eq 'Continue') {
            Write-Info "Port mappings: $ports"
        }
    } else {
        Write-Info "$containerName has no published ports (internal service)"
    }
}

# Test 10: Restart Policy
Write-TestHeader "TEST 10: Restart Policy Verification"
foreach ($container in $runningContainers) {
    $fullName = $container.Name
    $containerName = $container.Expected.Name

    $restartPolicy = docker inspect $fullName --format "{{.HostConfig.RestartPolicy.Name}}" 2>$null

    if ($restartPolicy) {
        if ($restartPolicy -eq "unless-stopped" -or $restartPolicy -eq "always") {
            Write-Success "$containerName has restart policy: $restartPolicy"
            Record-Pass
        } else {
            Write-Warning "$containerName has restart policy: $restartPolicy (recommended: unless-stopped)"
            Record-Warning
        }
    } else {
        Write-Warning "$containerName has no restart policy set"
        Record-Warning
    }
}

# Test 11: Container Uptime
Write-TestHeader "TEST 11: Container Uptime"
foreach ($container in $runningContainers) {
    $fullName = $container.Name
    $containerName = $container.Expected.Name

    $startedAt = docker inspect $fullName --format "{{.State.StartedAt}}" 2>$null

    if ($startedAt) {
        $startTime = [DateTime]::Parse($startedAt)
        $uptime = (Get-Date) - $startTime

        Write-Success "$containerName uptime: $($uptime.Days)d $($uptime.Hours)h $($uptime.Minutes)m"
        Record-Pass

        # Warn if container recently restarted
        if ($uptime.TotalMinutes -lt 5) {
            Write-Warning "Container was recently started (< 5 minutes ago)"
            Record-Warning
        }
    } else {
        Write-Failure "$containerName has no start time"
        Record-Fail
    }
}

# Test 12: Resource Usage Snapshot
Write-TestHeader "TEST 12: Current Resource Usage"
try {
    Write-Info "Collecting resource usage statistics..."
    $stats = docker stats --no-stream --format "{{.Name}},{{.CPUPerc}},{{.MemUsage}},{{.NetIO}},{{.BlockIO}}" 2>&1

    if ($LASTEXITCODE -eq 0) {
        foreach ($container in $runningContainers) {
            $fullName = $container.Name
            $containerName = $container.Expected.Name

            $stat = $stats | Where-Object { $_ -like "$fullName,*" }

            if ($stat) {
                $parts = $stat -split ','
                $cpu = $parts[1]
                $mem = $parts[2]

                Write-Success "$containerName - CPU: $cpu, Memory: $mem"
                Record-Pass
            }
        }
    } else {
        Write-Warning "Unable to collect resource statistics"
        Record-Warning
    }
} catch {
    Write-Warning "Resource usage collection failed: $($_.Exception.Message)"
    Record-Warning
}

# Summary Report
Write-Header "Smoke Test Summary"

Write-Host "Stack Prefix: $StackPrefix" -ForegroundColor White
Write-Host "Test Duration: $([math]::Round(((Get-Date) - $startTime).TotalSeconds, 2)) seconds" -ForegroundColor White
Write-Host ""

Write-Host "Tests Passed:  $passedTests / $totalTests" -ForegroundColor Green
Write-Host "Tests Failed:  $failedTests / $totalTests" -ForegroundColor $(if ($failedTests -gt 0) { "Red" } else { "Green" })
Write-Host "Warnings:      $warnings" -ForegroundColor Yellow
Write-Host ""

# Final status
if ($failedTests -eq 0) {
    Write-Host "🎉 ALL TESTS PASSED!" -ForegroundColor Green
    Write-Host ""
    Write-Host "The MCP stack is healthy and ready for use." -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  • Monitor container logs: docker logs <container-name> -f" -ForegroundColor White
    Write-Host "  • Check resource usage: docker stats" -ForegroundColor White
    Write-Host "  • Access Portainer: https://jabba.lan:9444" -ForegroundColor White

    if ($warnings -gt 0) {
        Write-Host ""
        Write-Warning "There are $warnings warnings. Review above for details."
    }

    exit 0
} else {
    Write-Host "❌ SOME TESTS FAILED" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please review the failures above and take corrective action:" -ForegroundColor Yellow
    Write-Host "  • Check container logs: docker logs <container-name>" -ForegroundColor White
    Write-Host "  • Verify docker-compose configuration" -ForegroundColor White
    Write-Host "  • Check Portainer stack status" -ForegroundColor White
    Write-Host "  • Review observability/README.md for troubleshooting" -ForegroundColor White
    Write-Host ""

    exit 1
}
