BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot "..\..\scripts\install\install-edge-agent.ps1"
}

Describe "Install-Edge-Agent Script Tests" -Tag "Unit" {

    Context "Script Structure and Parameters" {
        It "Should exist" {
            $script:ScriptPath | Should -Exist
        }

        It "Should be valid PowerShell" {
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $script:ScriptPath -Raw), [ref]$errors)
            $errors.Count | Should -Be 0
        }

        It "Should have DockerCommand parameter" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match '\[Parameter\(\)\].*\$DockerCommand'
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

    Context "Edge Agent Installation Logic" {
        It "Should check for existing edge agent" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'docker ps -a.*portainer_edge_agent'
        }

        It "Should prompt for reinstall if edge agent exists" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'already exists'
            $content | Should -Match 'Remove and reinstall'
        }

        It "Should remove existing edge agent if Force is used" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'docker stop portainer_edge_agent'
            $content | Should -Match 'docker rm portainer_edge_agent'
        }
    }

    Context "User Instructions and Prompts" {
        It "Should provide step-by-step instructions" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Instructions:'
            $content | Should -Match 'Edge Agent'
            $content | Should -Match 'Standard'
        }

        It "Should prompt for docker run command if not provided" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Read-Host.*Command'
            $content | Should -Match 'docker run -d'
        }

        It "Should reference correct Portainer URL" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'https://jabba\.lan:9444'
        }

        It "Should mention laptops edge group" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Edge Group.*laptops'
        }
    }

    Context "Command Validation" {
        It "Should validate docker run command format" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'docker run'
            $content | Should -Match 'Invalid command'
        }

        It "Should warn if not an Edge Agent command" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'portainer/agent.*--edge'
            $content | Should -Match "doesn't look like"
        }

        It "Should allow continuation after warning" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Continue anyway'
        }
    }

    Context "Command Execution" {
        It "Should execute the docker command" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match '\[System.Management.Automation.PSParser\]::Tokenize'
            $content | Should -Match '& docker @dockerArgs'
        }

        It "Should verify edge agent deployment" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Edge Agent deployed successfully'
        }
    }

    Context "Post-Installation Information" {
        It "Should verify edge agent is running" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'docker ps.*portainer_edge_agent'
        }

        It "Should explain edge agent behavior" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'will:'
            $content | Should -Match 'tunnel port 8000'
            $content | Should -Match 'Poll for commands'
        }

        It "Should provide verification steps" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Verify in Portainer'
            $content | Should -Match 'Edge Configurations'
            $content | Should -Match 'Edge Stacks'
        }
    }
}
