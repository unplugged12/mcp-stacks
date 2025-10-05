BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot "..\..\scripts\validation\post-deploy-check.ps1"
}

Describe "Post-Deploy-Check Script Tests" -Tag "Unit" {

    Context "Script Structure" {
        It "Should exist" {
            $script:ScriptPath | Should -Exist
        }

        It "Should be valid PowerShell" {
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $script:ScriptPath -Raw), [ref]$errors)
            $errors.Count | Should -Be 0
        }

        It "Should have StackPrefix parameter with default value" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match '\$StackPrefix.*=.*"mcp"'
        }
    }

    Context "Container Validation" {
        It "Should define expected MCP containers" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'mcp-context7'
            $content | Should -Match 'mcp-dockerhub'
            $content | Should -Match 'mcp-playwright'
            $content | Should -Match 'mcp-sequentialthinking'
        }

        It "Should fetch running containers" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'docker ps'
            $content | Should -Match '--format'
        }

        It "Should filter containers by prefix" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Where-Object.*\$_.*-like.*\$StackPrefix'
        }
    }

    Context "Health Check Validation" {
        It "Should inspect container status" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'docker inspect'
            $content | Should -Match 'State\.Status'
        }

        It "Should check container health status" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'State\.Health\.Status'
        }

        It "Should verify running status" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'running'
        }

        It "Should verify healthy status" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'healthy'
        }
    }

    Context "Environment Variable Validation" {
        It "Should check environment variables are loaded" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Config\.Env'
        }

        It "Should count environment variables" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'len.*\.Config\.Env'
        }
    }

    Context "Error Handling and Reporting" {
        It "Should handle no containers found scenario" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'No containers found'
        }

        It "Should handle container not found for specific services" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Container not found'
        }

        It "Should track passed and failed checks" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match '\$passedChecks'
            $content | Should -Match '\$failedChecks'
        }

        It "Should provide validation summary" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Validation Summary'
            $content | Should -Match 'Running:'
        }
    }

    Context "Exit Codes and Next Steps" {
        It "Should exit 0 when all containers are running" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'exit 0'
        }

        It "Should exit 1 on failures" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'exit 1'
        }

        It "Should suggest next steps on success" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Next steps'
            $content | Should -Match 'docker logs'
        }
    }
}
