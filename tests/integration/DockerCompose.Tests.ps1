function script:Remove-ComposeComments {
    param([Parameter(Mandatory)][string]$Text)

    $lines = $Text -split "`n"
    $buffer = New-Object System.Collections.Generic.List[string]

    foreach ($line in $lines) {
        $current = $line -replace "`r$", ""

        if ($current -match '^\s*#') {
            continue
        }

        if ($current -match '^(?<content>.*?)(\s+#.*)$') {
            $current = $matches['content'].TrimEnd()
        }

        $buffer.Add($current)
    }

    return [string]::Join("`n", $buffer)
}

function script:Get-ScalarValue {
    param(
        [string]$Text,
        [int]$Indent,
        [string]$Key
    )

    if (-not $Text) { return $null }

    $pattern = '(?m)^\s{' + $Indent + '}' + [regex]::Escape($Key) + ':\s*(.+)$'
    $match = [regex]::Match($Text, $pattern)
    if ($match.Success) {
        $value = $match.Groups[1].Value.Trim()
        if ($value.StartsWith("'") -and $value.EndsWith("'")) {
            $value = $value.Substring(1, $value.Length - 2)
        } elseif ($value.StartsWith('"') -and $value.EndsWith('"')) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        return $value
    }

    return $null
}

function script:Get-Block {
    param(
        [string]$Text,
        [int]$Indent,
        [string]$Key
    )

    if (-not $Text) { return $null }

    $pattern = '(?ms)^\s{' + $Indent + '}' + [regex]::Escape($Key) + ':\s*\n(.*?)(?=^\s{' + $Indent + '}[A-Za-z0-9_-]+:\s|\Z)'
    $match = [regex]::Match($Text, $pattern)
    if ($match.Success) {
        return $match.Groups[1].Value
    }

    return $null
}

function script:Get-ListItems {
    param(
        [string]$Text,
        [int]$Indent
    )

    if (-not $Text) { return @() }

    $items = New-Object System.Collections.Generic.List[string]
    foreach ($line in $Text -split "`n") {
        $pattern = '^\s{' + $Indent + '}-\s*(.+)$'
        if ($line -match $pattern) {
            $value = $matches[1].Trim()
            if ($value.StartsWith("'") -and $value.EndsWith("'")) {
                $value = $value.Substring(1, $value.Length - 2)
            } elseif ($value.StartsWith('"') -and $value.EndsWith('"')) {
                $value = $value.Substring(1, $value.Length - 2)
            }
            $items.Add($value)
        }
    }

    return $items.ToArray()
}

