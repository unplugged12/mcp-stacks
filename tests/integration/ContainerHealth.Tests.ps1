BeforeAll {
    $script:ExpectedContainers = @(
        "mcp-context7",
        "mcp-dockerhub",
        "mcp-playwright",
        "mcp-sequentialthinking"
    )
}

Describe "Container Health Integration Tests" -Tag "Integration" {

    BeforeAll {
        # Check if Docker is available
        $dockerAvailable = $null -ne (Get-Command docker -ErrorAction SilentlyContinue)
        if (-not $dockerAvailable) {
            Write-Warning "Docker not available - tests will be skipped"
        }
        $script:DockerAvailable = $dockerAvailable
    }

    Context "Container Running State" {
        It "Should have Docker available" {
            if (-not $script:DockerAvailable) {
                Set-ItResult -Skipped -Because "Docker not available"
                return
            }
            Get-Command docker | Should -Not -BeNullOrEmpty
        }

        It "Should query running containers" {
            if (-not $script:DockerAvailable) {
                Set-ItResult -Skipped -Because "Docker not available"
                return
            }

            $output = docker ps --format "{{.Names}}" 2>&1
            $LASTEXITCODE | Should -Be 0
        }

        It "Should find MCP containers (if deployed)" {
            if (-not $script:DockerAvailable) {
                Set-ItResult -Skipped -Because "Docker not available"
                return
            }

            $runningContainers = docker ps --format "{{.Names}}" | Where-Object { $_ -match "mcp-" }

            if ($runningContainers) {
                $runningContainers.Count | Should -BeGreaterThan 0
            } else {
                Set-ItResult -Skipped -Because "No MCP containers running"
            }
        }
    }

    Context "Health Check Status" {
        BeforeEach {
            if (-not $script:DockerAvailable) {
                Set-ItResult -Skipped -Because "Docker not available"
                return
            }
        }

        It "Should verify health status for each container" {
            $runningContainers = docker ps --filter "name=mcp-" --format "{{.Names}}"

            if (-not $runningContainers) {
                Set-ItResult -Skipped -Because "No MCP containers running"
                return
            }

            foreach ($container in $runningContainers) {
                $health = docker inspect $container --format "{{.State.Health.Status}}" 2>$null

                if ($health -and $health -ne "<no value>") {
                    $health | Should -BeIn @("starting", "healthy", "unhealthy")
                }
            }
        }

        It "Should have containers in healthy or starting state" {
            $runningContainers = docker ps --filter "name=mcp-" --format "{{.Names}}"

            if (-not $runningContainers) {
                Set-ItResult -Skipped -Because "No MCP containers running"
                return
            }

            foreach ($container in $runningContainers) {
                $health = docker inspect $container --format "{{.State.Health.Status}}" 2>$null

                if ($health -and $health -ne "<no value>") {
                    $health | Should -Not -Be "unhealthy" -Because "Container $container should be healthy or starting"
                }
            }
        }
    }

    Context "Container Resource Usage" {
        BeforeEach {
            if (-not $script:DockerAvailable) {
                Set-ItResult -Skipped -Because "Docker not available"
                return
            }
        }

        It "Should report container stats" {
            $runningContainers = docker ps --filter "name=mcp-" --format "{{.Names}}"

            if (-not $runningContainers) {
                Set-ItResult -Skipped -Because "No MCP containers running"
                return
            }

            foreach ($container in $runningContainers) {
                $stats = docker stats $container --no-stream --format "{{.MemUsage}}" 2>$null
                $stats | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context "Container Configuration" {
        BeforeEach {
            if (-not $script:DockerAvailable) {
                Set-ItResult -Skipped -Because "Docker not available"
                return
            }
        }

        It "Should have restart policy configured" {
            $runningContainers = docker ps --filter "name=mcp-" --format "{{.Names}}"

            if (-not $runningContainers) {
                Set-ItResult -Skipped -Because "No MCP containers running"
                return
            }

            foreach ($container in $runningContainers) {
                $restartPolicy = docker inspect $container --format "{{.HostConfig.RestartPolicy.Name}}"
                $restartPolicy | Should -BeIn @("unless-stopped", "always")
            }
        }

        It "Should have environment variables configured" {
            $runningContainers = docker ps --filter "name=mcp-" --format "{{.Names}}"

            if (-not $runningContainers) {
                Set-ItResult -Skipped -Because "No MCP containers running"
                return
            }

            foreach ($container in $runningContainers) {
                $envCount = docker inspect $container --format "{{len .Config.Env}}"
                [int]$envCount | Should -BeGreaterThan 0
            }
        }

        It "Should have proper labels for observability" {
            $runningContainers = docker ps --filter "name=mcp-" --format "{{.Names}}"

            if (-not $runningContainers) {
                Set-ItResult -Skipped -Because "No MCP containers running"
                return
            }

            foreach ($container in $runningContainers) {
                $labels = docker inspect $container --format "{{json .Config.Labels}}" | ConvertFrom-Json

                if ($labels) {
                    $labels.PSObject.Properties.Name | Should -Contain 'com.mcp.service'
                }
            }
        }
    }

    Context "Container Logs" {
        BeforeEach {
            if (-not $script:DockerAvailable) {
                Set-ItResult -Skipped -Because "Docker not available"
                return
            }
        }

        It "Should be able to retrieve container logs" {
            $runningContainers = docker ps --filter "name=mcp-" --format "{{.Names}}"

            if (-not $runningContainers) {
                Set-ItResult -Skipped -Because "No MCP containers running"
                return
            }

            foreach ($container in $runningContainers) {
                { docker logs $container --tail 10 2>&1 } | Should -Not -Throw
            }
        }

        It "Should not have critical errors in recent logs" {
            $runningContainers = docker ps --filter "name=mcp-" --format "{{.Names}}"

            if (-not $runningContainers) {
                Set-ItResult -Skipped -Because "No MCP containers running"
                return
            }

            foreach ($container in $runningContainers) {
                $logs = docker logs $container --tail 50 2>&1 | Out-String

                # Check for common critical errors
                $logs | Should -Not -Match "FATAL"
                $logs | Should -Not -Match "panic:"
                $logs | Should -Not -Match "Exception in thread"
            }
        }
    }

    Context "Playwright Specific Health Checks" {
        BeforeEach {
            if (-not $script:DockerAvailable) {
                Set-ItResult -Skipped -Because "Docker not available"
                return
            }
        }

        It "Should have shared memory configured for Playwright" {
            $playwrightContainer = docker ps --filter "name=mcp-playwright" --format "{{.Names}}"

            if (-not $playwrightContainer) {
                Set-ItResult -Skipped -Because "Playwright container not running"
                return
            }

            $shmSize = docker inspect $playwrightContainer --format "{{.HostConfig.ShmSize}}"
            [long]$shmSize | Should -BeGreaterThan 1GB
        }

        It "Should have security options for browser automation" {
            $playwrightContainer = docker ps --filter "name=mcp-playwright" --format "{{.Names}}"

            if (-not $playwrightContainer) {
                Set-ItResult -Skipped -Because "Playwright container not running"
                return
            }

            $securityOpt = docker inspect $playwrightContainer --format "{{json .HostConfig.SecurityOpt}}"
            $securityOpt | Should -Match "seccomp"
        }
    }
}
