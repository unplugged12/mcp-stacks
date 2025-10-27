BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot "..\..\scripts\validation\pre-deploy-check.ps1"
}

Describe "Pre-Deploy-Check Script Tests" -Tag "Unit" {

    Context "Script Structure" {
        It "Should exist" {
            $script:ScriptPath | Should -Exist
        }

        It "Should be valid PowerShell" {
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $script:ScriptPath -Raw), [ref]$errors)
            $errors.Count | Should -Be 0
        }

        It "Should have StackType parameter with default value" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match '\$StackType.*=.*"both"'
        }
    }

    Context "Validation Checks Implementation" {
        It "Should check Docker availability" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'docker --version'
            $content | Should -Match 'Docker available'
        }

        It "Should check Portainer UI reachability on port 9444" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'https://portainer-server\.lan:9444'
            $content | Should -Match 'Invoke-WebRequest'
        }

        It "Should check Portainer Edge tunnel on port 8000" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Test-NetConnection.*8000'
        }

        It "Should validate compose files" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'docker-compose\.yml'
            $content | Should -Match 'Test-Path'
        }

        It "Should check MCP image availability" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'mcp/context7'
            $content | Should -Match 'mcp/dockerhub'
            $content | Should -Match 'mcp/mcp-playwright'
            $content | Should -Match 'mcp/sequentialthinking'
            $content | Should -Match 'docker pull'
        }

        It "Should check Git repository status" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'git status'
        }
    }

    Context "SSL Certificate Handling" {
        It "Should handle PowerShell 6+ certificate validation" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'PSVersion\.Major.*-ge.*6'
            $content | Should -Match 'SkipCertificateCheck'
        }

        It "Should handle PowerShell 5.1 certificate validation" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'ServerCertificateValidationCallback'
        }
    }

    Context "Reporting and Exit Codes" {
        It "Should track passed and failed checks" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match '\$passedChecks'
            $content | Should -Match '\$failedChecks'
        }

        It "Should provide summary output" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Validation Summary'
            $content | Should -Match 'Passed:'
            $content | Should -Match 'Failed:'
        }

        It "Should exit 0 on success" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'exit 0'
        }

        It "Should exit 1 on failure" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'exit 1'
        }
    }

    Context "Stack Type Filtering" {
        It "Should support desktop stack type" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'desktop.*both'
        }

        It "Should support laptop stack type" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'laptop.*both'
        }

        It "Should handle compose file paths correctly" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'stacks.*desktop.*docker-compose\.yml'
            $content | Should -Match 'stacks.*laptop.*docker-compose\.yml'
        }
    }
}
