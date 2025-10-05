# MCP Stacks Test Suite

Comprehensive test suite for the mcp-stacks deployment infrastructure, including unit tests, integration tests, and mock API server for offline testing.

## Table of Contents

- [Overview](#overview)
- [Test Structure](#test-structure)
- [Running Tests](#running-tests)
- [Coverage Thresholds](#coverage-thresholds)
- [Mock API Server](#mock-api-server)
- [CI/CD Integration](#cicd-integration)
- [Writing Tests](#writing-tests)

## Overview

The test suite provides:

- **Unit Tests**: Pester-based tests for PowerShell scripts
- **Integration Tests**: End-to-end validation of Portainer API, Docker Compose, and container health
- **Mock API Server**: Standalone HTTP server mocking Portainer API for offline testing
- **Test Fixtures**: Realistic mock data for stacks, edge stacks, and endpoints
- **Coverage Reporting**: Automated test coverage analysis

## Test Structure

```
tests/
├── unit/                           # Unit tests for individual scripts
│   ├── BuildEdgeConfig.Tests.ps1   # Edge config builder tests
│   ├── RedeployStack.Tests.ps1     # Stack redeploy API tests
│   ├── PreDeployCheck.Tests.ps1    # Pre-deployment validation tests
│   ├── PostDeployCheck.Tests.ps1   # Post-deployment validation tests
│   ├── InstallAgent.Tests.ps1      # Agent installation tests
│   ├── InstallEdgeAgent.Tests.ps1  # Edge agent installation tests
│   └── RollbackStack.Tests.ps1     # Stack rollback tests
├── integration/                    # Integration tests
│   ├── PortainerAPI.Tests.ps1      # Portainer API integration tests
│   ├── DockerCompose.Tests.ps1     # Compose file validation tests
│   └── ContainerHealth.Tests.ps1   # Container health check tests
├── mocks/                          # Mock API server
│   ├── portainer-api-mock.ps1      # Mock Portainer API HTTP server
│   └── README.md                   # Mock server documentation
├── fixtures/                       # Test data
│   ├── mock-stacks.json            # Mock stack definitions
│   ├── mock-edge-stacks.json       # Mock edge stack definitions
│   ├── mock-endpoints.json         # Mock endpoint definitions
│   └── README.md                   # Fixture documentation
└── README.md                       # This file
```

## Running Tests

### Prerequisites

Install Pester (PowerShell testing framework):

```powershell
Install-Module -Name Pester -Force -SkipPublisherCheck
```

### Run All Tests

```powershell
# From repository root
.\scripts\run-tests.ps1
```

### Run Specific Test Categories

```powershell
# Unit tests only
.\scripts\run-tests.ps1 -TestType Unit

# Integration tests only
.\scripts\run-tests.ps1 -TestType Integration

# Specific test file
Invoke-Pester .\tests\unit\BuildEdgeConfig.Tests.ps1

# With coverage
.\scripts\run-tests.ps1 -CodeCoverage
```

### Run Tests with Mock API

```powershell
# Start mock API server (in separate terminal)
.\tests\mocks\portainer-api-mock.ps1 -Port 9444

# Run integration tests with mock API
$env:USE_MOCK_API = $true
$env:TEST_PORTAINER_URL = "http://localhost:9444"
Invoke-Pester .\tests\integration\ -Output Detailed
```

### Run Tests in CI Mode

```powershell
# CI-friendly output with JUnit XML
.\scripts\run-tests.ps1 -CI
```

## Coverage Thresholds

The test suite enforces the following code coverage thresholds:

| Category | Threshold | Description |
|----------|-----------|-------------|
| **Overall** | 75% | Minimum overall code coverage |
| **Unit Tests** | 80% | PowerShell script coverage |
| **Integration Tests** | 70% | End-to-end workflow coverage |

### Viewing Coverage Reports

```powershell
# Generate coverage report
.\scripts\run-tests.ps1 -CodeCoverage

# View HTML report
Start-Process .\tests\coverage\index.html
```

Coverage reports are generated in `tests/coverage/`:
- `coverage.xml` - Cobertura format for CI
- `index.html` - Human-readable HTML report

## Mock API Server

The mock Portainer API server enables offline testing without a real Portainer instance.

### Features

- Mocks all critical Portainer API endpoints
- Uses realistic fixture data
- No authentication required (for simplicity)
- Runs on HTTP (not HTTPS)
- Suitable for CI/CD pipelines

### Starting the Mock Server

```powershell
.\tests\mocks\portainer-api-mock.ps1 -Port 9444
```

### Supported Endpoints

- `POST /api/auth` - Authentication (returns mock JWT)
- `GET /api/stacks` - List all stacks
- `GET /api/stacks/{id}` - Get specific stack
- `PUT /api/stacks/{id}/git/redeploy` - Redeploy stack from Git
- `GET /api/edge_stacks` - List edge stacks
- `GET /api/edge_stacks/{id}` - Get specific edge stack
- `GET /api/endpoints` - List environments

### Configuring Tests to Use Mock API

```powershell
$env:USE_MOCK_API = $true
$env:TEST_PORTAINER_URL = "http://localhost:9444"
Invoke-Pester
```

## CI/CD Integration

### GitHub Actions

The test suite integrates with GitHub Actions CI pipeline:

```yaml
- name: Install Pester
  run: Install-Module -Name Pester -Force -SkipPublisherCheck

- name: Run Tests
  run: .\scripts\run-tests.ps1 -CI -CodeCoverage

- name: Upload Coverage
  uses: codecov/codecov-action@v3
  with:
    files: ./tests/coverage/coverage.xml
```

### Azure DevOps

```yaml
- task: PowerShell@2
  inputs:
    targetType: 'filePath'
    filePath: '$(System.DefaultWorkingDirectory)/scripts/run-tests.ps1'
    arguments: '-CI -CodeCoverage'

- task: PublishTestResults@2
  inputs:
    testResultsFormat: 'JUnit'
    testResultsFiles: '**/test-results.xml'

- task: PublishCodeCoverageResults@1
  inputs:
    codeCoverageTool: 'Cobertura'
    summaryFileLocation: '$(System.DefaultWorkingDirectory)/tests/coverage/coverage.xml'
```

## Writing Tests

### Unit Test Template

```powershell
BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot "..\..\scripts\your-script.ps1"
}

Describe "Your-Script Tests" -Tag "Unit" {
    Context "Script Structure" {
        It "Should exist" {
            $script:ScriptPath | Should -Exist
        }

        It "Should be valid PowerShell" {
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize(
                (Get-Content $script:ScriptPath -Raw), [ref]$errors
            )
            $errors.Count | Should -Be 0
        }
    }

    Context "Functionality" {
        It "Should perform expected operation" {
            # Test logic here
        }
    }
}
```

### Integration Test Template

```powershell
BeforeAll {
    $script:PortainerUrl = $env:TEST_PORTAINER_URL ?? "http://localhost:9444"
    $script:UseMockAPI = $env:USE_MOCK_API ?? $true
}

Describe "Integration Test Name" -Tag "Integration" {
    Context "Test Scenario" {
        It "Should validate integration point" {
            if (-not $script:UseMockAPI) {
                Set-ItResult -Skipped -Because "Requires mock API"
                return
            }

            # Test logic here
        }
    }
}
```

### Best Practices

1. **Use Tags**: Tag tests with `Unit` or `Integration`
2. **Mock External Dependencies**: Use Pester mocks for external calls
3. **Skip When Appropriate**: Skip tests that require unavailable resources
4. **Clear Test Names**: Use descriptive `It` block descriptions
5. **BeforeAll/AfterAll**: Set up and tear down test state properly
6. **Test Isolation**: Ensure tests don't depend on each other

## Test Execution Order

Tests run in this order:

1. **Unit Tests** - Fast, isolated tests for individual scripts
2. **Integration Tests** - Slower tests requiring Docker/API
3. **Coverage Analysis** - Generate and validate coverage reports

## Troubleshooting

### Pester Not Found

```powershell
Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser
```

### Mock API Connection Issues

```powershell
# Verify mock server is running
Test-NetConnection localhost -Port 9444

# Check server logs
.\tests\mocks\portainer-api-mock.ps1 -Verbose
```

### Docker Not Available

Some integration tests require Docker:

```powershell
# Verify Docker is running
docker --version
docker ps

# Skip Docker-dependent tests
Invoke-Pester -ExcludeTag Integration
```

### Coverage Report Not Generated

```powershell
# Ensure CodeCoverage parameter is used
.\scripts\run-tests.ps1 -CodeCoverage

# Manually generate report
$config = New-PesterConfiguration
$config.CodeCoverage.Enabled = $true
$config.CodeCoverage.OutputPath = "tests/coverage/coverage.xml"
Invoke-Pester -Configuration $config
```

## Contributing

When adding new scripts:

1. Create corresponding unit test file in `tests/unit/`
2. Add integration tests if applicable
3. Update mock fixtures if testing API interactions
4. Ensure coverage meets thresholds
5. Update this README if introducing new test patterns

## Resources

- [Pester Documentation](https://pester.dev/)
- [Portainer API Documentation](https://docs.portainer.io/api/access)
- [PowerShell Testing Best Practices](https://pester.dev/docs/usage/mocking)
