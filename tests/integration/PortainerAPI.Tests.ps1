BeforeAll {
    # Load test fixtures
    $script:FixturesPath = Join-Path $PSScriptRoot "..\fixtures"
    $script:MocksPath = Join-Path $PSScriptRoot "..\mocks"

    # Configuration
    $script:PortainerUrl = $env:TEST_PORTAINER_URL ?? "http://localhost:9444"
    $script:UseMockAPI = $env:USE_MOCK_API ?? $true
}

Describe "Portainer API Integration Tests" -Tag "Integration" {

    Context "API Authentication" {
        BeforeAll {
            if ($script:UseMockAPI) {
                Mock Invoke-RestMethod {
                    param($Uri, $Method, $Body, $Headers)

                    if ($Uri -match "/api/auth") {
                        return @{ jwt = "mock-jwt-token-12345" }
                    }
                }
            }
        }

        It "Should authenticate with valid credentials" {
            $authBody = @{
                username = "admin"
                password = "testpassword"
            } | ConvertTo-Json

            $response = Invoke-RestMethod `
                -Uri "$script:PortainerUrl/api/auth" `
                -Method Post `
                -Body $authBody `
                -ContentType "application/json"

            $response.jwt | Should -Not -BeNullOrEmpty
        }

        It "Should reject invalid credentials" {
            if (-not $script:UseMockAPI) {
                Set-ItResult -Skipped -Because "Requires mock API"
                return
            }

            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new("Unauthorized")
            }

            {
                Invoke-RestMethod `
                    -Uri "$script:PortainerUrl/api/auth" `
                    -Method Post `
                    -Body (@{ username = "invalid"; password = "wrong" } | ConvertTo-Json) `
                    -ContentType "application/json"
            } | Should -Throw
        }
    }

    Context "Stack Operations" {
        BeforeAll {
            $script:ApiKey = "ptr_mock_api_key"
            $script:Headers = @{
                "X-API-Key" = $script:ApiKey
                "Content-Type" = "application/json"
            }

            if ($script:UseMockAPI) {
                Mock Invoke-RestMethod {
                    param($Uri, $Method, $Body, $Headers)

                    if ($Uri -match "/api/stacks$") {
                        $mockStacks = Get-Content "$script:FixturesPath/mock-stacks.json" -Raw | ConvertFrom-Json
                        return $mockStacks
                    }

                    if ($Uri -match "/api/stacks/(\d+)$") {
                        $stackId = $Matches[1]
                        return @{
                            Id = [int]$stackId
                            Name = "mcp-desktop-$stackId"
                            Status = 1
                        }
                    }

                    if ($Uri -match "/api/stacks/(\d+)/git/redeploy") {
                        return @{
                            Id = [int]$Matches[1]
                            Message = "Stack redeployed successfully"
                        }
                    }
                }
            }
        }

        It "Should list all stacks" {
            $stacks = Invoke-RestMethod `
                -Uri "$script:PortainerUrl/api/stacks" `
                -Headers $script:Headers `
                -Method Get

            $stacks | Should -Not -BeNullOrEmpty
            $stacks.Count | Should -BeGreaterThan 0
        }

        It "Should get specific stack by ID" {
            $stackId = 1
            $stack = Invoke-RestMethod `
                -Uri "$script:PortainerUrl/api/stacks/$stackId" `
                -Headers $script:Headers `
                -Method Get

            $stack.Id | Should -Be $stackId
        }

        It "Should trigger stack redeploy from Git" {
            $stackId = 1
            $endpointId = 1

            $body = @{
                RepositoryAuthentication = $false
                RepositoryReferenceName = "refs/heads/main"
                Prune = $false
                PullImage = $true
            } | ConvertTo-Json

            $response = Invoke-RestMethod `
                -Uri "$script:PortainerUrl/api/stacks/$stackId/git/redeploy?endpointId=$endpointId" `
                -Headers $script:Headers `
                -Method Put `
                -Body $body

            $response | Should -Not -BeNullOrEmpty
        }
    }

    Context "Edge Stack Operations" {
        BeforeAll {
            if ($script:UseMockAPI) {
                Mock Invoke-RestMethod {
                    param($Uri, $Method, $Body, $Headers)

                    if ($Uri -match "/api/edge_stacks$") {
                        $mockEdgeStacks = Get-Content "$script:FixturesPath/mock-edge-stacks.json" -Raw | ConvertFrom-Json
                        return $mockEdgeStacks
                    }

                    if ($Uri -match "/api/edge_stacks/(\d+)$") {
                        $stackId = $Matches[1]
                        return @{
                            Id = [int]$stackId
                            Name = "mcp-laptop-$stackId"
                            EdgeGroups = @(1)
                        }
                    }
                }
            }
        }

        It "Should list all edge stacks" {
            $edgeStacks = Invoke-RestMethod `
                -Uri "$script:PortainerUrl/api/edge_stacks" `
                -Headers $script:Headers `
                -Method Get

            $edgeStacks | Should -Not -BeNullOrEmpty
        }

        It "Should get specific edge stack by ID" {
            $edgeStackId = 1
            $edgeStack = Invoke-RestMethod `
                -Uri "$script:PortainerUrl/api/edge_stacks/$edgeStackId" `
                -Headers $script:Headers `
                -Method Get

            $edgeStack.Id | Should -Be $edgeStackId
            $edgeStack.EdgeGroups | Should -Not -BeNullOrEmpty
        }
    }

    Context "Environment Operations" {
        BeforeAll {
            if ($script:UseMockAPI) {
                Mock Invoke-RestMethod {
                    param($Uri, $Method, $Body, $Headers)

                    if ($Uri -match "/api/endpoints$") {
                        $mockEndpoints = Get-Content "$script:FixturesPath/mock-endpoints.json" -Raw | ConvertFrom-Json
                        return $mockEndpoints
                    }
                }
            }
        }

        It "Should list all environments" {
            $endpoints = Invoke-RestMethod `
                -Uri "$script:PortainerUrl/api/endpoints" `
                -Headers $script:Headers `
                -Method Get

            $endpoints | Should -Not -BeNullOrEmpty
        }

        It "Should filter Agent environments" {
            $endpoints = Invoke-RestMethod `
                -Uri "$script:PortainerUrl/api/endpoints" `
                -Headers $script:Headers `
                -Method Get

            $agentEndpoints = $endpoints | Where-Object { $_.Type -eq 1 }
            $agentEndpoints | Should -Not -BeNullOrEmpty
        }

        It "Should filter Edge environments" {
            $endpoints = Invoke-RestMethod `
                -Uri "$script:PortainerUrl/api/endpoints" `
                -Headers $script:Headers `
                -Method Get

            $edgeEndpoints = $endpoints | Where-Object { $_.Type -eq 4 }
            $edgeEndpoints | Should -Not -BeNullOrEmpty
        }
    }
}
