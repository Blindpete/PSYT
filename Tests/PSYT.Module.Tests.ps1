BeforeAll {
    $ModuleRoot = Split-Path -Parent $PSScriptRoot
    $ModuleName = 'PSYT'
    $ManifestPath = Join-Path $ModuleRoot "$ModuleName.psd1"
    $ModulePath = Join-Path $ModuleRoot "$ModuleName.psm1"
    
    # Import the module for testing
    Import-Module $ManifestPath -Force
}

Describe "PSYT Module Tests" {
    Context "Module Manifest" {
        It "Should have a valid manifest file" {
            $ManifestPath | Should -Exist
        }
        
        It "Should have a valid module file" {
            $ModulePath | Should -Exist
        }
        
        It "Should import without errors" {
            { Import-Module $ManifestPath -Force } | Should -Not -Throw
        }
        
        It "Should have correct module metadata" {
            $Manifest = Test-ModuleManifest -Path $ManifestPath
            $Manifest.Name | Should -Be 'PSYT'
            $Manifest.Version | Should -Be '0.2.0'
            $Manifest.Author | Should -Be 'Peter Cook'
            $Manifest.PowerShellVersion | Should -Be '7.4'
        }
        
        It "Should export the expected functions" {
            $ExportedFunctions = (Get-Module PSYT).ExportedFunctions.Keys
            $ExpectedFunctions = @(
                'Get-VideoPageHtml'
                'Get-LangOptionsWithLink'
                'Get-RawTranscript'
                'Get-Transcript'
            )
            
            foreach ($Function in $ExpectedFunctions) {
                $ExportedFunctions | Should -Contain $Function
            }
        }
        
        It "Should not export private functions" {
            $ExportedFunctions = (Get-Module PSYT).ExportedFunctions.Keys
            $ExportedFunctions | Should -Not -Contain 'Test-YouTubeVideoId'
        }
    }
    
    Context "Module Structure" {
        It "Should have all required files" {
            $RequiredFiles = @(
                'PSYT.psd1'
                'PSYT.psm1'
                'README.md'
                'LICENSE'
            )
            
            foreach ($File in $RequiredFiles) {
                Join-Path $ModuleRoot $File | Should -Exist
            }
        }
    }
}