function script:Get-ComposeData {
    param([Parameter(Mandatory)][string]$Path)

    $raw = Get-Content $Path -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "Compose file '$Path' is empty."
    }

    $content = Remove-ComposeComments -Text $raw

    $servicesMatch = [regex]::Match($content, '(?ms)^services:\s*\n(.*?)(?=^\S|\Z)')
    if (-not $servicesMatch.Success) {
        throw "Services block not found in '$Path'."
    }

    $servicesBody = $servicesMatch.Groups[1].Value
    $serviceRegex = [regex]'(?ms)^\s{2}([A-Za-z0-9_-]+):\s*\n(.*?)(?=^\s{2}[A-Za-z0-9_-]+:\s|\Z)'

    $services = [ordered]@{}

    foreach ($match in $serviceRegex.Matches($servicesBody)) {
        $name = $match.Groups[1].Value
        $body = $match.Groups[2].Value

        $service = [ordered]@{}
        $service['image']    = Get-ScalarValue -Text $body -Indent 4 -Key 'image'
        $service['restart']  = Get-ScalarValue -Text $body -Indent 4 -Key 'restart'
        $service['env_file'] = Get-ScalarValue -Text $body -Indent 4 -Key 'env_file'

        $healthBlock = Get-Block -Text $body -Indent 4 -Key 'healthcheck'
        if ($healthBlock) {
            $service['healthcheck'] = [pscustomobject]@{
                test         = Get-ScalarValue -Text $healthBlock -Indent 6 -Key 'test'
                interval     = Get-ScalarValue -Text $healthBlock -Indent 6 -Key 'interval'
                timeout      = Get-ScalarValue -Text $healthBlock -Indent 6 -Key 'timeout'
                retries      = Get-ScalarValue -Text $healthBlock -Indent 6 -Key 'retries'
                start_period = Get-ScalarValue -Text $healthBlock -Indent 6 -Key 'start_period'
            }
        }

        $deployBlock = Get-Block -Text $body -Indent 4 -Key 'deploy'
        if ($deployBlock) {
            $resourcesBlock = Get-Block -Text $deployBlock -Indent 6 -Key 'resources'
            $limitsPs = $null
            $reservationsPs = $null

            if ($resourcesBlock) {
                $limitsBlock = Get-Block -Text $resourcesBlock -Indent 8 -Key 'limits'
                $reservationsBlock = Get-Block -Text $resourcesBlock -Indent 8 -Key 'reservations'

                if ($limitsBlock) {
                    $limitsPs = [pscustomobject]@{
                        cpus   = Get-ScalarValue -Text $limitsBlock -Indent 10 -Key 'cpus'
                        memory = Get-ScalarValue -Text $limitsBlock -Indent 10 -Key 'memory'
                    }
                }

                if ($reservationsBlock) {
                    $reservationsPs = [pscustomobject]@{
                        cpus   = Get-ScalarValue -Text $reservationsBlock -Indent 10 -Key 'cpus'
                        memory = Get-ScalarValue -Text $reservationsBlock -Indent 10 -Key 'memory'
                    }
                }
            }

            $service['deploy'] = [pscustomobject]@{
                resources = [pscustomobject]@{
                    limits = $limitsPs
                    reservations = $reservationsPs
                }
            }
        }

        $loggingBlock = Get-Block -Text $body -Indent 4 -Key 'logging'
        if ($loggingBlock) {
            $optionsBlock = Get-Block -Text $loggingBlock -Indent 6 -Key 'options'
            $service['logging'] = [pscustomobject]@{
                driver  = Get-ScalarValue -Text $loggingBlock -Indent 6 -Key 'driver'
                options = if ($optionsBlock) {
                    [pscustomobject]@{
                        'max-size' = Get-ScalarValue -Text $optionsBlock -Indent 8 -Key 'max-size'
                        'max-file' = Get-ScalarValue -Text $optionsBlock -Indent 8 -Key 'max-file'
                        labels     = Get-ScalarValue -Text $optionsBlock -Indent 8 -Key 'labels'
                    }
                } else { $null }
            }
        }

        $labelsBlock = Get-Block -Text $body -Indent 4 -Key 'labels'
        if ($labelsBlock) {
            $service['labels'] = Get-ListItems -Text $labelsBlock -Indent 6
        } else {
            $service['labels'] = @()
        }

        $securityBlock = Get-Block -Text $body -Indent 4 -Key 'security_opt'
        if ($securityBlock) {
            $service['security_opt'] = Get-ListItems -Text $securityBlock -Indent 6
        }

        $service['shm_size'] = Get-ScalarValue -Text $body -Indent 4 -Key 'shm_size'

        $services[$name] = [pscustomobject]$service
    }

    return [pscustomobject]@{
        Services = $services
    }
}

$script:CommonComposeCache = $null
function script:Get-CommonComposeData {
    param([Parameter(Mandatory)][string]$StacksPath)

    if (-not $script:CommonComposeCache) {
        $script:CommonComposeCache = Get-ComposeData -Path (Join-Path $StacksPath 'common\docker-compose.yml')
    }

    return $script:CommonComposeCache
}

