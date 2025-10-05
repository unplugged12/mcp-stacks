# Test Fixtures

This directory contains test data and mock responses for testing the mcp-stacks deployment infrastructure.

## Files

### Portainer API Mock Data

- **`mock-stacks.json`** - Mock stack definitions for Agent endpoints
  - Contains sample stack configurations with Git integration
  - Includes environment variables (secrets masked)
  - Auto-update configuration

- **`mock-edge-stacks.json`** - Mock edge stack definitions for Edge endpoints
  - Edge-specific stack configurations
  - Edge group associations
  - Deployment status

- **`mock-endpoints.json`** - Mock environment/endpoint definitions
  - Agent endpoints (Type: 1) - Direct connection
  - Edge endpoints (Type: 4) - Tunnel connection
  - Status and connectivity information

## Usage in Tests

Import fixtures in your tests:

```powershell
BeforeAll {
    $script:FixturesPath = Join-Path $PSScriptRoot "..\..\fixtures"
    $mockStacks = Get-Content "$script:FixturesPath\mock-stacks.json" -Raw | ConvertFrom-Json
}
```

## Data Structure

### Stack Type

```json
{
  "Id": 1,
  "Name": "mcp-desktop",
  "Type": 2,
  "EndpointId": 1,
  "Status": 1,
  "GitConfig": {
    "URL": "https://github.com/unplugged12/mcp-stacks",
    "ReferenceName": "refs/heads/main",
    "ConfigFilePath": "stacks/desktop/docker-compose.yml"
  }
}
```

### Edge Stack Type

```json
{
  "Id": 1,
  "Name": "mcp-laptop",
  "EdgeGroups": [1],
  "DeploymentType": 0,
  "Status": {
    "1": {
      "Type": 0,
      "Error": "",
      "EndpointId": 5
    }
  }
}
```

### Endpoint Type

```json
{
  "Id": 1,
  "Name": "desktop-jabba",
  "Type": 1,
  "URL": "192.168.1.100:9001",
  "Status": 1
}
```

## Portainer Types Reference

- **Endpoint Type 1**: Agent (Direct connection)
- **Endpoint Type 4**: Edge Agent (Tunnel connection)
- **Stack Status 1**: Active
- **Stack Status 2**: Inactive
