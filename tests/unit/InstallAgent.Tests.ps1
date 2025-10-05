BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot "..\..\scripts\install\install-agent.ps1"
}

Describe "Install-Agent Script Tests" -Tag "Unit" {

    Context "Script Structure and Parameters" {
        It "Should exist" {
            $script:ScriptPath | Should -Exist
        }

        It "Should be valid PowerShell" {
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $script:ScriptPath -Raw), [ref]$errors)
            $errors.Count | Should -Be 0
        }

        It "Should have AgentPort parameter with default value" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match '\$AgentPort.*=.*"9001"'
        }

        It "Should have Force switch parameter" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match '\[switch\]\$Force'
        }
    }

    Context "Docker Validation" {
        It "Should check Docker availability" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'docker --version'
        }

        It "Should exit if Docker not found" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Docker not found'
            $content | Should -Match 'exit 1'
        }
    }

    Context "Agent Installation Logic" {
        It "Should check for existing agent" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'docker ps -a.*portainer_agent'
        }

        It "Should prompt for reinstall if agent exists" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'already exists'
            $content | Should -Match 'Remove and reinstall'
        }

        It "Should remove existing agent if Force is used" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'docker stop portainer_agent'
            $content | Should -Match 'docker rm portainer_agent'
        }

        It "Should pull latest agent image" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'docker pull portainer/agent:latest'
        }
    }

    Context "Platform-Specific Deployment" {
        It "Should handle Windows platform" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Win32NT'
            $content | Should -Match 'pipe.*docker_engine'
        }

        It "Should handle Linux/macOS platform" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match '/var/run/docker.sock'
        }

        It "Should deploy with correct parameters" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match '--name portainer_agent'
            $content | Should -Match '--restart=always'
            $content | Should -Match '-p.*9001'
        }
    }

    Context "Post-Installation Verification" {
        It "Should verify agent is running" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'docker ps.*portainer_agent'
            $content | Should -Match 'Status'
        }

        It "Should provide next steps instructions" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Next steps'
            $content | Should -Match 'Add environment'
        }
    }

    Context "Error Handling" {
        It "Should handle deployment failures" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'LASTEXITCODE'
            $content | Should -Match 'deployment failed'
        }
    }
}
