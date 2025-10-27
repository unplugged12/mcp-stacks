BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot "..\..\scripts\api\redeploy-stack.ps1"
}

Describe "Redeploy-Stack Script Tests" -Tag "Unit" {

    Context "Script Structure and Parameters" {
        It "Should exist" {
            $script:ScriptPath | Should -Exist
        }

        It "Should be valid PowerShell" {
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $script:ScriptPath -Raw), [ref]$errors)
            $errors.Count | Should -Be 0
        }

        It "Should have mandatory ApiKey parameter" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match '\[Parameter\(Mandatory\)\].*\$ApiKey'
        }

        It "Should have mandatory StackName parameter" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match '\[Parameter\(Mandatory\)\].*\$StackName'
        }

        It "Should have Type parameter with ValidateSet" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match '\[ValidateSet\(.*agent.*edge.*\)\]'
        }

        It "Should have default PortainerUrl parameter" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'PortainerUrl.*=.*https://portainer-server\.lan:9444'
        }
    }

    Context "API Integration Logic" {
        It "Should configure API headers correctly" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'X-API-Key.*=.*\$ApiKey'
            $content | Should -Match 'Content-Type.*=.*application/json'
        }

        It "Should handle SSL certificate validation" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'SkipCertificateCheck'
            $content | Should -Match 'ServerCertificateValidationCallback'
        }

        It "Should support both agent and edge stack types" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'if.*\$Type.*-eq.*agent'
            $content | Should -Match 'elseif.*\$Type.*-eq.*edge'
        }
    }

    Context "Agent Stack Deployment" {
        It "Should fetch stack list from API" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Invoke-RestMethod.*api/stacks'
        }

        It "Should trigger Git redeploy with correct endpoint" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'api/stacks/\$stackId/git/redeploy'
            $content | Should -Match 'endpointId=\$endpointId'
        }

        It "Should include PullImage parameter in request body" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'PullImage.*=.*\$true'
        }
    }

    Context "Edge Stack Handling" {
        It "Should fetch edge stack list from API" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'api/edge_stacks'
        }

        It "Should warn about CE limitations for edge stacks" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Business feature'
            $content | Should -Match 'Pull and redeploy'
        }
    }

    Context "Error Handling" {
        It "Should handle stack not found scenario" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Stack.*not found'
            $content | Should -Match 'Available stacks'
        }

        It "Should include try-catch blocks" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'try\s*\{'
            $content | Should -Match 'catch\s*\{'
        }

        It "Should provide troubleshooting guidance" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Troubleshooting'
            $content | Should -Match 'Verify API key'
        }
    }
}
