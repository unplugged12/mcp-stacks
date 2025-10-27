BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot "..\..\scripts\rollback-stack.ps1"
}

Describe "Rollback-Stack Script Tests" -Tag "Unit" {

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

        It "Should have optional CommitHash parameter" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match '\[Parameter\(\)\].*\$CommitHash'
        }

        It "Should have default PortainerUrl parameter" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'PortainerUrl.*=.*https://portainer-server\.lan:9444'
        }
    }

    Context "Git Operations" {
        It "Should show recent commits if no hash provided" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'git log --oneline'
        }

        It "Should prompt for commit hash" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Read-Host.*commit hash'
        }

        It "Should validate commit hash exists" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'git show'
            $content | Should -Match 'Invalid commit hash'
        }

        It "Should perform git revert" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'git revert'
            $content | Should -Match '--no-commit'
        }

        It "Should create rollback commit" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'git commit -m.*Rollback'
        }

        It "Should push to remote" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'git push origin main'
        }
    }

    Context "Safety Confirmations" {
        It "Should display warning before rollback" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'WARNING'
            $content | Should -Match 'rollback stack'
        }

        It "Should require explicit confirmation" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match "type 'yes' to confirm"
            $content | Should -Match '\$confirm -ne.*yes'
        }

        It "Should explain what will happen" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'This operation will:'
            $content | Should -Match 'Create a new commit'
            $content | Should -Match 'Trigger Portainer'
        }
    }

    Context "Portainer API Integration" {
        It "Should configure API headers" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'X-API-Key'
            $content | Should -Match 'Content-Type.*application/json'
        }

        It "Should handle SSL certificates" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'SkipCertificateCheck'
            $content | Should -Match 'ServerCertificateValidationCallback'
        }

        It "Should fetch stack information" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Invoke-RestMethod.*api/stacks'
        }

        It "Should trigger stack redeploy" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'api/stacks/\$stackId/git/redeploy'
        }
    }

    Context "Error Handling" {
        It "Should handle invalid commit hash" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'LASTEXITCODE -ne 0'
        }

        It "Should provide abort instructions on failure" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'git revert --abort'
        }

        It "Should handle API failures gracefully" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Failed to trigger Portainer'
            $content | Should -Match 'GitOps polling will sync'
        }

        It "Should use try-catch blocks" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'try\s*\{'
            $content | Should -Match 'catch\s*\{'
        }
    }

    Context "Post-Rollback Guidance" {
        It "Should provide verification steps" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Verify deployment'
            $content | Should -Match 'post-deploy-check'
        }

        It "Should reference Portainer UI" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Check Portainer UI'
        }
    }
}
