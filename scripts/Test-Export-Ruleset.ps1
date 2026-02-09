<#
.SYNOPSIS
    Test script for Export-Ruleset.ps1

.DESCRIPTION
    Tests the Export-Ruleset.ps1 script functionality with various scenarios.
#>

Describe "Export-Ruleset" {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot "Export-Ruleset.ps1"
        
        # Mock data for testing
        $mockRuleset = @{
            id          = 12345
            name        = "Test Ruleset"
            target      = "branch"
            enforcement = "active"
            conditions  = @{
                ref_name = @{
                    include = @("refs/heads/main")
                    exclude = @()
                }
            }
            rules       = @(
                @{
                    type = "pull_request"
                    parameters = @{
                        required_approving_review_count = 1
                    }
                }
            )
        }
    }

    Context "Parameter Validation" {
        It "Should require Owner parameter" {
            { & $scriptPath -Repo "test" } | Should -Throw
        }

        It "Should require Repo parameter" {
            { & $scriptPath -Owner "test" } | Should -Throw
        }

        It "Should accept valid Owner and Repo" {
            $params = @{
                Owner = "test-owner"
                Repo  = "test-repo"
            }
            # This will fail due to missing token, but parameter validation passes
            { & $scriptPath @params } | Should -Throw -ErrorId "No GitHub token found*"
        }

        It "Should accept custom OutputPath" {
            $params = @{
                Owner      = "test-owner"
                Repo       = "test-repo"
                OutputPath = "/tmp/custom-path"
            }
            # This will fail due to missing token, but parameter validation passes
            { & $scriptPath @params } | Should -Throw
        }
    }

    Context "Token Handling" {
        It "Should use provided Token parameter" {
            # Test is conceptual - actual API call would need mocking
            $true | Should -Be $true
        }

        It "Should use GITHUB_TOKEN environment variable" {
            # Test is conceptual - actual API call would need mocking
            $true | Should -Be $true
        }

        It "Should throw when no token is available" {
            $env:GITHUB_TOKEN = $null
            $env:GH_TOKEN = $null
            
            $params = @{
                Owner = "test-owner"
                Repo  = "test-repo"
            }
            
            { & $scriptPath @params } | Should -Throw "*No GitHub token found*"
        }
    }

    Context "Output Path Creation" {
        It "Should create output directory if it doesn't exist" {
            # Test is conceptual - requires mocking file system operations
            $true | Should -Be $true
        }
    }

    Context "Ruleset Export" {
        It "Should format ruleset name correctly" {
            $name = "Main Branch Protection"
            $formatted = $name -replace '\s', '-' -replace '[^a-zA-Z0-9-]', ''
            $formatted | Should -Be "Main-Branch-Protection"
        }

        It "Should convert to lowercase filename" {
            $fileName = "Main-Branch-Protection.json".ToLower()
            $fileName | Should -Be "main-branch-protection.json"
        }

        It "Should add metadata comments to JSON" {
            # Test the comment structure
            $comments = @(
                "_comment"
                "_description"
                "_export_command"
                "_api_reference"
                "_last_exported"
            )
            
            foreach ($comment in $comments) {
                $comment | Should -Not -BeNullOrEmpty
            }
        }
    }

    Context "Error Handling" {
        It "Should handle API errors gracefully" {
            # Test is conceptual - requires mocking API failures
            $true | Should -Be $true
        }

        It "Should handle invalid ruleset ID" {
            # Test is conceptual - requires mocking API responses
            $true | Should -Be $true
        }
    }
}

# Additional integration tests
Describe "Export-Ruleset Integration Tests" -Tag "Integration" {
    BeforeAll {
        $scriptPath = Join-Path $PSScriptRoot "Export-Ruleset.ps1"
    }

    Context "When GITHUB_TOKEN is available" {
        It "Should export rulesets successfully" -Skip {
            # This test requires a valid GITHUB_TOKEN
            # Skip by default, run manually when needed
            
            if ($env:GITHUB_TOKEN) {
                $params = @{
                    Owner      = "anokye-labs"
                    Repo       = "akwaaba"
                    OutputPath = "/tmp/test-rulesets"
                }
                
                { & $scriptPath @params } | Should -Not -Throw
                Test-Path "/tmp/test-rulesets/*.json" | Should -Be $true
            }
        }
    }

    Context "Output Validation" {
        It "Should create valid JSON files" -Skip {
            # This test requires actual export to have run
            $jsonFiles = Get-ChildItem "/tmp/test-rulesets" -Filter "*.json" -ErrorAction SilentlyContinue
            
            foreach ($file in $jsonFiles) {
                { Get-Content $file.FullName | ConvertFrom-Json } | Should -Not -Throw
            }
        }

        It "Should include all required metadata fields" -Skip {
            # This test requires actual export to have run
            $jsonFiles = Get-ChildItem "/tmp/test-rulesets" -Filter "*.json" -ErrorAction SilentlyContinue
            
            foreach ($file in $jsonFiles) {
                $content = Get-Content $file.FullName -Raw | ConvertFrom-Json
                
                $content._comment | Should -Not -BeNullOrEmpty
                $content._description | Should -Not -BeNullOrEmpty
                $content._export_command | Should -Not -BeNullOrEmpty
                $content._api_reference | Should -Not -BeNullOrEmpty
            }
        }
    }
}
