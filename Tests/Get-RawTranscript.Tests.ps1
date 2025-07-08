BeforeAll {
    $ModuleRoot = Split-Path -Parent $PSScriptRoot
    $ModuleName = 'PSYT'
    $ManifestPath = Join-Path $ModuleRoot "$ModuleName.psd1"
    
    # Import the module for testing
    Import-Module $ManifestPath -Force
}

Describe "Get-RawTranscript" {
    Context "Successful transcript retrieval" {
        It "Should parse valid transcript XML" {
            # Mock Invoke-WebRequest to return valid transcript XML
            Mock Invoke-WebRequest -ModuleName PSYT {
                return [PSCustomObject]@{
                    Content = @'
<?xml version="1.0" encoding="utf-8" ?>
<transcript>
<text start="0.000" dur="2.500">Welcome to this video</text>
<text start="2.500" dur="3.200">Today we're going to learn about PowerShell</text>
<text start="5.700" dur="2.800">It's a powerful scripting language</text>
</transcript>
'@
                }
            }
            
            $Result = Get-RawTranscript -link "/api/timedtext?v=dQw4w9WgXcQ&test=true"
            
            $Result | Should -Not -BeNullOrEmpty
            $Result | Should -BeOfType [PSCustomObject]
            $Result.Count | Should -Be 3
        }
        
        It "Should include start time for each transcript part" {
            Mock Invoke-WebRequest -ModuleName PSYT {
                return [PSCustomObject]@{
                    Content = @'
<?xml version="1.0" encoding="utf-8" ?>
<transcript>
<text start="0.000" dur="2.500">Welcome to this video</text>
<text start="2.500" dur="3.200">Today we're going to learn</text>
</transcript>
'@
                }
            }
            
            $Result = Get-RawTranscript -link "/api/timedtext?test=true"
            
            $Result[0].start | Should -Be "0.000"
            $Result[1].start | Should -Be "2.500"
        }
        
        It "Should include duration for each transcript part" {
            Mock Invoke-WebRequest -ModuleName PSYT {
                return [PSCustomObject]@{
                    Content = @'
<?xml version="1.0" encoding="utf-8" ?>
<transcript>
<text start="0.000" dur="2.500">Welcome to this video</text>
<text start="2.500" dur="3.200">Today we're going to learn</text>
</transcript>
'@
                }
            }
            
            $Result = Get-RawTranscript -link "/api/timedtext?test=true"
            
            $Result[0].duration | Should -Be "2.500"
            $Result[1].duration | Should -Be "3.200"
        }
        
        It "Should include decoded text for each transcript part" {
            Mock Invoke-WebRequest -ModuleName PSYT {
                return [PSCustomObject]@{
                    Content = @'
<?xml version="1.0" encoding="utf-8" ?>
<transcript>
<text start="0.000" dur="2.500">Welcome to this video</text>
<text start="2.500" dur="3.200">Today we&apos;re going to learn about &quot;PowerShell&quot;</text>
</transcript>
'@
                }
            }
            
            $Result = Get-RawTranscript -link "/api/timedtext?test=true"
            
            $Result[0].text | Should -Be "Welcome to this video"
            $Result[1].text | Should -Be "Today we're going to learn about `"PowerShell`""
        }
        
        It "Should prepend YouTube domain to relative URLs" {
            Mock Invoke-WebRequest -ModuleName PSYT {
                return [PSCustomObject]@{
                    Content = @'
<?xml version="1.0" encoding="utf-8" ?>
<transcript>
<text start="0.000" dur="2.500">Test transcript</text>
</transcript>
'@
                }
            }
            
            Get-RawTranscript -link "/api/timedtext?v=dQw4w9WgXcQ"
            
            Should -Invoke Invoke-WebRequest -ModuleName PSYT -ParameterFilter { 
                $Uri -eq "https://www.youtube.com/api/timedtext?v=dQw4w9WgXcQ" 
            } -Exactly 1
        }
        
        It "Should use absolute URLs as-is" {
            Mock Invoke-WebRequest -ModuleName PSYT {
                return [PSCustomObject]@{
                    Content = @'
<?xml version="1.0" encoding="utf-8" ?>
<transcript>
<text start="0.000" dur="2.500">Test transcript</text>
</transcript>
'@
                }
            }
            
            Get-RawTranscript -link "https://www.youtube.com/api/timedtext?v=dQw4w9WgXcQ"
            
            Should -Invoke Invoke-WebRequest -ModuleName PSYT -ParameterFilter { 
                $Uri -eq "https://www.youtube.com/api/timedtext?v=dQw4w9WgXcQ" 
            } -Exactly 1
        }
    }
    
    Context "HTML entity decoding" {
        It "Should decode common HTML entities" {
            Mock Invoke-WebRequest -ModuleName PSYT {
                return [PSCustomObject]@{
                    Content = @'
<?xml version="1.0" encoding="utf-8" ?>
<transcript>
<text start="0.000" dur="2.500">Testing &amp; decoding &lt;entities&gt;</text>
<text start="2.500" dur="3.200">Quotes: &quot;Hello&quot; and &apos;World&apos;</text>
<text start="5.700" dur="2.800">Numbers: 1 &lt; 2 &amp; 3 &gt; 2</text>
</transcript>
'@
                }
            }
            
            $Result = Get-RawTranscript -link "/api/timedtext?test=true"
            
            $Result[0].text | Should -Be "Testing & decoding <entities>"
            $Result[1].text | Should -Be "Quotes: `"Hello`" and 'World'"
            $Result[2].text | Should -Be "Numbers: 1 < 2 & 3 > 2"
        }
        
        It "Should handle unicode characters" {
            Mock Invoke-WebRequest -ModuleName PSYT {
                return [PSCustomObject]@{
                    Content = @'
<?xml version="1.0" encoding="utf-8" ?>
<transcript>
<text start="0.000" dur="2.500">Unicode: &#8364; &#8220;smart quotes&#8221;</text>
</transcript>
'@
                }
            }
            
            $Result = Get-RawTranscript -link "/api/timedtext?test=true"
            
            $Result[0].text | Should -Not -BeNullOrEmpty
            # The actual unicode characters might vary based on system encoding
            $Result[0].text | Should -Match "Unicode:"
        }
    }
    
    Context "Empty or invalid transcript data" {
        It "Should handle empty transcript" {
            Mock Invoke-WebRequest -ModuleName PSYT {
                return [PSCustomObject]@{
                    Content = @'
<?xml version="1.0" encoding="utf-8" ?>
<transcript>
</transcript>
'@
                }
            }
            
            $Result = Get-RawTranscript -link "/api/timedtext?test=true"
            
            $Result | Should -Be @()
        }
        
        It "Should handle transcript with no text elements" {
            Mock Invoke-WebRequest -ModuleName PSYT {
                return [PSCustomObject]@{
                    Content = @'
<?xml version="1.0" encoding="utf-8" ?>
<transcript>
<metadata>Some metadata</metadata>
</transcript>
'@
                }
            }
            
            $Result = Get-RawTranscript -link "/api/timedtext?test=true"
            
            # The function processes all child nodes, so we expect one result with empty attributes
            $Result | Should -Not -BeNullOrEmpty
            $Result.Count | Should -Be 1
            $Result[0].start | Should -Be ""
            $Result[0].duration | Should -Be ""
            $Result[0].text | Should -Be "Some metadata"
        }
        
        It "Should handle malformed XML gracefully" {
            Mock Invoke-WebRequest -ModuleName PSYT {
                return [PSCustomObject]@{
                    Content = "This is not valid XML"
                }
            }
            
            { Get-RawTranscript -link "/api/timedtext?test=true" } | Should -Throw
        }
    }
    
    Context "Error conditions" {
        It "Should handle network errors" {
            Mock Invoke-WebRequest -ModuleName PSYT {
                throw "Network error"
            }
            
            { Get-RawTranscript -link "/api/timedtext?test=true" } | Should -Throw
        }
        
        It "Should handle 404 errors" {
            Mock Invoke-WebRequest -ModuleName PSYT {
                throw [System.Net.WebException]::new("The remote server returned an error: (404) Not Found.")
            }
            
            { Get-RawTranscript -link "/api/timedtext?test=true" } | Should -Throw
        }
        
        It "Should handle timeout errors" {
            Mock Invoke-WebRequest -ModuleName PSYT {
                throw [System.TimeoutException]::new("Request timeout")
            }
            
            { Get-RawTranscript -link "/api/timedtext?test=true" } | Should -Throw
        }
    }
    
    Context "Input validation" {
        It "Should handle empty link" {
            Mock Invoke-WebRequest -ModuleName PSYT {
                throw "Invalid URL"
            }
            
            { Get-RawTranscript -link "" } | Should -Throw
        }
        
        It "Should handle null link" {
            Mock Invoke-WebRequest -ModuleName PSYT {
                throw "Invalid URL"
            }
            
            { Get-RawTranscript -link $null } | Should -Throw
        }
    }
    
    Context "Transcript structure validation" {
        It "Should create proper PSCustomObject for each transcript part" {
            Mock Invoke-WebRequest -ModuleName PSYT {
                return [PSCustomObject]@{
                    Content = @'
<?xml version="1.0" encoding="utf-8" ?>
<transcript>
<text start="0.000" dur="2.500">Test text</text>
</transcript>
'@
                }
            }
            
            $Result = Get-RawTranscript -link "/api/timedtext?test=true"
            
            $Result[0] | Should -BeOfType [PSCustomObject]
            $Result[0].PSObject.Properties.Name | Should -Contain "start"
            $Result[0].PSObject.Properties.Name | Should -Contain "duration"
            $Result[0].PSObject.Properties.Name | Should -Contain "text"
        }
        
        It "Should handle missing attributes gracefully" {
            Mock Invoke-WebRequest -ModuleName PSYT {
                return [PSCustomObject]@{
                    Content = @'
<?xml version="1.0" encoding="utf-8" ?>
<transcript>
<text start="0.000">Missing duration</text>
<text dur="2.500">Missing start time</text>
<text>Missing both attributes</text>
</transcript>
'@
                }
            }
            
            $Result = Get-RawTranscript -link "/api/timedtext?test=true"
            
            $Result.Count | Should -Be 3
            $Result[0].start | Should -Be "0.000"
            $Result[0].duration | Should -Be ""
            $Result[1].start | Should -Be ""
            $Result[1].duration | Should -Be "2.500"
            $Result[2].start | Should -Be ""
            $Result[2].duration | Should -Be ""
        }
    }
}