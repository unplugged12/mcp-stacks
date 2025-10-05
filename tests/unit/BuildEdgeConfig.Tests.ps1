BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot "..\..\scripts\build-edge-config.ps1"
}

Describe "Build-EdgeConfig Script Tests" -Tag "Unit" {

    Context "Script Structure and Syntax" {
        It "Should exist" {
            $script:ScriptPath | Should -Exist
        }

        It "Should be valid PowerShell" {
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $script:ScriptPath -Raw), [ref]$errors)
            $errors.Count | Should -Be 0
        }

        It "Should have proper help documentation" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match '\.SYNOPSIS'
            $content | Should -Match '\.DESCRIPTION'
            $content | Should -Match '\.EXAMPLE'
        }
    }

    Context "Environment Template Generation" {
        BeforeAll {
            Mock Write-Host {}
            Mock Read-Host { return "" }
            Mock New-Item {}
            Mock Out-File {}
            Mock Compress-Archive {}
            Mock Remove-Item {}
            Mock Test-Path { return $false }
        }

        It "Should create required directory structure" {
            # This would require mocking the actual script execution
            # For now, we validate the structure exists in the script
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'New-Item.*-ItemType Directory'
        }

        It "Should include all required environment variables in template" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'HUB_USERNAME'
            $content | Should -Match 'HUB_PAT_TOKEN'
            $content | Should -Match 'CONTEXT7_TOKEN'
        }

        It "Should handle SecureString for sensitive inputs" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match '-AsSecureString'
            $content | Should -Match 'SecureStringToBSTR'
        }
    }

    Context "Output File Handling" {
        It "Should output to edge-configs directory" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'edge-configs'
        }

        It "Should create ZIP archive" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Compress-Archive'
            $content | Should -Match 'laptops\.zip'
        }

        It "Should cleanup temporary files" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Remove-Item.*-Recurse'
        }
    }

    Context "Security Considerations" {
        It "Should not contain hardcoded secrets" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Not -Match 'ptr_[a-zA-Z0-9]+'
            $content | Should -Not -Match 'password\s*=\s*["\'][^"\']+["\']'
        }

        It "Should warn about not committing secrets" {
            $content = Get-Content $script:ScriptPath -Raw
            $content | Should -Match 'Never commit'
        }
    }
}