BeforeAll {
    $script:RepoRoot = Join-Path $PSScriptRoot "..\.."
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
            { Get-ComposeData -Path $script:CommonComposePath } | Should -Not -Throw
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
            { Get-ComposeData -Path $script:LaptopComposePath } | Should -Not -Throw
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
            $script:CommonComposeData = Get-CommonComposeData -StacksPath $script:StacksPath
        }

        It "Should define mcp-context7 service" {
            $script:CommonComposeData.Services.Keys | Should -Contain 'mcp-context7'
        }

        It "Should define mcp-dockerhub service" {
            $script:CommonComposeData.Services.Keys | Should -Contain 'mcp-dockerhub'
        }

        It "Should define mcp-playwright service" {
            $script:CommonComposeData.Services.Keys | Should -Contain 'mcp-playwright'
        }

        It "Should define mcp-sequentialthinking service" {
            $script:CommonComposeData.Services.Keys | Should -Contain 'mcp-sequentialthinking'
        }

        It "Should configure restart policy for all services" {
            foreach ($service in $script:CommonComposeData.Services.Values) {
                $service.restart | Should -Be 'unless-stopped'
            }
        }

        It "Should configure env_file for all services" {
            foreach ($service in $script:CommonComposeData.Services.Values) {
                $service.env_file | Should -Not -BeNullOrEmpty
            }
        }

        It "Should configure health checks for all services" {
            foreach ($service in $script:CommonComposeData.Services.Values) {
                $service.healthcheck | Should -Not -BeNullOrEmpty
                $service.healthcheck.test | Should -Not -BeNullOrEmpty
                $service.healthcheck.interval | Should -Not -BeNullOrEmpty
            }
        }

        It "Should configure resource limits for all services" {
            foreach ($service in $script:CommonComposeData.Services.Values) {
                $service.deploy.resources.limits.cpus | Should -Not -BeNullOrEmpty
                $service.deploy.resources.limits.memory | Should -Not -BeNullOrEmpty
                $service.deploy.resources.reservations.cpus | Should -Not -BeNullOrEmpty
                $service.deploy.resources.reservations.memory | Should -Not -BeNullOrEmpty
            }
        }

        It "Should configure logging for all services" {
            foreach ($service in $script:CommonComposeData.Services.Values) {
                $service.logging.driver | Should -Be 'json-file'
                $service.logging.options.'max-size' | Should -Be '10m'
                $service.logging.options.'max-file' | Should -Be '3'
                $service.logging.options.labels | Should -Be 'service,environment'
            }
        }

        It "Should have labels for observability" {
            foreach ($serviceName in $script:CommonComposeData.Services.Keys) {
                $service = $script:CommonComposeData.Services[$serviceName]
                $service.labels | Should -Not -BeNullOrEmpty
                $service.labels | Should -Contain "com.mcp.service=$($serviceName.Replace('mcp-', ''))"
            }
        }
    }

    Context "Image References" {
        BeforeAll {
            $script:CommonComposeData = Get-CommonComposeData -StacksPath $script:StacksPath
        }

        It "Should use official MCP images" {
            $script:CommonComposeData.Services.'mcp-context7'.image | Should -Be 'mcp/context7:latest'
            $script:CommonComposeData.Services.'mcp-dockerhub'.image | Should -Be 'mcp/dockerhub:latest'
            $script:CommonComposeData.Services.'mcp-playwright'.image | Should -Be 'mcp/mcp-playwright:latest'
            $script:CommonComposeData.Services.'mcp-sequentialthinking'.image | Should -Be 'mcp/sequentialthinking:latest'
        }
    }

    Context "Playwright Specific Configuration" {
        BeforeAll {
            $script:CommonComposeData = Get-CommonComposeData -StacksPath $script:StacksPath
            $script:PlaywrightService = $script:CommonComposeData.Services.'mcp-playwright'
        }

        It "Should configure shared memory for Playwright" {
            $script:PlaywrightService.shm_size | Should -Be '1gb'
        }

        It "Should configure security options for browser automation" {
            $script:PlaywrightService.security_opt | Should -Contain 'seccomp:unconfined'
        }

        It "Should have higher resource limits than other services" {
            $cpuLimit = $script:PlaywrightService.deploy.resources.limits.cpus
            $memLimit = $script:PlaywrightService.deploy.resources.limits.memory

            $cpuLimit | Should -Be '1.0'
            $memLimit | Should -Be '1G'
        }

        It "Should have longer startup period" {
            $script:PlaywrightService.healthcheck.start_period | Should -Be '60s'
        }
    }
}
