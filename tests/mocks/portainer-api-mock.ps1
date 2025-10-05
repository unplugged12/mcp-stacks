#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Mock Portainer API server for offline testing
.DESCRIPTION
    Provides a simple HTTP server that mocks Portainer API responses.
    Used for unit and integration testing without requiring a real Portainer instance.
.PARAMETER Port
    Port to run the mock server on (default: 9444)
.EXAMPLE
    .\portainer-api-mock.ps1 -Port 9444
#>

[CmdletBinding()]
param(
    [Parameter()]
    [int]$Port = 9444
)

$ErrorActionPreference = "Stop"

Write-Host "Starting Mock Portainer API Server on port $Port..." -ForegroundColor Cyan

# Load mock data
$script:MockStacksPath = Join-Path $PSScriptRoot "..\fixtures\mock-stacks.json"
$script:MockEdgeStacksPath = Join-Path $PSScriptRoot "..\fixtures\mock-edge-stacks.json"
$script:MockEndpointsPath = Join-Path $PSScriptRoot "..\fixtures\mock-endpoints.json"

# Mock JWT token
$script:MockJWT = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.mock.token"

# HTTP listener
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()

Write-Host "Mock API listening on http://localhost:$Port" -ForegroundColor Green
Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
Write-Host ""

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        $path = $request.Url.AbsolutePath
        $method = $request.HttpMethod

        Write-Host "[$method] $path" -ForegroundColor Gray

        # Handle API routes
        $responseContent = ""
        $statusCode = 200

        switch -Regex ($path) {
            '^/api/auth$' {
                if ($method -eq 'POST') {
                    $responseContent = @{ jwt = $script:MockJWT } | ConvertTo-Json
                } else {
                    $statusCode = 405
                }
            }

            '^/api/stacks$' {
                if ($method -eq 'GET') {
                    if (Test-Path $script:MockStacksPath) {
                        $responseContent = Get-Content $script:MockStacksPath -Raw
                    } else {
                        $responseContent = '[]'
                    }
                } else {
                    $statusCode = 405
                }
            }

            '^/api/stacks/(\d+)$' {
                if ($method -eq 'GET') {
                    $stackId = $Matches[1]
                    $responseContent = @{
                        Id = [int]$stackId
                        Name = "mcp-desktop-$stackId"
                        Status = 1
                        EndpointId = 1
                    } | ConvertTo-Json
                } else {
                    $statusCode = 405
                }
            }

            '^/api/stacks/(\d+)/git/redeploy' {
                if ($method -eq 'PUT') {
                    $stackId = $Matches[1]
                    $responseContent = @{
                        Id = [int]$stackId
                        Message = "Stack redeployed successfully"
                    } | ConvertTo-Json
                } else {
                    $statusCode = 405
                }
            }

            '^/api/edge_stacks$' {
                if ($method -eq 'GET') {
                    if (Test-Path $script:MockEdgeStacksPath) {
                        $responseContent = Get-Content $script:MockEdgeStacksPath -Raw
                    } else {
                        $responseContent = '[]'
                    }
                } else {
                    $statusCode = 405
                }
            }

            '^/api/edge_stacks/(\d+)$' {
                if ($method -eq 'GET') {
                    $stackId = $Matches[1]
                    $responseContent = @{
                        Id = [int]$stackId
                        Name = "mcp-laptop-$stackId"
                        EdgeGroups = @(1)
                    } | ConvertTo-Json
                } else {
                    $statusCode = 405
                }
            }

            '^/api/endpoints$' {
                if ($method -eq 'GET') {
                    if (Test-Path $script:MockEndpointsPath) {
                        $responseContent = Get-Content $script:MockEndpointsPath -Raw
                    } else {
                        $responseContent = '[]'
                    }
                } else {
                    $statusCode = 405
                }
            }

            default {
                $statusCode = 404
                $responseContent = @{ message = "Not found" } | ConvertTo-Json
            }
        }

        # Send response
        $response.StatusCode = $statusCode
        $response.ContentType = "application/json"
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($responseContent)
        $response.ContentLength64 = $buffer.Length
        $response.OutputStream.Write($buffer, 0, $buffer.Length)
        $response.Close()

        if ($statusCode -eq 200) {
            Write-Host "  → 200 OK" -ForegroundColor Green
        } else {
            Write-Host "  → $statusCode" -ForegroundColor Yellow
        }
    }
} finally {
    $listener.Stop()
    Write-Host "Mock API server stopped" -ForegroundColor Yellow
}
