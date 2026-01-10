BeforeAll {
    $ModuleRoot = Split-Path -Parent $PSScriptRoot
    $ModuleName = 'PSYT'
    $ManifestPath = Join-Path $ModuleRoot "$ModuleName.psd1"
    
    # Import the module for testing
    Import-Module $ManifestPath -Force
    
    # Get the private function Test-YouTubeVideoId from the module
    $Module = Get-Module $ModuleName
    $TestYouTubeVideoIdFunction = & $Module { Get-Command Test-YouTubeVideoId }
}

Describe "Get-Transcript" {
    BeforeEach {
        # Mock Test-YouTubeVideoId to return a valid video ID
        Mock Test-YouTubeVideoId -ModuleName PSYT {
            return "dQw4w9WgXcQ"
        }
        
        # Mock Get-LangOptionsWithLink to return language options
        Mock Get-LangOptionsWithLink -ModuleName PSYT {
            return @(
                [PSCustomObject]@{
                    title = "Rick Astley - Never Gonna Give You Up"
                    description = "The official video for Rick Astley's 1987 hit song Never Gonna Give You Up."
                    language = "English"
                    link = "/api/timedtext?v=dQw4w9WgXcQ&lang=en"
                }
            )
        }
        
        # Mock Get-RawTranscript to return transcript data
        Mock Get-RawTranscript -ModuleName PSYT {
            return @(
                [PSCustomObject]@{
                    start = "0.000"
                    duration = "3.200"
                    text = "We're no strangers to love"
                },
                [PSCustomObject]@{
                    start = "3.200"
                    duration = "2.800"
                    text = "You know the rules and so do I"
                },
                [PSCustomObject]@{
                    start = "6.000"
                    duration = "3.500"
                    text = "A full commitment's what I'm thinking of"
                }
            )
        }
    }
    
    Context "Basic functionality" {
        It "Should return transcript in Markdown format by default" {
            $Result = Get-Transcript -videoId "dQw4w9WgXcQ"
            
            $Result | Should -Not -BeNullOrEmpty
            $Result | Should -BeOfType [string]
            $Result | Should -Match "# Video Transcript"
            $Result | Should -Match "## Language"
            $Result | Should -Match "## Transcript"
        }
        
        It "Should return PSObject when OutputFormat is PSObject" {
            $Result = Get-Transcript -videoId "dQw4w9WgXcQ" -OutputFormat PSObject
            
            $Result | Should -Not -BeNullOrEmpty
            $Result | Should -BeOfType [PSCustomObject]
            $Result.language | Should -Be "English"
            $Result.transcript | Should -Not -BeNullOrEmpty
            $Result.transcript.Count | Should -Be 3
        }
        
        It "Should call Test-YouTubeVideoId with input string" {
            Get-Transcript -videoId "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
            
            Should -Invoke Test-YouTubeVideoId -ModuleName PSYT -ParameterFilter { 
                $InputString -eq "https://www.youtube.com/watch?v=dQw4w9WgXcQ" 
            } -Exactly 1
        }
        
        It "Should call Get-LangOptionsWithLink with video ID" {
            Get-Transcript -videoId "dQw4w9WgXcQ"
            
            Should -Invoke Get-LangOptionsWithLink -ModuleName PSYT -ParameterFilter { 
                $videoId -eq "dQw4w9WgXcQ" 
            } -Exactly 1
        }
        
        It "Should call Get-RawTranscript with caption link" {
            Get-Transcript -videoId "dQw4w9WgXcQ"
            
            Should -Invoke Get-RawTranscript -ModuleName PSYT -ParameterFilter { 
                $link -eq "/api/timedtext?v=dQw4w9WgXcQ&lang=en" 
            } -Exactly 1
        }
    }
    
    Context "Include Title functionality" {
        It "Should include title when IncludeTitle switch is used" {
            $Result = Get-Transcript -videoId "dQw4w9WgXcQ" -IncludeTitle -OutputFormat PSObject
            
            $Result.title | Should -Be "Rick Astley - Never Gonna Give You Up"
        }
        
        It "Should include title in Markdown when IncludeTitle switch is used" {
            $Result = Get-Transcript -videoId "dQw4w9WgXcQ" -IncludeTitle
            
            $Result | Should -Match "## Title"
            $Result | Should -Match "Rick Astley - Never Gonna Give You Up"
        }
        
        It "Should not include title when IncludeTitle switch is not used" {
            $Result = Get-Transcript -videoId "dQw4w9WgXcQ" -OutputFormat PSObject
            
            $Result.PSObject.Properties.Name | Should -Not -Contain "title"
        }
        
        It "Should not include title section in Markdown when IncludeTitle switch is not used" {
            $Result = Get-Transcript -videoId "dQw4w9WgXcQ"
            
            $Result | Should -Not -Match "## Title"
        }
    }
    
    Context "Include Description functionality" {
        It "Should include description when IncludeDescription switch is used" {
            $Result = Get-Transcript -videoId "dQw4w9WgXcQ" -IncludeDescription -OutputFormat PSObject
            
            $Result.description | Should -Be "The official video for Rick Astley's 1987 hit song Never Gonna Give You Up."
        }
        
        It "Should include description in Markdown when IncludeDescription switch is used" {
            $Result = Get-Transcript -videoId "dQw4w9WgXcQ" -IncludeDescription
            
            $Result | Should -Match "## Description"
            $Result | Should -Match "The official video for Rick Astley's 1987 hit song Never Gonna Give You Up."
        }
        
        It "Should not include description when IncludeDescription switch is not used" {
            $Result = Get-Transcript -videoId "dQw4w9WgXcQ" -OutputFormat PSObject
            
            $Result.PSObject.Properties.Name | Should -Not -Contain "description"
        }
        
        It "Should not include description section in Markdown when IncludeDescription switch is not used" {
            $Result = Get-Transcript -videoId "dQw4w9WgXcQ"
            
            $Result | Should -Not -Match "## Description"
        }
    }
    
    Context "Both title and description" {
        It "Should include both title and description when both switches are used" {
            $Result = Get-Transcript -videoId "dQw4w9WgXcQ" -IncludeTitle -IncludeDescription -OutputFormat PSObject
            
            $Result.title | Should -Be "Rick Astley - Never Gonna Give You Up"
            $Result.description | Should -Be "The official video for Rick Astley's 1987 hit song Never Gonna Give You Up."
        }
        
        It "Should include both sections in Markdown when both switches are used" {
            $Result = Get-Transcript -videoId "dQw4w9WgXcQ" -IncludeTitle -IncludeDescription
            
            $Result | Should -Match "## Title"
            $Result | Should -Match "## Description"
            $Result | Should -Match "Rick Astley - Never Gonna Give You Up"
            $Result | Should -Match "The official video for Rick Astley's 1987 hit song Never Gonna Give You Up."
        }
    }
    
    Context "Markdown format validation" {
        It "Should produce valid Markdown table structure" {
            $Result = Get-Transcript -videoId "dQw4w9WgXcQ"
            
            $Result | Should -Match "\| Start\s+\| Duration\s+\| Text\s+\|"
            $Result | Should -Match "\| :-------\s+\| :------\s+\| :------\s+\|"
            $Result | Should -Match "\| 0\.000\s+\| 3\.200\s+\| We're no strangers to love\s+\|"
        }
        
        It "Should include all transcript parts in Markdown table" {
            $Result = Get-Transcript -videoId "dQw4w9WgXcQ"
            
            $Result | Should -Match "We're no strangers to love"
            $Result | Should -Match "You know the rules and so do I"
            $Result | Should -Match "A full commitment's what I'm thinking of"
        }
        
        It "Should have proper Markdown heading structure" {
            $Result = Get-Transcript -videoId "dQw4w9WgXcQ"
            
            $Result | Should -Match "^# Video Transcript"
            $Result | Should -Match "## Language"
            $Result | Should -Match "## Transcript"
        }
    }
    
    Context "PSObject format validation" {
        It "Should always include language and transcript properties" {
            $Result = Get-Transcript -videoId "dQw4w9WgXcQ" -OutputFormat PSObject
            
            $Result.language | Should -Be "English"
            $Result.transcript | Should -Not -BeNullOrEmpty
            $Result.transcript | Should -BeOfType [PSCustomObject]
        }
        
        It "Should maintain transcript structure in PSObject" {
            $Result = Get-Transcript -videoId "dQw4w9WgXcQ" -OutputFormat PSObject
            
            $Result.transcript[0].start | Should -Be "0.000"
            $Result.transcript[0].duration | Should -Be "3.200"
            $Result.transcript[0].text | Should -Be "We're no strangers to love"
        }
    }
    
    Context "Error conditions" {
        It "Should return empty array when no transcripts are available" {
            Mock Get-LangOptionsWithLink -ModuleName PSYT { return @() }
            
            $Result = Get-Transcript -videoId "dQw4w9WgXcQ"
            $Result | Should -Be @()
        }
        
        It "Should return empty array when language options link is null" {
            Mock Get-LangOptionsWithLink -ModuleName PSYT {
                return @(
                    [PSCustomObject]@{
                        title = "Test Video"
                        description = "Test Description"
                        language = "English"
                        link = $null
                    }
                )
            }
            
            $Result = Get-Transcript -videoId "dQw4w9WgXcQ"
            $Result | Should -Be @()
        }
        
        It "Should handle invalid video IDs gracefully" {
            Mock Test-YouTubeVideoId -ModuleName PSYT {
                return @()
            }
            Mock Get-LangOptionsWithLink -ModuleName PSYT { return @() }
            
            $Result = Get-Transcript -videoId "invalid"
            $Result | Should -Be @()
        }
    }
    
    Context "Parameter validation" {
        It "Should require videoId parameter" {
            # Test that the function has a mandatory parameter by checking the parameter metadata
            $Function = Get-Command Get-Transcript
            $VideoIdParam = $Function.Parameters['videoId']
            $VideoIdParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] } | ForEach-Object { $_.Mandatory } | Should -Contain $true
        }
        
        It "Should validate OutputFormat parameter" {
            { Get-Transcript -videoId "dQw4w9WgXcQ" -OutputFormat "InvalidFormat" } | Should -Throw
        }
        
        It "Should accept valid OutputFormat values" {
            { Get-Transcript -videoId "dQw4w9WgXcQ" -OutputFormat "PSObject" } | Should -Not -Throw
            { Get-Transcript -videoId "dQw4w9WgXcQ" -OutputFormat "Markdown" } | Should -Not -Throw
        }
    }
    
    Context "Integration scenarios" {
        It "Should handle complete workflow for valid video" {
            $Result = Get-Transcript -videoId "https://www.youtube.com/watch?v=dQw4w9WgXcQ" -IncludeTitle -IncludeDescription
            
            $Result | Should -Not -BeNullOrEmpty
            $Result | Should -Match "# Video Transcript"
            $Result | Should -Match "## Title"
            $Result | Should -Match "## Description"
            $Result | Should -Match "## Language"
            $Result | Should -Match "## Transcript"
        }
        
        It "Should maintain proper call chain" {
            Get-Transcript -videoId "test-id" -IncludeTitle -OutputFormat PSObject
            
            Should -Invoke Test-YouTubeVideoId -ModuleName PSYT -Exactly 1
            Should -Invoke Get-LangOptionsWithLink -ModuleName PSYT -Exactly 1
            Should -Invoke Get-RawTranscript -ModuleName PSYT -Exactly 1
        }
    }
}