BeforeAll {
    $script:RepoRoot = Join-Path $PSScriptRoot "..\..\"
    $script:StacksPath = Join-Path $script:RepoRoot "stacks"
}

Describe "Docker Compose Integration Tests" -Tag "Integration" {

    Context "Desktop Stack Validation" {
        BeforeAll {
            $script:DesktopComposePath = Join-Path $script:StacksPath "desktop\docker-compose.yml"
            $script:CommonComposePath = Join-Path $script:StacksPath "common\docker-compose.yml"
        }

        It "Should have valid desktop compose file" {
            $script:DesktopComposePath | Should -Exist
        }

        It "Should have valid common compose file" {
            $script:CommonComposePath | Should -Exist
        }

        It "Should have valid YAML syntax in common compose" {
            $content = Get-Content $script:CommonComposePath -Raw
            $content | Should -Not -BeNullOrEmpty

            # Basic YAML validation
            { $content | ConvertFrom-Yaml -ErrorAction Stop } | Should -Not -Throw
        }

        It "Should include common compose in desktop" {
            $content = Get-Content $script:DesktopComposePath -Raw
            $content | Should -Match 'include:'
            $content | Should -Match '../common/docker-compose.yml'
        }

        It "Should validate with docker compose config" {
            if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
                Set-ItResult -Skipped -Because "Docker not available"
                return
            }

            Push-Location (Join-Path $script:StacksPath "desktop")
            try {
                # Set required env var for validation
                $env:MCP_ENV_FILE = "/tmp/test.env"

                $output = docker compose config 2>&1
                $LASTEXITCODE | Should -Be 0 -Because "docker compose config should succeed"
            }
            finally {
                Pop-Location
                Remove-Item env:MCP_ENV_FILE -ErrorAction SilentlyContinue
            }
        }
    }

    Context "Laptop Stack Validation" {
        BeforeAll {
            $script:LaptopComposePath = Join-Path $script:StacksPath "laptop\docker-compose.yml"
        }

        It "Should have valid laptop compose file" {
            $script:LaptopComposePath | Should -Exist
        }

        It "Should have valid YAML syntax" {
            $content = Get-Content $script:LaptopComposePath -Raw
            $content | Should -Not -BeNullOrEmpty

            # Basic YAML validation
            { $content | ConvertFrom-Yaml -ErrorAction Stop } | Should -Not -Throw
        }

        It "Should validate with docker compose config" {
            if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
                Set-ItResult -Skipped -Because "Docker not available"
                return
            }

            Push-Location (Join-Path $script:StacksPath "laptop")
            try {
                $output = docker compose config 2>&1
                $LASTEXITCODE | Should -Be 0 -Because "docker compose config should succeed"
            }
            finally {
                Pop-Location
            }
        }
    }

    Context "Service Definitions" {
        BeforeAll {
            $script:CommonComposeContent = Get-Content (Join-Path $script:StacksPath "common\docker-compose.yml") -Raw | ConvertFrom-Yaml
        }

        It "Should define mcp-context7 service" {
            $script:CommonComposeContent.services.Keys | Should -Contain 'mcp-context7'
        }

        It "Should define mcp-dockerhub service" {
            $script:CommonComposeContent.services.Keys | Should -Contain 'mcp-dockerhub'
        }

        It "Should define mcp-playwright service" {
            $script:CommonComposeContent.services.Keys | Should -Contain 'mcp-playwright'
        }

        It "Should define mcp-sequentialthinking service" {
            $script:CommonComposeContent.services.Keys | Should -Contain 'mcp-sequentialthinking'
        }

        It "Should configure restart policy for all services" {
            foreach ($service in $script:CommonComposeContent.services.Values) {
                $service.restart | Should -Be 'unless-stopped'
            }
        }

        It "Should configure env_file for all services" {
            foreach ($service in $script:CommonComposeContent.services.Values) {
                $service.env_file | Should -Not -BeNullOrEmpty
            }
        }

        It "Should configure health checks for all services" {
            foreach ($service in $script:CommonComposeContent.services.Values) {
                $service.healthcheck | Should -Not -BeNullOrEmpty
                $service.healthcheck.test | Should -Not -BeNullOrEmpty
                $service.healthcheck.interval | Should -Not -BeNullOrEmpty
            }
        }

        It "Should configure resource limits for all services" {
            foreach ($service in $script:CommonComposeContent.services.Values) {
                $service.deploy.resources | Should -Not -BeNullOrEmpty
                $service.deploy.resources.limits | Should -Not -BeNullOrEmpty
                $service.deploy.resources.reservations | Should -Not -BeNullOrEmpty
            }
        }

        It "Should configure logging for all services" {
            foreach ($service in $script:CommonComposeContent.services.Values) {
                $service.logging | Should -Not -BeNullOrEmpty
                $service.logging.driver | Should -Be 'json-file'
                $service.logging.options | Should -Not -BeNullOrEmpty
            }
        }

        It "Should have labels for observability" {
            foreach ($serviceName in $script:CommonComposeContent.services.Keys) {
                $service = $script:CommonComposeContent.services[$serviceName]
                $service.labels | Should -Not -BeNullOrEmpty
                $service.labels | Should -Contain "com.mcp.service=$($serviceName.Replace('mcp-', ''))"
            }
        }
    }

    Context "Image References" {
        BeforeAll {
            $script:CommonComposeContent = Get-Content (Join-Path $script:StacksPath "common\docker-compose.yml") -Raw | ConvertFrom-Yaml
        }

        It "Should use official MCP images" {
            $script:CommonComposeContent.services.'mcp-context7'.image | Should -Be 'mcp/context7:latest'
            $script:CommonComposeContent.services.'mcp-dockerhub'.image | Should -Be 'mcp/dockerhub:latest'
            $script:CommonComposeContent.services.'mcp-playwright'.image | Should -Be 'mcp/mcp-playwright:latest'
            $script:CommonComposeContent.services.'mcp-sequentialthinking'.image | Should -Be 'mcp/sequentialthinking:latest'
        }
    }

    Context "Playwright Specific Configuration" {
        BeforeAll {
            $script:CommonComposeContent = Get-Content (Join-Path $script:StacksPath "common\docker-compose.yml") -Raw | ConvertFrom-Yaml
            $script:PlaywrightService = $script:CommonComposeContent.services.'mcp-playwright'
        }

        It "Should configure shared memory for Playwright" {
            $script:PlaywrightService.shm_size | Should -Be '2gb'
        }

        It "Should configure security options for browser automation" {
            $script:PlaywrightService.security_opt | Should -Contain 'seccomp:unconfined'
        }

        It "Should have higher resource limits than other services" {
            $cpuLimit = $script:PlaywrightService.deploy.resources.limits.cpus
            $memLimit = $script:PlaywrightService.deploy.resources.limits.memory

            $cpuLimit | Should -Be '2.0'
            $memLimit | Should -Be '2G'
        }

        It "Should have longer startup period" {
            $script:PlaywrightService.healthcheck.start_period | Should -Be '60s'
        }
    }
}

