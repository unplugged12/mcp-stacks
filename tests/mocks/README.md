# Mock Portainer API Server

This directory contains a mock Portainer API server for offline testing.

## Usage

Start the mock server:

```powershell
.\portainer-api-mock.ps1 -Port 9444
```

The mock server will respond to common Portainer API endpoints:

- `POST /api/auth` - Returns a mock JWT token
- `GET /api/stacks` - Returns mock stack data
- `GET /api/stacks/{id}` - Returns specific stack data
- `PUT /api/stacks/{id}/git/redeploy` - Simulates stack redeploy
- `GET /api/edge_stacks` - Returns mock edge stack data
- `GET /api/edge_stacks/{id}` - Returns specific edge stack data
- `GET /api/endpoints` - Returns mock environment data

## Configuration

The mock server uses fixture data from `tests/fixtures/`:

- `mock-stacks.json` - Stack definitions
- `mock-edge-stacks.json` - Edge stack definitions
- `mock-endpoints.json` - Environment/endpoint definitions

## Testing with Mock API

Set environment variable to use mock API in tests:

```powershell
$env:USE_MOCK_API = $true
$env:TEST_PORTAINER_URL = "http://localhost:9444"
```

Then run tests:

```powershell
Invoke-Pester
```

## Notes

- The mock server runs on HTTP (not HTTPS) for simplicity
- Authentication is not enforced - any request succeeds
- Data is static and loaded from fixture files
- Useful for CI/CD pipelines where real Portainer is not available