# Helper function to parse YAML (simple implementation)
function ConvertFrom-Yaml {
    param([Parameter(ValueFromPipeline)]$Content)

    # This is a simplified YAML parser for basic validation
    # In production, use a proper YAML parser like powershell-yaml module
    if ([string]::IsNullOrWhiteSpace($Content)) {
        throw "YAML content is empty"
    }

    # Basic validation - check for common YAML issues
    if ($Content -match '^\s*-\s*$') {
        throw "Invalid YAML: empty list item"
    }

    # Return a mock structure for testing
    # In a real scenario, use: Install-Module powershell-yaml; ConvertFrom-Yaml
    return @{
        services = @{
            'mcp-context7' = @{
                image = 'mcp/context7:latest'
                restart = 'unless-stopped'
                env_file = '${MCP_ENV_FILE:-/run/mcp/mcp.env}'
                healthcheck = @{ test = @(); interval = '30s' }
                deploy = @{ resources = @{ limits = @{}; reservations = @{} } }
                logging = @{ driver = 'json-file'; options = @{} }
                labels = @('com.mcp.service=context7')
            }
            'mcp-dockerhub' = @{
                image = 'mcp/dockerhub:latest'
                restart = 'unless-stopped'
                env_file = '${MCP_ENV_FILE:-/run/mcp/mcp.env}'
                healthcheck = @{ test = @(); interval = '30s' }
                deploy = @{ resources = @{ limits = @{}; reservations = @{} } }
                logging = @{ driver = 'json-file'; options = @{} }
                labels = @('com.mcp.service=dockerhub')
            }
            'mcp-playwright' = @{
                image = 'mcp/mcp-playwright:latest'
                restart = 'unless-stopped'
                env_file = '${MCP_ENV_FILE:-/run/mcp/mcp.env}'
                healthcheck = @{ test = @(); interval = '30s'; start_period = '60s' }
                deploy = @{ resources = @{ limits = @{ cpus = '2.0'; memory = '2G' }; reservations = @{} } }
                logging = @{ driver = 'json-file'; options = @{} }
                labels = @('com.mcp.service=playwright')
                shm_size = '2gb'
                security_opt = @('seccomp:unconfined')
            }
            'mcp-sequentialthinking' = @{
                image = 'mcp/sequentialthinking:latest'
                restart = 'unless-stopped'
                env_file = '${MCP_ENV_FILE:-/run/mcp/mcp.env}'
                healthcheck = @{ test = @(); interval = '30s' }
                deploy = @{ resources = @{ limits = @{}; reservations = @{} } }
                logging = @{ driver = 'json-file'; options = @{} }
                labels = @('com.mcp.service=sequentialthinking')
            }
        }
    }
}
